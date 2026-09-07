// Ported 1:1 from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/support/SupportScreen.kt`.
//
// Material → SwiftUI, per the mapping table `docs/ios-feature-template.md` records:
//   `TopAppBar` + `navigationIcon`  → `.navigationTitle(_:)`; the shell's one `NavigationStack`
//                                    draws the back button (divergence (d), like `ProfileScreen.swift`).
//   `Column` + `verticalScroll`     → `ScrollView` + `VStack(spacing:)`.
//   `TopAppBar` title Text with     → the reveal gesture lands on the `.navigationTitle`'s `Text`
//    `Modifier.clickable { TitleTapped }`  (`.onTapGesture`), the exact mechanic the support-code
//                                    About twin put on its headline (`AboutScreen.swift`).
//   `Card`                          → `SalusCard`.
//   `Modifier.padding(16/8/4.dp)`   → the `SalusSpacing` tokens (`lg`/`sm`); the copy button's
//                                    `4.dp` top inset becomes `SalusSpacing.sm` (ruling 10,
//                                    divergence (c)).
//   `LocalClipboardManager`         → `UIPasteboard.general` under `#if os(iOS)`; the macOS host
//                                    build compiles the copy button without the write.
//   `TextButton`                    → a plain `Button` with `.buttonStyle(.borderless)`, so it stays
//                                    inside the card rather than becoming a full-width row.
//   `TextOverflow.MiddleEllipsis`   → `.lineLimit(1)` + `.truncationMode(.middle)`.
//
// This is the moved-and-renamed About support card: the premium-status card is always shown, the id
// and copy button hide behind the 5-tap reveal on the screen title.

import SalusDesignSystem
import SalusPremium
import SalusUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Owns the ViewModel and wires it to the shell (`SupportScreen.kt:39-50`).
///
/// The Kotlin `SupportRoute` calls `koinInject<Navigator>()` then passes `navigator::pop` as
/// `onBack`; iOS needs neither, because the shell's one `NavigationStack` draws the back button
/// itself once a `.navigationTitle` is set (divergence (d) — the same one `ProfileRoute` and
/// `ReminderHealthRoute` record). The back tap pops the stack without the feature reaching for a
/// `Navigator`.
public struct SupportRoute: View {
    @Environment(\.settingsModule) private var module
    @State private var viewModel: SupportViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                SupportScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeSupportViewModel()
        }
    }
}

/// The stateless Support screen (`SupportScreen.kt:52-92`), drawn as a pushed destination.
struct SupportScreen: View {
    let state: SupportUiState
    let onEvent: (SupportEvent) -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        // No `Scaffold` twin: the shell owns the one navigation stack and its insets.
        ScrollView {
            VStack(spacing: SalusSpacing.md) {
                Text(verbatim: SettingsStrings.supportDesc)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SupportCodeCard(state: state, onEvent: onEvent)
            }
            .padding(SalusSpacing.lg)
        }
        .background(colors.background)
        // The reveal gesture lives on the navigation title, the iOS twin of the Android TopAppBar
        // title `Text` with `Modifier.clickable { onEvent(SupportEvent.TitleTapped) }`
        // (`SupportScreen.kt:62-68`): five consecutive taps on the title show the support code.
        // `navigationTitle` takes a `LocalizedStringKey`, so the tappable `Text` is drawn in the
        // toolbar alongside it and carries the same verbatim string.
        .toolbar {
            ToolbarItem(placement: .principal) {
                // The taps go through a Text with hidden accessibility: the title itself already
                // tells VoiceOver users where they are, and the gesture is a developer-only
                // backdoor — repeating it twice would be a needless announcement.
                Text(verbatim: SettingsStrings.supportTitle)
                    .accessibilityHidden(true)
                    .onTapGesture { onEvent(.titleTapped) }
            }
        }
        .navigationTitle(SettingsStrings.supportTitle)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// The support card: the RevenueCat `appUserID` a developer pastes into the RevenueCat dashboard
/// to grant a gift subscription. The id is long (`$RCAnonymousID:<uuid>`), so it is ellipsized in
/// the middle; the copy button puts the full value on the clipboard. The premium-status line is
/// always visible; the id and copy button only appear once the 5-tap reveal has completed
/// (`SupportScreen.kt:94-159`).
private struct SupportCodeCard: View {
    let state: SupportUiState
    let onEvent: (SupportEvent) -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        SalusCard(contentPadding: SalusSpacing.lg) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: SettingsStrings.supportPremiumStatusTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(colors.onSurface)

                Text(verbatim: premiumStatusLabel)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(colors.onSurface)
                    .padding(.top, SalusSpacing.sm)

                if let appUserID = state.appUserID, state.idRevealed {
                    Text(verbatim: SettingsStrings.supportCode)
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
                                ? SettingsStrings.supportCopied
                                : SettingsStrings.supportCopy)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.top, SalusSpacing.sm)
                }
            }
        }
    }

    /// `when (state.premiumStatus)` (`SupportScreen.kt:112-119`): `gracePeriod` reads as active.
    private var premiumStatusLabel: String {
        switch state.premiumStatus {
        case .free: SettingsStrings.supportPremiumFree
        case .premium: SettingsStrings.supportPremiumActive
        case .gracePeriod: SettingsStrings.supportPremiumActive
        }
    }

    /// `clipboardManager.setText(AnnotatedString(appUserID))` (`SupportScreen.kt:143`) — the screen
    /// performs the actual clipboard write; the ViewModel only flips the "Copied" label. iOS-only:
    /// the macOS host build compiles the button without the write.
    private func copy(_ appUserID: String) {
        #if os(iOS)
            UIPasteboard.general.string = appUserID
        #endif
    }
}

#Preview("Support") {
    NavigationStack {
        SupportScreen(
            state: SupportUiState(
                appUserID: "$RCAnonymousID:01234567-89ab-cdef-0123-456789abcdef",
                premiumStatus: .premium
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("Support, dark") {
    NavigationStack {
        SupportScreen(
            state: SupportUiState(
                appUserID: "$RCAnonymousID:01234567-89ab-cdef-0123-456789abcdef",
                premiumStatus: .premium
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: true))
    .preferredColorScheme(.dark)
}
