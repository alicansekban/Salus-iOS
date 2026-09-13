// The decisions behind `SalusSelectableRow`, pinned without rendering it — the shape
// `SalusDateFieldTests` sets: the view itself is only a `#Preview` build, and everything it decides
// lives in a plain enum beside it.
//
// There are three, and the Kotlin twin makes them inline: an accent tints the icon tile
// (`SalusSelectableRow.kt:51-52`, reaching the `leading` slot's `SalusIconBadge`) and the radio
// mark follows the selection (`:95-104`). The container/border pair this suite used to pin was
// never in the twin — owner QA round 3 (D1) removed it from the component, and these two tests
// with it; `rowsAreTransparent` below is what keeps it gone.

import Foundation
import SalusDesignSystem
import Testing

@testable import SalusUI

@Suite("SalusSelectableRowStyle")
struct SalusSelectableRowTests {
    private let colors = SalusTheme.resolve(systemIsDark: false).colorScheme
    private let accent = SalusTheme.resolve(systemIsDark: false).extendedColors.cycle

    /// `SalusSelectableRow.kt:56-68` is a bare `Row` — no `Surface`, no `background`, no
    /// `BorderStroke` — so a selected row is told apart from its neighbours by the radio mark
    /// alone. A regex over the source is the only mechanical hold on that: the fill this pins
    /// against was a view modifier, not a value a style enum returned, and it came back once
    /// already when the component was renamed from `SalusOptionRow` (owner QA round 3, D1).
    @Test("the row paints no ground and no border in either state")
    func rowsAreTransparent() throws {
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let body = try #require(source.range(of: "public var body: some View {")).upperBound
        let leading = try #require(source.range(of: "/// The option's own leading visual")).lowerBound
        let rowBody = source[body ..< leading]

        #expect(!rowBody.contains(".background("))
        #expect(!rowBody.contains(".overlay {"))
        #expect(!rowBody.contains("stroke("))
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

    /// `RadioButtonDefaults.colors(selectedColor = primary, unselectedColor = onSurfaceVariant)`
    /// (`SalusSelectableRow.kt:100-103`) — the ring the hand-drawn radio mark uses. `outlineVariant`
    /// is the value this pinned until owner QA round 3 (D1); it is a lighter tone than the twin's
    /// and read as a disabled control beside it.
    @Test("the radio ring follows the selection")
    func theRadioRingFollowsTheSelection() {
        #expect(SalusSelectableRowStyle.indicatorRing(selected: true, colors: colors) == colors.primary)
        #expect(SalusSelectableRowStyle.indicatorRing(selected: false, colors: colors) == colors.onSurfaceVariant)
    }

    /// The init's argument list, pinned by calling it: `accent` is the one optional knob
    /// (`SalusSelectableRow.kt:49`), and the selected flag round-trips into the accessibility trait the
    /// row publishes for Kotlin's `Role.RadioButton` (`SalusSelectableRow.kt:63`).
    @Test("the row is built from a title, a selected flag and a handler")
    @MainActor
    func theRowTakesItsArguments() {
        let selected = SalusSelectableRow(
            title: "Kadın",
            systemImage: "person",
            accent: accent,
            isSelected: true
        ) {}
        let unselected = SalusSelectableRow(title: "Erkek", systemImage: "person", isSelected: false) {}

        #expect(selected.isSelected)
        #expect(!unselected.isSelected)
        // The default for the one optional argument.
        #expect(unselected.accent == nil)
    }

    /// The M15 qualification pair (`SalusSelectableRow.kt:84-99`): a `badge` qualifies the option
    /// next to its label ("Varsayılan" on the theme sheet's Classic row) and `locked` swaps the
    /// radio mark for a lock glyph without touching the selection state. Both round-trip through the
    /// stored properties so the theme sheet can decide the row's look from the state it built.
    @Test("a badge and a lock round-trip, and locked is independent of selected")
    @MainActor
    func badgeAndLockRoundTrip() {
        let classic = SalusSelectableRow(
            title: "Klasik",
            swatch: colors.primary,
            badge: "Varsayılan",
            isSelected: true
        ) {}
        let ocean = SalusSelectableRow(
            title: "Okyanus",
            swatch: colors.primary,
            locked: true,
            isSelected: false
        ) {}

        #expect(classic.badge == "Varsayılan")
        #expect(classic.locked == false)
        #expect(ocean.locked)
        #expect(!ocean.isSelected)
    }

    /// The component's own source, reached from this file rather than from a working directory the
    /// test runner does not promise.
    private var sourceURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SalusUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SalusUI
            .appendingPathComponent("Sources/SalusUI/component/SalusSelectableRow.swift")
    }
}
