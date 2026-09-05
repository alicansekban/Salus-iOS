import SalusDesignSystem
import Testing

@testable import SalusUI

/// The initials rule of `SalusAvatar.kt:88-95`, pinned without rendering the view — the shape the
/// other component suites set: the view is only a `#Preview` build, and everything it decides
/// lives in a pure helper beside it.
@Suite("SalusAvatar.initials")
struct SalusAvatarTests {
    @Test("two words take the first letter of each, uppercased")
    func twoWordsTakeBothInitials() {
        #expect(SalusAvatar.initials(from: "Alican Sekban") == "AS")
        #expect(SalusAvatar.initials(from: "ayşe yılmaz") == "AY")
    }

    @Test("a single word takes its first letter only")
    func singleWordTakesOneInitial() {
        #expect(SalusAvatar.initials(from: "Ayşe") == "A")
    }

    @Test("extra whitespace between words is ignored")
    func extraWhitespaceIsIgnored() {
        #expect(SalusAvatar.initials(from: "  Alican   Sekban  ") == "AS")
    }

    @Test("a blank name is nil")
    func blankNameIsNil() {
        #expect(SalusAvatar.initials(from: "") == nil)
        #expect(SalusAvatar.initials(from: "   ") == nil)
    }

    @Test("a nil name is nil")
    func nilNameIsNil() {
        #expect(SalusAvatar.initials(from: nil) == nil)
    }
}

/// The clamp of `SalusProgressRing` (divergence (c), M14 plan — Android deferred it).
@Suite("SalusProgressRing.clamped")
struct SalusProgressRingTests {
    @Test("a value in range passes through unchanged")
    func inRangePassesThrough() {
        #expect(SalusProgressRing.clamped(0) == 0)
        #expect(SalusProgressRing.clamped(0.6) == 0.6)
        #expect(SalusProgressRing.clamped(1) == 1)
    }

    @Test("a value below zero clamps to zero")
    func belowZeroClampsToZero() {
        #expect(SalusProgressRing.clamped(-0.5) == 0)
        #expect(SalusProgressRing.clamped(-3) == 0)
    }

    @Test("a value above one clamps to one")
    func aboveOneClampsToOne() {
        #expect(SalusProgressRing.clamped(1.5) == 1)
        #expect(SalusProgressRing.clamped(4) == 1)
    }
}

/// The accent resolution of `SalusDateTile.kt:34-35`, pinned without rendering the view.
@Suite("SalusDateTile.accent")
struct SalusDateTileTests {
    private let theme = SalusTheme.resolve(systemIsDark: false)

    @Test("an accent supplies its own container and accent")
    func accentSuppliesItsOwnColors() {
        let accent = theme.extendedColors.appointments
        #expect(SalusDateTileStyle.container(accent: accent, theme: theme) == accent.container)
        #expect(SalusDateTileStyle.tint(accent: accent, theme: theme) == accent.accent)
    }

    @Test("nil accent falls back to the primary role")
    func nilAccentFallsBackToPrimary() {
        #expect(SalusDateTileStyle.container(accent: nil, theme: theme) == theme.colorScheme.primaryContainer)
        #expect(SalusDateTileStyle.tint(accent: nil, theme: theme) == theme.colorScheme.primary)
    }
}
