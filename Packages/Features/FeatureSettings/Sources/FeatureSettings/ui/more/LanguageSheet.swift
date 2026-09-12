// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/LanguageSheet.kt`.
//
// The language sheet: Sistem dili / Türkçe / English, one `SalusSelectableRow` each. It is a sheet
// rather than a dialog for one reason — the appearance picker next to it is a sheet, and two
// settings that are the same kind of choice should not arrive in two kinds of popup. Like that one
// it applies the pick straight through and stays open: the whole app repaints in the chosen
// language underneath, which is the preview a staged sheet would have to fake.
//
// Material → SwiftUI: `SalusBottomSheet` → the `salusBottomSheet(isPresented:)` modifier with
// `detents: [.medium]`; `onDismissRequest` is the binding's `false` edge, which sends
// `languageSheetDismissed`. The leading `SalusIconBadge(Small, globe)` maps to
// `SalusIconBadge(systemImage: "globe", size: .small)`.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The language sheet (`LanguageSheet.kt:50-66`). A self-presenting view, the same shape
/// `ThemeSheet` uses: `MoreScreen` embeds it in a `.background`, and it attaches its own
/// `salusBottomSheet` (`.medium` detent) driven by the state flag.
struct LanguageSheet: View {
    let state: MoreUiState
    let onEvent: (MoreEvent) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .salusBottomSheet(
                isPresented: Binding(
                    get: { state.isLanguageSheetOpen },
                    set: { presented in
                        if !presented {
                            onEvent(.languageSheetDismissed)
                        }
                    }
                ),
                title: SettingsStrings.languageTitle,
                subtitle: SettingsStrings.languageSheetSubtitle,
                detents: [.medium]
            ) {
                LanguageSheetContent(state: state, onEvent: onEvent)
            }
    }
}

/// The sheet's body, separate from the sheet only so it can be previewed (`LanguageSheet.kt:70-72`).
private struct LanguageSheetContent: View {
    let state: MoreUiState
    let onEvent: (MoreEvent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // `Column(modifier = Modifier.selectableGroup())` (`LanguageSheet.kt:64`) — the iOS
            // twin is `children: .contain`, so VoiceOver reads the three rows as one radio set
            // while each stays individually reachable.
            VStack(spacing: 0) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    SalusSelectableRow(
                        title: language.label,
                        systemImage: "globe",
                        isSelected: state.language == language,
                        action: { onEvent(.selectLanguage(language)) }
                    )
                }
            }
            .accessibilityElement(children: .contain)
            // The sheet's own content stops at the last row; the gesture bar needs the room
            // (`LanguageSheet.kt:81-82`).
            Spacer().frame(height: SalusSpacing.xl)
        }
    }
}

/// `AppLanguage.labelRes()` (`MoreScreen.kt:430-438` in the Kotlin MoreScreen) — the row label.
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

#Preview("Language sheet content") {
    SalusPreviewPalettes {
        LanguageSheetContent(
            state: MoreUiState(isLoading: false, language: .turkish),
            onEvent: { _ in }
        )
    }
}
