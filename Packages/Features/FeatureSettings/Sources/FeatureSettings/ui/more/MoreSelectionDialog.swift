// The radio-list popup the three More pickers share — the twin of Kotlin's private
// `SelectionDialog` + `SelectionOption` (`MoreScreen.kt:480-527`), extracted into its own file
// rather than nested in `MoreScreen.swift` so that file stays under the 500-line gate.
//
// Three spelling differences from the Kotlin, all recorded in `MoreScreen.swift`'s divergence list:
//
//   `AlertDialog(text = { Column(     → a `.sheet` whose body is this view. A SwiftUI `alert` can
//    selectableGroup()) { … } })`       hold only plain buttons — no selection state, no custom
//                                       row — so an alert cannot draw the radio mark Kotlin draws,
//                                       which is the whole point of the dialog.
//   `RadioButton(selected = …)` +     → `SalusOptionRow`, the house radio row (`SalusOptionRow.kt`),
//    `Text(label)`                      which draws the same indicator plus a tinted icon circle.
//                                       Kotlin's rows carry no icon, so every option in one dialog
//                                       repeats the icon of the More row that opened it: the
//                                       indicator is what distinguishes the options, exactly as on
//                                       Android.
//
//   (no twin)                       → an optional `footnote` line under the options, passed by the
//                                       language dialog alone (`language_relaunch_note`): iOS
//                                       applies a language pick on the next launch, Android
//                                       recreates the activity inline, so only this port has
//                                       something to say (divergence 9 / recorded divergence (a)).
//
// `confirmButton = { TextButton(settings_cancel) }` (`MoreScreen.kt:517-521`) is a tonal
// `SalusPillButton` — the house button, since `SalusUI` ships no text button.

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
    /// The SF Symbol every row in this dialog carries — the icon of the More row that opened it.
    let systemImage: String
    let options: [MoreSelectionOption]
    /// An optional line under the options. Only the language dialog passes one
    /// (`SettingsStrings.languageRelaunchNote`), because only the language pick defers its effect
    /// to the next launch — **recorded divergence (a)**, ruling 6. Kotlin's `SelectionDialog` has
    /// no such parameter: appcompat recreates the activity, so there is nothing to warn about.
    /// Defaulted to `nil` so the theme and colour-theme call sites stay the Kotlin shape — which is
    /// also why it is the one `var` here: a `let` with a default is dropped from the memberwise
    /// initializer's parameter list entirely, so the language dialog's call site — the one that
    /// *does* pass a footnote — could not compile. Only a `var` keeps the parameter overridable.
    var footnote: String?
    let onDismiss: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.lg) {
            // `title = { Text(title) }` (`MoreScreen.kt:512`).
            Text(verbatim: title)
                .font(SalusTypography.titleLarge.font)
                .tracking(SalusTypography.titleLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Scrolls rather than clipping: four palettes plus a title and a button do not fit the
            // medium detent on a small screen.
            ScrollView {
                VStack(spacing: SalusSpacing.sm) {
                    ForEach(options) { option in
                        SalusOptionRow(
                            systemImage: systemImage,
                            label: option.label,
                            isSelected: option.isSelected,
                            onSelected: option.onSelect
                        )
                    }
                }
            }

            if let footnote {
                // `Text(verbatim:)`, not `Text(_:)`: the value is already resolved, and `Text(_:)`
                // would re-read it as a `LocalizedStringKey` against the MAIN bundle (the M7
                // `c726e22` finding).
                Text(verbatim: footnote)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SalusPillButton(
                text: SettingsStrings.settingsCancel,
                tonal: true,
                fillsWidth: true,
                action: onDismiss
            )
        }
        .padding(SalusSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.colorScheme.background)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Previews

#Preview("Selection dialog") {
    MoreSelectionDialog(
        title: "Renk teması",
        systemImage: "circle.hexagons.fill",
        options: [
            MoreSelectionOption(id: "CLASSIC", label: "Klasik", isSelected: false, onSelect: {}),
            MoreSelectionOption(id: "OCEAN", label: "Okyanus", isSelected: true, onSelect: {}),
            MoreSelectionOption(id: "SUNSET", label: "Gün batımı", isSelected: false, onSelect: {}),
            MoreSelectionOption(id: "FOREST", label: "Orman", isSelected: false, onSelect: {})
        ],
        onDismiss: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}
