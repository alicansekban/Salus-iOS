// The main screen's format keys, rendered: the placeholder mapping (`%d` -> `%lld`, `%1$s` ->
// `%1$@`) and the two-key plurals (spec §9 (h)) must still read as the Android sentences.

import SalusTesting
import Testing

@testable import FeatureSmoking

extension SmokingStringsTests {
    static func expectMainScreenSentences(_ catalog: StringCatalog) throws {
        try #expect(render(catalog, "smoking_hero_days", "tr", 42) == "42 gün")
        try #expect(render(catalog, "smoking_hero_days", "en", 42) == "42 days")
        try #expect(render(catalog, "smoking_hero_days_one", "en", 1) == "1 day")
        try #expect(render(catalog, "smoking_slips_one", "en", 1) == "1 slip")
        try #expect(render(catalog, "smoking_hero_hours_minutes", "tr", 6, 12) == "6 saat · 12 dakika")
        try #expect(render(catalog, "smoking_hero_min_sec", "tr", 13, 28) == "13 dk 28 sn")
        try #expect(render(catalog, "smoking_hero_min_sec", "en", 13, 28) == "13 min 28 s")
        try #expect(render(catalog, "smoking_since_last", "tr", "9 gün") == "Son sigaradan beri 9 gün")
        try #expect(render(catalog, "smoking_hero_semantics", "en", "13 min 28 s") == "13 min 28 s smoke-free")
        try #expect(render(catalog, "smoking_metric_today", "tr", 18) == "+18 bugün")
        try #expect(render(catalog, "smoking_regained_days_hours", "en", 6, 10) == "6 d 10 h")
        // `%%` is a literal percent: Turkish puts it first, English last.
        try #expect(render(catalog, "smoking_stage_card_percent", "tr", 64) == "%64")
        try #expect(render(catalog, "smoking_stage_card_percent", "en", 64) == "64%")
        try #expect(render(catalog, "smoking_stage_remaining_minutes", "en", 7) == "7 min left")
    }
}
