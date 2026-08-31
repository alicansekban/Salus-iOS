// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/domain/
// AiLanguageProvider.kt`.

import SalusAI

/// The language the model should answer in, derived from the locale the app is running under.
///
/// Behind an interface for the same reason `:feature:settings`' `AppLocaleController` is:
/// `AppCompatDelegate` is an Android class and would throw "not mocked" in a plain JVM unit
/// test, so the ViewModel must never read it directly. On iOS the production implementation reads
/// `Bundle.main.preferredLocalizations` — the twin of Android's `ResourceAiLanguageProvider`,
/// which resolves `ai_language_code` through the resource system — and lives in the app target,
/// where the composition root builds it and hands it to the ViewModel.
public protocol AiLanguageProvider: Sendable {
    /// The language the model should answer in.
    func current() -> AiLanguage
}
