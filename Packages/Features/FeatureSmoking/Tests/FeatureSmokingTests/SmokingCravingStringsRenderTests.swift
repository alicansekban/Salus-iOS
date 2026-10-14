// The craving flow's format keys, rendered: the placeholder mapping (`%d` -> `%lld`, `%1$s` ->
// `%1$@`) and the two-key plural (spec §9 (h)) must still read as the Android sentences.

import SalusTesting
import Testing

@testable import FeatureSmoking

extension SmokingStringsTests {
    @Test("the craving flow's format keys render the Android sentences")
    func cravingSentences() throws {
        let catalog = try Self.loadCatalog()

        try #expect(Self.render(catalog, "smoking_craving_line_days", "tr", 42) == "42 gündür sigarasızsın")
        try #expect(Self.render(catalog, "smoking_craving_line_days", "en", 42) == "42 days smoke-free")
        try #expect(Self.render(catalog, "smoking_craving_line_days_one", "en", 1) == "1 day smoke-free")
        try #expect(Self
            .render(catalog, "smoking_craving_line_saved", "tr", "₺3.150") == "Şimdiye kadar ₺3.150 biriktirdin")
        try #expect(Self.render(catalog, "smoking_craving_line_stage", "en", "1 month") == "Next stage: 1 month")
        try #expect(Self.render(catalog, "smoking_craving_reason", "tr", "Kızım için") == "“Kızım için”")
        try #expect(Self.render(catalog, "smoking_craving_done_count", "tr", 18) == "18. krizi atlattın")
        try #expect(Self.render(catalog, "smoking_craving_done_count", "en", 18) == "Craving #18 beaten")
        // The spoken timer wraps the same "13 dk 28 sn" the main screen's hero reads.
        try #expect(
            Self.render(catalog, "smoking_craving_timer_semantics", "tr", "4 dk 12 sn", "Nefes al")
                == "Kalan süre 4 dk 12 sn. Nefes al"
        )
        try #expect(
            Self.render(catalog, "smoking_craving_timer_semantics", "en", "4 min 12 s", "Hold")
                == "4 min 12 s left. Hold"
        )
    }
}
