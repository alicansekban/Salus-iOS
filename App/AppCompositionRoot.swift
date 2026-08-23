import FeatureVitals
import Foundation
import Observation
import os
import SalusCommon
import SalusDatabase
import SalusModel
import SalusNavigation
import SalusProfile
import SalusSettings
import SalusUI

/// Where the object graph gets assembled — the iOS twin of Android's Koin container
/// (`app/src/main/kotlin/com/alicansekban/salus/di/AppModules.kt`, whose `salusModules` list is
/// started from `SalusApplication.onCreate`).
///
/// Salus on iOS wires its dependencies by hand rather than pulling in a DI framework: the
/// dependency allowlist is closed at three and holds no container (CLAUDE.md), and a hand-written
/// root is both readable and trivially substitutable in tests. Concretely, this type is the single
/// place that knows how to build a real dependency.
///
/// Everything below is a `let`, and every one of them is what Koin calls a `single`: one instance
/// for the process, created here and handed down. There is no global and no shared singleton —
/// `SalusApp` owns the instance and injects it with `.environment(_:)`, so a test (or a future
/// second scene) builds its own graph instead of mutating a static one.
///
/// Build order below follows the dependency edges, which is also the order `salusModules` lists
/// them in (`AppModules.kt:55-76`): clock and ids first, then the database, then the stores built
/// over it, then the process-lifetime controllers.
@MainActor
@Observable
final class AppCompositionRoot {
    /// Boot diagnostics only. Category `boot` so `xcrun simctl spawn booted log stream` can filter
    /// to it; nothing health-related is ever written here (spec §12).
    static let logger = Logger(subsystem: "com.alicansekban.salus", category: "boot")

    /// `commonModule`: the single time source every repository is injected with, so no call site
    /// reaches for `Date()` (`architecture-rules.md`: "inject SalusClock").
    let clock: any SalusClock

    /// `commonModule`: ids come from here, never from a call site.
    let idGenerator: any IdGenerator

    /// `databaseModule`: opened and migrated at launch.
    let database: SalusDatabase

    /// `databaseModule`: Room's `salusDatabase.profileDao()`.
    let profileDao: ProfileDao

    /// The app-lock flag's store. Keychain rather than `UserDefaults` — see
    /// `KeychainAppLockFlagStore`; it is the one setting whose backing store differs from the
    /// other twelve, because a flag that gates access must not be clearable by a backup restore.
    let appLockFlagStore: any AppLockFlagStore

    /// `dataStoreModule`: the twelve `UserDefaults`-backed settings plus the Keychain-backed lock.
    let preferences: SalusPreferencesDataSource

    /// `aiModule`'s usage counters (`ai_free_summary_used`, `ai_calls_count`, `ai_calls_epoch_day`).
    let aiUsage: AiUsageDataSource

    /// `profileModule`: `single<ProfileRepository> { ProfileRepositoryImpl(get(), get()) }`.
    let profileRepository: any ProfileRepository

    /// `appModule` (`AppModules.kt:37-41`): "Outlives every screen: an undo window must survive the
    /// ViewModel of the screen the delete was triggered from."
    let pendingDelete: PendingDeleteController

    /// `navigationModule`: publishes what ViewModels ask for; the shell applies it.
    let navigator: Navigator

    /// The twin of the one `SnackbarHostState` `SalusApp.kt:106-136` remembers: the app has exactly
    /// one, and `RootView` mounts exactly one `SalusSnackbarHost` over it. A screen cannot own one —
    /// deleting from the editor pops that screen, and the undo has to appear on the list underneath.
    let snackbar: SalusSnackbarController

    /// `vitalsModule` (`feature/vitals/.../di/VitalsModule.kt`), built once and handed to the vitals
    /// tab through the environment. It owns the feature's `single` repository and the
    /// `UndoableDelete` built over `pendingDelete` + `snackbar`, so nothing here re-creates either.
    let vitalsModule: VitalsModule

