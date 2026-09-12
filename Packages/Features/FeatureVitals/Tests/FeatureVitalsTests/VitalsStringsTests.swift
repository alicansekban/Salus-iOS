import Foundation
import SalusTesting
import Testing

@testable import FeatureVitals

/// The twin of Android's `feature/vitals/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: all 56 keys and
/// both of their translations are pinned here, copied from the XML.
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `VitalsStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all, so a
/// resolved string here would only ever be the key back. The end-to-end check is the simulator
/// run (iOS-M2 Task 7).
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the Android-verbatim values.
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`, so the
/// next feature's catalog is covered without remembering to copy a test.
@Suite("FeatureVitals strings")
struct VitalsStringsTests {
    static let samples = VitalsStringTable.samples
    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 56 keys :feature:vitals owns")
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

    @Test(
        "the values are Android-verbatim (feature/vitals/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: VitalsStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `VitalsStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(VitalsStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the two format keys carry Swift specifiers and render the Android sentence")
    func formatKeysRenderTheAndroidSentence() throws {
        let catalog = try Self.loadCatalog()

        // Android's `%1$s`/`%1$d` are Java specifiers. `%s` reads a C string pointer under
        // `String(format:)` and `%d` reads 32 bits of a 64-bit Swift `Int`, so the catalog carries
        // `%1$@`/`%1$lld` instead — see the mapping table in `VitalsStrings.swift`. The sentence
        // around them is unchanged, and these are the assertions that say so.
        for locale in ["tr", "en"] {
            let format = try #require(catalog.value(of: "vitals_kpi_chip", in: locale))
            #expect(format.contains("%1$@"))
            #expect(format.contains("%2$@"))
            #expect(String(format: format, locale: nil, "Kilo", "78,7 kg") == "Kilo · 78,7 kg")
        }
        try #expect(Self.render("vitals_pulse_value", "tr", 72) == "Nabız: 72 bpm")
        try #expect(Self.render("vitals_pulse_value", "en", 72) == "Pulse: 72 bpm")
        try #expect(#require(catalog.value(of: "vitals_pulse_value", in: "tr")).contains("%1$lld"))
        try #expect(#require(catalog.value(of: "vitals_pulse_value", in: "en")).contains("%1$lld"))
    }

    /// Spec §6: overline strings are stored upper-case, so no call site ever calls
    /// `uppercased()` — Turkish has two dotted i's and a runtime fold cannot know which one a
    /// label means. These are the eleven keys M15 draws as an overline.
    @Test("every overline is stored upper-case, in both languages")
    func overlinesAreStoredUpperCase() throws {
        let catalog = try Self.loadCatalog()
        let overlines = [
            "vitals_weight_label", "vitals_systolic_label", "vitals_diastolic_label",
            "vitals_pulse_label", "vitals_glucose_value_label", "vitals_note_label",
            "vitals_latest_label", "vitals_chart_section", "vitals_history_section",
            "vitals_metric_max", "vitals_metric_avg", "vitals_metric_min"
        ]
        for key in overlines {
            for locale in ["tr", "en"] {
                let value = try #require(catalog.value(of: key, in: locale))
                #expect(
                    value == value.uppercased(with: Locale(identifier: locale)),
                    "\(key) in \(locale) is not stored upper-case"
                )
            }
        }
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
            .deletingLastPathComponent() // FeatureVitalsTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeatureVitals
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeatureVitals/Resources/Localizable.xcstrings")
        )
    }
}

