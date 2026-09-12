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
//                                    values are identical, `lg = 16`, `md = 12`, `sm = 8`). The
//                                    feature rows use `horizontal = lg, vertical = md` on Android
//                                    (`AboutScreen.kt:127-131`); iOS's `SalusCard` takes one uniform
//                                    padding (divergence (8) in `MoreScreen.swift`), so the rows use
//                                    `lg` on all four edges, the same accepted limitation the More
//                                    cards carry.
//   `SalusIconBadge`                → stays `SalusIconBadge(systemImage:)`.
//   `Icons.Outlined.*`              → SF Symbols (the Material→SF map is a recorded divergence, the
//                                    same one `MoreScreen.swift` records).
//   `TopAppBar` title Text with     → the reveal gesture lands on the `.navigationTitle`'s `Text`
//    `Modifier.clickable { TitleTapped }`  (`.onTapGesture`), the exact mechanic the Android
//                                    About title carries (`AboutScreen.kt:83-86`).
//   `LocalClipboardManager`         → `UIPasteboard.general` under `#if os(iOS)`; the macOS host
//                                    build compiles the copy button without the write.
//   `TextButton`                    → a plain `Button` with `.buttonStyle(.borderless)`, so it stays
//                                    inside the card rather than becoming a full-width row.
//   `TextOverflow.MiddleEllipsis`   → `.lineLimit(1)` + `.truncationMode(.middle)`.
//
// The app version deliberately lives on the More screen's About row only, so the number has a
// single home (`AboutScreen.kt:52-53`); see `docs/architecture/m9-plan.md` item 1. No version
// footer here.

import SalusDesignSystem
import SalusPremium
import SalusUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Owns the ViewModel and wires it to the shell (`AboutScreen.kt:56-70`).
///
/// The Kotlin `AboutRoute` calls `koinInject<Navigator>()` then passes `navigator::pop` as
/// `onBack`; iOS needs neither, because the shell's one `NavigationStack` draws the back button
/// itself once a `.navigationTitle` is set (divergence (d) — the same one `ProfileRoute` and
/// `ReminderHealthRoute` record). The back tap pops the stack without the feature reaching for a
/// `Navigator`.
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

