// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/history/
// SmokingHistoryScreen.kt`.
//
// The history screen: the journey so far, one card per attempt, a supportive note and the
// day-by-day log. A pushed screen, so the shell has reserved the insets and the system bar names
// it. With no entries it is the empty state and the explainer instead; the editor and its delete
// confirmation hang off the state.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `SalusTopBar.Pushed(title, onBack)`  → `.navigationTitle` + inline mode, the back button the
//                           system's (spec §2.2).
//   `LazyColumn` + `items`               → `ScrollView` + `LazyVStack`.
//   `HorizontalDivider(cardBorder)`      → ``HistoryDivider``.
//   `pluralStringResource`               → the two-key accessors of ``SmokingStrings``.

import SalusCommon
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The stateless screen: `state` + `onEvent` only, so it previews without a ViewModel. `clock` is
/// the app's (a fixed one in a preview), for the editor's "not in the future" check; `onBack` is the
/// empty state's way home.
struct SmokingHistoryScreen: View {
    let state: SmokingHistoryUiState
    let onEvent: (SmokingHistoryEvent) -> Void
    let onBack: () -> Void
    let clock: any SalusClock

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SalusSpacing.md) {
                if state.isEmpty {
                    HistoryEmpty(onBack: onBack)
                } else {
                    HistoryList(state: state, onEvent: onEvent)
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .eventEditSheet(
            row: state.editing,
            writing: state.writing,
            deleteConfirm: state.deleteConfirm,
            clock: clock,
            onEvent: onEvent
        )
        .navigationTitle(Text(verbatim: SmokingStrings.historyTitle))
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - List

private struct HistoryList: View {
    let state: SmokingHistoryUiState
    let onEvent: (SmokingHistoryEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        if state.loaded {
            JourneyHeader(days: Int(state.journeyDays))
        }
        if !state.attempts.isEmpty {
            sectionTitle(SmokingStrings.historyAttemptsTitle)
            ForEach(state.attempts, id: \.id) { attempt in
                AttemptCard(attempt: attempt, currencyCode: state.currencyCode, fallbackZoneId: state.zoneId)
            }
            SupportiveCard()
        }
        sectionTitle(SmokingStrings.historyLogTitle)
        if state.showHowTo {
            HowToCard()
        }
        ForEach(state.days, id: \.epochDay) { day in
            DayGroup(day: day, state: state) { onEvent(.rowTapped($0)) }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(verbatim: title)
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Journey and attempts

private struct JourneyHeader: View {
    let days: Int

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(tone: .elevated) {
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                Text(verbatim: SmokingStrings.historyJourneyOverline)
                    .font(SalusTypography.labelSmall.font)
                    .tracking(SalusTypography.labelSmall.tracking)
                    .foregroundStyle(theme.extendedColors.overline)
                Text(verbatim: SmokingStrings.historyJourneyDays(days))
                    .font(SalusTypography.headlineSmall.font)
                    .tracking(SalusTypography.headlineSmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct AttemptCard: View {
    let attempt: AttemptCardUi
    let currencyCode: String
    let fallbackZoneId: String

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    private var zone: TimeZone {
        TimeZone(identifier: attempt.tzId) ?? TimeZone(identifier: fallbackZoneId) ?? .gmt
    }

    var body: some View {
        SalusCard(tone: attempt.isActive ? .accentOutlined : .standard) {
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                // Side by side while they fit, stacked at the large text sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SalusSpacing.sm) { header }
                    VStack(alignment: .leading, spacing: SalusSpacing.sm) { header }
                }
                Text(verbatim: range)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Text(verbatim: duration)
                    .font(SalusTypography.titleLarge.font)
                    .tracking(SalusTypography.titleLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Text(verbatim: facts.joined(separator: " · "))
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var header: some View {
        Text(verbatim: SmokingStrings.historyAttemptTitle(attempt.ordinal))
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            .frame(maxWidth: .infinity, alignment: .leading)
        if attempt.isActive {
            SalusStatusChip(label: SmokingStrings.historyAttemptActive, status: .accent)
        }
        if attempt.isLongest {
            SalusStatusChip(label: SmokingStrings.historyAttemptLongest, status: .neutral, systemImage: "trophy")
        }
    }

    private var range: String {
        let started = formatShortDay(epochMs: attempt.startedAtMs, zone: zone, locale: locale)
        guard let ended = attempt.endedAtMs else { return SmokingStrings.historyAttemptRangeOpen(started) }
        return SmokingStrings.historyAttemptRange(started, formatShortDay(epochMs: ended, zone: zone, locale: locale))
    }

    private var duration: String {
        let days = Int(attempt.durationMs / HistoryDefaults.dayMs)
        return days == 0 ? SmokingStrings.historyAttemptUnderDay : SmokingStrings.historyAttemptDays(days)
    }

    private var facts: [String] {
        var facts = [
            attempt.slipCount == 0
                ? SmokingStrings.historyAttemptNoSlips
                : SmokingStrings.historyAttemptSlips(attempt.slipCount)
        ]
        if let saved = attempt.savedMinor {
            facts.append(
                SmokingStrings.historyAttemptSaved(
                    formatMoney(minor: saved, currencyCode: currencyCode, locale: locale, showFraction: false)
                )
            )
        }
        if let beaten = attempt.cravingsBeaten, beaten > 0 {
            facts.append(SmokingStrings.historyAttemptCravings(beaten))
        }
        return facts
    }
}

private struct SupportiveCard: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(systemImage: "lightbulb", accent: theme.extendedColors.smoking)
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: SmokingStrings.historySupportTitle)
                        .font(SalusTypography.titleSmall.font)
                        .tracking(SalusTypography.titleSmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    Text(verbatim: SmokingStrings.historySupportBody)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Log

private struct DayGroup: View {
    let day: DayGroupUi
    let state: SmokingHistoryUiState
    let onRowTap: (String) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            Text(verbatim: formatDayHeader(epochDay: day.epochDay, todayEpochDay: state.todayEpochDay, locale: locale))
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .accessibilityAddTraits(.isHeader)
            // The rows bring their own horizontal inset, so the card only pads vertically.
            SalusCard(
                contentPadding: EdgeInsets(top: SalusSpacing.xs, leading: 0, bottom: SalusSpacing.xs, trailing: 0)
            ) {
                ForEach(Array(day.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        HistoryDivider()
                    }
                    EventRow(row: row, fallbackZoneId: state.zoneId) { onRowTap(row.id) }
                }
            }
        }
    }
}

private struct EventRow: View {
    let row: EventRowUi
    let fallbackZoneId: String
    let onTap: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    private var zone: TimeZone {
        TimeZone(identifier: row.tzId) ?? TimeZone(identifier: fallbackZoneId) ?? .gmt
    }

    var body: some View {
        SalusListItem(
            title: title,
            subtitle: details,
            systemImage: symbol,
            accent: theme.extendedColors.smoking,
            onTap: onTap,
            trailing: {
                Text(verbatim: formatClockTime(epochMs: row.atMs, zone: zone, locale: locale))
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
        )
    }

    private var title: String {
        if row.isMarker {
            SmokingStrings.historyRowNone
        } else if row.type == .smoked {
            SmokingStrings.historyRowSmoked(row.units ?? 0)
        } else {
            SmokingStrings.historyRowCraving
        }
    }

    private var details: String? {
        let parts = [row.trigger?.label, row.intensity.map(SmokingStrings.historyRowIntensity)].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var symbol: String {
        if row.isMarker {
            "checkmark.circle"
        } else if row.type == .smoked {
            "smoke"
        } else {
            "shield"
        }
    }
}

/// The hairline between two rows of one card (`HorizontalDivider(cardBorder)`).
private struct HistoryDivider: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.extendedColors.cardBorder)
            .frame(height: HistoryDefaults.hairline)
            .accessibilityHidden(true)
    }
}

// MARK: - Empty

private struct HistoryEmpty: View {
    let onBack: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusEmptyState(
            systemImage: "clock.arrow.circlepath",
            title: SmokingStrings.historyEmptyTitle,
            message: SmokingStrings.historyEmptyBody,
            accent: theme.extendedColors.smoking,
            actionLabel: SmokingStrings.historyEmptyBack,
            onAction: onBack
        )
        HowToCard()
    }
}

/// The explainer shared by the full empty state and a log that is still empty.
private struct HowToCard: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                Text(verbatim: SmokingStrings.historyEmptyHowTitle)
                    .font(SalusTypography.titleSmall.font)
                    .tracking(SalusTypography.titleSmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Text(verbatim: SmokingStrings.historyEmptyHowCraving)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Text(verbatim: SmokingStrings.historyEmptyHowSmoked)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum HistoryDefaults {
    static let dayMs: Int64 = 24 * 60 * 60 * 1000
    static let hairline: CGFloat = 1
}
