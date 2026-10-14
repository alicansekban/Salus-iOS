import SalusDesignSystem
import Testing

@testable import SalusUI

/// The accent resolution `SalusChoiceChip.kt` gained in Android's M17 Task 10 (`accent`, R1),
/// pinned without rendering the view — the shape `SalusDateTileTests` sets.
@Suite("SalusChoiceChip.accent")
struct SalusChoiceChipTests {
    private let theme = SalusTheme.resolve(systemIsDark: false)

    @Test("a selected chip with an accent takes the accent's container and its content colour")
    func selectedAccentTakesItsOwnColors() {
        let accent = theme.extendedColors.smoking
        #expect(SalusChoiceChipStyle.container(isSelected: true, accent: accent, theme: theme) == accent.container)
        #expect(SalusChoiceChipStyle.content(isSelected: true, accent: accent, theme: theme) == accent.onContainer)
    }

    @Test("a selected chip without an accent keeps the primary container")
    func selectedWithoutAccentIsPrimary() {
        #expect(
            SalusChoiceChipStyle.container(isSelected: true, accent: nil, theme: theme)
                == theme.colorScheme.primaryContainer
        )
        #expect(
            SalusChoiceChipStyle.content(isSelected: true, accent: nil, theme: theme)
                == theme.colorScheme.onPrimaryContainer
        )
    }

    @Test("an unselected chip ignores the accent")
    func unselectedIgnoresTheAccent() {
        let accent = theme.extendedColors.smoking
        #expect(
            SalusChoiceChipStyle.content(isSelected: false, accent: accent, theme: theme)
                == theme.colorScheme.onSurfaceVariant
        )
    }
}
