// The one mapping of `Sex` to a tile glyph, pinned without rendering a tile — the shape
// `SalusStepperFieldTests` and `SalusCardTests` set.
//
// Kotlin writes the same table twice (`ProfileScreen.kt:259-263`,
// `OnboardingPages.kt:379-383`) as `Icons.Outlined.Female / Male / Transgender`. On iOS there is
// one table, because the signs are chosen rather than named, and two copies of a choice drift
// (divergence (aa), owner QA round 2 C3). What is pinned here is what drifting would look like:
// two options sharing a sign — the bug the owner met, where all three tiles drew one person
// symbol — and a sign that has lost the text variation selector that keeps it out of the colour
// emoji font.

import SalusModel
import Testing

@testable import SalusUI

@Suite("SalusSexGlyph")
struct SalusSexGlyphTests {
    /// `Sex.FEMALE -> Female`, `MALE -> Male`, `OTHER -> Transgender` — the three Material icons,
    /// as the three Unicode signs SF Symbols has no twin for.
    @Test(
        "each sex draws its own sign",
        arguments: [
            (Sex.female, "\u{2640}"),
            (Sex.male, "\u{2642}"),
            (Sex.other, "\u{26A7}")
        ]
    )
    func eachSexDrawsItsOwnSign(_ sex: Sex, _ sign: String) {
        #expect(SalusSexGlyph.glyph(for: sex) == .text(sign + "\u{FE0E}"))
    }

    /// The regression the owner found: three tiles, one glyph. A shared sign is the finding
    /// whatever the sign is, so this asks the question of the whole table rather than of a case.
    @Test("no two options share a sign")
    func noTwoOptionsShareASign() {
        let glyphs = Set(Sex.allCases.map { SalusSexGlyph.glyph(for: $0) })

        #expect(glyphs.count == Sex.allCases.count)
    }

    /// U+FE0E is what keeps `♀ ♂ ⚧` plain text: all three have an emoji presentation, and a sign
    /// rendered from the colour emoji font ignores the tile's tint, so the selected state would
    /// stop showing on it.
    @Test("every sign asks for its text presentation")
    func everySignAsksForItsTextPresentation() {
        for sex in Sex.allCases {
            guard case let .text(sign) = SalusSexGlyph.glyph(for: sex) else {
                Issue.record("\(sex) is not drawn as a Unicode sign")
                continue
            }
            #expect(sign.unicodeScalars.count == 2)
            #expect(sign.unicodeScalars.last == "\u{FE0E}")
        }
    }
}
