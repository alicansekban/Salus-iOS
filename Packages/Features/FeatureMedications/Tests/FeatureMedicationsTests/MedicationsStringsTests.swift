import Foundation
import SalusTesting
import Testing

@testable import FeatureMedications

/// The twin of Android's `feature/medications/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: all 113 keys and
/// both of their translations are pinned here, copied from the XML — apart from `medications_title`,
/// which M15 retired on Android and iOS keeps for the system back button (the reason is on its row
/// below and in `MedicationsStrings.swift`'s header).
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `MedicationsStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all,
/// so a resolved string here would only ever be the key back. The end-to-end check is the
/// simulator run.
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the values themselves, Android's own apart from the
/// one recorded divergence.
@Suite("FeatureMedications strings")
struct MedicationsStringsTests {
    static let samples = MedicationStringSamples.all

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 113 keys :feature:medications owns")
    func catalogHoldsExactlyTheOneHundredAndThirteenKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 113)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values match res/values*/strings.xml, apart from the one recorded divergence",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: MedicationStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `MedicationsStrings.Key`'s raw values does not fail to compile — it
        // ships the key itself as the label. This is the check that catches it.
        #expect(Set(MedicationsStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the nine format keys carry Swift specifiers and render the Android sentence")
    func formatKeysRenderTheAndroidSentence() throws {
        // Android's `%1$s`/`%1$d` are Java specifiers. `%s` reads a C string pointer under
        // `String(format:)` and `%d` reads 32 bits of a 64-bit Swift `Int`, so the catalog carries
        // `%1$@`/`%1$lld` instead — see the mapping table in `MedicationsStrings.swift`. The
        // sentence around them is unchanged, and these are the assertions that say so. A literal
        // `%%` is neither, and stays as it is: `String(format:)` prints it as one `%`.
        try #expect(Self.render("medications_overline_today", "tr", "8 Mart") == "BUGÜN • 8 Mart")
        try #expect(Self.render("medications_overline_today", "en", "8 March") == "TODAY • 8 March")
        try #expect(Self.render("medications_stock_left", "tr", "4") == "Stok: 4")
        try #expect(Self.render("medications_stock_left", "en", "4") == "Stock: 4")
        try #expect(Self.render("medication_detail_threshold", "tr", "10") == "Uyarı eşiği: 10")
        try #expect(Self.render("medication_detail_threshold", "en", "10") == "Alert at: 10")
        try #expect(Self.render("medication_detail_record_now", "tr", "08:00") == "Dozu Şimdi Kaydet (08:00)")
        try #expect(Self.render("medication_detail_record_now", "en", "08:00") == "Record dose now (08:00)")
        try #expect(Self.render("recurrence_every_n_days", "tr", 3) == "3 günde bir")
        try #expect(Self.render("recurrence_every_n_days", "en", 3) == "Every 3 days")
        try #expect(Self.render("medications_detail_days_of_supply", "tr", 4) == "≈ 4 gün yetecek")
        try #expect(Self.render("medications_detail_days_of_supply", "en", 4) == "≈ 4 day(s) left")
        try #expect(Self.render("medications_detail_per_day", "tr", 2) == "Günde 2 kez")
        try #expect(Self.render("medications_detail_per_day", "en", 2) == "2 time(s) a day")
        try #expect(Self.render("notification_dose_title", "tr", "Aspirin") == "Aspirin zamanı")
        try #expect(Self.render("notification_dose_title", "en", "Aspirin") == "Time for Aspirin")
        try #expect(Self.render("notification_dose_text_plain", "tr", "2") == "2 doz al")
        try #expect(Self.render("notification_dose_text_plain", "en", "2") == "Take 2 dose(s)")
        try #expect(Self.render("medication_delete_title", "tr", "Aspirin") == "Aspirin silinsin mi?")
        try #expect(Self.render("medication_delete_title", "en", "Aspirin") == "Delete Aspirin?")

        // The one two-argument key: the dose amount, then the strength.
        try #expect(Self.render2("notification_dose_text", "tr", "2", "500 mg") == "2 × 500 mg al")
        try #expect(Self.render2("notification_dose_text", "en", "2", "500 mg") == "Take 2 × 500 mg")

        try Self.assertSpecifiers()
    }

    @Test("the catalog names nothing on the banned health-claims list")
    func theCatalogNamesNothingBanned() throws {
        // Repository-wide coverage already exists in `SalusTestingTests.BannedHealthClaimsTests`.
        // This narrower run points at this package's own catalog so the feature that introduces a
        // banned word fails in its own suite, where whoever wrote the string is already looking.
        try BannedHealthClaims.assertCatalogsNameNothingBanned(paths: [Self.catalogURL])
    }

    /// Every format key carries the Swift specifier in both languages, not only in the one the
    /// rendering assertions above happened to exercise.
    static func assertSpecifiers() throws {
        let catalog = try loadCatalog()
        let objectKeys = [
            "medications_overline_today",
            "medications_stock_left",
            "medication_detail_threshold",
            "medication_detail_record_now",
            "notification_dose_title",
            "notification_dose_text",
            "notification_dose_text_plain",
            "medication_delete_title"
        ]
        let integerKeys = [
            "medications_detail_days_of_supply",
            "medications_detail_per_day",
            "recurrence_every_n_days"
        ]

        for locale in ["tr", "en"] {
            for key in objectKeys {
                try #expect(#require(catalog.value(of: key, in: locale)).contains("%1$@"))
            }
            for key in integerKeys {
                try #expect(#require(catalog.value(of: key, in: locale)).contains("%1$lld"))
            }
            try #expect(#require(catalog.value(of: "notification_dose_text", in: locale)).contains("%2$@"))
        }
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The same, for `notification_dose_text` — the only key that carries two arguments.
    static func render2(_ key: String, _ locale: String, _ first: CVarArg, _ second: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, first, second)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // FeatureMedicationsTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // FeatureMedications
        .appendingPathComponent("Sources/FeatureMedications/Resources/Localizable.xcstrings")

    static func loadCatalog() throws -> StringCatalog {
        try StringCatalogParity.load(at: catalogURL)
    }
}
