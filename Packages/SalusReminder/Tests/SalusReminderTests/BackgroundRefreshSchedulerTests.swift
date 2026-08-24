// The coalescing contract of `BackgroundRefreshScheduler`, the iOS twin of Kotlin's
// `WorkManagerReminderScheduler` (`work/WorkManagerReminderScheduler.kt`).
//
// Android gets uniqueness from WorkManager: `enqueueUniqueWork(REPLACE)` guarantees that however
// many features ask for a sync, one worker runs, and a request arriving while one runs replaces it
// rather than stacking a second. iOS reminders run in-process, so the same two properties have to
// be built here — and they are the reason this type exists at all, because
// `ReminderWindowSynchronizer` is a plain `Sendable` class whose `sync()` is not serialized.
//
// The two properties, and the two cases that pin them:
//
//  * Requests that arrive before a pass starts collapse into that ONE pass (the unique-work half).
//  * A request that arrives while a pass is running earns exactly one more pass (the REPLACE
//    half) — never one per request, and never zero, which would drop the write that asked.
//
// Everything else here is what each pass owes afterwards: the `lastSyncCompletedAt` stamp Reminder
// Health reads, and the re-submitted background-refresh request that is the periodic-refill twin
// of `ensurePeriodicRefill()`.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import SalusReminder

/// Blocks the synchronizer's first pass until the test lets it go, so a request can be made to
/// arrive provably *during* a pass rather than by hoping the scheduler is slow.
///
/// A class with a lock because `ReminderWindowSyncing` is `Sendable` and the pass runs on whichever
/// executor the scheduler's `Task` landed on.
final class GatedWindowSynchronizer: ReminderWindowSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var completedPasses = 0
    private var isHeld = false
    private var released: [CheckedContinuation<Void, Never>] = []
    private var started: [CheckedContinuation<Void, Never>] = []
    private var startedPasses = 0

    /// How many passes have run to completion.
    var passes: Int { lock.withLock { completedPasses } }

    /// Makes every pass park until ``release()``.
    func hold() {
        lock.withLock { isHeld = true }
    }

    /// Lets every parked pass — and every later one — through.
    func release() {
        let waiting: [CheckedContinuation<Void, Never>] = lock.withLock {
            isHeld = false
            defer { released = [] }
            return released
        }
        waiting.forEach { $0.resume() }
    }

    /// Suspends until a pass has actually begun.
    func waitForPassToStart() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if startedPasses > 0 {
                lock.unlock()
                continuation.resume()
                return
            }
            started.append(continuation)
            lock.unlock()
        }
    }

    func sync() async {
        let waiters: [CheckedContinuation<Void, Never>] = lock.withLock {
            startedPasses += 1
            defer { started = [] }
            return started
        }
        waiters.forEach { $0.resume() }

        await parkIfHeld()
        lock.withLock { completedPasses += 1 }
    }

    private func parkIfHeld() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            guard isHeld else {
                lock.unlock()
                continuation.resume()
                return
            }
            released.append(continuation)
            lock.unlock()
        }
    }
}

/// Records what the scheduler asked the OS to schedule, without a `BGTaskScheduler` in sight.
final class RecordingBackgroundRefreshRequester: BackgroundRefreshRequesting, @unchecked Sendable {
    private let lock = NSLock()
    private var submitted: [Date] = []

    /// Every submitted `earliestBeginDate`, in order.
    var submissions: [Date] { lock.withLock { submitted } }

    func submitRefreshRequest(earliestBeginDate: Date) {
        lock.withLock { submitted.append(earliestBeginDate) }
    }
}

/// The `lastSyncCompletedAt` store, in memory.
final class InMemoryReminderSyncStateStore: ReminderSyncStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stamps: [Date] = []

    /// Every recorded completion, in order — so a case can tell "written once" from "written per
    /// pass".
    var recorded: [Date] { lock.withLock { stamps } }

    var lastSyncCompletedAt: Date? { lock.withLock { stamps.last } }

    func recordSyncCompleted(at instant: Date) {
        lock.withLock { stamps.append(instant) }
    }
}

@Suite("Background refresh scheduler")
struct BackgroundRefreshSchedulerTests {
    /// 2025-08-24T02:26:40Z, the instant the reminder suites are written around.
    static let now = Date(epochMilliseconds: 1_756_000_000_000)

    private let synchronizer = GatedWindowSynchronizer()
    private let requester = RecordingBackgroundRefreshRequester()
    private let syncState = InMemoryReminderSyncStateStore()
    private let clock = FixedSalusClock(now: BackgroundRefreshSchedulerTests.now, timeZone: .gmt)

    private func makeScheduler() -> BackgroundRefreshScheduler {
        BackgroundRefreshScheduler(
            synchronizer: synchronizer,
            backgroundRefresh: requester,
            syncState: syncState,
            clock: clock
        )
    }

    @Test("requests made before the pass starts collapse into one sync")
    func requestsCoalesceIntoOnePass() async {
        let scheduler = makeScheduler()

        scheduler.requestSync()
        scheduler.requestSync()
        scheduler.requestSync()
        await scheduler.currentPass?.value

        #expect(synchronizer.passes == 1)
    }

    @Test("a request made during a pass earns exactly one more pass")
    func requestDuringPassRunsOneMore() async {
        let scheduler = makeScheduler()
        synchronizer.hold()

        scheduler.requestSync()
        await synchronizer.waitForPassToStart()
        // Two writes landing while the first pass is mid-flight: the window has to be reconciled
        // again afterwards, but once, not twice.
        scheduler.requestSync()
        scheduler.requestSync()
        synchronizer.release()
        await scheduler.currentPass?.value

        #expect(synchronizer.passes == 2)
    }

    @Test("sync() runs a pass of its own and waits for it")
    func syncAwaitsItsOwnPass() async {
        let scheduler = makeScheduler()

        // The delegate's post-action refill and the background task both come through here, and
        // both need the pass to have HAPPENED when the call returns — the snooze the handler just
        // wrote is materialized by this pass, not by a later one.
        await scheduler.sync()

        #expect(synchronizer.passes == 1)
    }

    @Test("every pass stamps lastSyncCompletedAt with the clock")
    func everyPassStampsLastSync() async {
        let scheduler = makeScheduler()

        await scheduler.sync()
        clock.advanceTo(Self.now.addingTimeInterval(.hours(3)))
        await scheduler.sync()

        #expect(syncState.recorded == [Self.now, Self.now.addingTimeInterval(.hours(3))])
    }

    @Test("every pass re-submits the background refresh request 12 hours out")
    func everyPassResubmitsTheRefreshRequest() async {
        let scheduler = makeScheduler()

        await scheduler.sync()
        await scheduler.sync()

        // `ensurePeriodicRefill()`'s 12-hour period, re-armed from the end of each pass: iOS has no
        // periodic background task, so the refill is a fresh one-shot request every time.
        let expected = Self.now.addingTimeInterval(ReminderBackgroundRefresh.refillInterval)
        #expect(requester.submissions == [expected, expected])
    }

    @Test("the background refresh task identifier is the one Info.plist permits")
    func taskIdentifierIsPinned() {
        // `BGTaskSchedulerPermittedIdentifiers` in `project.yml` carries this string verbatim.
        // Registering an identifier the Info.plist does not list fails at launch, and a background
        // sync that never runs is invisible until a user's reminders quietly stop refilling.
        #expect(ReminderBackgroundRefresh.taskIdentifier == "com.alicansekban.salus.reminder.refresh")
        #expect(ReminderBackgroundRefresh.refillInterval == 12 * 60 * 60)
    }
}
