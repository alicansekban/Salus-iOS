import Foundation
import SalusModel
import SalusTesting
import Testing

@testable import FeatureCycle

/// The twin of Android's `feature/cycle/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: all 56 keys and
/// both of their translations are pinned here, copied from the XML.
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `CycleStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all, so a
/// resolved string here would only ever be the key back. The end-to-end check is the simulator
/// run.
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the values themselves, Android's own, verbatim.
@Suite("FeatureCycle strings")
struct CycleStringsTests {
    /// Every key `:feature:cycle` owns, with both translations, copied from the XML. A new key
    /// there means a new row here, in the same commit — that is the whole job of this table. The
    /// rows follow the XML's order, grouped by the screen that reads them.
    static let samples: [CycleStringSample] = [
        // The calendar screen: chrome and legend (6).
        CycleStringSample(key: "cycle_title", turkish: "Döngü", english: "Cycle"),
        CycleStringSample(key: "cycle_previous_month", turkish: "Önceki ay", english: "Previous month"),
        CycleStringSample(key: "cycle_next_month", turkish: "Sonraki ay", english: "Next month"),
        CycleStringSample(key: "cycle_legend_period", turkish: "Regl", english: "Period"),
        CycleStringSample(key: "cycle_legend_predicted", turkish: "Tahmin", english: "Predicted"),
        CycleStringSample(key: "cycle_legend_fertile", turkish: "Doğurgan dönem", english: "Fertile window"),
        // The prediction summary (9).
        CycleStringSample(key: "cycle_day_number", turkish: "Döngünün %1$lld. günü", english: "Cycle day %1$lld"),
        CycleStringSample(
            key: "cycle_days_until_period",
            turkish: "Tahmini regl %1$lld gün sonra",
            english: "Predicted next period in %1$lld days"
        ),
        CycleStringSample(
            key: "cycle_period_overdue",
            turkish: "Tahmini regl %1$lld gün gecikti",
            english: "Predicted period is %1$lld days late"
        ),
        CycleStringSample(
            key: "cycle_no_prediction",
            turkish: "Tahminleri görmek için en az iki regl kaydı ekle.",
            english: "Log at least two periods to see predictions."
        ),
        CycleStringSample(
            key: "cycle_confidence",
            turkish: "Tahmin güveni: %1$@",
            english: "Prediction confidence: %1$@"
        ),
        CycleStringSample(key: "cycle_confidence_low", turkish: "Düşük", english: "Low"),
        CycleStringSample(key: "cycle_confidence_medium", turkish: "Orta", english: "Medium"),
        CycleStringSample(key: "cycle_confidence_high", turkish: "Yüksek", english: "High"),
        CycleStringSample(
            key: "cycle_irregular",
            turkish: "Döngülerin düzensiz görünüyor; tahminler daha az isabetli olabilir.",
            english: "Your cycles look irregular; predictions may be less accurate."
        ),
        // The day sheet: actions and section headers (9).
        CycleStringSample(key: "cycle_period_started", turkish: "Regl başladı", english: "Period started"),
        CycleStringSample(key: "cycle_period_ended", turkish: "Regl bitti", english: "Period ended"),
        CycleStringSample(
            key: "cycle_disclaimer",
            turkish: "Bu tıbbi tavsiye değildir.",
            english: "This is not medical advice."
        ),
        CycleStringSample(key: "cycle_symptoms_title", turkish: "Belirtiler", english: "Symptoms"),
        CycleStringSample(key: "cycle_flow_title", turkish: "Akış", english: "Flow"),
        CycleStringSample(key: "cycle_mood_title", turkish: "Ruh hali", english: "Mood"),
        CycleStringSample(key: "cycle_note_label", turkish: "Not (isteğe bağlı)", english: "Note (optional)"),
        CycleStringSample(key: "cycle_save", turkish: "Kaydet", english: "Save"),
        CycleStringSample(key: "cycle_back", turkish: "Geri", english: "Back"),
        // The symptom catalog (8).
        CycleStringSample(key: "cycle_symptom_cramps", turkish: "Kramp", english: "Cramps"),
        CycleStringSample(key: "cycle_symptom_headache", turkish: "Baş ağrısı", english: "Headache"),
        CycleStringSample(key: "cycle_symptom_mood_swings", turkish: "Duygu dalgalanması", english: "Mood swings"),
        CycleStringSample(key: "cycle_symptom_bloating", turkish: "Şişkinlik", english: "Bloating"),
        CycleStringSample(key: "cycle_symptom_fatigue", turkish: "Yorgunluk", english: "Fatigue"),
        CycleStringSample(key: "cycle_symptom_tender_breasts", turkish: "Göğüs hassasiyeti", english: "Tender breasts"),
        CycleStringSample(key: "cycle_symptom_acne", turkish: "Akne", english: "Acne"),
        CycleStringSample(key: "cycle_symptom_back_pain", turkish: "Bel ağrısı", english: "Back pain"),
        // The flow levels (4).
        CycleStringSample(key: "cycle_flow_spotting", turkish: "Lekelenme", english: "Spotting"),
        CycleStringSample(key: "cycle_flow_light", turkish: "Hafif", english: "Light"),
        CycleStringSample(key: "cycle_flow_medium", turkish: "Orta", english: "Medium"),
        CycleStringSample(key: "cycle_flow_heavy", turkish: "Yoğun", english: "Heavy"),
        // The moods (6).
        CycleStringSample(key: "cycle_mood_great", turkish: "Harika", english: "Great"),
        CycleStringSample(key: "cycle_mood_good", turkish: "İyi", english: "Good"),
        CycleStringSample(key: "cycle_mood_neutral", turkish: "Nötr", english: "Neutral"),
        CycleStringSample(key: "cycle_mood_low", turkish: "Keyifsiz", english: "Low"),
        CycleStringSample(key: "cycle_mood_irritable", turkish: "Gergin", english: "Irritable"),
        CycleStringSample(key: "cycle_mood_anxious", turkish: "Endişeli", english: "Anxious"),
        // The period reminder settings card (10).
        CycleStringSample(key: "cycle_reminder_title", turkish: "Dönem hatırlatıcısı", english: "Period reminder"),
        CycleStringSample(
            key: "cycle_reminder_desc",
            turkish: "Tahmin edilen dönem başlangıcından önce bildirim al",
            english: "Get notified before your predicted period start"
        ),
        CycleStringSample(
            key: "cycle_reminder_needs_data",
            turkish: "Yeterli döngü verisi olduğunda bildirim gönderilir",
            english: "Notifications start once there is enough cycle data"
        ),
        CycleStringSample(key: "cycle_reminder_lead_label", turkish: "Ne zaman", english: "When"),
        CycleStringSample(key: "cycle_reminder_time_label", turkish: "Saat", english: "Time"),
        CycleStringSample(
            key: "cycle_reminder_lead_same_day",
            turkish: "Tahmin edilen gün",
            english: "On the predicted day"
        ),
        CycleStringSample(
            key: "cycle_reminder_lead_days_before",
            turkish: "%1$lld gün önce",
            english: "%1$lld days before"
        ),
        CycleStringSample(key: "cycle_reminder_cancel", turkish: "Vazgeç", english: "Cancel"),
        CycleStringSample(key: "cycle_reminder_time_confirm", turkish: "Tamam", english: "OK"),
        // The reminder notification (3).
        CycleStringSample(
            key: "cycle_reminder_notification_title",
            turkish: "Dönem yaklaşıyor",
            english: "Period coming up"
        ),
        CycleStringSample(
            key: "cycle_reminder_notification_body_today",
            turkish: "Tahmini dönem başlangıcı bugün. Tahminler kesin değildir.",
            english: "Your period is predicted to start today. Predictions are estimates."
        ),
        CycleStringSample(
            key: "cycle_reminder_notification_body_days",
            turkish: "Tahmini dönem başlangıcına %1$lld gün var. Tahminler kesin değildir.",
            english: "Your period is predicted to start in %1$lld days. Predictions are estimates."
        ),
        // What VoiceOver says on a calendar day (2).
        CycleStringSample(key: "cycle_a11y_today", turkish: "Bugün", english: "Today"),
        CycleStringSample(key: "cycle_a11y_ovulation", turkish: "Yumurtlama günü", english: "Ovulation day")
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 56 keys :feature:cycle owns")
    func catalogHoldsExactlyTheFiftySixKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 56)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test("the values match res/values*/strings.xml", arguments: samples)
    func valuesAreAndroidVerbatim(sample: CycleStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `CycleStrings.Key`'s raw values does not fail to compile — it ships the
        // key itself as the label. This is the check that catches it.
        #expect(Set(CycleStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the six format keys carry Swift specifiers and render the Android sentence")
    func formatKeysRenderTheAndroidSentence() throws {
        // Android's `%1$s`/`%1$d` are Java specifiers. `%s` reads a C string pointer under
        // `String(format:)` and `%d` reads 32 bits of a 64-bit Swift `Int`, so the catalog carries
        // `%1$@`/`%1$lld` instead — see the mapping table in `CycleStrings.swift`. The sentence
        // around them is unchanged, and these are the assertions that say so.
        try #expect(Self.render("cycle_day_number", "tr", 14) == "Döngünün 14. günü")
        try #expect(Self.render("cycle_day_number", "en", 14) == "Cycle day 14")
        try #expect(Self.render("cycle_days_until_period", "tr", 3) == "Tahmini regl 3 gün sonra")
        try #expect(Self.render("cycle_days_until_period", "en", 3) == "Predicted next period in 3 days")
        try #expect(Self.render("cycle_period_overdue", "tr", 2) == "Tahmini regl 2 gün gecikti")
        try #expect(Self.render("cycle_period_overdue", "en", 2) == "Predicted period is 2 days late")
        try #expect(Self.render("cycle_confidence", "tr", "Yüksek") == "Tahmin güveni: Yüksek")
        try #expect(Self.render("cycle_confidence", "en", "High") == "Prediction confidence: High")
        try #expect(Self.render("cycle_reminder_lead_days_before", "tr", 2) == "2 gün önce")
        try #expect(Self.render("cycle_reminder_lead_days_before", "en", 2) == "2 days before")
        try #expect(
            Self.render("cycle_reminder_notification_body_days", "tr", 3)
                == "Tahmini dönem başlangıcına 3 gün var. Tahminler kesin değildir."
        )
        try #expect(
            Self.render("cycle_reminder_notification_body_days", "en", 3)
                == "Your period is predicted to start in 3 days. Predictions are estimates."
        )

        try Self.assertSpecifiers()
    }

    @Test("symptomLabel maps the eight catalog keys and falls back to a custom entry's raw key")
    func symptomLabelMapsTheEightCatalogKeys() {
        // The Swift twin of `CycleDayScreen.kt:181-191`. The mapping is asserted through the KEY
        // rather than the resolved label, because `swift test` does not compile the catalog (the
        // toolchain note) — and asserting the key is also what would catch the mapping pointing
        // at the wrong string once it does resolve.
        let mapped: [(nameKey: String, key: CycleStrings.Key)] = [
            ("cramps", .symptomCramps),
            ("headache", .symptomHeadache),
            ("mood_swings", .symptomMoodSwings),
            ("bloating", .symptomBloating),
            ("fatigue", .symptomFatigue),
            ("tender_breasts", .symptomTenderBreasts),
            ("acne", .symptomAcne),
            ("back_pain", .symptomBackPain)
        ]

        for row in mapped {
            #expect(CycleStrings.symptomKey(nameKey: row.nameKey) == row.key)
        }

        // A custom symptom the user typed is in no catalog, so `symptomLabel` hands the raw key
        // back untouched — the one branch that resolves nothing and can be asserted end to end.
        #expect(CycleStrings.symptomKey(nameKey: "kolik") == nil)
        #expect(CycleStrings.symptomLabel(nameKey: "kolik") == "kolik")
        #expect(CycleStrings.symptomLabel(nameKey: "").isEmpty)
    }

    @Test("flowLabel, moodLabel and confidenceLabel cover every case of their enum")
    func enumLabelsCoverEveryCase() {
        // Read the same way: the case-to-key mapping is the assertion, and it is the Kotlin one
        // (`CycleDayScreen.kt:194-209`, `CycleScreen.kt:536-540`).
        #expect(FlowLevel.allCases.map(CycleStrings.flowKey) == [
            .flowSpotting,
            .flowLight,
            .flowMedium,
            .flowHeavy
        ])
        #expect(Mood.allCases.map(CycleStrings.moodKey) == [
            .moodGreat,
            .moodGood,
            .moodNeutral,
            .moodLow,
            .moodIrritable,
            .moodAnxious
        ])
        #expect(CycleConfidence.allCases.map(CycleStrings.confidenceKey) == [
            .confidenceLow,
            .confidenceMedium,
            .confidenceHigh
        ])
    }

    @Test("CycleConfidence's raw values are the Kotlin constant names")
    func confidenceRawValuesAreTheKotlinConstantNames() {
        // Not persisted — a prediction never is — but the raw values still stay Android's, so the
        // enum reads as the twin of `CyclePrediction.kt`'s and a future log or export cannot
        // invent a second spelling.
        #expect(CycleConfidence.allCases.map(\.rawValue) == ["LOW", "MEDIUM", "HIGH"])
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
        let integerKeys = [
            "cycle_day_number",
            "cycle_days_until_period",
            "cycle_period_overdue",
            "cycle_reminder_lead_days_before",
            "cycle_reminder_notification_body_days"
        ]

        for locale in ["tr", "en"] {
            for key in integerKeys {
                try #expect(#require(catalog.value(of: key, in: locale)).contains("%1$lld"))
            }
            // The one `%1$s` on the Android side, and so the one `%1$@` here.
            try #expect(#require(catalog.value(of: "cycle_confidence", in: locale)).contains("%1$@"))
        }
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // FeatureCycleTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // FeatureCycle
        .appendingPathComponent("Sources/FeatureCycle/Resources/Localizable.xcstrings")

    static func loadCatalog() throws -> StringCatalog {
        try StringCatalogParity.load(at: catalogURL)
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct CycleStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
