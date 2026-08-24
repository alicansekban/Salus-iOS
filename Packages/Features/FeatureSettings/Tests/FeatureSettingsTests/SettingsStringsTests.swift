import Foundation
import SalusTesting
import Testing

@testable import FeatureSettings

/// The twin of Android's `feature/settings/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml` for the `reminder_health_*` block, and the drift detector
/// between the two locales: all 15 keys and both of their translations are pinned here.
///
/// Ten of the fifteen are copied from the XML verbatim. Five are iOS-only — the Background App
/// Refresh row and the last-pass line, which answer questions Android answers with a different
/// mechanism or not at all. `SettingsStrings.swift`'s header carries the card-by-card mapping and
/// the reason each Android key is kept, dropped or replaced; this table is where a drift in either
/// direction fails.
///
/// The catalog is read off disk rather than through `Bundle.module`, for the two reasons
/// `VitalsStringsTests` records: `String(localized:)` answers for ONE locale, so it can never prove
/// both carry a key, and command-line `swift test` does not compile a `.xcstrings` at all.
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`.
@Suite("FeatureSettings strings")
struct SettingsStringsTests {
    /// Every key `:feature:settings` owns today, with both translations. A new key means a new row
    /// here, in the same commit — that is the whole job of this table.
    static let samples: [SettingsStringSample] = [
        SettingsStringSample(
            key: "reminder_health_title",
            turkish: "Hatırlatıcı sağlığı",
            english: "Reminder health"
        ),
        SettingsStringSample(
            key: "reminder_health_intro",
            turkish: "Hatırlatıcıların zamanında gelmesi için Salus'un aşağıdaki ayarlara ihtiyacı var. "
                + "Tüm kontroller yalnızca bu cihazda çalışır — hiçbir veri dışarı çıkmaz.",
            english: "For reminders to arrive on time, Salus needs the settings below. "
                + "All checks run on this device only — nothing leaves it."
        ),
        SettingsStringSample(
            key: "reminder_health_all_ok",
            turkish: "Her şey yolunda görünüyor — hatırlatıcılar zamanında gelecektir.",
            english: "Everything looks good — reminders should arrive on time."
        ),
        SettingsStringSample(
            key: "reminder_health_fix",
            turkish: "Düzelt",
            english: "Fix"
        ),
        SettingsStringSample(
            key: "reminder_health_notifications_title",
            turkish: "Bildirimler",
            english: "Notifications"
        ),
        SettingsStringSample(
            key: "reminder_health_notifications_ok",
            turkish: "Bildirimler açık.",
            english: "Notifications are enabled."
        ),
        SettingsStringSample(
            key: "reminder_health_notifications_problem",
            turkish: "Bildirimler kapalı — hatırlatıcılar gösterilemez.",
            english: "Notifications are off — reminders cannot be shown."
        ),
        SettingsStringSample(
            key: "reminder_health_full_screen_title",
            turkish: "Tam ekran ilaç alarmları",
            english: "Full-screen medication alarms"
        ),
        SettingsStringSample(
            key: "reminder_health_full_screen_ok",
            turkish: "İlaç alarmları kilit ekranını kaplayarak çalacak.",
            english: "Medication alarms will take over the lock screen."
        ),
        SettingsStringSample(
            key: "reminder_health_full_screen_problem",
            turkish: "İlaç alarmları ekranı kaplayamıyor — doz saati geldiğinde sesli bildirim gelir, "
                + "ama kilit ekranında alarm açılmaz.",
            english: "Medication alarms cannot take over the screen — a dose still arrives as a "
                + "notification with sound, but no alarm opens on the lock screen."
        ),
        SettingsStringSample(
            key: "reminder_health_background_refresh_title",
            turkish: "Arka plan yenilemesi",
            english: "Background App Refresh"
        ),
        SettingsStringSample(
            key: "reminder_health_background_refresh_ok",
            turkish: "Salus hatırlatıcı listesini arka planda tazeleyebiliyor.",
            english: "Salus can refresh the reminder list in the background."
        ),
        SettingsStringSample(
            key: "reminder_health_background_refresh_problem",
            turkish: "Arka plan yenilemesi kapalı — hatırlatıcı listesi yalnızca uygulamayı "
                + "açtığınızda tazelenir.",
            english: "Background App Refresh is off — the reminder list is only refreshed while "
                + "the app is open."
        ),
        SettingsStringSample(
            key: "reminder_health_last_sync",
            turkish: "Son hatırlatıcı taraması: %1$@",
            english: "Last reminder pass: %1$@"
        ),
        SettingsStringSample(
            key: "reminder_health_never_synced",
            turkish: "Hatırlatıcı taraması bu cihazda henüz çalışmadı.",
            english: "The reminder pass has not run on this device yet."
        )
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 15 keys :feature:settings owns")
    func catalogHoldsExactlyTheFifteenKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 15)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values match the ported table (feature/settings/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesMatchThePortedTable(sample: SettingsStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `SettingsStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(SettingsStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the one format key carries the Swift specifier and renders its sentence")
    func theFormatKeyRendersItsSentence() throws {
        let catalog = try Self.loadCatalog()

        // Java's `%1$s` reads a C string pointer under `String(format:)`; `%1$@` is the object
        // form — see the mapping table in `SettingsStrings.swift`.
        try #expect(#require(catalog.value(of: "reminder_health_last_sync", in: "tr")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "reminder_health_last_sync", in: "en")).contains("%1$@"))

        try #expect(
            Self.render("reminder_health_last_sync", "tr", "23 Ağu 2026 14:05")
                == "Son hatırlatıcı taraması: 23 Ağu 2026 14:05"
        )
        try #expect(
            Self.render("reminder_health_last_sync", "en", "23 Aug 2026 14:05")
                == "Last reminder pass: 23 Aug 2026 14:05"
        )
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FeatureSettingsTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeatureSettings
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeatureSettings/Resources/Localizable.xcstrings")
        )
    }
}

/// One row of the ported string table: a key and the two translations the app ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct SettingsStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
