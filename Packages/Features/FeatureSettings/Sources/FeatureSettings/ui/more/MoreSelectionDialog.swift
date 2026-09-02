// The radio-list popup the three More pickers share — the twin of Kotlin's private
// `SelectionDialog` + `SelectionOption` (`MoreScreen.kt:480-527`), extracted into its own file
// rather than nested in `MoreScreen.swift` so that file stays under the 500-line gate.
//
// Presented through `salusDialog` — the house popup, a centred scrimmed card over the whole window,
// which is what Kotlin's `AlertDialog` is. This view is the card's content only: `SalusDialogHost`
// paints the surface, so the padding here is Material's dialog inset and nothing else.
//
// The rows are Kotlin's rows, drawn plain on purpose: `RadioButton(selected) + Spacer(lg) +
// Text(bodyLarge)` inside a `selectable` row with `md` vertical padding (`MoreScreen.kt:493-508`).
// Not `SalusOptionRow` — that is the editors' pill row with an icon circle, and the release QA pass
// found the two dialogs visibly different for it. `RadioButton` has no SwiftUI twin, so ``RadioMark``
// draws Material's 20pt ring and 10pt dot from tokens.
//
// One spelling difference from the Kotlin, recorded in `MoreScreen.swift`'s divergence list:
//
//   `confirmButton = { TextButton(   → a plain `Button` in `labelLarge` + `primary`, trailing-aligned
//    settings_cancel) }`                as Material's action slot is. `SalusUI` ships no text button,
//                                       and a pill here would out-weigh the rows it closes.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// One option of a ``MoreSelectionDialog`` (`MoreScreen.kt:524-527`).
struct MoreSelectionOption: Identifiable {
    /// The enum's stored raw value — stable, and already Android-verbatim.
    let id: String
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
}

/// Radio-list popup; selecting an option applies it immediately and closes the dialog
/// (`MoreScreen.kt:480-522`).
struct MoreSelectionDialog: View {
    let title: String
    let options: [MoreSelectionOption]
    let onDismiss: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.lg) {
            // `title = { Text(title) }` (`MoreScreen.kt:489`) — `AlertDialog` sets it in
            // `headlineSmall`.
            Text(verbatim: title)
                .font(SalusTypography.headlineSmall.font)
                .tracking(SalusTypography.headlineSmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)

            // `Column(Modifier.selectableGroup())` (`MoreScreen.kt:491`): zero spacing, each row
            // brings its own vertical padding.
            VStack(spacing: 0) {
                ForEach(options) { option in
                    RadioRow(label: option.label, isSelected: option.isSelected, onSelect: option.onSelect)
                }
            }

            // `confirmButton = { TextButton(onClick = onDismiss) { Text(settings_cancel) } }`
            // (`MoreScreen.kt:517-521`), in Material's trailing action slot.
            Button(action: onDismiss) {
                Text(verbatim: SettingsStrings.settingsCancel)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(theme.colorScheme.primary)
                    .padding(.horizontal, SalusSpacing.md)
                    .frame(minHeight: Self.textButtonHeight)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(SalusSpacing.xl)
    }

    /// Material's `TextButton` minimum height.
    private static let textButtonHeight: CGFloat = 40
}

/// `Row(Modifier.fillMaxWidth().selectable(role = RadioButton).padding(vertical = md)) {
/// RadioButton; Spacer(lg); Text(bodyLarge) }` (`MoreScreen.kt:493-508`).
private struct RadioRow: View {
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: SalusSpacing.lg) {
                RadioMark(isSelected: isSelected)
                Text(verbatim: label)
                    .font(SalusTypography.bodyLarge.font)
                    .tracking(SalusTypography.bodyLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, SalusSpacing.md)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // `role = Role.RadioButton` (`MoreScreen.kt:499`): the row, not a control inside it, is what
        // a screen reader calls "selected".
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Material's `RadioButton` glyph (`RadioButtonTokens`): a 20pt ring, 2pt stroke, and a 10pt dot
/// while selected; `primary` when selected, `onSurfaceVariant` otherwise. Purely visual — the row
/// carries the semantics.
private struct RadioMark: View {
    let isSelected: Bool

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Circle()
            .stroke(
                isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                lineWidth: Self.stroke
            )
            .frame(width: Self.size, height: Self.size)
            .overlay {
                if isSelected {
                    Circle()
                        .fill(theme.colorScheme.primary)
                        .frame(width: Self.dot, height: Self.dot)
                }
            }
            .accessibilityHidden(true)
    }

    private static let size: CGFloat = 20
    private static let stroke: CGFloat = 2
    private static let dot: CGFloat = 10
}

// MARK: - Previews

#Preview("Selection dialog") {
    MoreSelectionDialog(
        title: "Tema",
        options: [
            MoreSelectionOption(id: "SYSTEM", label: "Sistem varsayılanı", isSelected: false, onSelect: {}),
            MoreSelectionOption(id: "LIGHT", label: "Açık", isSelected: true, onSelect: {}),
            MoreSelectionOption(id: "DARK", label: "Koyu", isSelected: false, onSelect: {})
        ],
        onDismiss: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}
