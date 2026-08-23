import Foundation

/// A stand-in for a snackbar's auto-dismiss wait, released by the test rather than by the clock.
///
/// The same seam `PendingDeleteController` uses (`SalusCommon/PendingDeleteController.swift:56`):
/// Kotlin drives Compose's `delay` with `runTest`'s virtual clock, Swift Testing has none, so the
/// wait is injected. Nothing in `SalusSnackbarControllerTests` ever waits on wall-clock time.
actor SnackbarSleepGate {
    /// Every duration the controller asked to sleep for, in order — this is how the tests assert
    /// that Android's 4000 ms really is the number reaching the timer.
    private(set) var durations: [Duration] = []

    private var waiting: [CheckedContinuation<Void, any Error>] = []
    private var arrivalWatchers: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []

    /// The injected sleep: records the duration, then suspends until `fire()`.
    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        releaseArrivalWatchers()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { waiting.append($0) }
        } onCancel: {
            Task { await self.cancelAll() }
        }
    }

    /// Suspends until `count` waits have reached the gate, so "the timer has not fired yet" is a
    /// real assertion rather than a race with a task that has not started.
    func waitForArrivals(_ count: Int) async {
        if durations.count >= count {
            return
        }
        await withCheckedContinuation { arrivalWatchers.append((count, $0)) }
    }

    /// Lets every waiting timer through — the twin of the clock reaching the timeout.
    func fire() {
        let resumed = waiting
        waiting = []
        for continuation in resumed {
            continuation.resume()
        }
    }

    private func cancelAll() {
        let resumed = waiting
        waiting = []
        for continuation in resumed {
            continuation.resume(throwing: CancellationError())
        }
    }

    private func releaseArrivalWatchers() {
        let reached = arrivalWatchers.filter { durations.count >= $0.target }
        arrivalWatchers.removeAll { durations.count >= $0.target }
        for watcher in reached {
            watcher.continuation.resume()
        }
    }
}
