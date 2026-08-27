// No Android twin: a Kotlin `ViewModel` is torn down by `onCleared()`, which runs on the main
// thread and can touch everything the ViewModel owns.
//
// Swift 6.0 has no isolated `deinit` (SE-0371 landed later), so the `deinit` of a `@MainActor`
// class is nonisolated and cannot read the class's own stored properties — which is exactly where
// the observation task an `init` started would otherwise live. Holding it here instead is what lets
// `deinit { observation.cancel() }` compile without `nonisolated(unsafe)`.
//
// **Byte-for-byte the same helper as `FeatureVitals/ui/CancellationBox.swift` and
// `FeatureAppointments/ui/CancellationBox.swift`, on purpose.** The feature template names it as
// the mechanism every `@Observable` ViewModel uses (`docs/ios-feature-template.md:125`); features
// never depend on each other, so a shared home would mean moving it into a core package.
//
// **This is the third copy, which is the trigger the appointments copy named** ("a change that
// belongs to whichever milestone needs a third copy"). Hoisting it into `SalusCommon` is a change
// to a core package and to two features that this task may not touch — iOS-M5 Task 10 is scoped to
// `Packages/Features/FeatureMedications/**` — so the copy lands here and the hoist is carried as a
// milestone finding rather than done silently on the way past.

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
