// The iOS twin of Android
// `core/reminder/src/main/kotlin/.../work/WorkManagerReminderScheduler.kt` and the worker it
// enqueues (`RescheduleAllRemindersWorker.kt`).
//
// Android hands both jobs to WorkManager. `enqueueUniqueWork(REPLACE)` guarantees that however
// many features ask for a sync, one worker runs — and that a request arriving while one runs
// replaces it instead of stacking a second — while `enqueueUniquePeriodicWork(12h, KEEP)` refills
// the window even if nothing else ever asks. iOS reminders run in-process and there is no
// WorkManager, so both collapse into this one type:
//
//  * **Unique work** becomes a single in-flight `Task`. Requests made before it starts collapse
//    into that pass; a request made *during* it earns exactly one more pass, which is what REPLACE
//    means once "replace the queued work" and "re-run after the current one" are the same thing.
//    This is also the only serialization the engine has: `ReminderWindowSynchronizer` is a plain
//    `Sendable` class whose `sync()` is not serialized, so two concurrent passes would reconcile
//    the same window against each other. Nothing else may call the synchronizer directly.
//  * **Periodic refill** becomes a `BGAppRefreshTaskRequest` re-submitted after every pass. iOS has
//    no periodic background task: a request is one-shot, the system decides whether and when to run
//    it, and the only way to stay armed is to arm again from inside the run. Twelve hours out,
//    Android's period.
//  * **The retry cap** (`RescheduleAllRemindersWorker`'s `MAX_RETRIES = 3`) has no twin, because
//    the thing it retried has no twin: `sync()` does not throw (see the synchronizer's delta 5), so
//    there is no failure for this type to observe and nothing to count. What a failed pass gets
//    instead is the next trigger — foreground, time change, background refresh.

import Foundation
import os
import SalusCommon

/// Names and periods the app and its `Info.plist` have to agree on.
public enum ReminderBackgroundRefresh {
    /// Must appear verbatim in `BGTaskSchedulerPermittedIdentifiers` (`project.yml`), or
    /// registration fails at launch and the window is only ever refilled while the app is open.
    public static let taskIdentifier = "com.alicansekban.salus.reminder.refresh"

    /// `ensurePeriodicRefill()`'s twelve hours (`WorkManagerReminderScheduler.kt:27`) — the
    /// earliest the system may run the refresh, never a promise that it will.
    public static let refillInterval: TimeInterval = 12 * 60 * 60
}

/// Arming the OS's background refresh. A seam because `BGTaskScheduler` cannot be constructed,
/// substituted or observed in a test — and because it does not exist at all on the macOS host
/// `swift test` builds this package for.
public protocol BackgroundRefreshRequesting: Sendable {
    /// Asks the system to run the reminder refresh task no earlier than `earliestBeginDate`.
    /// Submitting again under the same identifier replaces the pending request.
    func submitRefreshRequest(earliestBeginDate: Date)
}

/// The ``ReminderScheduler`` the app runs on: every request for a sync, from every trigger, funnels
/// through here and comes out as one coalesced reconciliation pass.
public final class BackgroundRefreshScheduler: ReminderScheduler, ReminderWindowSyncing, @unchecked Sendable {
    /// Diagnostics only, category `reminder` so `log stream` can filter to the engine. Nothing
    /// health-related is ever written (spec §12).
    private static let logger = Logger(subsystem: "com.alicansekban.salus", category: "reminder")

    private let synchronizer: any ReminderWindowSyncing
    private let backgroundRefresh: any BackgroundRefreshRequesting
    private let syncState: any ReminderSyncStateStore
    private let clock: any SalusClock
    private let refillInterval: TimeInterval

    /// Guards both fields below. A lock rather than an actor because ``ReminderScheduler``
    /// declares `requestSync()` non-`async`: a feature calls it from wherever it just finished
    /// writing, and an actor could not offer that.
    private let lock = NSLock()
    /// The pass currently absorbing requests, or nil when none is running.
    private var pass: Task<Void, Never>?
    /// Whether a pass is still owed. Set by every request, consumed by the pass loop.
    private var isDirty = false

