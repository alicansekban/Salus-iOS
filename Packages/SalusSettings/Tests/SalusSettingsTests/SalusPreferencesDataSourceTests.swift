import Foundation
import SalusModel
import Testing

@testable import SalusSettings

// Ported from Android `core/datastore/.../SalusPreferencesDataSource.kt`, which has no test class
// of its own: on Android the reader is a one-line `map` over DataStore and the enum decoding is
// covered by `:core:model`. The iOS store carries more of its own machinery — the absent/zero
// distinction `DataStore` gets for free, the Keychain detour for `app_lock_enabled`, and the
// change stream — so each of those gets a test here.

/// One setter row: what to call, and the `UserSettings` the store must read back afterwards.
///
/// Every field of `UserSettings` defaults to the Android default (`Settings.kt:18-33`), so an
/// expectation names only the field its setter touched — a setter that writes a second key would
/// fail the comparison.
struct SetterRow: Sendable, CustomStringConvertible {
    let name: String
    let apply: @Sendable (SalusPreferencesDataSource) -> Void
    let expected: UserSettings

    var description: String { name }
}

/// All ten setters of `SalusPreferencesDataSource.kt:37-75`, in declaration order.
let setterRows: [SetterRow] = [
    SetterRow(
        name: "setThemeMode",
        apply: { $0.setThemeMode(.dark) },
        expected: UserSettings(themeMode: .dark)
    ),
    SetterRow(
        name: "setAppLockEnabled",
        apply: { $0.setAppLockEnabled(true) },
        expected: UserSettings(appLockEnabled: true)
    ),
    SetterRow(
        name: "setSecureScreenEnabled",
        apply: { $0.setSecureScreenEnabled(true) },
        expected: UserSettings(secureScreenEnabled: true)
    ),
    SetterRow(
        name: "setOnboardingCompleted",
        apply: { $0.setOnboardingCompleted(true) },
        expected: UserSettings(onboardingCompleted: true)
    ),
    SetterRow(
        name: "setGlucoseUnit",
        apply: { $0.setGlucoseUnit(.mmolL) },
        expected: UserSettings(glucoseUnit: .mmolL)
    ),
    SetterRow(
        name: "setCycleReminderEnabled",
        apply: { $0.setCycleReminderEnabled(true) },
        expected: UserSettings(cycleReminderEnabled: true)
    ),
    SetterRow(
        name: "setCycleReminderLeadDays",
        apply: { $0.setCycleReminderLeadDays(3) },
        expected: UserSettings(cycleReminderLeadDays: 3)
    ),
    SetterRow(
        name: "setCycleReminderMinuteOfDay",
        apply: { $0.setCycleReminderMinuteOfDay(7 * 60 + 30) },
        expected: UserSettings(cycleReminderMinuteOfDay: 7 * 60 + 30)
    ),
    SetterRow(
        name: "setPaywallIntroShown",
        apply: { $0.setPaywallIntroShown(true) },
        expected: UserSettings(paywallIntroShown: true)
    ),
    SetterRow(
        name: "setPremiumTheme",
        apply: { $0.setPremiumTheme(.forest) },
        expected: UserSettings(premiumTheme: .forest)
    )
]

@Suite("SalusPreferencesDataSource")
struct SalusPreferencesDataSourceTests {
    /// The store under test plus the throwaway suite and flag store it was built on.
    private struct Fixture {
        let env: TestUserDefaults
        let flagStore: InMemoryAppLockFlagStore
        let source: SalusPreferencesDataSource
    }

    private func makeFixture() throws -> Fixture {
        let env = try TestUserDefaults()
        let flagStore = InMemoryAppLockFlagStore()
        return Fixture(
            env: env,
            flagStore: flagStore,
            source: SalusPreferencesDataSource(defaults: env.defaults, appLockFlagStore: flagStore)
        )
    }

    // --- reads ----------------------------------------------------------------------

    @Test("an untouched store reports the Android defaults")
    func untouchedStoreReportsDefaults() async throws {
        let fixture = try makeFixture()

        let settings = try #require(await fixture.source.userSettings.firstValue())

        // `SalusPreferencesDataSource.kt:22-33` — every `?:` branch, taken.
        #expect(settings == UserSettings())
    }

    @Test("every setter round-trips through the store", arguments: setterRows)
    func setterRoundTrips(_ row: SetterRow) async throws {
        let fixture = try makeFixture()

        row.apply(fixture.source)

        let settings = try #require(await fixture.source.userSettings.firstValue())
        #expect(settings == row.expected, "\(row.name)")
    }

