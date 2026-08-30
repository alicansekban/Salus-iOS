import FeatureAppointments
import FeatureCycle
import FeatureHome
import FeatureMedications
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

    /// `appointmentsModule` (`feature/appointments/.../di/AppointmentsModule.kt`), built once and
    /// handed to the appointments tab through the environment. It also owns the reminder handler
    /// the registry below is built with, so the engine and the screens read one repository.
    let appointmentsModule: AppointmentsModule

    /// `medicationsModule` (`feature/medications/.../di/MedicationsModule.kt`), built once and
    /// handed to the medications tab through the environment. Like the appointments module it owns
    /// the reminder handler the registry below is built with, so the dose engine and the screens
    /// read one repository.
    let medicationsModule: MedicationsModule

    /// `cycleModule` (`feature/cycle/.../di/CycleModule.kt`), built once and handed to the two tabs
    /// that can reach the calendar — More, which offers the row, and Home, which a tapped cycle
    /// reminder lands on (iOS-M6 rulings 1 and 2). Cycle has no tab of its own in v1, so unlike the
    /// three modules above this one is injected into stacks whose roots belong to nobody.
    let cycleModule: CycleModule

    /// `settingsModule` (`feature/settings/.../di/SettingsModule.kt`), built once and handed to the
    /// More tab through the environment. `settingsModule` is built from local values at
    /// construction, not from the three reminder properties below — those `let`s exist to keep the
    /// reminder surface alive and visible on the root, and the settings module is handed the same
    /// instances at construction time so Reminder Health reads them and offers the two prompts.
    let settingsModule: SettingsModule

    /// `homeModule` (`feature/home/.../di/HomeModule.kt`), built once and handed to the Home tab
    /// through the environment. Its `TodayRepository` joins what the other modules own, and its
    /// "Al" button is Medications' `MarkDoseTakenUseCase`, reached through
    /// ``MedicationsModule/makeMarkDoseTakenUseCase()`` in ``makeHomeGraph(infrastructure:medications:)``.
    let homeModule: HomeModule

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

    /// What an alarm's buttons run through, once ``startReminderEngine()`` has handed it to
    /// ``AlarmActionBridge``. Held here because the graph owns it: the bridge keeps a reference,
    /// not ownership, and an intent that arrives before the bind waits for this value.
    private let alarmActionDispatcher: ReminderActionDispatcher

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
    /// repository. Nothing consumes it yet; onboarding's "current weight" step (M8) is the caller
    /// this exists for, and exposing it here is what keeps that step from opening a second graph.
    var vitalsQuickEntry: any VitalsQuickEntry { vitalsModule.makeSaveWeightEntryUseCase() }

    init() {
        let infrastructure = Self.makeInfrastructure()
        clock = infrastructure.clock
        idGenerator = infrastructure.idGenerator
        database = infrastructure.database
        profileDao = infrastructure.profileDao
        appLockFlagStore = infrastructure.appLockFlagStore
        preferences = infrastructure.preferences
        aiUsage = infrastructure.aiUsage
        profileRepository = infrastructure.profileRepository
        pendingDelete = infrastructure.pendingDelete
        navigator = infrastructure.navigator
        snackbar = infrastructure.snackbar

        // One line per module, which is the point of the split: a feature added in a later
        // milestone costs a `let` above and an assignment here, not a paragraph of wiring.
        let modules = Self.makeFeatureModules(infrastructure: infrastructure)
        vitalsModule = modules.vitals
        appointmentsModule = modules.appointments
        medicationsModule = modules.medications
        cycleModule = modules.cycle
        settingsModule = modules.settings
        homeModule = modules.home

        // `reminderModule` (`ReminderModule.kt:18-28`), assembled in one place — see
        // `makeReminderGraph`. The properties below are eight views of that one sub-graph.
        let reminder = modules.reminder
        systemReminderEnvironment = reminder.environment
        reminderEnvironment = reminder.environment
        reminderAuthorization = reminder.environment
        reminderSyncState = reminder.syncState
        backgroundRefreshScheduler = reminder.scheduler
        reminderScheduler = reminder.scheduler
        reminderOpenRouter = reminder.openRouter
        alarmActionDispatcher = reminder.actionDispatcher
        reminderDelegate = reminder.delegate
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

        // An alarm's buttons run an `AppIntent`, which the system instantiates and which therefore
        // cannot be handed the graph in an `init` — see `AlarmActionBridge`. This is the bind, done
        // as early as the process has a graph at all: iOS may have launched the app for no reason
        // other than to run that intent, and an intent that got there first is waiting on it.
        let dispatcher = alarmActionDispatcher
        Task { await AlarmActionBridge.shared.bind(dispatcher) }

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
            Self.logger.error("default profile unreadable: \(String(describing: error), privacy: .private)")
        }
    }

    /// `commonModule`, `databaseModule`, `dataStoreModule`, `profileModule` and `appModule` in one
    /// value: the process-lifetime singletons everything else is built over.
    ///
    /// The database opens first because every store below reads it and because a store that cannot
    /// open is a fatal launch failure — see `openDatabase`.
    private static func makeInfrastructure() -> Infrastructure {
        let clock = SystemSalusClock()
        let database = openDatabase(clock: clock)
        let appLockFlagStore = KeychainAppLockFlagStore()
        // The root's own DAO, so the app builds exactly one over this database (Koin's `get()`).
        let profileDao = ProfileDao(database: database)
        return Infrastructure(
            clock: clock,
            idGenerator: UUIDIdGenerator(),
            database: database,
            profileDao: profileDao,
            appLockFlagStore: appLockFlagStore,
            preferences: SalusPreferencesDataSource(defaults: .standard, appLockFlagStore: appLockFlagStore),
            aiUsage: AiUsageDataSource(defaults: .standard),
            profileRepository: makeProfileRepository(profileDao: profileDao, clock: clock),
            pendingDelete: PendingDeleteController(),
            navigator: Navigator(),
            snackbar: SalusSnackbarController()
        )
    }

    /// Every feature module, each the twin of a Koin feature module and each built exactly once,
    /// together with the reminder sub-graph they were wired against.
    ///
    /// A function rather than a run of statements in `init` because the reminder engine and the
    /// modules that feed it are the one cycle in the app's graph, and this is where it is broken.
    /// Everything here is a local, so a module is reachable from the next one without the
    /// half-initialized-`self` dance `init` would otherwise have to do.
    private static func makeFeatureModules(infrastructure: Infrastructure) -> FeatureModules {
        let database = infrastructure.database
        let clock = infrastructure.clock
        let idGenerator = infrastructure.idGenerator
        // The one cycle in the graph, broken here. `makeReminderGraph` builds the handler registry
        // and the scheduler together as one immutable value, the appointment handler needs the
        // repository, and the repository needs a scheduler — so the modules are built first against
        // a relay, and the relay is pointed at the real scheduler once there is one. See
        // `ReminderSchedulerRelay`.
        let reminderRelay = ReminderSchedulerRelay()
        let scheduled = makeScheduledModules(infrastructure: infrastructure, reminderScheduler: reminderRelay)
        let reminder = makeReminderGraph(
            database: database,
            clock: clock,
            idGenerator: idGenerator,
            // `single<ReminderHandler>(named(APPOINTMENT))` (`AppointmentsModule.kt:32-35`) and its
            // `named(MEDICATION)` (`MedicationsModule.kt:35-38`) and `named(CYCLE)`
            // (`CycleModule.kt:37-45`) twins reaching `getAll()` — the registry is what Koin's
            // qualified lookup becomes here. All three the app owns are now registered.
            handlers: debugHandlers(clock: clock) + [
                scheduled.appointments.reminderHandler,
                scheduled.medications.reminderHandler,
                scheduled.cycle.reminderHandler
            ]
        )
        // Now that there is a scheduler, everything the module already handed out starts working.
        // Nothing has called `requestSync()` in between — see `ReminderSchedulerRelay` for why a
        // call that did would still be correct.
        reminderRelay.bind(reminder.scheduler)

        let vitals = makeVitalsModule(
            vitalsDao: VitalsDao(database: database),
            preferences: infrastructure.preferences,
            clock: clock,
            idGenerator: idGenerator,
            pendingDeletes: infrastructure.pendingDelete,
            snackbar: infrastructure.snackbar,
            navigator: infrastructure.navigator
        )
        let home = makeHomeGraph(infrastructure: infrastructure, medications: scheduled.medications)
        let settings = makeSettingsModule(
            reminderEnvironment: reminder.environment,
            reminderAuthorization: reminder.environment,
            reminderSyncState: reminder.syncState,
            clock: clock,
            alarmKitSupported: reminder.alarmKitSupported,
            profileRepository: infrastructure.profileRepository,
            navigator: infrastructure.navigator,
            // The four More-specific deps (T6). `preferencesDataSource` is the one
            // `SalusPreferencesDataSource` the root already owns; the factory builds the
            // `SettingsPreferencesImpl` over it inside the package, because that impl is the one
            // of the four that is `internal` to `FeatureSettings`. The other three are `public`
            // and are built here, where every other singleton is: `localeController` is the
            // `UserDefaultsAppLocaleController` over `.standard`, `premiumStatus` is the
            // `FreeOnlyMorePremiumStatus` stand-in (ruling 5) and `paywallRequester` is the
            // `NoOpPaywallRequester` stand-in (ruling 5 — M9 swaps the last two here).
            preferencesDataSource: infrastructure.preferences,
            localeController: UserDefaultsAppLocaleController(defaults: .standard),
            premiumStatus: FreeOnlyMorePremiumStatus(),
            paywallRequester: NoOpPaywallRequester()
        )
        return FeatureModules(
            reminder: reminder,
            vitals: vitals,
            appointments: scheduled.appointments,
            medications: scheduled.medications,
            cycle: scheduled.cycle,
            settings: settings,
            home: home
        )
    }

    /// The three modules that own a reminder handler, and are therefore built before there is a
    /// scheduler to hand them — see the relay in ``makeFeatureModules(infrastructure:)``.
    ///
    /// Split out for the same reason `init` was split in M5: a milestone that adds a fourth
    /// scheduled feature should cost one call here and one field on the result, not another ten
    /// lines in a function already at the 60-line limit.
    private static func makeScheduledModules(
        infrastructure: Infrastructure,
        reminderScheduler: ReminderSchedulerRelay
    ) -> ScheduledModules {
        let database = infrastructure.database
        let clock = infrastructure.clock
        let idGenerator = infrastructure.idGenerator
        let appointments = makeAppointmentsModule(
            appointmentDao: AppointmentDao(database: database),
            profileRepository: infrastructure.profileRepository,
            reminderScheduler: reminderScheduler,
            clock: clock,
            idGenerator: idGenerator,
            pendingDeletes: infrastructure.pendingDelete,
            snackbar: infrastructure.snackbar,
            navigator: infrastructure.navigator
        )
        // The dose handler needs the repository, and the repository needs a scheduler.
        let medications = makeMedicationsModule(
            medicationDao: MedicationDao(database: database),
            reminderScheduler: reminderScheduler,
            clock: clock,
            idGenerator: idGenerator,
            pendingDeletes: infrastructure.pendingDelete,
            snackbar: infrastructure.snackbar,
            navigator: infrastructure.navigator
        )
        // A third variant of the same reason: the cycle handler reads the periods the calendar
        // writes, and the calendar asks the scheduler to refill the window whenever a period
        // starts, ends, or the reminder setting changes.
        let cycle = makeCycleModule(
            cycleDao: CycleDao(database: database),
            preferences: infrastructure.preferences,
            reminderScheduler: reminderScheduler,
            clock: clock,
            idGenerator: idGenerator,
            navigator: infrastructure.navigator
        )
        return ScheduledModules(appointments: appointments, medications: medications, cycle: cycle)
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
            logger.critical("cannot open \(SalusDatabase.name, privacy: .public): \(reason, privacy: .private)")
            fatalError("Salus cannot open its database (\(SalusDatabase.name)): \(reason)")
        }
    }
}

/// The process-lifetime singletons, handed back from `makeInfrastructure` in one piece.
///
/// `internal` rather than `private` because ``AppCompositionRoot/makeHomeGraph(infrastructure:medications:)``
/// lives in `AppCompositionRoot+Modules.swift` and takes it.
struct Infrastructure {
    let clock: any SalusClock
    let idGenerator: any IdGenerator
    let database: SalusDatabase
    let profileDao: ProfileDao
    let appLockFlagStore: any AppLockFlagStore
    let preferences: SalusPreferencesDataSource
    let aiUsage: AiUsageDataSource
    let profileRepository: any ProfileRepository
    let pendingDelete: PendingDeleteController
    let navigator: Navigator
    let snackbar: SalusSnackbarController
}