    /// `single<VitalsQuickEntry> { … }` — Kotlin's `bind VitalsQuickEntry::class`
    /// (`VitalsModule.kt:26`). A computed property rather than a stored one because the Koin
    /// registration it ports is a `factory`: every caller gets a fresh use case over the same
    /// repository. Nothing consumes it yet; onboarding's "current weight" step (M6) is the caller
    /// this exists for, and exposing it here is what keeps that step from opening a second graph.
    var vitalsQuickEntry: any VitalsQuickEntry { vitalsModule.makeSaveWeightEntryUseCase() }

    init() {
        let clock = SystemSalusClock()
        let database = Self.openDatabase(clock: clock)
        let appLockFlagStore = KeychainAppLockFlagStore()
        let profileDao = ProfileDao(database: database)

        let idGenerator = UUIDIdGenerator()
        let pendingDelete = PendingDeleteController()
        let navigator = Navigator()
        let snackbar = SalusSnackbarController()

        self.clock = clock
        self.idGenerator = idGenerator
        self.database = database
        self.profileDao = profileDao
        self.appLockFlagStore = appLockFlagStore
        preferences = SalusPreferencesDataSource(defaults: .standard, appLockFlagStore: appLockFlagStore)
        aiUsage = AiUsageDataSource(defaults: .standard)
        // The root's own DAO, so the app builds exactly one over this database (Koin's `get()`).
        profileRepository = makeProfileRepository(profileDao: profileDao, clock: clock)
        self.pendingDelete = pendingDelete
        self.navigator = navigator
        self.snackbar = snackbar
        // The locals above rather than `self.…`: `vitalsModule` is still uninitialised here, so the
        // instance is not whole yet and Swift will not let this read its own stored properties.
        vitalsModule = makeVitalsModule(
            vitalsDao: VitalsDao(database: database),
            clock: clock,
            idGenerator: idGenerator,
            pendingDeletes: pendingDelete,
            snackbar: snackbar,
            navigator: navigator
        )
    }

    /// Commits every open undo window.
    ///
    /// The twin of `MainActivity.onStop` (`MainActivity.kt:111-116`): "Undo windows do not survive
    /// backgrounding: a deletion the user confirmed must not linger unresolved across a process
    /// death." `scenePhase == .background` is iOS's `onStop`, and `SalusApp` is what calls this —
    /// inside a `beginBackgroundTask` window, because unlike `onStop` this is `async` and iOS would
    /// otherwise be free to suspend the process partway through the commit.
    func commitPendingDeletes() async {
        await pendingDelete.commitAll()
    }

    /// One boot line proving the migration ran and the seeded default profile is readable.
    ///
    /// The id only — never a name, never a health field. `default-profile` is a constant
    /// (`SalusDatabase.defaultProfileId`), not user data, which is what makes it safe to log.
    func logSeededProfile() async {
        do {
            let id = try await profileRepository.getProfile()?.id ?? "<none>"
            Self.logger.info("database ready, default profile id=\(id, privacy: .public)")
        } catch {
            Self.logger.error("default profile unreadable: \(String(describing: error), privacy: .public)")
        }
    }

    /// Opens `<Application Support>/salus.db`, creating the directory first.
    ///
    /// `SalusDatabase.init` does not create parent directories, and `Application Support` — unlike
    /// `Documents` — is not created for an app by the system. Two things can fail here, and both
    /// are fatal: a health log that cannot open its store must not run silently, showing empty
    /// screens and quietly discarding everything the user types into it. Android reaches the same
    /// end by a different road — Room throws on first query — so this is the port of a behaviour,
    /// not a new policy.
    private static func openDatabase(clock: any SalusClock) -> SalusDatabase {
        let fileManager = FileManager.default
        do {
            let directory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let path = directory.appendingPathComponent(SalusDatabase.name).path
            return try SalusDatabase(path: path, clock: clock)
        } catch {
            let reason = String(describing: error)
            logger.critical("cannot open \(SalusDatabase.name, privacy: .public): \(reason, privacy: .public)")
            fatalError("Salus cannot open its database (\(SalusDatabase.name)): \(reason)")
        }
    }
}
