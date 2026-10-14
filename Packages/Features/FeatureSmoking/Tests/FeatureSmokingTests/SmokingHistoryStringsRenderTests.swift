// The history and settings screens' format keys, rendered: the placeholder mapping (`%d` -> `%lld`,
// `%1$s` -> `%1$@`) and the two-key plurals (spec §9 (h)) must still read as the Android sentences.

import SalusTesting
import Testing

@testable import FeatureSmoking

extension SmokingStringsTests {
    static func expectHistoryAndSettingsSentences(_ catalog: StringCatalog) throws {
        try #expect(render(catalog, "smoking_history_journey_days", "tr", 69) == "69 günlük süreç")
        try #expect(render(catalog, "smoking_history_journey_days_one", "en", 1) == "1-day journey")
        try #expect(render(catalog, "smoking_history_attempt_title", "tr", 2) == "2. deneme")
        try #expect(render(catalog, "smoking_history_attempt_title", "en", 2) == "Attempt 2")
        try #expect(render(catalog, "smoking_history_attempt_days", "en", 42) == "42 days")
        try #expect(render(catalog, "smoking_history_attempt_days_one", "en", 1) == "1 day")
        try #expect(render(catalog, "smoking_history_attempt_slips_one", "en", 1) == "1 slip")
        try #expect(render(catalog, "smoking_history_attempt_cravings", "tr", 12) == "12 kriz atlatıldı")
        try #expect(render(catalog, "smoking_history_attempt_range", "en", "10 Mar 2026", "1 Apr 2026") ==
            "10 Mar 2026 – 1 Apr 2026")
        try #expect(render(catalog, "smoking_history_attempt_range_open", "tr", "10 Mar 2026") == "10 Mar 2026 – şimdi")
        try #expect(render(catalog, "smoking_history_attempt_saved", "tr", "₺3.150") == "Biriken: ₺3.150")
        try #expect(render(catalog, "smoking_history_row_smoked", "tr", 2) == "2 adet içildi")
        try #expect(render(catalog, "smoking_history_row_intensity", "en", 4) == "Intensity 4/5")
        try #expect(render(catalog, "smoking_settings_price_value", "tr", "₺4,75") == "₺4,75 / adet")
        try #expect(render(catalog, "smoking_settings_price_value_vape", "en", "$1.43") == "$1.43 / day")
        try #expect(render(catalog, "smoking_settings_limit_value", "tr", 10) == "10 adet")
        try #expect(render(catalog, "smoking_settings_reason_value", "tr", "Kızım için") == "“Kızım için”")
    }
}
