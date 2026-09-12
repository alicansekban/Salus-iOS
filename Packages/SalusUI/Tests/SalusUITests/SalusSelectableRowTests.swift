// The decisions behind `SalusSelectableRow`, pinned without rendering it — the shape
// `SalusDateFieldTests` sets: the view itself is only a `#Preview` build, and everything it decides
// lives in a plain enum beside it.
//
// The Kotlin twin makes the same four choices inline
// (`SalusSelectableRow.kt:51-68, 106-110`): the selected row swaps its surface for
// `primaryContainer` and gains a border, an accent tints the icon circle, and the radio ring
// follows the selection.

import SalusDesignSystem
import Testing

@testable import SalusUI

@Suite("SalusSelectableRowStyle")
struct SalusSelectableRowTests {
    private let colors = SalusTheme.resolve(systemIsDark: false).colorScheme
    private let accent = SalusTheme.resolve(systemIsDark: false).extendedColors.cycle

    /// `SalusSelectableRow.kt:59-63` — `if (selected) primaryContainer else surfaceVariant`.
    @Test("the selected row is filled with the primary container, an unselected one with the surface variant")
    func selectionSwapsTheContainer() {
        #expect(SalusSelectableRowStyle.container(selected: true, colors: colors) == colors.primaryContainer)
        #expect(SalusSelectableRowStyle.container(selected: false, colors: colors) == colors.surfaceVariant)
    }

    /// `SalusSelectableRow.kt:64-68` — the border exists only while selected, which is why the return
    /// type is optional rather than a transparent colour: a stroke of `.clear` still costs a layer.
    @Test("only the selected row draws a border")
    func onlyTheSelectedRowHasABorder() {
        #expect(SalusSelectableRowStyle.border(selected: true, colors: colors) == colors.primary)
        #expect(SalusSelectableRowStyle.border(selected: false, colors: colors) == nil)
    }

    /// `SalusSelectableRow.kt:51-52` — `accent?.accent ?: primary` and `accent?.container
    /// ?: primaryContainer`. Both fall back together; tinting one and not the other is the bug this
    /// pins.
    @Test("an accent tints the icon circle, and nil falls back to the primary role")
    func theAccentTintsTheIconCircle() {
        #expect(SalusSelectableRowStyle.iconTint(accent: accent, colors: colors) == accent.accent)
        #expect(SalusSelectableRowStyle.iconBackground(accent: accent, colors: colors) == accent.container)
        #expect(SalusSelectableRowStyle.iconTint(accent: nil, colors: colors) == colors.primary)
        #expect(SalusSelectableRowStyle.iconBackground(accent: nil, colors: colors) == colors.primaryContainer)
    }

    /// `SalusSelectableRow.kt:106-110` — the ring the hand-drawn radio mark uses.
    @Test("the radio ring follows the selection")
    func theRadioRingFollowsTheSelection() {
        #expect(SalusSelectableRowStyle.indicatorRing(selected: true, colors: colors) == colors.primary)
        #expect(SalusSelectableRowStyle.indicatorRing(selected: false, colors: colors) == colors.outlineVariant)
    }

    /// The init's argument list, pinned by calling it: `accent` is the one optional knob
    /// (`SalusSelectableRow.kt:49`), and the selected flag round-trips into the accessibility trait the
    /// row publishes for Kotlin's `Role.RadioButton` (`SalusSelectableRow.kt:57`).
    @Test("the row is built from an icon, a label, a selected flag and a handler")
    @MainActor
    func theRowTakesItsFiveArguments() {
        let selected = SalusSelectableRow(
            systemImage: "person",
            label: "Kadın",
            isSelected: true,
            accent: accent,
            onSelected: {}
        )
        let unselected = SalusSelectableRow(systemImage: "person", label: "Erkek", isSelected: false) {}

        #expect(selected.isSelected)
        #expect(!unselected.isSelected)
        // The default for the one optional argument.
        #expect(unselected.accent == nil)
    }
}
