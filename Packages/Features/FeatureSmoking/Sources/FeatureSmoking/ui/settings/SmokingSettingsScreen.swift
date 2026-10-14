// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/settings/
// SmokingSettingsScreen.kt`.
//
// The smoking settings: habit and goals, notifications, mode management and the reset, as grouped
// rows. A pushed screen, so the shell has reserved the insets and the system bar names it. Rows
// that belong to one mode only (limit and evening reminder: REDUCE; quit date: QUIT) are absent in
// the other. The sheets and confirmations hang off the state.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `SalusTopBar.Pushed(title, onBack)`  → `.navigationTitle` + inline mode.
//   `Switch`                             → `Toggle(_:isOn:)` over a get/set `Binding`, the label
//                           given and hidden (`CycleReminderSections.swift`).
//   `HorizontalDivider(cardBorder)`      → ``SettingsDivider``.
//   `SalusConfirmDialog`                 → `.salusConfirmDialog`, presented once the sheet that
//                           asked has left the screen (see ``SettingsConfirmHost``).

import SalusCommon
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The stateless screen: `state` + `onEvent` only, so it previews without a ViewModel. `clock` is
/// the app's (a fixed one in a preview), for the quit-date sheets' "not in the future" check.
struct SmokingSettingsScreen: View {
    let state: SmokingSettingsUiState
    let onEvent: (SmokingSettingsEvent) -> Void
    let clock: any SalusClock

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ScrollView {
            if state.mode != .none {
                SettingsRows(state: state, onEvent: onEvent)
                    .padding(.horizontal, SalusSpacing.lg)
                    .padding(.vertical, SalusSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .settingsSheets(state, clock: clock, onEvent: onEvent)
        .settingsConfirm(state, onEvent: onEvent)
        .navigationTitle(Text(verbatim: SmokingStrings.settingsTitle))
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Rows

private struct SettingsRows: View {
    let state: SmokingSettingsUiState
    let onEvent: (SmokingSettingsEvent) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            section(SmokingStrings.settingsSectionHabit, top: SalusSpacing.sm) {
                SalusListItem(
                    title: SmokingStrings.settingsPrice,
                    systemImage: "banknote",
                    accent: accent,
                    onTap: { onEvent(.priceTapped) },
                    trailing: { ValueWithChevron(value: priceText) }
                )
                SettingsDivider()
                SalusListItem(
                    title: SmokingStrings.settingsCurrency,
                    systemImage: "dollarsign.arrow.circlepath",
                    accent: accent,
                    onTap: { onEvent(.currencyTapped) },
                    trailing: { ValueWithChevron(value: state.currencyCode) }
                )
                if state.showLimit {
                    SettingsDivider()
                    SalusListItem(
                        title: SmokingStrings.settingsLimit,
                        systemImage: "speedometer",
                        accent: accent,
                        onTap: { onEvent(.limitTapped) },
                        trailing: { ValueWithChevron(value: SmokingStrings.settingsLimitValue(state.dailyLimit ?? 0)) }
                    )
                }
                if state.showQuitDate {
                    SettingsDivider()
                    SalusListItem(
                        title: SmokingStrings.settingsQuitDate,
                        subtitle: state.quitAtMs.map {
                            formatDateTime(
                                epochMs: $0,
                                zone: TimeZone(identifier: state.zoneId) ?? .gmt,
                                locale: locale
                            )
                        },
                        systemImage: "calendar",
                        accent: accent,
                        onTap: { onEvent(.quitDateTapped) }
                    )
                }
                SettingsDivider()
                SalusListItem(
                    title: SmokingStrings.settingsReason,
                    subtitle: state.reason.map(SmokingStrings.settingsReasonValue) ?? SmokingStrings
                        .settingsReasonEmpty,
                    systemImage: "heart",
                    accent: accent,
                    onTap: { onEvent(.reasonTapped) }
                )
            }

            section(SmokingStrings.settingsSectionNotifications) {
                SwitchRow(
                    title: SmokingStrings.settingsNotifications,
                    subtitle: SmokingStrings.settingsNotificationsDesc,
                    systemImage: "bell",
                    isOn: state.notificationsEnabled,
                    enabled: !state.writing
                ) { onEvent(.notificationsToggled($0)) }
                if state.showEveningReminder {
                    SettingsDivider()
                    SwitchRow(
                        title: SmokingStrings.settingsEvening,
                        subtitle: SmokingStrings.settingsEveningDesc,
                        systemImage: "moon.stars",
                        isOn: state.eveningReminderEnabled,
                        enabled: !state.writing
                    ) { onEvent(.eveningToggled($0)) }
                }
            }

            section(SmokingStrings.settingsSectionMode) {
                let toReduce = state.mode == .quit
                SalusListItem(
                    title: toReduce ? SmokingStrings.settingsSwitchToReduce : SmokingStrings.settingsSwitchToQuit,
                    subtitle: toReduce
                        ? SmokingStrings.settingsSwitchToReduceDesc
                        : SmokingStrings.settingsSwitchToQuitDesc,
                    systemImage: "arrow.left.arrow.right",
                    accent: accent,
                    onTap: { onEvent(.switchModeTapped) }
                )
            }

            section(SmokingStrings.settingsSectionData) {
                // The one destructive style in the feature: this deletes the whole plan.
                SalusListItem(
                    title: SmokingStrings.settingsReset,
                    subtitle: SmokingStrings.settingsResetDesc,
                    systemImage: "trash",
                    titleColor: theme.colorScheme.error,
                    onTap: { onEvent(.resetTapped) }
                )
            }
        }
    }

    private func section(
        _ title: String,
        top: CGFloat = SalusSpacing.lg,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            SalusSectionHeader(
                title: title,
                contentPadding: EdgeInsets(top: top, leading: 0, bottom: SalusSpacing.sm, trailing: 0)
            )
            // The rows bring their own horizontal inset, so the card only pads vertically.
            SalusCard(
                contentPadding: EdgeInsets(top: SalusSpacing.xs, leading: 0, bottom: SalusSpacing.xs, trailing: 0),
                content: content
            )
        }
    }

    private var priceText: String {
        let money = formatMoney(
            minor: state.unitCostMinor,
            currencyCode: state.currencyCode,
            locale: locale,
            showFraction: true
        )
        return state.productType == .vape
            ? SmokingStrings.settingsPriceValueVape(money)
            : SmokingStrings.settingsPriceValue(money)
    }
}

private struct ValueWithChevron: View {
    let value: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.xs) {
            Text(verbatim: value)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            SalusListItemChevron()
        }
    }
}

