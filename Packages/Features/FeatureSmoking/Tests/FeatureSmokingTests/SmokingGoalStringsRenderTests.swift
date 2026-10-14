// The premium cards' format keys, rendered: the placeholder mapping (`%d` -> `%lld`,
// `%1$s` -> `%1$@`) and the two-key plural (spec §9 (h)) must still read as the Android sentences.

import SalusTesting
import Testing

@testable import FeatureSmoking

extension SmokingStringsTests {
    static func expectGoalSentences(_ catalog: StringCatalog) throws {
        try #expect(render(catalog, "smoking_goal_amounts", "tr", "₺3.150", "₺8.000") == "₺3.150 / ₺8.000")
        try #expect(render(catalog, "smoking_goal_eta", "tr", 49) == "yaklaşık 49 gün")
        try #expect(render(catalog, "smoking_goal_eta", "en", 49) == "about 49 days")
        try #expect(render(catalog, "smoking_goal_eta_one", "en", 1) == "about 1 day")
        try #expect(render(catalog, "smoking_goal_eta_one", "tr", 1) == "yaklaşık 1 gün")
        try #expect(
            render(catalog, "smoking_goal_reached_body", "tr", "Yeni bisiklet", "₺8.000") == "Yeni bisiklet · ₺8.000"
        )
    }
}
