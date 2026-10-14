// The smoking section's keys of `feature/trends/src/main/res/values*/strings.xml` (iOS-M17 Task 18),
// pinned in their own suite so `TrendsStringsTests` stays inside the 500-line budget. The catalog,
// the key-set pin and the accessor check stay in `TrendsStringsTests`, which reads this table too.
//
// `trends_smoking_heatmap_count` and `trends_smoking_attempt_days` are Android `<plurals>`; this port
// splits each into the plural key and a `_one` twin chosen by count (spec §9 (h), the M14 (e)
// precedent). The heatmap count word is "kayıt" / "entries" (contract §8.12: the cells count every
// occurrence, slips included), where the Android branch still ships "kriz" / "craving".

import Foundation
import SalusTesting
import Testing

@testable import FeatureTrends

extension TrendsStringsTests {
    static let smokingSamples: [TrendsStringSample] = [
        TrendsStringSample(key: "trends_smoking_overline", turkish: "SİGARA", english: "SMOKING"),
        TrendsStringSample(
            key: "trends_smoking_empty_title",
            turkish: "Henüz yeterli veri yok",
            english: "Not enough data yet"
        ),
        TrendsStringSample(
            key: "trends_smoking_empty_message",
            turkish: "Tetikleyicileri ve kriz saatlerini görebilmek için en az 7 farklı güne ait kayıt gerekiyor. "
                + "Kayıt girdikçe bu bölüm dolar.",
            english: "Triggers and craving times need entries from at least 7 different days. "
                + "This section fills in as you log."
        ),
        TrendsStringSample(key: "trends_smoking_triggers_title", turkish: "Tetikleyiciler", english: "Triggers"),
        TrendsStringSample(key: "trends_smoking_triggers_subtitle", turkish: "Son 30 gün", english: "Last 30 days"),
        TrendsStringSample(key: "trends_smoking_trigger_coffee", turkish: "Kahve", english: "Coffee"),
        TrendsStringSample(key: "trends_smoking_trigger_stress", turkish: "Stres", english: "Stress"),
        TrendsStringSample(key: "trends_smoking_trigger_alcohol", turkish: "Alkol", english: "Alcohol"),
        TrendsStringSample(
            key: "trends_smoking_trigger_after_meal",
            turkish: "Yemek sonrası",
            english: "After a meal"
        ),
        TrendsStringSample(key: "trends_smoking_trigger_social", turkish: "Sosyal ortam", english: "Social setting"),
        TrendsStringSample(key: "trends_smoking_trigger_boredom", turkish: "Can sıkıntısı", english: "Boredom"),
        TrendsStringSample(key: "trends_smoking_trigger_other", turkish: "Diğer", english: "Other"),
        TrendsStringSample(key: "trends_smoking_percent", turkish: "%%%1$lld", english: "%1$lld%%"),
        TrendsStringSample(
            key: "trends_smoking_trigger_description",
            turkish: "%1$@, yüzde %2$lld",
            english: "%1$@, %2$lld percent"
        ),
        TrendsStringSample(
            key: "trends_smoking_triggers_chart_description",
            turkish: "Tetikleyicilerin dağılımı, tetikleyici seçilen kayıtlar içinde",
            english: "Share of each trigger among the entries where one was chosen"
        ),
        TrendsStringSample(key: "trends_smoking_heatmap_title", turkish: "Krizlerin zamanı", english: "Craving times"),
        TrendsStringSample(
            key: "trends_smoking_heatmap_subtitle",
            turkish: "Haftalık dağılım",
            english: "Weekly pattern"
        ),
        TrendsStringSample(key: "trends_smoking_band_short_08_10", turkish: "08–10", english: "08–10"),
        TrendsStringSample(key: "trends_smoking_band_short_10_12", turkish: "10–12", english: "10–12"),
        TrendsStringSample(key: "trends_smoking_band_short_12_14", turkish: "12–14", english: "12–14"),
        TrendsStringSample(key: "trends_smoking_band_short_14_16", turkish: "14–16", english: "14–16"),
        TrendsStringSample(key: "trends_smoking_band_short_16_18", turkish: "16–18", english: "16–18"),
        TrendsStringSample(key: "trends_smoking_band_short_18_22", turkish: "18–22", english: "18–22"),
        TrendsStringSample(key: "trends_smoking_band_short_22_08", turkish: "22–08", english: "22–08"),
        TrendsStringSample(key: "trends_smoking_band_08_10", turkish: "08:00–10:00", english: "08:00–10:00"),
        TrendsStringSample(key: "trends_smoking_band_10_12", turkish: "10:00–12:00", english: "10:00–12:00"),
        TrendsStringSample(key: "trends_smoking_band_12_14", turkish: "12:00–14:00", english: "12:00–14:00"),
        TrendsStringSample(key: "trends_smoking_band_14_16", turkish: "14:00–16:00", english: "14:00–16:00"),
        TrendsStringSample(key: "trends_smoking_band_16_18", turkish: "16:00–18:00", english: "16:00–18:00"),
        TrendsStringSample(key: "trends_smoking_band_18_22", turkish: "18:00–22:00", english: "18:00–22:00"),
        TrendsStringSample(key: "trends_smoking_band_22_08", turkish: "22:00–08:00", english: "22:00–08:00"),
        TrendsStringSample(key: "trends_smoking_weekday_short_1", turkish: "Pzt", english: "Mon"),
        TrendsStringSample(key: "trends_smoking_weekday_short_2", turkish: "Sal", english: "Tue"),
        TrendsStringSample(key: "trends_smoking_weekday_short_3", turkish: "Çar", english: "Wed"),
        TrendsStringSample(key: "trends_smoking_weekday_short_4", turkish: "Per", english: "Thu"),
        TrendsStringSample(key: "trends_smoking_weekday_short_5", turkish: "Cum", english: "Fri"),
        TrendsStringSample(key: "trends_smoking_weekday_short_6", turkish: "Cmt", english: "Sat"),
        TrendsStringSample(key: "trends_smoking_weekday_short_7", turkish: "Paz", english: "Sun"),
        TrendsStringSample(key: "trends_smoking_weekday_1", turkish: "Pazartesi", english: "Monday"),
        TrendsStringSample(key: "trends_smoking_weekday_2", turkish: "Salı", english: "Tuesday"),
        TrendsStringSample(key: "trends_smoking_weekday_3", turkish: "Çarşamba", english: "Wednesday"),
        TrendsStringSample(key: "trends_smoking_weekday_4", turkish: "Perşembe", english: "Thursday"),
        TrendsStringSample(key: "trends_smoking_weekday_5", turkish: "Cuma", english: "Friday"),
        TrendsStringSample(key: "trends_smoking_weekday_6", turkish: "Cumartesi", english: "Saturday"),
        TrendsStringSample(key: "trends_smoking_weekday_7", turkish: "Pazar", english: "Sunday"),
        TrendsStringSample(key: "trends_smoking_heatmap_cell", turkish: "%1$@ %2$@: %3$@", english: "%1$@ %2$@: %3$@"),
        TrendsStringSample(key: "trends_smoking_heatmap_count", turkish: "%1$lld kayıt", english: "%1$lld entries"),
        TrendsStringSample(key: "trends_smoking_heatmap_count_one", turkish: "%1$lld kayıt", english: "%1$lld entry"),
        TrendsStringSample(
            key: "trends_smoking_heatmap_caption",
            turkish: "En yoğun aralık: %1$@ · payı %%%2$lld",
            english: "Busiest window: %1$@ · %2$lld%% of entries"
        ),
        TrendsStringSample(
            key: "trends_smoking_reduction_title",
            turkish: "Azaltma eğrisi",
            english: "Reduction curve"
        ),
        TrendsStringSample(
            key: "trends_smoking_reduction_subtitle",
            turkish: "Haftalık günlük ortalama",
            english: "Daily average per week"
        ),
        TrendsStringSample(key: "trends_smoking_reduction_week", turkish: "%1$lld. hafta", english: "Week %1$lld"),
        TrendsStringSample(
            key: "trends_smoking_reduction_description",
            turkish: "Haftalık günlük ortalama: ilk hafta %1$lld, son hafta %2$lld",
            english: "Daily average per week: %1$lld in the first week, %2$lld in the latest"
        ),
        TrendsStringSample(key: "trends_smoking_attempts_title", turkish: "Denemeler", english: "Attempts"),
        TrendsStringSample(
            key: "trends_smoking_attempts_subtitle",
            turkish: "Süre karşılaştırması",
            english: "Length comparison"
        ),
        TrendsStringSample(key: "trends_smoking_attempt_label", turkish: "%1$lld. deneme", english: "Attempt %1$lld"),
        TrendsStringSample(key: "trends_smoking_attempt_days", turkish: "%1$lld gün", english: "%1$lld days"),
        TrendsStringSample(key: "trends_smoking_attempt_days_one", turkish: "%1$lld gün", english: "%1$lld day"),
        TrendsStringSample(key: "trends_smoking_attempt_description", turkish: "%1$@: %2$@", english: "%1$@: %2$@"),
        TrendsStringSample(key: "trends_smoking_quit_marker", turkish: "Bıraktın", english: "You quit")
    ]
}