/// The About screen (`AboutScreen.kt:72-139`), drawn as a pushed destination.
///
/// About is a feature overview — the app name, a short description, a "What Salus does" feature
/// list, and a privacy card — with the premium-status card and the hidden RevenueCat id embedded
/// below the privacy card (`AboutScreen.kt:137`). The premium-status line is always visible; the id
/// and copy button only appear once the 5-tap reveal on the title has completed.
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

                Text(verbatim: SettingsStrings.aboutDescription)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // The "What Salus does" section header (`AboutScreen.kt:87-91`). The scroll column
                // already applies the horizontal screen padding.
                SalusSectionHeader(
                    title: SettingsStrings.aboutFeaturesTitle,
                    contentPadding: SalusSectionHeaderDefaults.topOnly
                )

                // The feature-overview rows in one card (`AboutScreen.kt:92-122`): each line keeps
                // the glyph and the accent its feature wears everywhere else in the app, so the
                // list reads as the features themselves (spec §4.17, A61). The card carries no
                // horizontal padding of its own — the rows bring theirs, like every
                // `SalusListItem` list.
                SalusCard(contentPadding: EdgeInsets(
                    top: SalusSpacing.sm,
                    leading: 0,
                    bottom: SalusSpacing.sm,
                    trailing: 0
                )) {
                    ForEach(AboutFeatureRows.all(accentedBy: theme), id: \.systemImage) { row in
                        SalusListItem(
                            title: row.title,
                            subtitle: row.description,
                            systemImage: row.systemImage,
                            accent: row.accent
                        )
                    }
                }

                // The privacy card (`AboutScreen.kt:99-111`).
                SalusCard(contentPadding: EdgeInsets(
                    top: SalusSpacing.lg,
                    leading: SalusSpacing.lg,
                    bottom: SalusSpacing.lg,
                    trailing: SalusSpacing.lg
                )) {
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

                // The premium-status card, embedded below the privacy card (`AboutScreen.kt:137`).
                PremiumStatusCard(state: state, onEvent: onEvent)
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

/// The premium-status card: the RevenueCat `appUserID` a developer pastes into the RevenueCat
/// dashboard to grant a gift subscription. The id is long (`$RCAnonymousID:<uuid>`), so it is
/// ellipsized in the middle; the copy button puts the full value on the clipboard. The
/// premium-status line is always visible; the id and copy button only appear once the 5-tap reveal
/// has completed (`AboutScreen.kt:143-207`).
private struct PremiumStatusCard: View {
    let state: AboutUiState
    let onEvent: (AboutEvent) -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        // The reveal gesture: five consecutive taps on this card show the support code. The card
        // is the most natural tap target — it is the thing the user is looking at when they want
        // their premium status, and a trusted user is told "tap your subscription card five times"
        // (`AboutScreen.kt:152-156`).
        SalusCard(contentPadding: EdgeInsets(
            top: SalusSpacing.lg,
            leading: SalusSpacing.lg,
            bottom: SalusSpacing.lg,
            trailing: SalusSpacing.lg
        )) {
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

                // The revealed section shows whenever the 5-tap reveal has completed, whether or not
                // RevenueCat has handed us an `appUserID`. With an id, the developer sees the value
                // and a copy button; without one (RevenueCat not configured, e.g. a debug build) the
                // reveal still answers with a short message instead of silently doing nothing.
                if state.idRevealed {
                    if let appUserID = state.appUserID {
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
                    } else {
                        Text(verbatim: SettingsStrings.supportCodeUnavailable)
                            .font(SalusTypography.labelMedium.font)
                            .tracking(SalusTypography.labelMedium.tracking)
                            .foregroundStyle(colors.onSurface)
                            .padding(.top, SalusSpacing.sm)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture { onEvent(.titleTapped) }
    }

    /// `when (state.premiumStatus)` (`AboutScreen.kt:163-167`): `gracePeriod` reads as active.
    private var premiumStatusLabel: String {
        switch state.premiumStatus {
        case .free: SettingsStrings.supportPremiumFree
        case .premium: SettingsStrings.supportPremiumActive
        case .gracePeriod: SettingsStrings.supportPremiumActive
        }
    }

    /// `clipboardManager.setText(AnnotatedString(appUserID))` (`AboutScreen.kt:192`) — the screen
    /// performs the actual clipboard write; the ViewModel only flips the "Copied" label. iOS-only:
    /// the macOS host build compiles the button without the write.
    private func copy(_ appUserID: String) {
        #if os(iOS)
            UIPasteboard.general.string = appUserID
        #endif
    }
}

/// One line of the feature overview: the glyph, the name, the one clause that says what it does,
/// and the feature's own accent (nil → the primary role, which is what `SalusIconBadge` does with
/// a null accent) (`AboutScreen.kt:252-290`).
private struct AboutFeatureRow {
    let systemImage: String
    let title: String
    let description: String
    /// The feature's accent, resolved from the environment (the accents are theme values, only
    /// readable from a composition). Features with no accent of their own take the primary role.
    let accent: FeatureAccent?
}

private enum AboutFeatureRows {
    /// The rows, in the order they are presented (`AboutScreen.kt:252-290`). The accents are theme
    /// values — only readable from a composition — so the list is built per render, exactly as
    /// Kotlin's `accentOf = { MaterialTheme.salusColors.medications }` resolves in composition.
    /// Features with no accent of their own (the AI pair, reminders) return nil and take the
    /// primary role, which is what `SalusIconBadge` does with a null accent.
    static func all(accentedBy theme: SalusResolvedTheme) -> [AboutFeatureRow] {
        [
            AboutFeatureRow(
                systemImage: "pills",
                title: SettingsStrings.aboutFeatureMedications,
                description: SettingsStrings.aboutFeatureMedicationsDesc,
                accent: theme.extendedColors.medications
            ),
            AboutFeatureRow(
                systemImage: "calendar",
                title: SettingsStrings.aboutFeatureAppointments,
                description: SettingsStrings.aboutFeatureAppointmentsDesc,
                accent: theme.extendedColors.appointments
            ),
            AboutFeatureRow(
                systemImage: "heart.text.square",
                title: SettingsStrings.aboutFeatureVitals,
                description: SettingsStrings.aboutFeatureVitalsDesc,
                accent: theme.extendedColors.vitals
            ),
            AboutFeatureRow(
                systemImage: "drop.fill",
                title: SettingsStrings.aboutFeatureCycle,
                description: SettingsStrings.aboutFeatureCycleDesc,
                accent: theme.extendedColors.cycle
            ),
            AboutFeatureRow(
                systemImage: "sparkles",
                title: SettingsStrings.aboutFeatureAI,
                description: SettingsStrings.aboutFeatureAIDesc,
                accent: nil
            ),
            AboutFeatureRow(
                systemImage: "chart.line.uptrend.xyaxis",
                title: SettingsStrings.aboutFeatureTrends,
                description: SettingsStrings.aboutFeatureTrendsDesc,
                accent: theme.extendedColors.trends
            ),
            AboutFeatureRow(
                systemImage: "bell",
                title: SettingsStrings.aboutFeatureReminders,
                description: SettingsStrings.aboutFeatureRemindersDesc,
                accent: nil
            )
        ]
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

#Preview("About, revealed") {
    NavigationStack {
        AboutScreen(
            state: AboutUiState(
                appUserID: "$RCAnonymousID:01234567-89ab-cdef-0123-456789abcdef",
                premiumStatus: .premium,
                idRevealed: true
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}
