// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/data/
// OnboardingPreferencesImpl.kt`.
//
// The preference store stays behind this type: nothing in `domain/` or `ui/` imports
// `SalusSettings`, so the `SalusPreferencesDataSource` surface is named in exactly one place on this
// side of the port — the same boundary `SettingsPreferencesImpl.swift` draws.

import SalusSettings

/// The only implementation of ``OnboardingPreferences`` (`OnboardingPreferencesImpl.kt:6-13`).
///
/// A `final class` rather than a struct, matching the Kotlin: it is one long-lived collaborator the
/// composition root holds, not a value anything copies. Its single stored property is an immutable
/// `Sendable` reference, so the protocol's `Sendable` conformance is checked rather than promised.
public final class OnboardingPreferencesImpl: OnboardingPreferences {
    private let dataSource: SalusPreferencesDataSource

    public init(dataSource: SalusPreferencesDataSource) {
        self.dataSource = dataSource
    }

    /// `OnboardingPreferencesImpl.kt:10-12` — `dataSource.setOnboardingCompleted(true)`. The key is
    /// Android-verbatim `onboarding_completed`, pinned by `SalusSettings`' own tests.
    public func setCompleted() async {
        dataSource.setOnboardingCompleted(true)
    }
}
