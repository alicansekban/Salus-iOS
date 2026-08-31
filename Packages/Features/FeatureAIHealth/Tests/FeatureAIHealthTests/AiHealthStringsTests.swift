import Foundation
import SalusTesting
import Testing

@testable import FeatureAIHealth

/// The twin of Android's `feature/aihealth/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: the `ai_summary_*`
/// keys and `ai_language_code`, with both of their translations pinned here, copied from the XML.
///
/// The doctor-report keys are deliberately absent, and that is the milestone split: `doctor_report_*`
/// belongs to Task 6 of iOS-M10, which ships the report screen. When Task 6 lands, the keys and
/// this pin grow together in the same commit.
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `AiHealthStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all, so a
/// resolved string here would only ever be the key back. The end-to-end check is the simulator
/// run.
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the Android-verbatim values.
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`, so the
/// next feature's catalog is covered without remembering to copy a test.
@Suite("FeatureAIHealth strings")
struct AiHealthStringsTests {
    /// Every key this task's catalog owns, with both translations, copied from the XML. A new key
    /// there means a new row here, in the same commit — that is the whole job of this table.
    static let samples: [AiHealthStringSample] = [
        AiHealthStringSample(
            key: "ai_summary_title",
            turkish: "Yapay zekâ özeti",
            english: "AI summary"
        ),
        AiHealthStringSample(
            key: "ai_summary_back",
            turkish: "Geri",
            english: "Back"
        ),
        AiHealthStringSample(
            key: "ai_summary_period_weekly",
            turkish: "Haftalık",
            english: "Weekly"
        ),
        AiHealthStringSample(
            key: "ai_summary_period_monthly",
            turkish: "Aylık",
            english: "Monthly"
        ),
        AiHealthStringSample(
            key: "ai_summary_loading",
            turkish: "Özetin hazırlanıyor…",
            english: "Preparing your summary…"
        ),
        AiHealthStringSample(
            key: "ai_summary_from_cache",
            turkish: "Daha önce oluşturulan özet gösteriliyor.",
            english: "Showing a summary generated earlier."
        ),
        AiHealthStringSample(
            key: "ai_summary_disclaimer",
            turkish: "Bu özet bilgilendirme amaçlıdır, tıbbi tavsiye değildir. "
                + "Sağlık kararların için doktoruna danış.",
            english: "This summary is for information only and is not medical advice. "
                + "Talk to your doctor about health decisions."
        ),
        AiHealthStringSample(
            key: "ai_summary_insufficient_title",
            turkish: "Henüz yeterli kayıt yok",
            english: "Not enough records yet"
        ),
        AiHealthStringSample(
            key: "ai_summary_insufficient_message",
            turkish: "Bu dönem için özet çıkarmaya yetecek kadar kaydın yok. "
                + "Birkaç gün daha kayıt tutunca özetin burada olacak.",
            english: "There aren't enough records in this period to summarise. "
                + "Keep logging for a few more days and your summary will appear here."
        ),
        AiHealthStringSample(
            key: "ai_summary_premium_title",
            turkish: "Bu özet Premium'a özel",
            english: "This summary is a Premium feature"
        ),
        AiHealthStringSample(
            key: "ai_summary_premium_message",
            turkish: "Ücretsiz deneme hakkını kullandın. Premium ile haftalık ve aylık "
                + "özetlerine dilediğin zaman ulaşabilirsin.",
            english: "You have used your free summary. With Premium you can open your "
                + "weekly and monthly summaries any time."
        ),
        AiHealthStringSample(
            key: "ai_summary_premium_action",
            turkish: "Premium'a geç",
            english: "Go Premium"
        ),
        AiHealthStringSample(
            key: "ai_summary_daily_limit_title",
            turkish: "Bugünlük özet hakkın doldu",
            english: "No summaries left for today"
        ),
        AiHealthStringSample(
            key: "ai_summary_daily_limit_message",
            turkish: "Günlük özet sınırına ulaştın. Yarın yeniden deneyebilirsin.",
            english: "You have reached today's summary limit. Try again tomorrow."
        ),
        AiHealthStringSample(
            key: "ai_summary_error_title",
            turkish: "Özet oluşturulamadı",
            english: "Summary could not be created"
        ),
        AiHealthStringSample(
            key: "ai_summary_error_message",
            turkish: "Özetin şu anda hazırlanamadı. İnternet bağlantını kontrol edip tekrar dene.",
            english: "Your summary could not be prepared right now. Check your connection and try again."
        ),
        AiHealthStringSample(
            key: "ai_summary_retry",
            turkish: "Tekrar dene",
            english: "Try again"
        ),
        AiHealthStringSample(
            key: "ai_summary_unavailable_title",
            turkish: "Yapay zekâ özeti kullanılamıyor",
            english: "AI summaries are unavailable"
        ),
        AiHealthStringSample(
            key: "ai_summary_unavailable_message",
            turkish: "Yapay zekâ özeti bu kurulumda kullanılamıyor. Uygulamanın bu sürümü "
                + "özet oluşturacak şekilde yapılandırılmamış, bu yüzden tekrar denemenin bir "
                + "faydası olmaz.",
            english: "AI summaries aren't available on this setup. This build of the app "
                + "isn't configured to generate them, so trying again won't help."
        ),
        AiHealthStringSample(
            key: "ai_language_code",
            turkish: "tr",
            english: "en"
        )
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 20 keys this task's screen owns")
    func catalogHoldsExactlyTheTwentyKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 20)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values are Android-verbatim (feature/aihealth/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: AiHealthStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `AiHealthStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(AiHealthStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FeatureAIHealthTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeatureAIHealth
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeatureAIHealth/Resources/Localizable.xcstrings")
        )
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct AiHealthStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
