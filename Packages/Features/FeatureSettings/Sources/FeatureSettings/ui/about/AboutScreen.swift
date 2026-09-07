// Ported 1:1 from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/about/AboutScreen.kt`.
//
// Material → SwiftUI, per the mapping table `docs/ios-feature-template.md` records:
//   `TopAppBar` + `navigationIcon`  → `.navigationTitle(_:)`; the shell's one `NavigationStack`
//                                    draws the back button, so `onBack` is not a back-button
//                                    callback but the shell's `navigator.pop` — and no
//                                    `settings_back` key ships (recorded divergence (d), the same
//                                    one `ProfileScreen.swift` and `ReminderHealthScreen.swift`
//                                    record).
//   `Column` + `verticalScroll`     → `ScrollView` + `VStack(spacing:)`.
//   `Card`                          → `SalusCard` (`SalusUI`).
//   `Modifier.padding(16.dp)`        → `SalusSpacing.lg` (ruling 10, divergence (c) — the Android
//                                    file's hardcoded 16/12/8 dp become the `SalusSpacing` tokens,
//                                    the same conversion every other screen in the port makes; the
//                                    values are identical, `lg = 16`, `md = 12`, `sm = 8`).
//   `Modifier.clickable` on the app  → `.onTapGesture` on the headline `Text` — the reveal gesture
//    name headline (`AboutScreen.kt:86`)  (five consecutive taps within 3 s) goes through the
//                                    existing text, no new component, no accessibility change.
//   `LocalClipboardManager`          → `UIPasteboard.general` under `#if os(iOS)`; the macOS host
//                                    build compiles the copy button without the write.
//   `TextButton`                     → a plain `Button` with the label style.
//
// The app version deliberately lives on the More screen's About row only, so the number has a single
// home (`AboutScreen.kt:52-53`); see `docs/architecture/m9-plan.md` item 1. No version footer here.

import SalusDesignSystem
import SalusModel
import SalusPremium
import SalusUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Owns the ViewModel and wires it to the shell (`AboutScreen.kt:39-50`).
///
/// The Kotlin `AboutRoute` calls `koinInject<Navigator>()` then passes `navigator::pop` as `onBack`;
/// iOS needs neither, because the shell's one `NavigationStack` draws the back button itself once a
/// `.navigationTitle` is set (divergence (d) — the same one `ProfileRoute` and `ReminderHealthRoute`
/// record). The back tap pops the stack without the feature reaching for a `Navigator`.
public struct AboutRoute: View {
    @Environment(\.settingsModule) private var module
    @State private var viewModel: AboutViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                AboutScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeAboutViewModel()
        }
    }
}

/// The stateless About screen (`AboutScreen.kt:54-108`).
struct AboutScreen: View {
    let state: AboutUiState
    let onEvent: (AboutEvent) -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        // No `Scaffold` twin: the shell owns the one navigation stack and its insets, and draws the
        // back button (divergence (d)).
        ScrollView {
            VStack(spacing: SalusSpacing.md) {
                Text(verbatim: SettingsStrings.aboutAppName)
                    .font(SalusTypography.headlineMedium.font)
                    .tracking(SalusTypography.headlineMedium.tracking)
                    .foregroundStyle(colors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The reveal gesture: five consecutive taps on the app name show the support
                    // code (`AboutScreen.kt:84-87`). The taps go through the existing Text — no new
                    // component, no accessibility change.
                    .onTapGesture { onEvent(.appNameTapped) }

                Text(verbatim: SettingsStrings.aboutDescription)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // The support card, below the description and above the privacy card
                // (`AboutScreen.kt:92`).
                SupportCodeCard(state: state, onEvent: onEvent)

                // The privacy card (`AboutScreen.kt:93-105`).
                SalusCard(contentPadding: SalusSpacing.lg) {
                    VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                        Text(verbatim: SettingsStrings.aboutPrivacyTitle)
                            .font(SalusTypography.titleMedium.font)
                            .tracking(SalusTypography.titleMedium.tracking)
                            .foregroundStyle(colors.onSurface)
                        Text(verbatim: SettingsStrings.aboutPrivacyBody)
                            .font(SalusTypography.bodyMedium.font)
                            .tracking(SalusTypography.bodyMedium.tracking)
                            .foregroundStyle(colors.onSurface)
                    }
                }
            }
            .padding(SalusSpacing.lg)
        }
        .background(colors.background)
        .navigationTitle(SettingsStrings.aboutTitle)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// The support card: the RevenueCat `appUserID` a developer pastes into the RevenueCat dashboard
/// to grant a gift subscription. The id is long (`$RCAnonymousID:<uuid>`), so it is ellipsized in
/// the middle; the copy button puts the full value on the clipboard (`AboutScreen.kt:110-174`).
private struct SupportCodeCard: View {
    let state: AboutUiState
    let onEvent: (AboutEvent) -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        SalusCard(contentPadding: SalusSpacing.lg) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: SettingsStrings.aboutSupportTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(colors.onSurface)

                Text(verbatim: premiumStatusLabel)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(colors.onSurface)
                    .padding(.top, SalusSpacing.sm)

                if let appUserID = state.appUserID, state.idRevealed {
                    Text(verbatim: SettingsStrings.aboutSupportCode)
                        .font(SalusTypography.labelMedium.font)
                        .tracking(SalusTypography.labelMedium.tracking)
                        .foregroundStyle(colors.onSurface)
                        .padding(.top, SalusSpacing.sm)

                    Text(verbatim: appUserID)
                        .font(SalusTypography.bodyMedium.font)
                        .tracking(SalusTypography.bodyMedium.tracking)
                        .foregroundStyle(colors.onSurface)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.top, SalusSpacing.sm)

                    HStack {
                        Spacer()
                        Button {
                            copy(appUserID)
                            onEvent(.copySupportCode)
                        } label: {
                            Text(verbatim: state.copied
                                ? SettingsStrings.aboutSupportCopied
                                : SettingsStrings.aboutSupportCopy)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.top, SalusSpacing.sm)
                }
            }
        }
    }

    /// `when (state.premiumStatus)` (`AboutScreen.kt:128-134`): `gracePeriod` reads as active.
    private var premiumStatusLabel: String {
        switch state.premiumStatus {
        case .free: SettingsStrings.aboutPremiumFree
        case .premium: SettingsStrings.aboutPremiumActive
        case .gracePeriod: SettingsStrings.aboutPremiumActive
        }
    }

    /// `clipboardManager.setText(AnnotatedString(appUserID))` (`AboutScreen.kt:158`) — the screen
    /// performs the actual clipboard write; the ViewModel only flips the "Copied" label. iOS-only:
    /// the macOS host build compiles the button without the write.
    private func copy(_ appUserID: String) {
        #if os(iOS)
            UIPasteboard.general.string = appUserID
        #endif
    }
}

#Preview("About") {
    NavigationStack {
        AboutScreen(
            state: AboutUiState(
                appUserID: "$RCAnonymousID:01234567-89ab-cdef-0123-456789abcdef",
                premiumStatus: .premium
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("About, dark") {
    NavigationStack {
        AboutScreen(
            state: AboutUiState(
                appUserID: "$RCAnonymousID:01234567-89ab-cdef-0123-456789abcdef",
                premiumStatus: .premium
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: true))
    .preferredColorScheme(.dark)
}
