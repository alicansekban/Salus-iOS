// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/ThemeSheet.kt`.
//
// The appearance sheet, opened by both the "theme mode" and the "colour theme" row: mode and
// palette are one decision about how the app looks, and splitting them over two pickers made the
// second one impossible to find. There is no "apply" pair: every selection is written straight
// through and the theme under the sheet repaints, which is the preview (plan ruling 1).
//
// Material → SwiftUI:
//   `SalusBottomSheet(title:subtitle:onDismiss:)` → the `salusBottomSheet(isPresented:)` modifier
//     with `detents: [.medium, .large]` — this sheet's content is taller than a medium sheet, so
//     it opens at medium and drags up; `onDismissRequest` (the scrim / swipe) is the binding's
//     `false` edge, which sends `themeSheetDismissed`.
//   `SalusChoiceTile` × theme mode → the same `SalusChoiceTile` (spec §3.3); the three modes
//     share one `HStack` with `.equalSpacing`.
//   `SalusSelectableRow(badge:locked:leading:swatch)` → the same row with its M15 `badge`/`locked`
//     knobs. `locked` is the M15 row's lock glyph; CLASSIC never draws one and never routes to the
//     paywall (A60).
//   `theme.swatch(dark)` (`ThemeSheet.kt:174`) → `theme.swatch(dark: theme.isDark)` — the swatch
//     is the same `PremiumTheme.swatch(dark:)` extension `SalusDesignSystem` ships.
//
// The sheet's preview renders the content inside a `VStack`, exactly as Kotlin previews
// `ThemeSheetContent` separately (a `ModalBottomSheet` draws in its own window).

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The appearance sheet, opened by both the "theme mode" and the "colour theme" row
/// (`ThemeSheet.kt:50-66`). A self-presenting view: `MoreScreen` embeds it in a `.background`, and
/// it attaches its own `salusBottomSheet` (`presentationDetents(.medium)`) driven by the state
/// flag. Placing two such views in a background keeps both sheet types in play without either
/// presenting over the other.
struct ThemeSheet: View {
    let state: MoreUiState
    let onEvent: (MoreEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // An invisible anchor: the presentation is attached here and shown whenever the state flag
        // flips, exactly as Kotlin's `if (state.isThemeSheetOpen) { ThemeSheet(…) }` draws it
        // (`MoreScreen.kt:181-183`).
        Color.clear
            .frame(width: 0, height: 0)
            .salusBottomSheet(
                isPresented: Binding(
                    get: { state.isThemeSheetOpen },
                    set: { presented in
                        // The scrim tap, the swipe, and the close button all take the binding's
                        // `false` edge — the twin of Kotlin's `onDismissRequest`
                        // (`ThemeSheet.kt:51-53`). Nothing is written on the way out.
                        if !presented {
                            onEvent(.themeSheetDismissed)
                        }
                    }
                ),
                title: SettingsStrings.themeSheetTitle,
                subtitle: SettingsStrings.themeSheetSubtitle,
                // Two detents, not the house `.medium` alone: mode tiles + section header + four
                // palette rows run past a medium sheet on every iPhone, and further still at a
                // large Dynamic Type. It opens at `.medium` and drags up to `.large`; the body's
                // own `ScrollView` (`SalusBottomSheet.swift`) reaches the rest at either height.
                detents: [.medium, .large]
            ) {
                ThemeSheetContent(state: state, onEvent: onEvent)
            }
    }
}

/// The sheet's body, separate from the sheet only so it can be previewed (`ThemeSheet.kt:68-70`).
private struct ThemeSheetContent: View {
    let state: MoreUiState
    let onEvent: (MoreEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SalusSectionHeader(title: SettingsStrings.themeSectionMode)
            // `Row(fillMaxWidth, padding(horizontal = lg), Modifier.selectableGroup())`
            // (`ThemeSheet.kt:83-89`) — three equal tiles for system / light / dark.
            HStack(spacing: SalusSpacing.md) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    SalusChoiceTile(
                        label: mode.label,
                        systemImage: mode.systemImage,
                        isSelected: state.themeMode == mode,
                        action: { onEvent(.selectTheme(mode)) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .frame(maxWidth: .infinity)
            // `Modifier.selectableGroup()` (`ThemeSheet.kt:87`) — the iOS twin, so VoiceOver reads
            // the three tiles as one radio set rather than as three unrelated buttons.
            // `children: .contain` keeps each tile individually reachable, where `.combine` would
            // flatten the row into one string (the shape `OnboardingPersonalPage.swift:119` set).
            .accessibilityElement(children: .contain)

            SalusSectionHeader(
                title: SettingsStrings.themeSectionPalette,
                contentPadding: EdgeInsets(
                    top: SalusSpacing.xl,
                    leading: SalusSpacing.lg,
                    bottom: SalusSpacing.sm,
                    trailing: SalusSpacing.lg
                )
            )
            // The stored pick is what the list shows as selected, not the palette actually being
            // drawn: a lapsed subscriber sees their own choice waiting for them here
            // (`ThemeSheet.kt:104-106`).
            let entitled = state.premiumStatus.isEntitled
            ForEach(PremiumTheme.allCases, id: \.self) { premiumTheme in
                SalusSelectableRow(
                    title: premiumTheme.label,
                    swatch: premiumTheme.swatch(dark: theme.isDark),
                    // A locked row is still tappable: the ViewModel turns an unentitled tap into
                    // the paywall, which is the whole point of showing the palettes to free users.
                    badge: premiumTheme == .classic ? SettingsStrings.themeDefaultBadge : nil,
                    locked: premiumTheme != .classic && !entitled,
                    isSelected: state.premiumTheme == premiumTheme,
                    action: { onEvent(.colorThemeSelected(premiumTheme)) }
                )
            }
            // The sheet's own content stops at the last row; the gesture bar needs the room
            // (`ThemeSheet.kt:120-121`).
            Spacer().frame(height: SalusSpacing.xl)
        }
    }
}

/// `ThemeMode.labelRes()` (`ThemeSheet.kt:186-190`) — the tile label for each mode.
extension ThemeMode {
    fileprivate var label: String {
        switch self {
        case .system: SettingsStrings.themeSystem
        case .light: SettingsStrings.themeLight
        case .dark: SettingsStrings.themeDark
        }
    }
}

/// `ThemeMode.icon()` (`ThemeSheet.kt:177-184`) — the SF Symbol twin of the three Material icons.
extension ThemeMode {
    fileprivate var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

/// `PremiumTheme.labelRes()` (`ThemeSheet.kt:192-197`) — the palette row label for each theme.
extension PremiumTheme {
    fileprivate var label: String {
        switch self {
        case .classic: SettingsStrings.colorThemeClassic
        case .ocean: SettingsStrings.colorThemeOcean
        case .sunset: SettingsStrings.colorThemeSunset
        case .forest: SettingsStrings.colorThemeForest
        }
    }
}

// MARK: - Previews

#Preview("Theme sheet content") {
    // Kotlin previews `ThemeSheetContent` (not the sheet) so the preview pane can draw it
    // (`ThemeSheet.kt:165-203`); the same trick here.
    SalusPreviewPalettes {
        ThemeSheetContent(
            state: MoreUiState(
                isLoading: false,
                themeMode: .dark,
                premiumTheme: .classic
            ),
            onEvent: { _ in }
        )
    }
}