    public init(
        synchronizer: any ReminderWindowSyncing,
        backgroundRefresh: any BackgroundRefreshRequesting,
        syncState: any ReminderSyncStateStore,
        clock: any SalusClock,
        refillInterval: TimeInterval = ReminderBackgroundRefresh.refillInterval
    ) {
        self.synchronizer = synchronizer
        self.backgroundRefresh = backgroundRefresh
        self.syncState = syncState
        self.clock = clock
        self.refillInterval = refillInterval
    }

    /// `WorkManagerReminderScheduler.requestSync()`: fire-and-forget, safe to call as often as a
    /// feature likes.
    public func requestSync() {
        _ = enqueuePass()
    }

    /// The same request, awaited — what the notification delegate's post-action refill and the
    /// background refresh task both need. Both have to know the pass HAPPENED before they return:
    /// the delegate because a snooze the handler just wrote is materialized by this pass and not by
    /// a later one, the background task because `setTaskCompleted` after a pass that never ran is
    /// a lie the system schedules against.
    public func sync() async {
        await enqueuePass().value
    }

    /// The pass currently coalescing requests, if any.
    ///
    /// Internal, and it exists for the coalescing tests: they have to await the pass their
    /// `requestSync()` calls collapsed into, and going through ``sync()`` would ask for a pass of
    /// its own — which is the very thing under test.
    var currentPass: Task<Void, Never>? {
        lock.withLock { pass }
    }

    /// Marks a pass owed and returns the one that will run it — the existing one when a pass is
    /// already in flight, a fresh one otherwise.
    private func enqueuePass() -> Task<Void, Never> {
        lock.lock()
        defer { lock.unlock() }

        isDirty = true
        if let pass {
            return pass
        }

        let created = Task { await self.runPasses() }
        pass = created
        return created
    }

    private func runPasses() async {
        while claimPass() {
            await synchronizer.sync()

            // After the pass, not before: the stamp says when the window was last reconciled, and
            // the refill is armed from the end of the work rather than the start of it.
            let completedAt = clock.now()
            syncState.recordSyncCompleted(at: completedAt)
            backgroundRefresh.submitRefreshRequest(
                earliestBeginDate: completedAt.addingTimeInterval(refillInterval)
            )
        }
    }

    /// True when a pass is owed, which also claims it. When nothing is owed it releases the
    /// in-flight slot instead.
    ///
    /// Both under the same lock as ``enqueuePass()``, which is what makes the hand-off total: a
    /// request arriving at this exact instant either sets the flag this loop is about to read, or
    /// finds the slot free and starts a pass of its own. It can never do neither.
    private func claimPass() -> Bool {
        lock.withLock {
            guard isDirty else {
                pass = nil
                return false
            }
            isDirty = false
            return true
        }
    }
}

extension ReminderBackgroundRefresh {
    /// One background reconciliation pass: refill the window, then report completion — in that
    /// order, because iOS schedules the next refresh opportunity against the answer.
    ///
    /// This is the body of the launched task minus the `BGTask` itself, and it is a function rather
    /// than four lines inside `registerTask` for one reason: `BGTaskScheduler` cannot be reached by
    /// any test. It does not exist on the macOS host `swift test` builds for, and on the simulator
    /// its daemon refuses every submission — so `_simulateLaunchForTaskWithIdentifier:` finds no
    /// scheduled request and refuses to launch anything (iOS-M3 Task 7 execution record has the
    /// commands and the error). Everything that is ours therefore lives on this side of the seam,
    /// where `BackgroundRefreshTaskBodyTests` runs it.
    ///
    /// - Parameter scheduler: the coalescing funnel, so a background pass joins a foreground one
    ///   instead of racing it.
    /// - Returns: the pass, so a caller can await it.
    @discardableResult
    static func runBackgroundPass(
        on scheduler: any ReminderWindowSyncing,
        reporting completion: BackgroundRefreshCompletion
    ) -> Task<Void, Never> {
        Task {
            await scheduler.sync()
            completion.finish(success: true)
        }
    }
}

