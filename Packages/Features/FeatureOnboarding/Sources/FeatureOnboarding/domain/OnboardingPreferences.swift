// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/domain/
// OnboardingPreferences.kt`.
//
// One divergence, the same one `FeatureSettings`' `SettingsPreferences.swift` records: the setter is
// `async` to match the Kotlin `suspend fun` (`OnboardingPreferences.kt:8`), even though the
// `SalusPreferencesDataSource` setter it delegates to is synchronous. An `async` function may call a
// synchronous one, so the wrapper is a no-op hop — and the protocol stays the shape a future
// asynchronous store would need.

/// The one preference this feature owns. Narrowing it to a protocol — as `FeatureVitals` and
/// `FeatureSettings` do — keeps the ViewModel testable without a real preferences store
/// (`OnboardingPreferences.kt:3-9`).
public protocol OnboardingPreferences: Sendable {
    /// `OnboardingPreferences.kt:8` — flips the gate that decides whether the flow is shown again.
    func setCompleted() async
}
