// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/editor/MedicationEditorSections.kt:356-379` (`FormGrid`).
//
// Its own file rather than a member of `MedicationEditorSections.swift`: Kotlin keeps six sections
// in one 422-line file, and six here would run that one past the 500-line limit.
//
// Kotlin chunks the eight forms four to a row by hand, because Compose's `FlowRow` would not give
// every tile the same width (`MedicationEditorSections.kt:364-377`). `LazyVGrid` with four flexible
// columns is the same two rows of four, sized by the grid rather than by the content — which is why
// nothing here chunks.
//
// `selectableGroup()` (`:361`) is the accessibility half of that layout: it tells the platform the
// eight tiles are one choice. `.accessibilityElement(children: .contain)` is SwiftUI's spelling of
// the same thing; `SalusChoiceTile` already carries the `.isSelected` trait per tile.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The eight dosage forms as a four-column grid of tiles
/// (`MedicationEditorSections.kt:356-379`).
///
/// Every form has its own glyph — the grid shows all eight at once, where a single repeated pill
/// would make the tiles unreadable (`MedicationFormIcon.swift`).
struct MedicationFormGrid: View {
    let selected: MedicationForm
    let onSelected: (MedicationForm) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            EditorFieldLabel(text: MedicationsStrings.editorForm)
            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: SalusSpacing.sm) {
                ForEach(MedicationForm.allCases, id: \.self) { form in
                    SalusChoiceTile(
                        label: form.label,
                        systemImage: form.systemImage,
                        isSelected: form == selected
                    ) { onSelected(form) }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    /// `GridCells` four wide with `spacedBy(SalusSpacing.sm)` between them
    /// (`MedicationEditorSections.kt:362`, `:366`, `:418`).
    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: SalusSpacing.sm, alignment: .top),
        count: MedicationEditorDefaults.formGridColumns
    )
}
