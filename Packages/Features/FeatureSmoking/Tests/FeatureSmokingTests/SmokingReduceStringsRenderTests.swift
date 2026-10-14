// The REDUCE keys that carry placeholders, rendered: the mapping (`%d` -> `%lld`, `%1$s` -> `%1$@`)
// must still read as the Android sentences.

import SalusTesting
import Testing

@testable import FeatureSmoking

extension SmokingStringsTests {
    @Test("the REDUCE format keys render the Android sentences")
    func reduceFormatKeysRenderTheAndroidSentences() throws {
        let catalog = try Self.loadCatalog()

        try #expect(Self.render(catalog, "smoking_reduce_ring_limit", "tr", 10) == " / 10")
        try #expect(Self.render(catalog, "smoking_reduce_ring_semantics", "tr", 6, 10) == "Bugün 6 adet, limit 10")
        try #expect(Self.render(catalog, "smoking_reduce_ring_semantics", "en", 6, 10) == "Today 6, limit 10")
        try #expect(Self.render(catalog, "smoking_reduce_over_chip", "en", 2) == "+2")
        try #expect(Self.render(catalog, "smoking_reduce_over_chip_cd", "tr", 2) == "Limitin 2 adet üzerinde")
        try #expect(
            Self.render(catalog, "smoking_reduce_week_full", "tr", 23, "₺161")
                == "Bu hafta 23 adet daha az · ₺161 cebinde kaldı"
        )
        try #expect(
            Self.render(catalog, "smoking_reduce_week_full", "en", 23, "₺161")
                == "23 fewer this week · ₺161 stays in your pocket"
        )
        try #expect(Self
            .render(catalog, "smoking_reduce_week_money", "en", "₺42") == "₺42 stays in your pocket this week")
        try #expect(Self.render(catalog, "smoking_reduce_chart_day_value", "tr", "Sal", "7") == "Sal 7")
        try #expect(
            Self.render(catalog, "smoking_reduce_chart_cd", "en", "Mon 8, Tue no data")
                == "Daily counts for the last 7 days: Mon 8, Tue no data"
        )
        try #expect(Self.render(catalog, "smoking_reduce_chart_baseline", "tr", 20) == "Eski ortalaman: 20")
        try #expect(Self.render(catalog, "smoking_reduce_under_body", "en", 4) == "4 left for today.")
        try #expect(Self.render(catalog, "smoking_reduce_over_body", "tr", 2).hasPrefix("Limitin 2 adet üzerindesin"))
    }
}
