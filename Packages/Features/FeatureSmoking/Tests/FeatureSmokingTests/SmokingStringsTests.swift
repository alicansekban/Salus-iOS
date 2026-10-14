import Foundation
import SalusTesting
import Testing

@testable import FeatureSmoking

/// The twin of Android's `feature/smoking/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: every key and both
/// of its translations are pinned here, copied from the XML.
///
/// The catalog is read off disk rather than through `Bundle.module`: `String(localized:)` answers
/// for ONE locale, so it can never prove both carry a key, and command-line `swift test` does not
/// compile a `.xcstrings` at all (see `SmokingStrings.swift`).
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests` over every `.xcstrings` and every Swift source under
/// `Packages/`, so this catalog is covered without remembering to copy a test.
@Suite("FeatureSmoking strings")
struct SmokingStringsTests {
    static let samples = SmokingStringTable.samples
    static let expectedKeys = Set(samples.map(\.key))

    /// Setup's overlines: the step counter and the field labels. Stored upper-case in both locales.
    static let overlineKeys = [
        "smoking_setup_step_of", "smoking_setup_units_per_day", "smoking_setup_pack_price",
        "smoking_setup_pouch_price", "smoking_setup_units_per_pack", "smoking_setup_units_per_pouch",
        "smoking_setup_currency", "smoking_setup_weekly_spend", "smoking_setup_quit_when",
        "smoking_setup_reason_label", "smoking_setup_daily_limit"
    ]

    @Test("the catalog holds exactly the 64 keys :feature:smoking owns so far")
    func catalogHoldsExactlyTheKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 64)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values are Android-verbatim (feature/smoking/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: SmokingStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `SmokingStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(SmokingStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    /// Overline strings are stored upper-case, so no call site ever calls `uppercased()` — Turkish
    /// has two dotted i's and a runtime fold cannot know which one a label means.
    @Test("every overline is stored upper-case, in both languages")
    func overlinesAreStoredUpperCase() throws {
        let catalog = try Self.loadCatalog()

        for key in Self.overlineKeys {
            for locale in ["tr", "en"] {
                // A format specifier is not text: `%1$lld` would fold to `%1$LLD`, which is another
                // specifier, so the check reads the sentence around the placeholders.
                let value = try #require(catalog.value(of: key, in: locale))
                    .replacingOccurrences(of: #"%\d\$(lld|@)"#, with: "", options: .regularExpression)
                #expect(
                    value == value.uppercased(with: Locale(identifier: locale)),
                    "\(key) in \(locale) is not stored upper-case"
                )
            }
        }
    }

    @Test("the format keys carry Swift specifiers and render the Android sentence")
    func formatKeysRenderTheAndroidSentence() throws {
        let catalog = try Self.loadCatalog()

        // Java's `%1$s` / `%1$d` become `%1$@` / `%1$lld`; the sentence around them is unchanged.
        try #expect(Self.render(catalog, "smoking_setup_step_of", "tr", 2, 4) == "ADIM 2 / 4")
        try #expect(Self.render(catalog, "smoking_setup_step_of", "en", 2, 4) == "STEP 2 / 4")
        try #expect(Self.render(catalog, "smoking_setup_quick_add", "tr", "₺", 50) == "+₺50")
        try #expect(
            Self.render(catalog, "smoking_setup_summary_daily", "tr", "₺95", "₺34.675")
                == "Günde yaklaşık ₺95 · yılda ₺34.675"
        )
        try #expect(
            Self.render(catalog, "smoking_setup_summary_weekly", "en", "₺400", "₺20.800")
                == "About ₺400 a week · ₺20.800 a year"
        )
        try #expect(Self.render(catalog, "smoking_setup_quit_today", "tr", "09:30") == "Bugün, 09:30")
        // `%%` is a literal percent under `String(format:)`, exactly as in Java's `Formatter`.
        try #expect(
            Self.render(catalog, "smoking_setup_limit_suggestion", "tr", 20)
                == "Öneri: şu anki miktarının %80'i (Mevcut: 20 adet)"
        )
        try #expect(
            Self.render(catalog, "smoking_setup_limit_suggestion", "en", 20)
                == "Suggestion: 80% of your current amount (currently 20)"
        )
    }

    /// One catalog value with its arguments substituted, formatted locale-independently so the
    /// expected sentence does not depend on where the test ran.
    static func render(
        _ catalog: StringCatalog,
        _ key: String,
        _ locale: String,
        _ arguments: CVarArg...
    ) throws -> String {
        let format = try #require(catalog.value(of: key, in: locale))
        return String(format: format, locale: nil, arguments: arguments)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FeatureSmokingTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeatureSmoking
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeatureSmoking/Resources/Localizable.xcstrings")
        )
    }
}
