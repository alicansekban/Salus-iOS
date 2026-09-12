// The hub's own blocks, ported from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/MoreSections.kt`.
//
// They live next to `MoreScreen` rather than inside it because the More root is a long list of
// rows with nothing else in it — one file of layout would bury the screen's shape (header cards,
// sections, footer) under the rows themselves. Extracted here in M16 Task 10 so `MoreScreen.swift`
// stays under the 500-line `file_length` gate.
//
// Material → SwiftUI, the same mapping `MoreScreen.swift` records:
//   `SalusCard` → `SalusCard`, `SalusListItem` → `SalusListItem`, `SalusSectionHeader` → the same.
//   `Switch` → the `MoreToggleRow`'s `Toggle`.
//   `PaletteSwatch` → the small `Circle` in the colour-theme row's trailing value.
//   `Icons.Outlined.*` → SF Symbols; `MaterialTheme.salusColors.<feature>` → `theme.extendedColors.<feature>`.
//
// Two divergences from the Kotlin twin, both recorded in `MoreScreen.swift`'s header list:
//   (8) `SalusCard`'s uniform padding — every card is `lg` on all four edges;
//   (11) the drawn palette value in the colour-theme row reads `effectivePremiumTheme`.

import SalusDesignSystem
import SalusModel
import SalusPremium
import SalusUI
import SwiftUI

