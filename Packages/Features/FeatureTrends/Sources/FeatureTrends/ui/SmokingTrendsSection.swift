// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// SmokingCards.kt` (iOS-M17 Task 18; design screen `08-trends`).
//
// Material -> SwiftUI: `SalusSectionHeader` and `SalusCard` are the shared components, the bars are
// `SalusProgressBar(accent:)` (the Android `AccentBar`), the heatmap is `SalusHeatmap` and the
// reduction curve `SalusLineChart` -- no hand-rolled copy of any of them. The accent is
// `extendedColors.smoking`, one amber for every card (R1: no red or pink).

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The premium "Sigara" section: trigger shares, the craving-time heatmap, the reduction curve and
/// the attempt comparison.
///
/// It sits inside the card stack and so inside the screen's whole-body premium lock -- there is no
/// paywall of its own. Below seven days of entries every card is replaced by one empty state that
/// names that threshold, because a share computed from three days would read as a finding.
///
/// Each card is absent rather than empty when its own figure has nothing to draw: no trigger was ever
/// chosen, no attempt exists (a REDUCE-only plan), or the plan is not REDUCE.
struct SmokingTrendsSection: View {
    let smoking: SmokingInsights

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            // The stack that holds this already pads the screen's sides, so the header only keeps
            // its vertical breathing room.
            SalusSectionHeader(
                title: TrendsStrings.smokingOverline,
                contentPadding: EdgeInsets(
                    top: SalusSpacing.sm,
                    leading: 0,
                    bottom: SalusSpacing.sm,
                    trailing: 0
                )
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if smoking.hasEnoughData {
                if !smoking.triggers.isEmpty {
                    SmokingTriggersCard(triggers: smoking.triggers)
                }
                if let busiest = smoking.busiestBand {
                    SmokingHeatmapCard(
                        heatmap: smoking.heatmap,
                        busiestBand: busiest,
                        busiestBandPermille: smoking.busiestBandPermille
                    )
                }
                SmokingReductionCard(weekly: smoking.reductionWeekly)
                if !smoking.attemptDurations.isEmpty {
                    SmokingAttemptsCard(durations: smoking.attemptDurations)
                }
            } else {
                SalusCard {
                    SalusEmptyState(
                        systemImage: "smoke",
                        title: TrendsStrings.smokingEmptyTitle,
                        message: TrendsStrings.smokingEmptyMessage,
                        accent: theme.extendedColors.smoking
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A card's title and its one-line subtitle, written once so four cards cannot drift into four
/// heading styles (Android `CardHeader`).
private struct SmokingCardHeader: View {
    let title: String
    let subtitle: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            Text(verbatim: title)
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            Text(verbatim: subtitle)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, SalusSpacing.md)
    }
}

/// One labelled row: a name, a trailing value and a bar filled in the smoking accent. Spoken as one
/// line, because the bar is a picture and the value a fragment.
private struct SmokingBarRow: View {
    let name: String
    let value: String
    let progress: Double
    let spoken: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: name)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer(minLength: SalusSpacing.sm)
                Text(verbatim: value)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            SalusProgressBar(progress: progress, accent: theme.extendedColors.smoking.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken))
    }
}

private struct SmokingTriggersCard: View {
    let triggers: [TriggerShare]

