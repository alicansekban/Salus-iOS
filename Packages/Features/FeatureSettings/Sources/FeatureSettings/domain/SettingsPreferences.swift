// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/domain/SettingsPreferences.kt`.
//
// Two halves of **recorded divergence (b)** land here, the same two `VitalsPreferences.swift`
// reasons out for the same store underneath:
//
//  1. Each stream is a non-throwing `AsyncStream`, not `AsyncThrowingStream`. Android's DataStore
//     `Flow` can fail on an IO error; the iOS side reads `UserDefaults` through `SalusSettings`'
//     `DefaultsValueStream`, which cannot.
//  2. The setters are `async` to match the Kotlin `suspend fun`s (`SettingsPreferences.kt:17-23`),
//     even though the `SalusPreferencesDataSource` setters they delegate to are synchronous
//     (`SalusPreferencesDataSource.swift:62-103`). An `async` function may call a synchronous one,
//     so the protocol keeps its shape and the caller stays in `await`-land; the wrapper is the
//     price of the protocol matching the Kotlin surface byte-for-byte.
//
// The narrowing — `dataSource.userSettings.map { it.field }` — is rebuilt as a `distinctUntilChanged`
// `AsyncStream` per field in `SettingsPreferencesImpl`, matching `VitalsPreferencesImpl.swift:40-55`
// and the Android `distinctUntilChanged` `SettingsPreferencesImpl.kt` carries implicitly through
// DataStore's own content-deduped `Flow`.

import SalusModel

/// The four settings the More/Settings hub reads and writes
/// (`SettingsPreferences.kt:7-23`).
///
/// A protocol so the ViewModel stays testable without a `UserDefaults`-backed
/// `SalusPreferencesDataSource` — the twin of the Kotlin `interface`.
public protocol SettingsPreferences: Sendable {
    /// `SettingsPreferences.kt:8` — the stored theme mode, then every later one, with equal
    /// consecutive values dropped.
    var themeMode: AsyncStream<ThemeMode> { get }

    /// `SettingsPreferences.kt:10` — whether the app-lock flag is on.
    var appLockEnabled: AsyncStream<Bool> { get }

    /// `SettingsPreferences.kt:12` — whether screenshot masking is on (spec §6.2).
    var secureScreenEnabled: AsyncStream<Bool> { get }

    /// `SettingsPreferences.kt:15` — the palette the user picked; stored even while they are not
    /// entitled to it.
    var premiumTheme: AsyncStream<PremiumTheme> { get }

    /// `SettingsPreferences.kt:17`.
    func setThemeMode(_ mode: ThemeMode) async

    /// `SettingsPreferences.kt:19`.
    func setAppLockEnabled(_ enabled: Bool) async

    /// `SettingsPreferences.kt:21`.
    func setSecureScreenEnabled(_ enabled: Bool) async

    /// `SettingsPreferences.kt:23`.
    func setPremiumTheme(_ theme: PremiumTheme) async
}
