// No Android twin: a Kotlin `ViewModel` is torn down by `onCleared()`, which runs on the main
// thread and can touch everything the ViewModel owns.
//
// Swift 6.0 has no isolated `deinit` (SE-0371 landed later), so the `deinit` of a `@MainActor`
// class is nonisolated and cannot read the class's own stored properties — which is exactly where
// the observation task an `init` started would otherwise live. Holding it here instead is what lets
// `deinit { observation.cancel() }` compile without `nonisolated(unsafe)`.
//
// It lived as a byte-identical copy in `FeatureVitals`, `FeatureAppointments` and
// `FeatureMedications` until iOS-M6: features never depend on each other, so the template
// sanctioned the duplicate and named the third copy as the moment it moves
// (`docs/plans/2026-08-27-ios-m5-medications.md`, ruling 8). This is that move. It belongs in
// `SalusCommon` rather than `SalusUI` because it is plain Swift concurrency — no UI framework — and
// the domain-layer rule holds.

import Foundation

/// Holds at most one task, cancellable from anywhere.
///
/// `@unchecked Sendable` for `FixedSalusClock`'s reason: the state is mutable, and the lock is what
/// makes the promise true.
public final class CancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    public init() {}

    /// Replaces the held task and cancels whatever it displaced — the twin of `flatMapLatest`
    /// dropping its previous inner collection.
    public func replace(with task: Task<Void, Never>?) {
        let previous = lock.withLock {
            let previous = self.task
            self.task = task
            return previous
        }
        previous?.cancel()
    }

    public func cancel() {
        replace(with: nil)
    }
}