/// Reports the outcome of a background task exactly once, whichever caller gets there first.
///
/// The whole point is the "once". `BGTask.setTaskCompleted` may be called a single time — a second
/// call terminates the app — and a launched task has two callers racing to make it: the pass that
/// finished, and the expiration handler iOS runs when it takes the time back. Neither can know
/// about the other, so the guard belongs between them.
///
/// `@unchecked Sendable` because it deliberately holds a non-`Sendable` closure: on iOS that
/// closure captures the `BGTask`, which is not `Sendable` either. The lock is what makes the
/// promise true — the closure is read and cleared under it, so it is called on exactly one thread,
/// exactly once, and never after that.
final class BackgroundRefreshCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var report: ((Bool) -> Void)?

    init(report: @escaping (Bool) -> Void) {
        self.report = report
    }

    func finish(success: Bool) {
        let pending: ((Bool) -> Void)? = lock.withLock {
            defer { report = nil }
            return report
        }
        pending?(success)
    }
}

#if os(iOS)

    import BackgroundTasks

    /// The real `BGTaskScheduler`.
    ///
    /// iOS only: `BGTaskScheduler` and `BGAppRefreshTaskRequest` are explicitly unavailable on
    /// macOS, which is the platform `swift test` builds this package for (CLAUDE.md's test-host
    /// concession). Everything above this line is therefore host-testable and this adapter is
    /// covered by `scripts/build-app.sh` plus the simulator smoke in the execution record — the
    /// same bargain `SystemAlarmKitScheduler` strikes.
    public struct SystemBackgroundRefreshRequester: BackgroundRefreshRequesting {
        private static let logger = Logger(subsystem: "com.alicansekban.salus", category: "reminder")

        public init() {}

        public func submitRefreshRequest(earliestBeginDate: Date) {
            let request = BGAppRefreshTaskRequest(identifier: ReminderBackgroundRefresh.taskIdentifier)
            request.earliestBeginDate = earliestBeginDate

            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                // Expected on the simulator, which refuses every submission
                // (`BGTaskSchedulerErrorDomain` code 1, "unavailable"), and possible on device when
                // the user has turned Background App Refresh off. Neither is recoverable here and
                // neither is a reason to stop: the foreground triggers still refill the window, and
                // Reminder Health is what tells the user the background half is not running.
                Self.logger.debug(
                    "background refresh request refused: \(String(describing: error), privacy: .private)"
                )
            }
        }
    }

    extension ReminderBackgroundRefresh {
        /// Registers the reminder refresh task. Must be called before the app finishes launching —
        /// the composition root does it from `SalusApp.init` — or iOS raises
        /// `NSInternalInconsistencyException` the first time a request is submitted.
        ///
        /// - Parameter scheduler: what a launched task runs. The app passes its
        ///   ``BackgroundRefreshScheduler``, so a background pass coalesces with a foreground one
        ///   instead of racing it.
        /// - Returns: false when the identifier is missing from `BGTaskSchedulerPermittedIdentifiers`
        ///   or was already registered.
        @discardableResult
        public static func registerTask(runningSyncOn scheduler: any ReminderWindowSyncing) -> Bool {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: taskIdentifier,
                using: nil
            ) { task in
                let completion = BackgroundRefreshCompletion { success in
                    task.setTaskCompleted(success: success)
                }
                // The system's warning shot: finish now, or be killed. There is no partial result
                // to save — a half-reconciled window is repaired by the next pass — so this only
                // reports the failure, which is how iOS learns to give the task a later slot.
                task.expirationHandler = { completion.finish(success: false) }

                runBackgroundPass(on: scheduler, reporting: completion)
            }
        }
    }

#endif
