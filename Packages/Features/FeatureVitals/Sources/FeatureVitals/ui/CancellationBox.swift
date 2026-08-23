// No Android twin: a Kotlin `ViewModel` is torn down by `onCleared()`, which runs on the main
// thread and can touch everything the ViewModel owns.
//
// Swift 6.0 has no isolated `deinit` (SE-0371 landed later), so the `deinit` of a `@MainActor`
// class is nonisolated and cannot read the class's own stored properties — which is exactly where
// the observation task an `init` started would otherwise live. Holding it here instead is what lets
// `deinit { observation.cancel() }` compile without `nonisolated(unsafe)`.

import Foundation

/// Holds at most one task, cancellable from anywhere.
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the lock is what
/// makes the promise true.
final class CancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    /// Replaces the held task and cancels whatever it displaced — the twin of `flatMapLatest`
    /// dropping its previous inner collection.
    func replace(with task: Task<Void, Never>?) {
        let previous = lock.withLock {
            let previous = self.task
            self.task = task
            return previous
        }
        previous?.cancel()
    }

    func cancel() {
        replace(with: nil)
    }
}
