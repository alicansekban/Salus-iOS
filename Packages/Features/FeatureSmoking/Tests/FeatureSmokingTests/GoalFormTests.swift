// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// GoalFormTest.kt`: what the goal sheet accepts, a name and a target above zero in the plan's
// currency.

import Testing

@testable import FeatureSmoking

@Suite("Goal form", .timeLimit(.minutes(1)))
struct GoalFormTests {
    @Test("a plain amount is read into minor units of the currency")
    func plainAmountIsReadIntoMinorUnits() {
        #expect(goalTargetMinor(amountText: "8000", fractionDigits: 2) == 800_000)
        #expect(goalTargetMinor(amountText: "8500,50", fractionDigits: 2) == 850_050)
        #expect(goalTargetMinor(amountText: "8000", fractionDigits: 0) == 8000)
    }

    @Test("zero, blank and malformed amounts are not a target")
    func zeroBlankAndMalformedAmountsAreNotATarget() {
        #expect(goalTargetMinor(amountText: "0", fractionDigits: 2) == nil)
        #expect(goalTargetMinor(amountText: "0,00", fractionDigits: 2) == nil)
        #expect(goalTargetMinor(amountText: "", fractionDigits: 2) == nil)
        #expect(goalTargetMinor(amountText: "abc", fractionDigits: 2) == nil)
        #expect(goalTargetMinor(amountText: "-5", fractionDigits: 2) == nil)
        #expect(goalTargetMinor(amountText: "1,234", fractionDigits: 2) == nil, "more decimals than the currency has")
    }

    @Test("the form can be saved only with a name and a target")
    func formNeedsANameAndATarget() {
        #expect(isGoalFormValid(title: "Yeni bisiklet", amountText: "8000", fractionDigits: 2))
        #expect(!isGoalFormValid(title: "   ", amountText: "8000", fractionDigits: 2))
        #expect(!isGoalFormValid(title: "Yeni bisiklet", amountText: "0", fractionDigits: 2))
        #expect(!isGoalFormValid(title: "", amountText: "", fractionDigits: 2))
    }

    @Test("a name is held to its limit")
    func nameIsHeldToItsLimit() {
        #expect(limitGoalTitle(String(repeating: "x", count: goalTitleMax + 10)).count == goalTitleMax)
        #expect(limitGoalTitle("Yeni bisiklet") == "Yeni bisiklet")
    }
}