/// Every key `:feature:vitals` owns, with both translations, copied from the XML. A new key
/// there means a new row here, in the same commit — that is the whole job of this table.
///
/// Its own type rather than a `static let` on the suite: it is data, not a test, and 56 rows
/// inside the suite put its body past SwiftLint's 300-line `type_body_length`.
enum VitalsStringTable {
    static let samples: [VitalsStringSample] = [
        VitalsStringSample(
            key: "vitals_title",
            turkish: "Ölçümler",
            english: "Vitals"
        ),
        VitalsStringSample(
            key: "vitals_type_weight",
            turkish: "Kilo",
            english: "Weight"
        ),
        VitalsStringSample(
            key: "vitals_type_blood_pressure",
            turkish: "Tansiyon",
            english: "Blood pressure"
        ),
        VitalsStringSample(
            key: "vitals_type_glucose",
            turkish: "Kan şekeri",
            english: "Blood glucose"
        ),
        VitalsStringSample(
            key: "vitals_empty",
            turkish: "Henüz ölçüm yok. İlk kilo kaydını ekle.",
            english: "No measurements yet. Add your first weight entry."
        ),
        VitalsStringSample(
            key: "vitals_empty_blood_pressure",
            turkish: "Henüz ölçüm yok. İlk tansiyon kaydını ekle.",
            english: "No measurements yet. Add your first blood pressure entry."
        ),
        VitalsStringSample(
            key: "vitals_empty_glucose",
            turkish: "Henüz ölçüm yok. İlk kan şekeri kaydını ekle.",
            english: "No measurements yet. Add your first blood glucose entry."
        ),
        VitalsStringSample(
            key: "vitals_add_entry",
            turkish: "Ölçüm ekle",
            english: "Add measurement"
        ),
        VitalsStringSample(
            key: "vitals_range_week",
            turkish: "7G",
            english: "7D"
        ),
        VitalsStringSample(
            key: "vitals_range_month",
            turkish: "30G",
            english: "30D"
        ),
        VitalsStringSample(
            key: "vitals_range_quarter",
            turkish: "90G",
            english: "90D"
        ),
        VitalsStringSample(
            key: "vitals_range_year",
            turkish: "1Y",
            english: "1Y"
        ),
        VitalsStringSample(
            key: "vitals_weight_label",
            turkish: "KİLO",
            english: "WEIGHT"
        ),
        VitalsStringSample(
            key: "vitals_systolic_label",
            turkish: "BÜYÜK TANSİYON",
            english: "SYSTOLIC"
        ),
        VitalsStringSample(
            key: "vitals_diastolic_label",
            turkish: "KÜÇÜK TANSİYON",
            english: "DIASTOLIC"
        ),
        VitalsStringSample(
            key: "vitals_pulse_label",
            turkish: "NABIZ (İSTEĞE BAĞLI)",
            english: "PULSE (OPTIONAL)"
        ),
        VitalsStringSample(
            key: "vitals_pulse_value",
            turkish: "Nabız: %1$lld bpm",
            english: "Pulse: %1$lld bpm"
        ),
        VitalsStringSample(
            key: "vitals_glucose_value_label",
            turkish: "KAN ŞEKERİ",
            english: "BLOOD GLUCOSE"
        ),
        VitalsStringSample(
            key: "vitals_note_label",
            turkish: "NOT (İSTEĞE BAĞLI)",
            english: "NOTE (OPTIONAL)"
        ),
        VitalsStringSample(
            key: "vitals_invalid_weight",
            turkish: "20 ile 400 kg arasında bir değer gir.",
            english: "Enter a weight between 20 and 400 kg."
        ),
        VitalsStringSample(
            key: "vitals_invalid_systolic",
            turkish: "Büyük tansiyon için 60 ile 250 mmHg arasında bir değer gir.",
            english: "Enter a systolic value between 60 and 250 mmHg."
        ),
        VitalsStringSample(
            key: "vitals_invalid_diastolic",
            turkish: "Küçük tansiyon için 30 ile 150 mmHg arasında bir değer gir.",
            english: "Enter a diastolic value between 30 and 150 mmHg."
        ),
        VitalsStringSample(
            key: "vitals_invalid_pulse",
            turkish: "Nabız için 20 ile 250 bpm arasında bir değer gir.",
            english: "Enter a pulse between 20 and 250 bpm."
        ),
        VitalsStringSample(
            key: "vitals_invalid_bp_difference",
            turkish: "Büyük tansiyon küçük tansiyondan yüksek olmalı.",
            english: "Systolic must be higher than diastolic."
        ),
        VitalsStringSample(
            key: "vitals_invalid_glucose",
            turkish: "20 ile 600 mg/dL (1,1 ile 33,3 mmol/L) arasında bir değer gir.",
            english: "Enter a value between 20 and 600 mg/dL (1.1 and 33.3 mmol/L)."
        ),
        VitalsStringSample(
            key: "vitals_context_fasting",
            turkish: "Açlık",
            english: "Fasting"
        ),
        VitalsStringSample(
            key: "vitals_context_post_meal",
            turkish: "Tokluk",
            english: "After meal"
        ),
        VitalsStringSample(
            key: "vitals_context_bedtime",
            turkish: "Yatmadan önce",
            english: "Bedtime"
        ),
        VitalsStringSample(
            key: "vitals_context_random",
            turkish: "Rastgele",
            english: "Random"
        ),
        VitalsStringSample(
            key: "vitals_select_date",
            turkish: "Tarih seç",
            english: "Select date"
        ),
        VitalsStringSample(
            key: "vitals_save",
            turkish: "Kaydet",
            english: "Save"
        ),
        VitalsStringSample(
            key: "vitals_delete",
            turkish: "Sil",
            english: "Delete"
        ),
        VitalsStringSample(
            key: "vitals_delete_title",
            turkish: "Kayıt silinsin mi?",
            english: "Delete this entry?"
        ),
        VitalsStringSample(
            key: "vitals_delete_message",
            turkish: "Bu ölçüm kalıcı olarak kaldırılır.",
            english: "This measurement is removed for good."
        ),
        VitalsStringSample(
            key: "vitals_entry_deleted",
            turkish: "Kayıt silindi",
            english: "Entry deleted"
        ),
        VitalsStringSample(
            key: "vitals_open_trends",
            turkish: "Analizler",
            english: "Trends"
        ),
        VitalsStringSample(
            key: "vitals_kpi_weight",
            turkish: "Kilo",
            english: "Weight"
        ),
        VitalsStringSample(
            key: "vitals_kpi_blood_pressure",
            turkish: "Tansiyon",
            english: "Blood pressure"
        ),
        VitalsStringSample(
            key: "vitals_kpi_glucose",
            turkish: "Şeker",
            english: "Glucose"
        ),
        VitalsStringSample(
            key: "vitals_kpi_chip",
            turkish: "%1$@ · %2$@",
            english: "%1$@ · %2$@"
        ),
        VitalsStringSample(
            key: "vitals_value_none",
            turkish: "—",
            english: "—"
        ),
        VitalsStringSample(
            key: "vitals_latest_label",
            turkish: "SON ÖLÇÜM",
            english: "LATEST MEASUREMENT"
        ),
        VitalsStringSample(
            key: "vitals_chart_section",
            turkish: "GRAFİK",
            english: "CHART"
        ),
        VitalsStringSample(
            key: "vitals_history_section",
            turkish: "GEÇMİŞ ÖLÇÜMLER",
            english: "PAST MEASUREMENTS"
        ),
        VitalsStringSample(
            key: "vitals_metric_max",
            turkish: "EN YÜKSEK",
            english: "HIGHEST"
        ),
        VitalsStringSample(
            key: "vitals_metric_avg",
            turkish: "ORTALAMA",
            english: "AVERAGE"
        ),
        VitalsStringSample(
            key: "vitals_metric_min",
            turkish: "EN DÜŞÜK",
            english: "LOWEST"
        ),
        VitalsStringSample(
            key: "vitals_edit",
            turkish: "Düzenle",
            english: "Edit"
        ),
        VitalsStringSample(
            key: "vitals_editor_title_new",
            turkish: "Yeni Ölçüm",
            english: "New measurement"
        ),
        VitalsStringSample(
            key: "vitals_editor_title_edit",
            turkish: "Ölçümü Düzenle",
            english: "Edit measurement"
        ),
        VitalsStringSample(
            key: "vitals_editor_subtitle",
            turkish: "Değerleri gir, tarihi seç ve kaydet.",
            english: "Enter the values, pick the date and save."
        ),
        VitalsStringSample(
            key: "vitals_editor_tip",
            turkish: """
            Ölçümleri her seferinde benzer koşullarda almak, kayıtlarını birbiriyle \
            karşılaştırılabilir kılar.
            """,
            english: """
            Taking measurements under similar conditions each time keeps your records \
            comparable with one another.
            """
        ),
        VitalsStringSample(
            key: "vitals_bp_hint_sys",
            turkish: "Aralık: 90–140",
            english: "Range: 90–140"
        ),
        VitalsStringSample(
            key: "vitals_bp_hint_dia",
            turkish: "Aralık: 60–90",
            english: "Range: 60–90"
        ),
        VitalsStringSample(
            key: "vitals_save_measurement",
            turkish: "Ölçümü Kaydet",
            english: "Save measurement"
        ),
        VitalsStringSample(
            key: "vitals_note_placeholder",
            turkish: "Kısa bir not ekle",
            english: "Add a short note"
        )
    ]
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct VitalsStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
