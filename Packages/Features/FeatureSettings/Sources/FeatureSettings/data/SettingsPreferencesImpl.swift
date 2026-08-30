// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/data/SettingsPreferencesImpl.kt`.
//
// The preference store stays behind this type: nothing in `domain/` or `ui/` imports
// `SalusSettings`, so the `SalusPreferencesDataSource` surface is named in exactly one place on this
// side of the port. The same boundary `VitalsPreferencesImpl.swift` draws.
//
// **Recorded divergence (b)**, the same one `VitalsPreferencesImpl.swift` and
// `CycleReminderSettingsImpl` reason out, in two halves:
//
//  1. Each stream is rebuilt as a `distinctUntilChanged` `AsyncStream` over
//     `dataSource.userSettings`, not mapped in place. The pattern is `VitalsPreferencesImpl.swift:40-55`:
//     `AsyncStream.map` answers an `AsyncMapSequence`, and the protocol promises the concrete
//     `AsyncStream` type. `.bufferingNewest(1)` is the conflation `DefaultsValueStream` already
//     applies to the source, restated because rebuilding the stream is what mapping it costs.
//     Android's `SettingsPreferencesImpl.kt:14-23` maps each field off `dataSource.userSettings`
//     and relies on DataStore's own content-deduped `Flow` for the distinct-until-changed guard;
//     here that guard is explicit per field, because the iOS source stream publishes the whole
//     `UserSettings` on every change and a narrowing without its own dedupe would re-emit on any
//     unrelated setting flip.
//  2. The setters are `async` to satisfy the `SettingsPreferences` protocol (which matches the
//     Kotlin `suspend fun`s), but they delegate to the synchronous `SalusPreferencesDataSource`
//     setters. An `async` function may call a synchronous one, so the wrapper is a no-op hop.

import SalusModel
import SalusSettings

/// The only implementation of ``SettingsPreferences`` (`SettingsPreferencesImpl.kt:10-39`).
///
/// A `final class` rather than a struct, matching the Kotlin: it is one long-lived collaborator the
/// composition root holds, not a value anything copies. Its single stored property is an immutable
/// `Sendable` reference, so the protocol's `Sendable` conformance is checked rather than promised.
final class SettingsPreferencesImpl: SettingsPreferences {
    private let dataSource: SalusPreferencesDataSource

    init(dataSource: SalusPreferencesDataSource) {
        self.dataSource = dataSource
    }

    /// `SettingsPreferencesImpl.kt:14` — the whole `UserSettings` narrowed to `themeMode`,
    /// `distinctUntilChanged` (the `VitalsPreferencesImpl.swift:40-55` shape).
    var themeMode: AsyncStream<ThemeMode> {
        narrowed { $0.themeMode }
    }

    /// `SettingsPreferencesImpl.kt:16-17`.
    var appLockEnabled: AsyncStream<Bool> {
        narrowed { $0.appLockEnabled }
    }

    /// `SettingsPreferencesImpl.kt:19-20`.
    var secureScreenEnabled: AsyncStream<Bool> {
        narrowed { $0.secureScreenEnabled }
    }

    /// `SettingsPreferencesImpl.kt:22-23`.
    var premiumTheme: AsyncStream<PremiumTheme> {
        narrowed { $0.premiumTheme }
    }

    /// `SettingsPreferencesImpl.kt:25-27`.
    func setThemeMode(_ mode: ThemeMode) async {
        dataSource.setThemeMode(mode)
    }

    /// `SettingsPreferencesImpl.kt:29-31`.
    func setAppLockEnabled(_ enabled: Bool) async {
        dataSource.setAppLockEnabled(enabled)
    }

    /// `SettingsPreferencesImpl.kt:33-35`.
    func setSecureScreenEnabled(_ enabled: Bool) async {
        dataSource.setSecureScreenEnabled(enabled)
    }

    /// `SettingsPreferencesImpl.kt:37-39`.
    func setPremiumTheme(_ theme: PremiumTheme) async {
        dataSource.setPremiumTheme(theme)
    }

    /// The shared distinct-until-changed narrowing — `VitalsPreferencesImpl.swift:40-55`, factored
    /// once because all four streams are the same shape.
    ///
    /// Each stream subscribes to `dataSource.userSettings` independently; the four subscriptions
    /// are what Android's four `map` calls produce too, and each dedupes its own field so a change
    /// to one setting does not re-emit the others. Cancellation ends the iteration:
    /// `AsyncStream` terminates its iterator when the consuming task is cancelled, and
    /// `onTermination` cancels the narrowing task so a consumer that goes away stops the underlying
    /// subscription too.
    private func narrowed<T: Equatable & Sendable>(
        _ select: @escaping @Sendable (UserSettings) -> T
    ) -> AsyncStream<T> {
        let settings = dataSource.userSettings
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                var previous: T?
                for await value in settings {
                    guard select(value) != previous else { continue }
                    previous = select(value)
                    continuation.yield(select(value))
                }
                continuation.finish()
            }
            // A consumer that stops reading must stop the underlying subscription too.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