    @Test("an unknown or mis-cased enum string falls back to the default")
    func unknownEnumStringsFallBack() async throws {
        let fixture = try makeFixture()

        // Anything a future Android version, a hand-edited backup, or a wrong-cased write could
        // leave behind. `toEnumOrDefault` (`SalusPreferencesDataSource.kt:89-90`) matches
        // `it.name == value` — no case folding, no prefix matching.
        fixture.env.defaults.set("MIDNIGHT", forKey: SettingsKeys.themeMode)
        fixture.env.defaults.set("mmol_l", forKey: SettingsKeys.glucoseUnit)
        fixture.env.defaults.set("NEON", forKey: SettingsKeys.premiumTheme)

        let settings = try #require(await fixture.source.userSettings.firstValue())
        #expect(settings.themeMode == .system)
        #expect(settings.glucoseUnit == .mgDl)
        #expect(settings.premiumTheme == .classic)
    }

    @Test("an absent int reads as its default, but a stored zero reads as zero")
    func absentIntIsNotZero() async throws {
        let fixture = try makeFixture()

        // The trap `UserDefaults` sets and `DataStore` does not: `integer(forKey:)` answers 0 for
        // a key that was never written, which would turn Kotlin's `?: UserSettings().x`
        // (`SalusPreferencesDataSource.kt:28-31`) into a silent 0 and fire the cycle reminder at
        // midnight. The store must read through `object(forKey:)` to tell the two apart.
        let untouched = try #require(await fixture.source.userSettings.firstValue())
        #expect(untouched.cycleReminderLeadDays == 1)
        #expect(untouched.cycleReminderMinuteOfDay == 9 * 60)

        fixture.source.setCycleReminderLeadDays(0)
        fixture.source.setCycleReminderMinuteOfDay(0)

        let stored = try #require(await fixture.source.userSettings.firstValue())
        #expect(stored.cycleReminderLeadDays == 0)
        #expect(stored.cycleReminderMinuteOfDay == 0)
    }

    // --- the one key that is not in UserDefaults -------------------------------------

    @Test("the app lock flag is routed to the flag store, never to UserDefaults")
    func appLockFlagBypassesUserDefaults() async throws {
        let fixture = try makeFixture()

        fixture.source.setAppLockEnabled(true)

        // Spec §5: `app_lock_enabled` is the one setting that gates access to the data, so it
        // lives in the Keychain, not in a plist any file-level backup would carry.
        #expect(fixture.env.defaults.object(forKey: SettingsKeys.appLockEnabled) == nil)
        #expect(fixture.flagStore.read())

        let settings = try #require(await fixture.source.userSettings.firstValue())
        #expect(settings.appLockEnabled)
    }

    @Test("the flag store is the only source of the app lock flag")
    func appLockFlagIsReadFromTheFlagStore() async throws {
        let env = try TestUserDefaults()
        let flagStore = InMemoryAppLockFlagStore(enabled: true)
        let source = SalusPreferencesDataSource(defaults: env.defaults, appLockFlagStore: flagStore)

        let settings = try #require(await source.userSettings.firstValue())
        #expect(settings.appLockEnabled)
    }

    // --- the change stream ------------------------------------------------------------

    @Test("the stream emits the current value first, then every change")
    func streamEmitsCurrentThenChanges() async throws {
        let fixture = try makeFixture()
        var stream = fixture.source.userSettings.makeAsyncIterator()

        let first = await stream.next()
        #expect(first == UserSettings())

        fixture.source.setThemeMode(.dark)
        let second = await stream.next()
        #expect(second == UserSettings(themeMode: .dark))
    }

    @Test("writing the value that is already stored emits nothing")
    func streamDoesNotRepeatEqualValues() async throws {
        let fixture = try makeFixture()
        var stream = fixture.source.userSettings.makeAsyncIterator()

        _ = await stream.next()
        fixture.source.setThemeMode(.dark)
        #expect(await stream.next() == UserSettings(themeMode: .dark))

        // Kotlin's `DataStore.data` is distinct by content, so a no-op write wakes no collector.
        // If this store emitted it anyway, the next element awaited below would be the dark-only
        // value and the expectation would fail — no sleep needed to prove the absence.
        fixture.source.setThemeMode(.dark)
        fixture.source.setOnboardingCompleted(true)

        #expect(await stream.next() == UserSettings(themeMode: .dark, onboardingCompleted: true))
    }

    @Test("a change to the app lock flag reaches the stream too")
    func streamEmitsAppLockChanges() async throws {
        let fixture = try makeFixture()
        var stream = fixture.source.userSettings.makeAsyncIterator()

        _ = await stream.next()
        // The flag store posts no `UserDefaults` notification, so this only arrives because the
        // setter re-emits by hand.
        fixture.source.setAppLockEnabled(true)

        #expect(await stream.next() == UserSettings(appLockEnabled: true))
    }
}

@Suite("InMemoryAppLockFlagStore")
struct InMemoryAppLockFlagStoreTests {
    @Test("it starts disabled and remembers what was written")
    func readsBackWhatWasWritten() {
        let store = InMemoryAppLockFlagStore()
        #expect(store.read() == false)

        store.write(true)
        #expect(store.read())

        store.write(false)
        #expect(store.read() == false)
    }
}
