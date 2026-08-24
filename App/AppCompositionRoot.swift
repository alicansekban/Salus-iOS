import FeatureSettings
import FeatureVitals
import Foundation
import Observation
import os
import SalusCommon
import SalusDatabase
import SalusModel
import SalusNavigation
import SalusProfile
import SalusReminder
import SalusSettings
import SalusUI
import UIKit
import UserNotifications

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

    /// `settingsModule` (`feature/settings/.../di/SettingsModule.kt`), built once and handed to the
    /// More tab through the environment. It is the only consumer of the three reminder properties
    /// below that a user ever sees: Reminder Health reads them and offers the two prompts.
    let settingsModule: SettingsModule

    /// `reminderModule`'s `single<ReminderEnvironment>` (`ReminderModule.kt:20`) — the honest
    /// read of what the OS will and will not let the reminder pipeline do. Reminder Health
    /// (iOS-M3 Task 8) is what shows it to the user.
    let reminderEnvironment: any ReminderEnvironment

    /// The write half of the same object: the two authorization prompts Reminder Health's fix
    /// buttons drive. Nothing in the engine ever asks — a prompt is a user-visible action, and it
    /// belongs to the screen that offered the button.
    let reminderAuthorization: any ReminderAuthorizationRequesting

    /// When the engine last reconciled the window. Read by Reminder Health, written by the
    /// scheduler after every pass.
    let reminderSyncState: any ReminderSyncStateStore

    /// `single { WorkManagerReminderScheduler(...) } bind ReminderScheduler::class`
    /// (`ReminderModule.kt:28`). Exposed as the protocol, because a feature's only business with it
    /// is "something I own changed, refill the window" — M4/M5/M6 inject exactly this.
    let reminderScheduler: any ReminderScheduler

    /// Where a tapped reminder notification lands until the shell picks it up.
    let reminderOpenRouter: ReminderOpenRouter

    /// The same object as ``reminderScheduler``, kept concretely because two callers need more
    /// than the protocol: the background task needs to *await* a pass, and the notification
    /// delegate needs the same coalescing funnel rather than the raw synchronizer.
    private let backgroundRefreshScheduler: BackgroundRefreshScheduler

    /// The same object as ``reminderEnvironment``, kept concretely for the one thing only the app
    /// layer can do: re-sample `UIApplication.backgroundRefreshStatus`, which is main-actor-only.
    private let systemReminderEnvironment: SystemReminderEnvironment

    /// `UNUserNotificationCenter.delegate` is a **weak** reference, so the graph is what keeps the
    /// delegate alive. Dropping this property would silently stop every reminder action from
    /// reaching its handler.
    private let reminderDelegate: ReminderNotificationDelegate

    /// The system-event observers ``startReminderEngine()`` installs — the twin of Android's
    /// `SystemEventsReceiver` manifest entry. Held because `addObserver(forName:)` returns a token
    /// that unregisters when it is released.
    @ObservationIgnored private var systemEventObservers: [any NSObjectProtocol] = []

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
        // `reminderModule` (`ReminderModule.kt:18-28`), assembled in one place — see
        // `makeReminderGraph`. The five properties below are five views of that one sub-graph.
        let reminder = Self.makeReminderGraph(database: database, clock: clock, idGenerator: idGenerator)
        systemReminderEnvironment = reminder.environment
        reminderEnvironment = reminder.environment
        reminderAuthorization = reminder.environment
        reminderSyncState = reminder.syncState
        backgroundRefreshScheduler = reminder.scheduler
        reminderScheduler = reminder.scheduler
        reminderOpenRouter = reminder.openRouter
        reminderDelegate = reminder.delegate

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
        settingsModule = makeSettingsModule(
            reminderEnvironment: reminder.environment,
            reminderAuthorization: reminder.environment,
            reminderSyncState: reminder.syncState,
            clock: clock,
            alarmKitSupported: reminder.alarmKitSupported
        )
    }

    /// Everything the reminder engine needs installed before the app finishes launching.
    ///
    /// Called from `SalusApp.init`, and it has to be: `BGTaskScheduler.register` throws
    /// `NSInternalInconsistencyException` if the first request is submitted after launch completes,
    /// and a notification tapped from a cold start is delivered as soon as the delegate exists —
    /// installed later, the tap is simply lost.
    ///
    /// The two observers below are the iOS twin of Android's `SystemEventsReceiver`
    /// (`receiver/SystemEventsReceiver.kt`), minus the actions that have no meaning here:
    /// `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`, because pending notification requests survive
    /// both a reboot and an app update (iOS holds them, not the app), and
    /// `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`, which has no iOS permission behind it. The
    /// third trigger, the foreground reconcile, is ``reminderDidBecomeActive()``.
    func startReminderEngine() {
        UNUserNotificationCenter.current().delegate = reminderDelegate

        if !ReminderBackgroundRefresh.registerTask(runningSyncOn: backgroundRefreshScheduler) {
            // Registration fails when the identifier is missing from
            // `BGTaskSchedulerPermittedIdentifiers`. Nothing crashes; the window is simply never
            // refilled in the background, which is exactly the state Reminder Health reports.
            Self.logger.error(
                """
                background refresh task \
                \(ReminderBackgroundRefresh.taskIdentifier, privacy: .public) \
                was refused registration
                """
            )
        }

        let scheduler = backgroundRefreshScheduler
        let notificationCenter = NotificationCenter.default
        systemEventObservers = [
            // `ACTION_TIMEZONE_CHANGED`: every materialized occurrence was computed in the old
            // zone, so the whole window is stale.
            Notification.Name.NSSystemTimeZoneDidChange,
            // `ACTION_TIME_CHANGED`, plus the midnight rollover iOS folds into the same
            // notification.
            UIApplication.significantTimeChangeNotification
        ].map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                scheduler.requestSync()
            }
        }
    }

    /// The foreground reconcile: `scenePhase == .active`.
    ///
    /// Two things, in this order. The background-refresh sample first, because the user may have
    /// just come back from Settings having changed it — and because the sync's own decisions read
    /// the environment. Then the pass itself, which is what makes opening the app the most
    /// reliable refill trigger the engine has.
    func reminderDidBecomeActive() {
        systemReminderEnvironment.setBackgroundRefreshAvailable(Self.isBackgroundRefreshAvailable())
        reminderScheduler.requestSync()
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

    /// `reminderModule` (`ReminderModule.kt:18-28`), built in its own dependency order: the AlarmKit
    /// backend first — its presence is the "iOS 26.1+" answer every layer below routes on — then the
    /// environment and gateway over it, then the synchronizer, and last the two types that funnel
    /// events into it.
    ///
    /// A function rather than more lines in `init` because it is a graph of its own: nothing in it
    /// is reachable from the rest of the app except through the five properties above.
    private static func makeReminderGraph(
        database: SalusDatabase,
        clock: any SalusClock,
        idGenerator: any IdGenerator
    ) -> ReminderGraph {
        let alarmKit = makeAlarmKitBackend()
        let notificationCenter = SystemUserNotificationCenter()
        let environment = SystemReminderEnvironment(
            center: notificationCenter,
            alarmKit: alarmKit.authorizing,
            backgroundRefreshAvailable: isBackgroundRefreshAvailable()
        )
        let syncState = UserDefaultsReminderSyncStateStore()
        // `getAll()` with nothing registered yet: the medication, appointment and cycle handlers
        // arrive with M4/M5/M6, and the engine reconciles an empty window until they do. A Debug
        // build can install one fake handler in their place — see `debugHandlers`.
        let handlerRegistry = ReminderHandlerRegistry(all: debugHandlers(clock: clock))
        let scheduler = BackgroundRefreshScheduler(
            synchronizer: ReminderWindowSynchronizer(
                dao: ReminderAlarmDao(database: database),
                gateway: UserNotificationGateway(
                    center: notificationCenter,
                    alarmScheduler: alarmKit.scheduling
                ),
                handlerRegistry: handlerRegistry,
                environment: environment,
                clock: clock,
                idGenerator: idGenerator,
                config: .ios
            ),
            backgroundRefresh: SystemBackgroundRefreshRequester(),
            syncState: syncState,
            clock: clock
        )
        let openRouter = ReminderOpenRouter()

        return ReminderGraph(
            environment: environment,
            // The authorizing seam's presence IS the "iOS 26.1+" answer, and this is the one place
            // in the app that knows it. Reminder Health needs the same fact to decide whether to
            // draw the AlarmKit row, so it is carried out of here rather than re-derived from a
            // second `#available`.
            alarmKitSupported: alarmKit.authorizing != nil,
            syncState: syncState,
            scheduler: scheduler,
            openRouter: openRouter,
            delegate: ReminderNotificationDelegate(
                handlerRegistry: handlerRegistry,
                // The scheduler, not the synchronizer underneath it: every trigger in the app goes
                // through the one coalescing funnel, so a notification action's refill cannot run
                // concurrently with the foreground or background pass it landed in the middle of.
                synchronizer: scheduler,
                onOpen: { ref in
                    Task { @MainActor in openRouter.open(ref) }
                }
            )
        )
    }

    /// The handlers a Debug build may add to the empty registry — today exactly one, and only when
    /// the app was launched with ``DebugReminderHandler/leadMinutesKey``.
    ///
    /// It exists because the acceptance criteria (`docs/plans/2026-08-23-ios-m3-reminder-engine.md`)
    /// are about a reminder surviving a force-quit, a timezone change and a cold period, and none of
    /// that can be walked on a device while every handler is still owed by a later milestone. A
    /// Release build has neither this list nor the type in it: both are `#if DEBUG`.
    private static func debugHandlers(clock: any SalusClock) -> [any ReminderHandler] {
        #if DEBUG
            if let handler = DebugReminderHandler(clock: clock) {
                return [handler]
            }
        #endif
        return []
    }

    /// The AlarmKit backend, or a pair of nils below the version that has one.
    ///
    /// The one place in the app that names an OS version. `SystemAlarmKitScheduler` fulfils both
    /// seams, so it is built once and handed out twice — the gateway routes on the scheduling half
    /// being present, Reminder Health on the authorizing half.
    private static func makeAlarmKitBackend() -> (
        scheduling: (any AlarmKitScheduling)?,
        authorizing: (any AlarmKitAuthorizing)?
    ) {
        // iOS 26.1 rather than 26.0 — see `SystemAlarmKitScheduler`'s doc comment.
        if #available(iOS 26.1, *) {
            let backend = SystemAlarmKitScheduler()
            return (backend, backend)
        }
        return (nil, nil)
    }

    /// `UIApplication.backgroundRefreshStatus`, sampled here because it is main-actor-only and
    /// `ReminderEnvironment.backgroundRefreshAvailable()` is neither `async` nor isolated.
    private static func isBackgroundRefreshAvailable() -> Bool {
        UIApplication.shared.backgroundRefreshStatus == .available
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

/// Where a tapped reminder notification waits for the shell.
///
/// The delegate runs off the main actor and knows only the occurrence; the tab bar lives in
/// `RootView` and knows only tabs. This is the one value between them: the delegate publishes,
/// `RootView` observes and consumes. It exists as a type of its own rather than as a closure into
/// the shell because a notification tapped from a cold start arrives before any view is on screen —
/// the ref has to survive until something is there to route it.
///
/// iOS-M3 routes to the owning tab's root and no further. The push onto the detail screen needs a
/// navigation key per reminder type, which arrives with M4/M5.
@MainActor
@Observable
final class ReminderOpenRouter {
    /// The occurrence waiting to be shown, if any.
    private(set) var pending: ReminderRef?

    func open(_ ref: ReminderRef) {
        pending = ref
    }

    /// Takes the pending occurrence and clears it, so a tab switch happens once per tap.
    func consume() -> ReminderRef? {
        defer { pending = nil }
        return pending
    }
}

/// The reminder engine's sub-graph, handed back from `makeReminderGraph` in one piece.
private struct ReminderGraph {
    let environment: SystemReminderEnvironment
    /// Whether this OS has AlarmKit at all — see `makeAlarmKitBackend`.
    let alarmKitSupported: Bool
    let syncState: any ReminderSyncStateStore
    let scheduler: BackgroundRefreshScheduler
    let openRouter: ReminderOpenRouter
    let delegate: ReminderNotificationDelegate
}
