// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/TrendsStringsTest.kt`
// and the iOS twin of it, `VitalsStringsTests.swift`, whose Shape every feature strings suite
// copies.
//
// The twin of `feature/trends/src/main/res/values/strings.xml` (`tr`, the source language) and
// `values-en/strings.xml`, and the drift detector between them: all 12 Task-1 keys and both of
// their translations are pinned here, copied from the XML. The keys for the four cards arrive
// with the analysis tasks that draw them (Tasks 2-5) and extend this table in the same commit.
//
// The catalog is read off disk rather than through `Bundle.module`, for the two reasons
// `VitalsStringsTests` records: `String(localized:)` answers for ONE locale, so it can never
// prove both carry a key; and command-line `swift test` does not compile a `.xcstrings`, so a
// resolved string would only ever be the key back. The end-to-end check is the simulator run.
//
// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`, so this
// catalog is covered without copying a test. Instead, this suite carries the shared helper's
// other half — the positive check that both translations still say what the dose share *is* a
// share of, exactly as `TrendsStringsTest` does on Android.

import Foundation
import SalusTesting
import Testing

@testable import FeatureTrends

@Suite("FeatureTrends strings")
struct TrendsStringsTests {
    /// Every key Task 1's catalog owns, with both translations, copied from the XML. A new key
    /// there means a new row here, in the same commit — that is the whole job of this table.
    static let samples: [TrendsStringSample] = [
        TrendsStringSample(key: "trends_title", turkish: "Analizler", english: "Trends"),
        TrendsStringSample(key: "trends_back", turkish: "Geri", english: "Back"),
        TrendsStringSample(key: "trends_range_month", turkish: "1 ay", english: "1 month"),
        TrendsStringSample(key: "trends_range_quarter", turkish: "3 ay", english: "3 months"),
        TrendsStringSample(key: "trends_range_half_year", turkish: "6 ay", english: "6 months"),
        TrendsStringSample(key: "trends_range_year", turkish: "1 yıl", english: "1 year"),
        TrendsStringSample(
            key: "trends_locked_title",
            turkish: "Analizler Premium'a özel",
            english: "Trends are a Premium feature"
        ),
        TrendsStringSample(
            key: "trends_locked_message",
            turkish: "Kayıtlarındaki örüntüleri gör: gün içi dağılım, metriklerin bir arada seyri, kaydedilen dozların "
                + "alınma oranı ve her metriğin önceki döneme göre değişimi.",
            english: "See the patterns in your records: time-of-day spread, your metrics side by side, the share of "
                + "recorded doses that were marked as taken, and how each metric changed from the previous period."
        ),
        TrendsStringSample(key: "trends_locked_action", turkish: "Premium ile aç", english: "Unlock with Premium"),
        TrendsStringSample(
            key: "trends_empty_title",
            turkish: "Analiz için kayıt yok",
            english: "Nothing to analyse yet"
        ),
        TrendsStringSample(
            key: "trends_empty_message",
            turkish: "Bu dönemde ölçüm ya da ilaç kaydın bulunmuyor. "
                + "Birkaç kayıt girdikten sonra analizler burada görünür.",
            english: "There are no measurements or doses in this period. Once you log a few, your trends "
                + "appear here."
        ),
        TrendsStringSample(
            key: "trends_error_title",
            turkish: "Analizler yüklenemedi",
            english: "Trends could not be loaded"
        ),
        TrendsStringSample(
            key: "trends_error_message",
            turkish: "Kayıtlarına şu anda ulaşılamadı. Tekrar denemek sorunu genellikle çözer.",
            english: "Your records could not be read just now. Trying again usually sorts it out."
        ),
        TrendsStringSample(key: "trends_error_action", turkish: "Tekrar dene", english: "Try again")
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 14 Task-1 keys :feature:trends owns")
    func catalogHoldsExactlyTheFourteenKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass. 14 = title + back + 4
        // ranges + 3 locked + 2 empty + 3 error.
        #expect(Self.samples.count == 14)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values are Android-verbatim (feature/trends/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: TrendsStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `TrendsStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(TrendsStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    /// The Android `TrendsStringsTest` also runs the `BannedHealthClaims` scan, which this suite
    /// deliberately does not (it is repo-wide in `SalusTestingTests`). This is the positive half
    /// it cannot own either way: banning the wrong words is only useful while the right phrase is
    /// still there to be found — the share is of *recorded* doses.
    @Test("both translations still name the dose share as taken, never claiming more")
    func bothTranslationsNameTheDoseShareCorrectly() throws {
        let catalog = try Self.loadCatalog()

        // The positive half of the banned-word rule. Turkish carries the exact phrase Android
        // ships ("kaydedilen dozlar") in the locked message that sells the dose card.
        let turkish = try #require(catalog.value(of: "trends_locked_message", in: "tr"))
        #expect(turkish.contains("kaydedilen doz"))

        // English carries its own phrasing ("share of recorded doses that were marked as taken").
        let english = try #require(catalog.value(of: "trends_locked_message", in: "en"))
        #expect(english.contains("recorded doses"))
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FeatureTrendsTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeatureTrends
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeatureTrends/Resources/Localizable.xcstrings")
        )
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct TrendsStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
