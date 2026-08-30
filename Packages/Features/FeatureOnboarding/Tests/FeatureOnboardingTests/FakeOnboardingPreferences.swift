// Ported 1:1 from the private `FakeOnboardingPreferences` in
// `feature/onboarding/src/test/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingViewModelTest.kt:62-68`.
//
// Kotlin's `var completed = false` becomes a lock-guarded read, because the flag is flipped from the
// ViewModel's write task and read from the test's main actor — the same `@unchecked Sendable` over a
// lock that every fake in this tree uses.

import Foundation

@testable import FeatureOnboarding

/// An ``OnboardingPreferences`` that only remembers whether it was told the flow finished
/// (`OnboardingViewModelTest.kt:62-68`).
final class FakeOnboardingPreferences: OnboardingPreferences, @unchecked Sendable {
    private let lock = NSLock()
    private var completedValue = false
    private let orderLog: FinishOrderLog?

    /// `OnboardingViewModelTest.kt:63` — `var completed`.
    var completed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completedValue
    }

    init(orderLog: FinishOrderLog? = nil) {
        self.orderLog = orderLog
    }

    /// `OnboardingViewModelTest.kt:65-67`.
    func setCompleted() async {
        markCompleted()
    }

    private func markCompleted() {
        lock.lock()
        completedValue = true
        lock.unlock()
        orderLog?.record(.completionFlag)
    }
}