    var body: some View {
        SalusCard {
            SmokingCardHeader(
                title: TrendsStrings.smokingTriggersTitle,
                subtitle: TrendsStrings.smokingTriggersSubtitle
            )
            VStack(spacing: SalusSpacing.md) {
                ForEach(triggerBarsOf(triggers), id: \.trigger) { bar in
                    let name = TrendsStrings.smokingTrigger(bar.trigger)
                    let percent = percentOf(bar.permille)
                    SmokingBarRow(
                        name: name,
                        value: TrendsStrings.smokingPercent(percent),
                        progress: bar.progress,
                        spoken: TrendsStrings.smokingTriggerDescription(name, percent)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SmokingHeatmapCard: View {
    let heatmap: [[Int]]
    let busiestBand: HourBand
    let busiestBandPermille: Int

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            SmokingCardHeader(
                title: TrendsStrings.smokingHeatmapTitle,
                subtitle: TrendsStrings.smokingHeatmapSubtitle
            )
            SalusHeatmap(
                rows: HourBand.allCases.map { TrendsStrings.smokingBandShort($0) },
                columns: (0 ..< heatmapColumns).map { TrendsStrings.smokingWeekdayShort($0) },
                values: heatmapValuesOf(heatmap),
                accent: theme.extendedColors.smoking,
                // Every cell speaks its weekday, its hour range and its count: a shade is not
                // something a screen reader can read, and the labels around the grid are silent.
                cellDescription: { row, column, value in
                    TrendsStrings.smokingHeatmapCell(
                        TrendsStrings.smokingWeekday(column),
                        TrendsStrings.smokingBandRange(HourBand.allCases[row]),
                        TrendsStrings.smokingHeatmapCount(value)
                    )
                }
            )
            Text(verbatim: TrendsStrings.smokingHeatmapCaption(
                TrendsStrings.smokingBandRange(busiestBand),
                percentOf(busiestBandPermille)
            ))
            .font(SalusTypography.bodySmall.font)
            .tracking(SalusTypography.bodySmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, SalusSpacing.md)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SmokingReductionCard: View {
    let weekly: [Int64?]

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // The calculator only fills this for a REDUCE plan, so a QUIT user simply has no card.
        if let model = reductionChartModelOf(weekly: weekly, weekLabel: { TrendsStrings.smokingReductionWeek($0) }) {
            card(model)
        }
    }

    private func card(_ model: ChartUiModel) -> some View {
        SalusCard {
            SmokingCardHeader(
                title: TrendsStrings.smokingReductionTitle,
                subtitle: TrendsStrings.smokingReductionSubtitle
            )
            SalusLineChart(
                model: model,
                lineColor: theme.extendedColors.smoking.accent,
                contentDescription: TrendsStrings.smokingReductionDescription(
                    first: Int(model.points.first?.y ?? 0),
                    last: Int(model.points.last?.y ?? 0)
                )
            )
            .frame(height: SmokingTrendsDefaults.curveHeight)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SmokingAttemptsCard: View {
    let durations: [AttemptDuration]

    var body: some View {
        SalusCard {
            SmokingCardHeader(
                title: TrendsStrings.smokingAttemptsTitle,
                subtitle: TrendsStrings.smokingAttemptsSubtitle
            )
            VStack(spacing: SalusSpacing.md) {
                ForEach(attemptBarsOf(durations), id: \.ordinal) { bar in
                    let label = TrendsStrings.smokingAttemptLabel(bar.ordinal)
                    let duration = TrendsStrings.smokingAttemptDays(bar.days)
                    SmokingBarRow(
                        name: label,
                        value: duration,
                        progress: bar.progress,
                        spoken: TrendsStrings.smokingAttemptDescription(label, duration)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The section's own dimensions -- component constants, not design tokens.
enum SmokingTrendsDefaults {
    /// The reduction curve's height; matches the other charts' fixed 200 pt card charts.
    static let curveHeight: CGFloat = 200
}

// MARK: - Preview

#Preview("Smoking section, quit") {
    SalusPreviewPalettes {
        SmokingTrendsSection(smoking: previewSmokingQuit())
            .padding(SalusSpacing.lg)
    }
}

#Preview("Smoking section, reduce") {
    SalusPreviewPalettes {
        SmokingTrendsSection(smoking: previewSmokingReduce())
            .padding(SalusSpacing.lg)
    }
}

#Preview("Smoking section, not enough data") {
    SalusPreviewPalettes {
        SmokingTrendsSection(smoking: previewSmokingNotEnoughData())
            .padding(SalusSpacing.lg)
    }
}

#Preview("Smoking section, accessibility3") {
    ScrollView {
        SmokingTrendsSection(smoking: previewSmokingReduce())
            .padding(SalusSpacing.lg)
    }
    .dynamicTypeSize(.accessibility3)
}

#Preview("Trends with smoking, quit") {
    SalusPreviewPalettes {
        TrendsScreen(
            state: TrendsUiState(
                isLoading: false,
                hasLoaded: true,
                data: .ready(TrendsReady.withSmoking(sampleTrendsReady(), previewSmokingQuit()))
            ),
            onEvent: { _ in }
        )
        .frame(height: SmokingTrendsDefaults.previewScreenHeight)
    }
}

extension SmokingTrendsDefaults {
    /// A screen-sized frame for the palette fan-out, which stacks its panels in one scroll view.
    static let previewScreenHeight: CGFloat = 900
}

extension TrendsReady {
    /// `ready` with a smoking section, for the previews.
    fileprivate static func withSmoking(_ ready: TrendsReady, _ smoking: SmokingInsights) -> TrendsReady {
        var copy = ready
        copy.smoking = smoking
        return copy
    }
}
