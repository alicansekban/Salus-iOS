// Where the sliding pill parks, pinned without rendering the control.
//
// `val selectedIndex = options.indexOf(selected)` plus `showIndicator = selectedIndex >= 0`
// (`SalusSegmentedTabs.kt:81`, `:106`) is the whole rule, and the case it exists for is the one a
// screenshot would never catch: a caller can hand the control a `selected` that is not in
// `options` — a filter cleared, a list swapped a frame before the selection follows — and then
// **nothing** is drawn, rather than a pill parked on the first segment claiming a selection that
// is not there (`SalusSegmentedTabs.kt:103-105`).

import Testing

@testable import SalusUI

@Suite("SalusSegmentedTabs")
struct SalusSegmentedTabsTests {
    static let options = ["Week", "Month", "Year"]

    @Test(
        "the pill sits on the selected option's position",
        arguments: [("Week", 0), ("Month", 1), ("Year", 2)]
    )
    func indicatorFollowsTheSelection(_ selected: String, _ expected: Int) {
        let index = SalusSegmentedTabs<String>.indicatorIndex(options: Self.options, selected: selected)

        #expect(index == expected)
    }

    /// `SalusSegmentedTabs.kt:103-106` — a selection the options do not carry draws no pill.
    @Test("a selection outside the options draws no pill")
    func selectionOutsideTheOptionsDrawsNoPill() {
        let index = SalusSegmentedTabs<String>.indicatorIndex(options: Self.options, selected: "Decade")

        #expect(index == nil)
    }

    /// `if (options.isEmpty())` (`SalusSegmentedTabs.kt:98`) — an empty control has nowhere to
    /// park, and answering `0` would place the pill on a segment that does not exist.
    @Test("an empty option list draws no pill")
    func emptyOptionsDrawNoPill() {
        let index = SalusSegmentedTabs<String>.indicatorIndex(options: [], selected: "Week")

        #expect(index == nil)
    }

    /// Duplicated options are a caller bug, but the pill still has to land somewhere definite:
    /// the first match, exactly as `indexOf` answers.
    @Test("a duplicated option resolves to its first position")
    func duplicatedOptionResolvesToItsFirstPosition() {
        let index = SalusSegmentedTabs<String>.indicatorIndex(
            options: ["Week", "Month", "Week"],
            selected: "Week"
        )

        #expect(index == 0)
    }
}
