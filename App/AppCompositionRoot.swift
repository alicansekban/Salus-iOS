import Foundation
import Observation
import os
import SalusCommon
import SalusDatabase
import SalusNavigation
import SalusProfile
import SalusSettings

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

    init() {
        let clock = SystemSalusClock()
        let database = Self.openDatabase(clock: clock)
        let appLockFlagStore = KeychainAppLockFlagStore()

        self.clock = clock
        idGenerator = UUIDIdGenerator()
        self.database = database
        profileDao = ProfileDao(database: database)
        self.appLockFlagStore = appLockFlagStore
        preferences = SalusPreferencesDataSource(defaults: .standard, appLockFlagStore: appLockFlagStore)
        aiUsage = AiUsageDataSource(defaults: .standard)
        profileRepository = makeProfileRepository(database: database, clock: clock)
        pendingDelete = PendingDeleteController()
        navigator = Navigator()
    }

    /// Commits every open undo window.
    ///
    /// The twin of `MainActivity.onStop` (`MainActivity.kt:111-116`): "Undo windows do not survive
    /// backgrounding: a deletion the user confirmed must not linger unresolved across a process
    /// death." `scenePhase == .background` is iOS's `onStop`.
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
