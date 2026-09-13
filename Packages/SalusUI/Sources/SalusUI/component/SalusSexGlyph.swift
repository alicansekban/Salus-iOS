// The iOS answer to `Sex.icon()`, which Android writes twice — once in
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/profile/
// ProfileScreen.kt:259-263` and once in
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingPages.kt:379-383` — as `Icons.Outlined.Female / Male / Transgender`.
//
// **Divergence (aa), spec §9 (owner QA round 2, C3): the three are Unicode signs, not SF Symbols.**
// SF Symbols ships no venus, mars or transgender glyph, and the port's first answer was to give all
// three tiles one neutral `person.crop.circle` — which is how Profile came to draw the same icon
// three times, with only the label telling the options apart. `♀ ♂ ⚧` say what Material's three
// icons say, in the tile's own tint, and they cost no asset.
//
// **One mapping, in `SalusUI`, and not twice.** Kotlin can afford its two private copies because a
// Material icon is the same object in both files; a hand-chosen glyph is a decision, and two copies
// of a decision drift — the profile editor and the onboarding page must never disagree about which
// sign means which option. It lives here rather than as an extension on `Sex` in `SalusModel`
// because the domain layer may not import a UI framework (CLAUDE.md, *Layer rules*), while `SalusUI`
// already depends on `SalusModel` (`Packages/SalusUI/Package.swift:25`, `:35`).

import SalusDesignSystem
import SalusModel
import SwiftUI

/// Which sign a ``SalusChoiceTile`` draws for a ``SalusModel/Sex`` — the twin of Kotlin's two
/// `Sex.icon()` extensions, kept in one place so the two screens cannot drift apart.
public enum SalusSexGlyph {
    /// `Sex.FEMALE -> Icons.Outlined.Female`, `MALE -> Male`, `OTHER -> Transgender`
    /// (`ProfileScreen.kt:259-263`, `OnboardingPages.kt:379-383`).
    ///
    /// Each sign carries U+FE0E, the text variation selector: `♀`, `♂` and `⚧` all have an emoji
    /// presentation, and without the selector the system is free to render one of them from the
    /// colour emoji font — which would ignore the tile's `primary` / `onSurfaceVariant` tint and
    /// leave the selected state invisible. The selector asks for the plain glyph, which takes the
    /// tint like any other text.
    public static func glyph(for sex: Sex) -> SalusChoiceTileGlyph {
        switch sex {
        case .female: .text("\u{2640}\u{FE0E}")
        case .male: .text("\u{2642}\u{FE0E}")
        case .other: .text("\u{26A7}\u{FE0E}")
        }
    }
}

#Preview("Sex tiles — the three Unicode glyphs") {
    // The grid C3 is about: ♀ ♂ ⚧ at the same size and tint an SF Symbol would take, one tile
    // selected so both tints are on screen in every palette. It lives beside the mapping rather
    // than with the other `SalusChoiceTile` previews because the mapping is what it shows, and
    // because naming a `Sex` needs the import this file has and `SalusChoiceTile.swift`
    // deliberately does not — a component that draws a glyph knows nothing about the domain.
    SalusPreviewPalettes {
        HStack(spacing: SalusSpacing.md) {
            SalusChoiceTile(label: "Kadın", glyph: SalusSexGlyph.glyph(for: .female), isSelected: true) {}
            SalusChoiceTile(label: "Erkek", glyph: SalusSexGlyph.glyph(for: .male), isSelected: false) {}
            SalusChoiceTile(label: "Diğer", glyph: SalusSexGlyph.glyph(for: .other), isSelected: false) {}
        }
    }
}
