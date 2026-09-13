// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/ThemeSheet.kt`.
//
// The appearance AND language sheet, opened by all three "Görünüm & Tema" rows: theme mode, colour
// palette and app language are one decision about how the app looks and speaks, and splitting them
// over two pickers made the second one impossible to find. There is no "apply" pair: every
// selection is written straight through and the app under the sheet repaints, which is the preview
// (plan ruling 1; the language section joins by the same reasoning — see
// `docs/superpowers/specs/2026-09-13-language-joins-appearance-sheet-design.md`, which supersedes
// the old "two settings, two sheets" rationale `LanguageSheet.swift` carried).
//
// Material → SwiftUI:
//   `SalusBottomSheet(title:subtitle:onDismiss:)` → the `salusBottomSheet(isPresented:)` modifier
//     with `sizing: .fitted` — the twin of the `skipPartiallyExpanded` sheet state Kotlin builds,
//     so the sheet opens at the height its mode tiles, palette rows and language tiles ask for
//     rather than at a half sheet that hides the last section; `onDismissRequest` (the scrim /
//     swipe) is the binding's `false` edge, which sends `themeSheetDismissed`.
//   `SalusChoiceTile` × theme mode → the same `SalusChoiceTile` (spec §3.3); the three modes
//     share one `HStack` with `.equalSpacing`.
//   `SalusChoiceTile` × app language → the same row shape as the mode trio above it
//     (`ThemeSheet.kt`'s language section, the 2026-09-13 merge): `globe` on all three, because
//     the choice is expressed by the tile's own selected state, not by per-language iconography.
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

/// The appearance and language sheet, opened by all three appearance rows — the "theme mode", the
/// "colour theme" and the "app language" row (`ThemeSheet.kt:50-66`). A self-presenting view:
/// `MoreScreen` embeds it in a `.background`, and it attaches its own `salusBottomSheet`
/// (`.fitted`, the twin of Kotlin's `skipPartiallyExpanded` sheet) driven by the state flag.
/// Placing the sheet view in a background keeps it in play without presenting over anything else.
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
                // The sheet opens at the height its own content asks for, the twin of the
                // `skipPartiallyExpanded` state `ThemeSheet.kt` gives its `ModalBottomSheet`.
                // A `.medium` first detent rested half-way up and cut the language section off
                // below the fold, and a plain `.large` would stand taller than the three sections
                // need; `.fitted` measures them. Content taller than the screen — the largest
                // Dynamic Type — is clamped to the sheet's own maximum and reached through the
                // body's `ScrollView` (`SalusBottomSheet.swift`). The merged sections measure far
                // past the ~400 pt below which iOS 26's Liquid Glass presentation squeezes a sheet
                // horizontally, which is what made the old single-section language sheet narrow —
                // see the design doc above.
                sizing: .fitted
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
            // The language section sits at the bottom, in the ordinary order — the same owner
            // ruling the Android twin's merge records (no entry-point-specific scroll; the sheet's
            // own `ScrollView` reaches it at every detent).
            SalusSectionHeader(
                title: SettingsStrings.themeSectionLanguage,
                contentPadding: EdgeInsets(
                    top: SalusSpacing.xl,
                    leading: SalusSpacing.lg,
                    bottom: SalusSpacing.sm,
                    trailing: SalusSpacing.lg
                )
            )
            // The same row shape the mode trio above it uses: `Row(fillMaxWidth,
            // padding(horizontal = lg), Modifier.selectableGroup())` with `spacedBy(md)` and
            // `Modifier.weight(1f)` tiles.
            HStack(spacing: SalusSpacing.md) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    SalusChoiceTile(
                        label: language.label,
                        // Each named language leads with its own flag (`ThemeSheet.kt`'s
                        // `AppLanguage.flag()`); "system language" is a device setting rather than
                        // a country, so it keeps the globe the hub row leads with.
                        glyph: language.glyph,
                        isSelected: state.language == language,
                        action: { onEvent(.selectLanguage(language)) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .frame(maxWidth: .infinity)
            // The same `Modifier.selectableGroup()` twin the mode row above uses, for the same
            // reason: VoiceOver reads the three tiles as one radio set rather than as three
            // unrelated buttons, while `children: .contain` keeps each tile individually
            // reachable.
            .accessibilityElement(children: .contain)
            // The sheet's own content stops at the last row; the gesture bar needs the room
            // (`ThemeSheet.kt:120-121`).
            Spacer().frame(height: SalusSpacing.xl)
        }
    }
}

/// `AppLanguage.flag()` (`ThemeSheet.kt`) — the flag over each named language's tile, and the
/// globe for the system language, which is a device setting rather than a country. The flags are
/// colour emoji: they keep their own colours where a symbol would take the tile's tint.
extension AppLanguage {
    fileprivate var glyph: SalusChoiceTileGlyph {
        switch self {
        case .system: .symbol("globe")
        case .turkish: .text("\u{1F1F9}\u{1F1F7}")
        case .english: .text("\u{1F1FA}\u{1F1F8}")
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

/// `AppLanguage.labelRes()` (`MoreScreen.kt:214-218`) — the tile label for each language, moved here
/// from the deleted `LanguageSheet.swift` when its rows became this sheet's third section.
extension AppLanguage {
    fileprivate var label: String {
        switch self {
        case .system: SettingsStrings.languageSystem
        case .turkish: SettingsStrings.languageTurkish
        case .english: SettingsStrings.languageEnglish
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
                premiumTheme: .classic,
                language: .turkish
            ),
            onEvent: { _ in }
        )
    }
}
