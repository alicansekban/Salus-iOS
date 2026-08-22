// The undo-window controller, ported 1:1 from Android
// `core/common/src/main/kotlin/com/alicansekban/salus/core/common/PendingDeleteController.kt`.
//
// Two Kotlin mechanisms have no twin here, and both are replaced by structured concurrency rather
// than by a Swift imitation of themselves:
//
//   * The injected `CoroutineScope` (`PendingDeleteController.kt:29`) is gone. Kotlin needs a
//     scope because the controller outlives every screen and its own delay has to be cancellable;
//     a `Task` created inside a `@MainActor` type is already both — it inherits the actor and is
//     cancelled through the handle stored below. `DispatcherProvider` therefore has no Swift twin
//     either, which is the ruling this port was written under.
//   * `delay(windowMillis)` (`PendingDeleteController.kt:47`) is injected as `sleep` instead of
//     being called directly. Kotlin gets a virtual clock from `runTest`; Swift Testing has none,
//     so the wait is the seam. Production passes `Task.sleep`, and the tests pass a gate they open
//     by hand — which is what keeps `PendingDeleteControllerTests` free of wall-clock waiting.
//
// `MutableStateFlow` becomes `@Observable` state: SwiftUI observes `pendingIds` the way Compose
// collects the flow. `Observation` is not a UI framework, so it is allowed in this layer
// (`CLAUDE.md`, layer rules) — that is the whole reason the property is not a SwiftUI type.
//
// `commitNow` and `commitAll` are `async` where Kotlin's are not. Kotlin's are synchronous only
// because they hand the suspension to `scope.launch`; with the scope gone the suspension surfaces
// in the signature, and the caller's own `Task { }` is what `scope.launch` was. The alternative —
// an unawaited `Task` inside the method — would make "the deletion has been written" unobservable
// to the app shell that calls `commitAll()` as the app stops, which is the one caller that must be
// able to wait for it.

import Observation

/// Holds deletions for an undo window and only then writes them.
///
/// Deletes in Salus are hard deletes that cascade into schedules, intake logs and reminder
/// rows, so "delete now, re-insert on undo" would have to reconstruct a whole aggregate —
/// including intake history the repository contract promises to preserve. Deferring the
/// write sidesteps that: nothing is deleted until the window closes, and the worst failure
/// mode (process death inside the window) leaves the record intact.
///
/// This is an application-scoped singleton on purpose. Deleting from a detail screen pops
/// back to the list, which destroys that screen's model; a timer living there would be
/// cancelled mid-window.
///
/// Ported from `PendingDeleteController.kt:12-80`. Every method runs on the main actor, which is
/// what keeps the bookkeeping below free of locks — the twin of Kotlin's "every method must be
/// called from `scope`'s dispatcher".
@MainActor
@Observable
public final class PendingDeleteController {
    /// How long a deletion can be taken back, in milliseconds (`PendingDeleteController.kt:78`).
    public static let undoWindowMillis = 5000

    /// Ids whose deletion is scheduled; list screens filter these out so the row vanishes at once
    /// (`PendingDeleteController.kt:36`).
    public private(set) var pendingIds: Set<String> = []

    private let windowMillis: Int
    private let sleep: @Sendable (Duration) async throws -> Void
    private var jobs: [String: Task<Void, Never>] = [:]
    private var commits: [String: @Sendable () async -> Void] = [:]

    /// - Parameters:
    ///   - windowMillis: how long the window stays open (`PendingDeleteController.kt:30`).
    ///   - sleep: how the window waits. Injected so tests close a window on demand instead of
    ///     waiting for one; production has no reason to pass anything but the default.
    public init(
        windowMillis: Int = PendingDeleteController.undoWindowMillis,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.windowMillis = windowMillis
        self.sleep = sleep
    }

    /// Starts the undo window for `id`; `commit` runs when it closes
    /// (`PendingDeleteController.kt:42-50`).
    ///
    /// Scheduling an id that is already pending replaces both the window and the commit, so a
    /// second delete of the same row never writes twice.
    public func schedule(id: String, commit: @escaping @Sendable () async -> Void) {
        jobs.removeValue(forKey: id)?.cancel()
        commits[id] = commit
        pendingIds.insert(id)
        jobs[id] = Task { [weak self] in
            guard let self else { return }
            do {
                try await sleep(.milliseconds(windowMillis))
            } catch {
                // What `delay` does when its job is cancelled: stop, write nothing.
                return
            }
            // An injected sleep is under no obligation to throw on cancellation, so the window
            // asks once more before writing. `Task.sleep` has already thrown by this point.
            guard !Task.isCancelled else { return }
            await runCommit(id: id)
        }
    }

    /// Cancels the pending deletion; the row comes back without a repository round trip
    /// (`PendingDeleteController.kt:53-57`).
    ///
    /// Undoing an id whose window has already closed does nothing: the commit has been taken out
    /// of the map by then, so there is nothing left to cancel and nothing to resurrect.
    public func undo(id: String) {
        jobs.removeValue(forKey: id)?.cancel()
        commits.removeValue(forKey: id)
        pendingIds.remove(id)
    }

    /// Closes the window early, e.g. when the app is backgrounded
    /// (`PendingDeleteController.kt:60-63`).
    public func commitNow(id: String) async {
        jobs.removeValue(forKey: id)?.cancel()
        await runCommit(id: id)
    }

    /// Called when the app stops, so a deletion never lingers unresolved across a process death
    /// (`PendingDeleteController.kt:66-68`).
    public func commitAll() async {
        // Snapshotted before the loop, exactly as Kotlin reads `_pendingIds.value` once:
        // `commitNow` empties the set as it goes.
        let scheduled = pendingIds
        for id in scheduled {
            await commitNow(id: id)
        }
    }

    /// The task that closes `id`'s undo window, for this package's tests to await instead of
    /// waiting on wall-clock time. Internal on purpose: the app never needs it.
    func windowTask(id: String) -> Task<Void, Never>? {
        jobs[id]
    }

    /// Drops the job, runs the commit, then drops the id — the order Kotlin's `runCommit` uses
    /// (`PendingDeleteController.kt:70-75`).
    ///
    /// Taking the commit out of the map before running it is what makes a commit run at most once:
    /// a window that closes after `commitNow` has already written finds nothing and returns.
    private func runCommit(id: String) async {
        jobs.removeValue(forKey: id)
        guard let commit = commits.removeValue(forKey: id) else { return }
        await commit()
        pendingIds.remove(id)
    }
}