/// The user's own row, above everything about the app. A blank name means onboarding skipped it,
/// so the card invites completing the profile instead of showing an empty line
/// (`MoreSections.kt:28-60`).
struct MoreProfileCard: View {
    let state: MoreUiState
    let onClick: () -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        let name = state.profileName.isEmpty ? nil : state.profileName
        let entitled = state.premiumStatus.isEntitled
        SalusCard(
            tone: .elevated,
            onTap: onClick,
            contentPadding: EdgeInsets(
                top: SalusSpacing.lg,
                leading: SalusSpacing.lg,
                bottom: SalusSpacing.lg,
                trailing: SalusSpacing.lg
            )
        ) {
            HStack(spacing: SalusSpacing.md) {
                SalusAvatar(name: name)
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    // `text = name ?: stringResource(R.string.more_profile_incomplete)`
                    // (`MoreSections.kt:44`) — no colour: the elevated card's own tone.
                    Text(verbatim: name ?? SettingsStrings.moreProfileIncomplete)
                        .font(SalusTypography.titleLarge.font)
                        .tracking(SalusTypography.titleLarge.tracking)
                        .foregroundStyle(colors.onSurface)
                    if state.profileSex != nil || entitled {
                        HStack(spacing: SalusSpacing.sm) {
                            if let sex = state.profileSex {
                                SalusStatusChip(label: sex.label, status: .neutral)
                            }
                            if entitled {
                                SalusStatusChip(label: SettingsStrings.moreProBadge, status: .accent)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SalusListItemChevron()
            }
        }
    }
}

/// The one band that sells rather than settles something. An entitled user taps the card itself
/// and lands in the store's subscription management; a free user gets the offer and a button,
/// because a card that only opens a paywall should say so in words (`MoreSections.kt:63-88`).
struct MorePremiumBand: View {
    let state: MoreUiState
    let onEvent: (MoreEvent) -> Void

    var body: some View {
        let entitled = state.premiumStatus.isEntitled
        SalusCard(
            tone: .accent,
            onTap: entitled ? { onEvent(.premiumClicked) } : nil,
            contentPadding: EdgeInsets(
                top: SalusSpacing.lg,
                leading: SalusSpacing.lg,
                bottom: SalusSpacing.lg,
                trailing: SalusSpacing.lg
            )
        ) {
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                // An Accent card carries `onPrimaryContainer` as its content colour; restating a
                // surface colour here would undo it.
                Text(verbatim: SettingsStrings.settingsPremium)
                    .font(SalusTypography.titleLarge.font)
                    .tracking(SalusTypography.titleLarge.tracking)
                Text(verbatim: entitled
                    ? SettingsStrings.settingsPremiumActive
                    : SettingsStrings.settingsPremiumPromo)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                if !entitled {
                    // `SalusButton(more_premium_cta, Medium)` (`MoreSections.kt:86-94`).
                    SalusButton(
                        SettingsStrings.morePremiumCta,
                        size: .medium,
                        action: { onEvent(.premiumClicked) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Every settings row, grouped under overline headers. The order runs from what the user came for
/// (their health data) down to what they read once (about, rate us) (`MoreSections.kt:91-214`).
struct MoreSections: View {
    let state: MoreUiState
    let appLockAvailable: Bool
    let onEvent: (MoreEvent) -> Void
    let onOpenCycle: () -> Void
    let onOpenReminderHealth: () -> Void
    let onOpenAbout: () -> Void
    let onOpenNotificationSettings: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            SalusSectionHeader(
                title: SettingsStrings.moreSectionHealth,
                contentPadding: SalusSectionHeaderDefaults.topOnly
            )
            SalusListItem(
                title: SettingsStrings.settingsDoctorReport,
                subtitle: SettingsStrings.settingsDoctorReportDesc,
                systemImage: "doc.text",
                onTap: { onEvent(.doctorReportClicked) }
            )
            // Not gated, unlike the report above: the trends screen carries its own lock, so a
            // free user gets to see what the feature is before being asked to pay for it.
            SalusListItem(
                title: SettingsStrings.moreTrends,
                subtitle: SettingsStrings.moreTrendsSubtitle,
                systemImage: "chart.xyaxis.line",
                accent: theme.extendedColors.trends,
                onTap: { onEvent(.trendsClicked) }
            )

            if state.showCycle {
                SalusSectionHeader(
                    title: SettingsStrings.moreSectionTracking,
                    contentPadding: SalusSectionHeaderDefaults.topOnly
                )
                SalusListItem(
                    title: SettingsStrings.moreCycle,
                    subtitle: SettingsStrings.moreCycleSubtitle,
                    systemImage: "drop.fill",
                    accent: theme.extendedColors.cycle,
                    onTap: onOpenCycle
                )
            }

            SalusSectionHeader(
                title: SettingsStrings.moreSectionAppearance,
                contentPadding: SalusSectionHeaderDefaults.topOnly
            )
            // The theme-mode row: the value trailing shows the stored mode's label.
            SalusListItem(
                title: SettingsStrings.moreThemeMode,
                systemImage: "paintpalette.fill",
                onTap: { onEvent(.themeSheetOpened) },
                trailing: {
                    RowValue(text: SettingsStrings.theme(state.themeMode))
                }
            )
            // The colour-theme row: the palette actually being drawn, not the stored pick — a lapsed
            // subscriber sees Classic here, which is what their app looks like. The sheet still
            // shows their choice as selected.
            SalusListItem(
                title: SettingsStrings.settingsColorTheme,
                systemImage: "swatchpalette.fill",
                onTap: { onEvent(.themeSheetOpened) },
                trailing: {
                    HStack(spacing: SalusSpacing.sm) {
                        PaletteSwatch(color: theme.colorScheme.primary)
                        RowValue(text: SettingsStrings.colorTheme(SalusPremium.effectivePremiumTheme(
                            state.premiumStatus,
                            state.premiumTheme
                        )))
                    }
                }
            )
            SalusListItem(
                title: SettingsStrings.moreLanguage,
                systemImage: "globe",
                onTap: { onEvent(.languageSheetOpened) },
                trailing: {
                    RowValue(text: SettingsStrings.language(state.language))
                }
            )

            SalusSectionHeader(
                title: SettingsStrings.moreSectionNotifications,
                contentPadding: SalusSectionHeaderDefaults.topOnly
            )
            SalusListItem(
                title: SettingsStrings.reminderHealthTitle,
                subtitle: SettingsStrings.settingsRemindersDesc,
                systemImage: "alarm.fill",
                onTap: onOpenReminderHealth
            )
            // Channels, sound and vibration are the system's to manage; the row deep-links there
            // rather than duplicating that UI in the app.
            SalusListItem(
                title: SettingsStrings.settingsNotifications,
                subtitle: SettingsStrings.settingsNotificationsDesc,
                systemImage: "bell.fill",
                onTap: onOpenNotificationSettings
            )

            SalusSectionHeader(
                title: SettingsStrings.moreSectionSecurity,
                contentPadding: SalusSectionHeaderDefaults.topOnly
            )
            let appLockChecked = state.appLockEnabled && appLockAvailable
            SalusListItem(
                title: SettingsStrings.settingsAppLock,
                subtitle: appLockAvailable
                    ? SettingsStrings.settingsAppLockDesc
                    : SettingsStrings.settingsAppLockUnavailable,
                systemImage: "lock.fill",
                onTap: appLockAvailable ? { onEvent(.setAppLock(!appLockChecked)) } : nil,
                trailing: {
                    Toggle(SettingsStrings.settingsAppLock, isOn: Binding(
                        get: { appLockChecked },
                        set: { onEvent(.setAppLock($0)) }
                    ))
                    .labelsHidden()
                    .disabled(!appLockAvailable)
                    .accessibilityLabel(SettingsStrings.settingsAppLock)
                }
            )
            SalusListItem(
                title: SettingsStrings.settingsSecureScreen,
                subtitle: SettingsStrings.settingsSecureScreenDesc,
                systemImage: "camera.viewfinder",
                onTap: { onEvent(.setSecureScreen(!state.secureScreenEnabled)) },
                trailing: {
                    Toggle(SettingsStrings.settingsSecureScreen, isOn: Binding(
                        get: { state.secureScreenEnabled },
                        set: { onEvent(.setSecureScreen($0)) }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(SettingsStrings.settingsSecureScreen)
                }
            )

            SalusSectionHeader(
                title: SettingsStrings.moreSectionApp,
                contentPadding: SalusSectionHeaderDefaults.topOnly
            )
            SalusListItem(
                title: SettingsStrings.settingsAbout,
                subtitle: SettingsStrings.settingsAboutDesc,
                systemImage: "info.circle.fill",
                onTap: onOpenAbout
            )
            // Rate Salus — the store's write-review page (in-app review spec §4).
            SalusListItem(
                title: SettingsStrings.settingsRateUs,
                subtitle: SettingsStrings.settingsRateUsDesc,
                systemImage: "star.fill",
                onTap: { onEvent(.rateUsClicked) }
            )
        }
    }
}

/// A row's current value, trailing the title in the quieter body colour (`MoreSections.kt:216-225`).
private struct RowValue: View {
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Text(verbatim: text)
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
    }
}

/// The palette's own colour, drawn as the disc the colour-theme row leads with — the twin of
/// `PaletteSwatch` (`ThemeSheet.kt:124-132`), at `SalusSelectableRowDefaults.SwatchSize` (24 pt).
private struct PaletteSwatch: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: Self.swatchSize, height: Self.swatchSize)
            .accessibilityHidden(true)
    }

    /// `SalusSelectableRowDefaults.SwatchSize` (`SalusSelectableRow.kt:113`).
    private static let swatchSize: CGFloat = 24
}

/// `Sex.labelRes()` (`MoreSections.kt:229-236`) — the chip label for each sex.
///
/// Internal so `MoreScreen.swift` could read it if a preview needed it.
extension Sex {
    fileprivate var label: String {
        switch self {
        case .female: SettingsStrings.profileSexFemale
        case .male: SettingsStrings.profileSexMale
        case .other: SettingsStrings.profileSexOther
        }
    }
}