private struct SwitchRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isOn: Bool
    let enabled: Bool
    let onToggle: (Bool) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusListItem(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            accent: theme.extendedColors.smoking,
            onTap: enabled ? { onToggle(!isOn) } : nil,
            trailing: { Toggle(title, isOn: binding).labelsHidden().disabled(!enabled) }
        )
    }

    /// The switch draws what the settings last emitted, never a local copy.
    ///
    /// The setter is a closure literal rather than `onToggle` passed straight through: `Binding`'s
    /// setter is `@isolated(any) @Sendable`, and only a literal written here picks up this view's
    /// main-actor isolation (`CycleReminderSections.swift`).
    private var binding: Binding<Bool> {
        Binding(get: { isOn }, set: { onToggle($0) })
    }
}

/// The hairline between two rows of one card (`HorizontalDivider(cardBorder)`).
private struct SettingsDivider: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.extendedColors.cardBorder)
            .frame(height: SettingsDefaults.hairline)
            .accessibilityHidden(true)
    }
}

// MARK: - Confirmations

/// Presents the open confirmation.
///
/// A currency or a quit date is chosen in a sheet and confirmed in a dialog, and the ViewModel
/// closes the one and opens the other in a single state change. SwiftUI drops an alert presented
/// while a sheet is still sliding away, so the dialog waits for the slide to finish; the reset has
/// no sheet before it and appears at once. The dialog is also kept down while the write runs: its
/// button has been answered, and the system would otherwise show it again.
private struct SettingsConfirmHost: ViewModifier {
    let state: SmokingSettingsUiState
    let onEvent: (SmokingSettingsEvent) -> Void

    @State private var presented: SettingsConfirm?

    func body(content: Content) -> some View {
        content
            .task(id: state.confirm) {
                guard let confirm = state.confirm else {
                    presented = nil
                    return
                }
                if confirm != .reset {
                    try? await Task.sleep(for: .seconds(SettingsDefaults.sheetSettleSeconds))
                    guard !Task.isCancelled else { return }
                }
                presented = confirm
            }
            .salusConfirmDialog(
                isPresented: Binding(
                    get: { presented != nil && state.confirm != nil && !state.writing },
                    set: { shown in
                        if !shown {
                            onEvent(.confirmDismissed)
                        }
                    }
                ),
                title: copy.title,
                message: copy.message,
                confirm: SalusDialogAction(label: copy.confirmLabel) { onEvent(.confirmAccepted) },
                dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.confirmDismissed) },
                confirmIsDestructive: copy.destructive
            )
    }

    private var copy: ConfirmCopy {
        switch presented ?? state.confirm {
        case .currency:
            ConfirmCopy(
                title: SmokingStrings.settingsCurrencyConfirmTitle,
                message: SmokingStrings.settingsCurrencyConfirmMessage,
                confirmLabel: SmokingStrings.settingsConfirmChange,
                destructive: false
            )

        case .quitDate:
            ConfirmCopy(
                title: SmokingStrings.settingsQuitDateConfirmTitle,
                message: SmokingStrings.settingsQuitDateConfirmMessage,
                confirmLabel: SmokingStrings.settingsConfirmChange,
                destructive: false
            )

        case nil, .reset:
            ConfirmCopy(
                title: SmokingStrings.settingsResetConfirmTitle,
                message: SmokingStrings.settingsResetConfirmMessage,
                confirmLabel: SmokingStrings.settingsResetConfirm,
                destructive: true
            )
        }
    }

    private struct ConfirmCopy {
        let title: String
        let message: String
        let confirmLabel: String
        let destructive: Bool
    }
}

extension View {
    /// Hosts the settings screen's confirmation dialog.
    fileprivate func settingsConfirm(
        _ state: SmokingSettingsUiState,
        onEvent: @escaping (SmokingSettingsEvent) -> Void
    ) -> some View {
        modifier(SettingsConfirmHost(state: state, onEvent: onEvent))
    }
}

enum SettingsDefaults {
    static let hairline: CGFloat = 1
    /// How long a sheet takes to slide away, so a dialog that follows it is not dropped.
    static let sheetSettleSeconds = 0.5
}
