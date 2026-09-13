import Foundation
import SalusTesting
import Testing

@testable import FeatureSettings

/// The twin of Android's `feature/settings/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between the two locales: all 122
/// keys and both of their translations are pinned here.
///
/// The 111 keys split four ways; two (`settings_rate_us*`) are the in-app review row, copied from
/// the XML. Of the rest, fifteen are the `reminder_health_*` block that shipped with
/// iOS-M3 — ten copied from the XML verbatim, five iOS-only (the Background App Refresh row and the
/// last-pass line, which answer questions Android answers with a different mechanism or not at all).
/// Ninety-two are the More / About / Profile / settings keys the M8 hub, the support-code plan T2
/// and the about-redesign plan T2 add, copied verbatim from the XML. Two (`more_cycle`,
/// `more_cycle_subtitle`) move here from the App target's catalog with M8. (The about-redesign moved
/// the six `about_support_*` / `about_premium_*` keys of the support-code T2 off About onto the new
/// Support screen as `support_*`, added the seven `about_feature_*` rows + `about_features_title`,
/// and the More row's `settings_support_*`; the about-redesign fix then scrapped the Support screen
/// and the `settings_support_*` row with it, so those two keys left the catalog.) (The iOS-only
/// `language_relaunch_note` of iOS-M8 T12 is gone: the language pick applies live through
/// `SalusLocalization`, so there is no launch to wait for and nothing to say. The 2026-09-13
/// language merge — see
/// `docs/superpowers/specs/2026-09-13-language-joins-appearance-sheet-design.md` — then deleted
/// `language_title` and `language_sheet_subtitle` with the deleted `LanguageSheet`'s header and
/// added the merged sheet's `theme_section_language` overline.) `SettingsStrings.swift`'s
/// header carries the card-by-card mapping and the reason each Android key is kept, dropped or
/// replaced; this table is where a drift in either direction fails.
///
/// Ten Android keys are deliberately not here (see `SettingsStrings.swift`'s header): the three
/// `reminder_health_exact_*`, the four `reminder_health_battery_*` — `*_title`, `*_problem`,
/// `*_restricted`, `*_ok` — `reminder_health_back`, `settings_back` and `profile_back`. Each is a
/// recorded divergence, not a silent drop.
///
/// `about_privacy_body` carries the iOS store-name divergence, the twin of
/// `paywall_renewal_note`'s (D-M9-a): "App Store" where Android says "Google Play". Every
/// other value is Android-verbatim.
///
/// The catalog is read off disk rather than through `Bundle.module`, for the two reasons
/// `VitalsStringsTests` records: `String(localized:)` answers for ONE locale, so it can never prove
/// both carry a key, and command-line `swift test` does not compile a `.xcstrings` at all.
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`.
@Suite("FeatureSettings strings")
struct SettingsStringsTests {
    static let samples = SettingsSamples.all
    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 122 keys :feature:settings owns")
    func catalogHoldsExactlyTheKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        //
        // The arithmetic behind 122, re-derived after the 2026-09-13 language merge: the M16 Task
        // 10 sweep left 123 keys. The merge — the language picker joins the appearance sheet —
        // deletes the two keys whose only consumers were the deleted `LanguageSheet`'s header
        // (`language_title`, `language_sheet_subtitle`), adds the merged sheet's language-section
        // overline (`theme_section_language`), and re-titles `theme_sheet_title` to "Görünüm ve
        // Dil" / "Appearance and Language". 123 − 2 + 1 = 122.
        #expect(Self.samples.count == 122)

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

    @Test("the format keys carry the Swift specifier and render their sentence")
    func theFormatKeyRendersItsSentence() throws {
        let catalog = try Self.loadCatalog()

        // Java's `%1$s` reads a C string pointer under `String(format:)`; `%1$@` is the object
        // form — see the mapping table in `SettingsStrings.swift`.
        try #expect(#require(catalog.value(of: "reminder_health_last_sync", in: "tr")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "reminder_health_last_sync", in: "en")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "about_version", in: "tr")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "about_version", in: "en")).contains("%1$@"))

        try #expect(
            Self.render("reminder_health_last_sync", "tr", "23 Ağu 2026 14:05")
                == "Son hatırlatıcı taraması: 23 Ağu 2026 14:05"
        )
        try #expect(
            Self.render("reminder_health_last_sync", "en", "23 Aug 2026 14:05")
                == "Last reminder pass: 23 Aug 2026 14:05"
        )
        try #expect(Self.render("about_version", "tr", "1.0.0") == "Sürüm 1.0.0")
        try #expect(Self.render("about_version", "en", "1.0.0") == "Version 1.0.0")
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
