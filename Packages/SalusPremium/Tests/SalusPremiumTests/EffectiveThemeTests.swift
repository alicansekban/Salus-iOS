import SalusModel
import Testing

@testable import SalusPremium

// Ported 1:1 from `EffectiveThemeTest.kt` (4 cases). Case names are the Kotlin
// backtick names in camelCase.

@Suite("EffectiveTheme (Android parity)")
struct EffectiveThemeTests {
    @Test("a premium user keeps the theme they picked")
    func aPremiumUserKeepsTheThemeTheyPicked() {
        for selected in PremiumTheme.allCases {
            #expect(effectivePremiumTheme(.premium, selected) == selected)
        }
    }

    @Test("a grace period user keeps the theme they picked")
    func aGracePeriodUserKeepsTheThemeTheyPicked() {
        for selected in PremiumTheme.allCases {
            #expect(effectivePremiumTheme(.gracePeriod, selected) == selected)
        }
    }

    @Test("a free user is drawn classic whatever the stored selection says")
    func aFreeUserIsDrawnClassicWhateverTheStoredSelectionSays() {
        for selected in PremiumTheme.allCases {
            #expect(effectivePremiumTheme(.free, selected) == .classic)
        }
    }

    @Test("losing the entitlement falls back without touching the stored selection")
    func losingTheEntitlementFallsBackWithoutTouchingTheStoredSelection() {
        let stored = PremiumTheme.forest

        #expect(effectivePremiumTheme(.premium, stored) == .forest)
        #expect(effectivePremiumTheme(.free, stored) == .classic)
        #expect(stored == .forest)
    }
}
