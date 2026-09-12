import Foundation
import SalusTesting
import Testing

@testable import FeatureAIHealth

// The twin of Android's `feature/aihealth/src/main/res/values/strings.xml` (`tr`, the source
// language) and `values-en/strings.xml`, and the drift detector between them: the `ai_summary_*`
// keys, the `doctor_report_*` keys and `ai_language_code`, with both of their translations pinned
// here, copied from the XML.
//
// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
// so it can never prove that both locales carry a key. The second is the toolchain note in
// `AiHealthStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all, so a
// resolved string here would only ever be the key back. The end-to-end check is the simulator
// run.
//
// The parity mechanics — loading, the key-set pin, the locale check — live in
// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
// plus the half no shared helper can own: the Android-verbatim values.
//
// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`, so the
// next feature's catalog is covered without remembering to copy a test.

@Suite("FeatureAIHealth strings")
struct AiHealthStringsTests {
    /// Every key this task's catalog owns, with both translations, copied from the XML. A new key
    /// there means a new row here, in the same commit — that is the whole job of this table.
    ///
    /// The table lives in its own type rather than on the suite for the reason
    /// `VitalsStringsTests` records: 63 rows inside the suite put its body past SwiftLint's
    /// 300-line `type_body_length`.
    static let samples: [AiHealthStringSample] = AiHealthStringTable.samples

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 63 keys this feature's screens own")
    func catalogHoldsExactlyTheSixtyThreeKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass. 63 = the 43 keys that
        // survived the M15 removals (`ai_summary_back`, `ai_summary_from_cache`,
        // `doctor_report_back`, `doctor_report_preview_close`) plus the 20 M15 additions.
        #expect(Self.samples.count == 63)

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

/// Every key `:feature:aihealth` owns, with both translations, copied from the XML.
///
/// Its own type rather than a `static let` on the suite: it is data, not a test, and 63 rows
/// inside the suite put its body past SwiftLint's 300-line `type_body_length`
/// (`VitalsStringsTests` moves it the same way).
enum AiHealthStringTable {
    static let samples: [AiHealthStringSample] = [
        AiHealthStringSample(key: "ai_summary_title", turkish: "Yapay zekâ özeti", english: "AI summary"),
        AiHealthStringSample(key: "ai_summary_period_weekly", turkish: "Haftalık", english: "Weekly"),
        AiHealthStringSample(key: "ai_summary_period_monthly", turkish: "Aylık", english: "Monthly"),
        AiHealthStringSample(
            key: "ai_summary_banner_title",
            turkish: "Yapay zekâ analizi",
            english: "AI analysis"
        ),
        AiHealthStringSample(
            key: "ai_summary_state_fresh",
            turkish: "Yeni oluşturuldu",
            english: "Just generated"
        ),
        AiHealthStringSample(key: "ai_summary_state_cached", turkish: "Önceki özet", english: "Saved summary"),
        AiHealthStringSample(
            key: "ai_summary_loading",
            turkish: "Özetin hazırlanıyor…",
            english: "Preparing your summary…"
        ),
        AiHealthStringSample(
            key: "ai_summary_open_report",
            turkish: "Doktor raporunu aç",
            english: "Open the doctor report"
        ),
        AiHealthStringSample(
            key: "ai_summary_metric_bp",
            turkish: "ORT. TANSİYON",
            english: "AVG. BLOOD PRESSURE"
        ),
        AiHealthStringSample(
            key: "ai_summary_metric_doses",
            turkish: "KAYDEDİLEN DOZ",
            english: "RECORDED DOSES"
        ),
        AiHealthStringSample(key: "ai_summary_metric_doses_value", turkish: "%%%1$lld", english: "%1$lld%%"),
        AiHealthStringSample(key: "ai_summary_metric_pulse", turkish: "ORT. NABIZ", english: "AVG. PULSE"),
        AiHealthStringSample(
            key: "ai_summary_share_pdf",
            turkish: "PDF olarak paylaş",
            english: "Share as PDF"
        ),
        AiHealthStringSample(
            key: "ai_summary_refresh",
            turkish: "Analizi güncelle",
            english: "Refresh the analysis"
        ),
        AiHealthStringSample(
            key: "ai_summary_disclaimer",
            turkish: "Bu özet bilgilendirme amaçlıdır, tıbbi tavsiye değildir. " +
                "Sağlık kararların için doktoruna danış.",
            english: "This summary is for information only and is not medical " +
                "advice. Talk to your doctor about health decisions."
        ),
        AiHealthStringSample(
            key: "ai_summary_insufficient_title",
            turkish: "Henüz yeterli kayıt yok",
            english: "Not enough records yet"
        ),
        AiHealthStringSample(
            key: "ai_summary_insufficient_message",
            turkish: "Bu dönem için özet çıkarmaya yetecek kadar kaydın yok. Birkaç " +
                "gün daha kayıt tutunca özetin burada olacak.",
            english: "There aren't enough records in this period to summarise. Keep " +
                "logging for a few more days and your summary will appear here."
        ),
        AiHealthStringSample(
            key: "ai_summary_premium_title",
            turkish: "Bu özet Premium'a özel",
            english: "This summary is a Premium feature"
        ),
        AiHealthStringSample(
            key: "ai_summary_premium_message",
            turkish: "Ücretsiz deneme hakkını kullandın. Premium ile haftalık ve " +
                "aylık özetlerine dilediğin zaman ulaşabilirsin.",
            english: "You have used your free summary. With Premium you can open " +
                "your weekly and monthly summaries any time."
        ),
        AiHealthStringSample(key: "ai_summary_premium_action", turkish: "Premium'a geç", english: "Go Premium"),
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
        AiHealthStringSample(key: "ai_summary_retry", turkish: "Tekrar dene", english: "Try again"),
        AiHealthStringSample(
            key: "ai_summary_unavailable_title",
            turkish: "Yapay zekâ özeti kullanılamıyor",
            english: "AI summaries are unavailable"
        ),
        AiHealthStringSample(
            key: "ai_summary_unavailable_message",
            turkish: "Yapay zekâ özeti bu kurulumda kullanılamıyor. Uygulamanın bu " +
                "sürümü özet oluşturacak şekilde yapılandırılmamış, bu yüzden " +
                "tekrar denemenin bir faydası olmaz.",
            english: "AI summaries aren't available on this setup. This build of the " +
                "app isn't configured to generate them, so trying again won't " +
                "help."
        ),
        AiHealthStringSample(key: "ai_language_code", turkish: "tr", english: "en"),
        AiHealthStringSample(key: "doctor_report_title", turkish: "Doktor Raporu", english: "Doctor report"),
        AiHealthStringSample(
            key: "doctor_report_idle_title",
            turkish: "Doktoruna göstermek için rapor oluştur",
            english: "Create a report to show your doctor"
        ),
        AiHealthStringSample(
            key: "doctor_report_idle_message",
            turkish: "Seçtiğin dönemdeki tansiyon, şeker ve kilo kayıtların ile ilaç " +
                "kaydı özetin PDF olarak hazırlanır. Uygunsa yapay zekâ " +
                "değerlendirmesi de eklenir.",
            english: "Your blood pressure, glucose and weight records for the " +
                "selected period, plus a summary of your recorded doses, are " +
                "prepared as a PDF. An AI assessment is added when there is " +
                "enough data."
        ),
        AiHealthStringSample(key: "doctor_report_generate", turkish: "Rapor oluştur", english: "Create report"),
        AiHealthStringSample(
            key: "doctor_report_generating",
            turkish: "Raporun hazırlanıyor…",
            english: "Preparing your report…"
        ),
        AiHealthStringSample(
            key: "doctor_report_ready_title",
            turkish: "Raporun hazır",
            english: "Your report is ready"
        ),
        AiHealthStringSample(key: "doctor_report_pdf_chip", turkish: "PDF", english: "PDF"),
        AiHealthStringSample(
            key: "doctor_report_ready_message",
            turkish: "Kayıtların ve yapay zekâ değerlendirmesi PDF'e eklendi. " +
                "Göndermeden önce önizleyebilir, sonra doktorunla " +
                "paylaşabilirsin.",
            english: "Your records and the AI assessment are in the PDF. Preview it " +
                "before you send it, then share it with your doctor."
        ),
        AiHealthStringSample(
            key: "doctor_report_ready_without_narrative",
            turkish: "Kayıtların PDF'e eklendi. Yapay zekâ değerlendirmesi bu " +
                "raporda oluşturulamadı; tablolar eksiksiz.",
            english: "Your records are in the PDF. The AI assessment could not be " +
                "produced for this report; the tables are complete."
        ),
        AiHealthStringSample(
            key: "doctor_report_preview_section",
            turkish: "BELGE ÖNİZLEME",
            english: "DOCUMENT PREVIEW"
        ),
        AiHealthStringSample(key: "doctor_report_preview_expand", turkish: "Büyüt", english: "Expand"),
        AiHealthStringSample(
            key: "doctor_report_preview_hint",
            turkish: "Raporunu açıp bütün sayfalarını okuyabilirsin.",
            english: "Open the report to read it page by page."
        ),
        AiHealthStringSample(
            key: "doctor_report_includes_title",
            turkish: "RAPORA DAHİL EDİLENLER",
            english: "INCLUDED IN THE REPORT"
        ),
        AiHealthStringSample(
            key: "doctor_report_section_blood_pressure",
            turkish: "Tansiyon kayıtları",
            english: "Blood pressure records"
        ),
        AiHealthStringSample(
            key: "doctor_report_section_glucose",
            turkish: "Kan şekeri kayıtları",
            english: "Blood glucose records"
        ),
        AiHealthStringSample(
            key: "doctor_report_section_weight",
            turkish: "Kilo kayıtları",
            english: "Weight records"
        ),
        AiHealthStringSample(
            key: "doctor_report_section_medications",
            turkish: "İlaç kaydı özeti",
            english: "Recorded dose summary"
        ),
        AiHealthStringSample(
            key: "doctor_report_section_narrative",
            turkish: "Yapay zekâ değerlendirmesi",
            english: "AI assessment"
        ),
        AiHealthStringSample(key: "doctor_report_share", turkish: "Paylaş", english: "Share"),
        AiHealthStringSample(key: "doctor_report_preview", turkish: "Önizle", english: "Preview"),
        AiHealthStringSample(
            key: "doctor_report_regenerate",
            turkish: "Yeniden oluştur",
            english: "Create again"
        ),
        AiHealthStringSample(
            key: "doctor_report_disclaimer",
            turkish: "Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir. " +
                "Sağlık kararların için doktoruna danış.",
            english: "This report is for information only and is not medical advice. " +
                "Talk to your doctor about health decisions."
        ),
        AiHealthStringSample(
            key: "doctor_report_preview_title",
            turkish: "Rapor önizleme",
            english: "Report preview"
        ),
        AiHealthStringSample(
            key: "doctor_report_preview_loading",
            turkish: "Önizleme hazırlanıyor…",
            english: "Preparing the preview…"
        ),
        AiHealthStringSample(
            key: "doctor_report_preview_page",
            turkish: "Sayfa %1$lld / %2$lld",
            english: "Page %1$lld of %2$lld"
        ),
        AiHealthStringSample(
            key: "doctor_report_preview_error_title",
            turkish: "Önizleme açılamadı",
            english: "Preview could not be opened"
        ),
        AiHealthStringSample(
            key: "doctor_report_preview_error_message",
            turkish: "Rapor dosyası bu cihazda açılamadı. Raporu yeniden oluşturup tekrar deneyebilirsin.",
            english: "The report file could not be opened on this device. Create the " +
                "report again and try once more."
        ),
        AiHealthStringSample(
            key: "doctor_report_premium_title",
            turkish: "Doktor raporu Premium'a özel",
            english: "The doctor report is a Premium feature"
        ),
        AiHealthStringSample(
            key: "doctor_report_premium_message",
            turkish: "Kayıtlarını PDF olarak dışa aktarmak ve doktorunla paylaşmak Premium ile mümkün.",
            english: "Exporting your records as a PDF and sharing them with your doctor comes with Premium."
        ),
        AiHealthStringSample(
            key: "doctor_report_premium_action",
            turkish: "Premium'a geç",
            english: "Go Premium"
        ),
        AiHealthStringSample(
            key: "doctor_report_insufficient_title",
            turkish: "Bu dönemde kayıt yok",
            english: "No records in this period"
        ),
        AiHealthStringSample(
            key: "doctor_report_insufficient_message",
            turkish: "Seçtiğin dönemde hiç kaydın bulunmuyor, bu yüzden raporda " +
                "gösterilecek bir şey yok. Kayıt tutmaya başlayınca raporunu " +
                "oluşturabilirsin.",
            english: "There are no records at all in the period you picked, so there " +
                "is nothing to put in a report. Start logging and you can " +
                "create one."
        ),
        AiHealthStringSample(
            key: "doctor_report_error_title",
            turkish: "Rapor oluşturulamadı",
            english: "Report could not be created"
        ),
        AiHealthStringSample(
            key: "doctor_report_error_message",
            turkish: "Rapor dosyası cihazına yazılamadı. Depolama alanını kontrol edip tekrar dene.",
            english: "The report file could not be written to your device. Check " +
                "your available storage and try again."
        ),
        AiHealthStringSample(key: "doctor_report_retry", turkish: "Tekrar dene", english: "Try again")
    ]
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
