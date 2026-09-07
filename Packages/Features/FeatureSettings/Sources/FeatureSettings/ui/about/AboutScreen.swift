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
//
// The app version deliberately lives on the More screen's About row only, so the number has a
// single home (`AboutScreen.kt:52-53`); see `docs/architecture/m9-plan.md` item 1. No version
// footer here.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The About screen (`AboutScreen.kt:46-114`).
///
/// About carries no ViewModel and no state: it is pure information — the app name, a short
/// description, a "What Salus does" feature overview, and a privacy card. The premium-status card
/// and the hidden RevenueCat id moved to the Support screen (`SupportScreen.swift`), reached from
/// the More tab's "Uygulama" section (`MoreScreen.kt:308-314`).
public struct AboutRoute: View {
    public init() {}

    public var body: some View {
        AboutScreen()
    }
}

/// The stateless About screen (`AboutScreen.kt:54-114`), drawn as a pushed destination.
struct AboutScreen: View {
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

                // The feature-overview rows, informational only (`AboutScreen.kt:92-98`).
                ForEach(AboutFeatureRows.all, id: \.systemImage) { row in
                    FeatureRow(
                        systemImage: row.systemImage,
                        title: row.title,
                        description: row.description
                    )
                }

                // The privacy card (`AboutScreen.kt:99-111`).
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

/// One non-interactive feature row: an icon badge, the feature name and a one-line description
/// (`AboutScreen.kt:119-149`). These are informational only — the `SalusCard` gets no `onTap`
/// (the twin of Kotlin's `SalusCard` without `onClick`), so there is no chevron and nothing
/// responds to a tap.
private struct FeatureRow: View {
    let systemImage: String
    let title: String
    let description: String

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        SalusCard(contentPadding: SalusSpacing.lg) {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: systemImage)
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: title)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(colors.onSurface)
                    Text(verbatim: description)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The feature-overview rows, in the order they are presented (`AboutScreen.kt:151-194`). The
/// Material icons map to SF Symbols exactly as the More screen's rows do (a recorded divergence);
/// each symbol is the established one for that feature's rows elsewhere in the port.
private struct AboutFeatureRow {
    let systemImage: String
    let title: String
    let description: String
}

private enum AboutFeatureRows {
    static let all: [AboutFeatureRow] = [
        AboutFeatureRow(
            systemImage: "pills",
            title: SettingsStrings.aboutFeatureMedications,
            description: SettingsStrings.aboutFeatureMedicationsDesc
        ),
        AboutFeatureRow(
            systemImage: "calendar",
            title: SettingsStrings.aboutFeatureAppointments,
            description: SettingsStrings.aboutFeatureAppointmentsDesc
        ),
        AboutFeatureRow(
            systemImage: "heart.text.square",
            title: SettingsStrings.aboutFeatureVitals,
            description: SettingsStrings.aboutFeatureVitalsDesc
        ),
        AboutFeatureRow(
            systemImage: "drop.fill",
            title: SettingsStrings.aboutFeatureCycle,
            description: SettingsStrings.aboutFeatureCycleDesc
        ),
        AboutFeatureRow(
            systemImage: "sparkles",
            title: SettingsStrings.aboutFeatureAI,
            description: SettingsStrings.aboutFeatureAIDesc
        ),
        AboutFeatureRow(
            systemImage: "chart.line.uptrend.xyaxis",
            title: SettingsStrings.aboutFeatureTrends,
            description: SettingsStrings.aboutFeatureTrendsDesc
        ),
        AboutFeatureRow(
            systemImage: "bell",
            title: SettingsStrings.aboutFeatureReminders,
            description: SettingsStrings.aboutFeatureRemindersDesc
        )
    ]
}

#Preview("About") {
    NavigationStack {
        AboutScreen()
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("About, dark") {
    NavigationStack {
        AboutScreen()
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: true))
    .preferredColorScheme(.dark)
}
