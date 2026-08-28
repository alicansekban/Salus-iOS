import Observation
import SalusCommon
import SalusDatabase
import SalusReminder
import UIKit

/// `reminderModule` (`ReminderModule.kt:18-28`) and the two app-layer types that carry it, split
/// out of `AppCompositionRoot.swift` so the composition root itself stays what it is meant to be:
/// a readable list of `let`s and the builders that fill them.
///
/// The members below are `internal` rather than `private` only because `AppCompositionRoot.init`
/// and ``AppCompositionRoot/reminderDidBecomeActive()`` live in the other file and call them.
/// Nothing here is `public`, so the reminder engine's assembly is still invisible outside the app
/// target — `makeAlarmKitBackend` stays `private`, because only this file calls it.
extension AppCompositionRoot {
    /// `reminderModule` (`ReminderModule.kt:18-28`), built in its own dependency order: the AlarmKit
    /// backend first — its presence is the "iOS 26.0+" answer every layer below routes on — then the
    /// environment and gateway over it, then the synchronizer, and last the two types that funnel
    /// events into it.
    ///
    /// A function rather than more lines in `init` because it is a graph of its own: nothing in it
    /// is reachable from the rest of the app except through the properties `init` assigns from
    /// the ``ReminderGraph`` it hands back.
    static func makeReminderGraph(
        database: SalusDatabase,
        clock: any SalusClock,
        idGenerator: any IdGenerator,
        handlers: [any ReminderHandler]
    ) -> ReminderGraph {
        let alarmKit = makeAlarmKitBackend()
        let notificationCenter = SystemUserNotificationCenter()
        let environment = SystemReminderEnvironment(
            center: notificationCenter,
            alarmKit: alarmKit.authorizing,
            backgroundRefreshAvailable: isBackgroundRefreshAvailable()
        )
        let syncState = UserDefaultsReminderSyncStateStore()
        // `getAll()`: the appointment and medication handlers landed with M4 and M5; the cycle
        // handler arrives with M6, and the engine reconciles without it until it does. A Debug
        // build may add one fake handler alongside — see `debugHandlers`.
        let handlerRegistry = ReminderHandlerRegistry(all: handlers)
        // Hoisted out of the synchronizer's argument list because the alarm dispatcher below reads
        // the same ledger: one DAO over this database, handed to both, rather than two handles that
        // could drift apart the day the DAO grows state.
        let alarmDao = ReminderAlarmDao(database: database)
        let scheduler = BackgroundRefreshScheduler(
            synchronizer: ReminderWindowSynchronizer(
                dao: alarmDao,
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
            // The authorizing seam's presence IS the "iOS 26.0+" answer, and this is the one place
            // in the app that knows it. Reminder Health needs the same fact to decide whether to
            // draw the AlarmKit row, so it is carried out of here rather than re-derived from a
            // second `#available`.
            alarmKitSupported: alarmKit.authorizing != nil,
            syncState: syncState,
            scheduler: scheduler,
            openRouter: openRouter,
            // The alarm surface's half of `HandleReminderActionUseCase`. It needs the ledger — an
            // `AppIntent` knows only the request code the alarm was scheduled under — where the
            // delegate's own dispatcher, built inside `ReminderNotificationDelegate`, does not.
            // `scheduler`, not the synchronizer under it, for the same reason the delegate takes
            // the scheduler: every refill in the app goes through the one coalescing funnel.
            actionDispatcher: ReminderActionDispatcher(
                alarmDao: alarmDao,
                registry: handlerRegistry,
                synchronizer: scheduler
            ),
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

    /// The handlers a Debug build may add alongside the real ones — today exactly one, and only
    /// when the app was launched with ``DebugReminderHandler/leadMinutesKey``.
    ///
    /// It exists because the acceptance criteria (`docs/plans/2026-08-23-ios-m3-reminder-engine.md`)
    /// are about a reminder surviving a force-quit, a timezone change and a cold period, and none of
    /// that can be walked on a device while every handler is still owed by a later milestone. A
    /// Release build has neither this list nor the type in it: both are `#if DEBUG`.
    static func debugHandlers(clock: any SalusClock) -> [any ReminderHandler] {
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
        // iOS 26.0, which is where AlarmKit itself starts — see `SystemAlarmKitScheduler`'s doc
        // comment for why this used to say 26.1 and no longer does. On 26.0 the stop button is
        // app-supplied, hence `dismissLabel`; from 26.1 up iOS draws and localizes it and the
        // label is ignored.
        if #available(iOS 26.0, *) {
            let backend = SystemAlarmKitScheduler(
                intents: AppAlarmIntents(),
                dismissLabel: ReminderStrings.alarmDismiss
            )
            return (backend, backend)
        }
        return (nil, nil)
    }

    /// `UIApplication.backgroundRefreshStatus`, sampled here because it is main-actor-only and
    /// `ReminderEnvironment.backgroundRefreshAvailable()` is neither `async` nor isolated.
    static func isBackgroundRefreshAvailable() -> Bool {
        UIApplication.shared.backgroundRefreshStatus == .available
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
/// iOS-M3 routed to the owning tab's root and no further; M4 pushes the appointment's detail screen
/// on top of it. A dose stays at the tab root (M5, decision 3): its `entityId` is the *schedule*'s
/// id, and no screen in the app is addressed by one.
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
struct ReminderGraph {
    let environment: SystemReminderEnvironment
    /// Whether this OS has AlarmKit at all — see `makeAlarmKitBackend`.
    let alarmKitSupported: Bool
    let syncState: any ReminderSyncStateStore
    let scheduler: BackgroundRefreshScheduler
    let openRouter: ReminderOpenRouter
    /// What an answered ALARM runs through. The notification surface has its own, built inside
    /// `ReminderNotificationDelegate` over the occurrence identity it is handed directly.
    let actionDispatcher: ReminderActionDispatcher
    let delegate: ReminderNotificationDelegate
}