@Suite("FeatureTrends smoking strings")
struct TrendsSmokingStringsTests {
    /// An overline is stored upper-case in both locales and never folded at run time: Turkish has two
    /// dotted i's and a runtime fold cannot know which one a label means (`copy.md`).
    @Test("every overline is stored upper-case in both locales")
    func overlinesAreStoredUpperCase() throws {
        let catalog = try TrendsStringsTests.loadCatalog()
        let overlineKeys = TrendsStringsTests.expectedKeys.filter { $0.hasSuffix("_overline") }.sorted()

        // The three metric overlines and the smoking section's.
        #expect(overlineKeys.count == 4)
        for key in overlineKeys {
            for locale in ["tr", "en"] {
                let value = try #require(catalog.value(of: key, in: locale))
                #expect(value == value.uppercased(with: Locale(identifier: locale)), "\(key) [\(locale)]")
            }
        }
    }

    /// The count word of the heatmap cells and its singular twin (contract §8.12, spec §9 (h)).
    @Test("the plural pairs carry one count and differ only where English does")
    func pluralPairsCarryOneCount() throws {
        let catalog = try TrendsStringsTests.loadCatalog()

        for key in [
            "trends_smoking_heatmap_count", "trends_smoking_heatmap_count_one",
            "trends_smoking_attempt_days", "trends_smoking_attempt_days_one"
        ] {
            for locale in ["tr", "en"] {
                let value = try #require(catalog.value(of: key, in: locale))
                #expect(value.contains("%1$lld"), "\(key) [\(locale)]")
            }
        }
        // Turkish has one form; English tells one from several.
        #expect(catalog.value(of: "trends_smoking_heatmap_count", in: "tr")
            == catalog.value(of: "trends_smoking_heatmap_count_one", in: "tr"))
        #expect(catalog.value(of: "trends_smoking_heatmap_count_one", in: "en") == "%1$lld entry")
        #expect(catalog.value(of: "trends_smoking_heatmap_count", in: "en") == "%1$lld entries")
    }

    /// The heatmap says "entries", never "cravings": slips are counted too (contract §8.12).
    @Test("the heatmap count word is not 'kriz' or 'craving'")
    func heatmapCountWordIsEntries() throws {
        let catalog = try TrendsStringsTests.loadCatalog()

        for key in ["trends_smoking_heatmap_count", "trends_smoking_heatmap_count_one"] {
            #expect(try #require(catalog.value(of: key, in: "tr")).contains("kayıt"))
            #expect(try #require(catalog.value(of: key, in: "en")).contains("entr"))
        }
    }
}
