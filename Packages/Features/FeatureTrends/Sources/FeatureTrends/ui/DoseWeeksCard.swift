// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// TrendsScreen.kt` (`DoseWeeksCard` at `:404-459`, `DoseWeekRow` at `:468-491`).
//
// Split out of `TrendsScreen.swift` into its own file so the screen stays under the 500-line
// lint limit as the four cards land; the time-of-day and overlay cards keep their own files'
// shape, and this one follows it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The dose-ratio card: one bar per week, and that week's measurement averages beneath it
/// (`TrendsScreen.kt:404-459`).
///
/// The chart's axis is a percentage, so the averages are written out rather than drawn — a
/// systolic reading laid on it would be measured against a scale it has nothing to do with. The
/// share sentence travels with every week, because it is the one number on this screen whose
/// meaning is not obvious from its unit: the denominator is the doses that were written down.
struct DoseWeeksCard: View {
    let weeks: [DoseWeek]
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // The mapping itself lives in `doseWeeksChartModelOf`, where it is unit-tested; nil means
        // no week logged a dose, which the analysis makes unreachable today but which is answered
        // here rather than assumed away.
        if let model = doseWeeksChartModelOf(
            weeks: weeks,
            weekLabel: { epochDay in
                LocalDateTime(date: LocalDate(epochDay: epochDay), minuteOfDay: 0)
                    .formatted(pattern: Self.axisDatePattern)
            },
            // A tick is a whole percentage, and the caption above the chart already says what it
            // is a share of, so the axis carries the number alone.
            axisLabel: { MetricDisplay.write(converted: Double($0), decimals: doseWeeksPercentDecimals) }
        ) {
            // The chart is announced as one line: what it plots and the span it covers. The weeks
            // themselves are the rows below, which are already the accessible presentation of the
            // same numbers — repeating them here would put a year range's 53 weeks into one
            // semantics node and then announce every one of them a second time. Read the span off
            // the drawn weeks rather than off the analysis, so what is spoken is the span that was
            // drawn.
            let chartDescription = TrendsStrings.doseWeeksChartDescription(
                model.weeks.first?.label ?? "",
                model.weeks.last?.label ?? ""
            )

            SalusCard(contentPadding: SalusSpacing.lg) {
                Text(verbatim: TrendsStrings.doseWeeksTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer().frame(height: SalusSpacing.xs)
                Text(verbatim: TrendsStrings.doseWeeksSubtitle)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Spacer().frame(height: SalusSpacing.md)
                SalusBarChart(
                    model: model.chart,
                    contentDescription: chartDescription
                )
                Spacer().frame(height: SalusSpacing.md)
                VStack(spacing: SalusSpacing.sm) {
                    ForEach(model.weeks, id: \.label) { week in
                        DoseWeekRow(week: week, glucoseUnit: glucoseUnit)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// `AXIS_DATE_PATTERN` (`TrendsScreen.kt:1118`) — the caption under each bar.
    private static let axisDatePattern = "d MMM"
}

/// `PERCENT_DECIMALS` (`TrendsScreen.kt:1115`) — a whole percentage needs no decimals. A file-level
/// constant rather than a `static let` on the card so the `@Sendable` axis closure can read it.
private let doseWeeksPercentDecimals = 0

/// One week under the chart: the share sentence, and the averages of the same week beneath it
/// (`TrendsScreen.kt:468-491`).
///
/// The share is never written as a bare percentage. It is the one number on this screen whose
/// meaning is not obvious from its unit, so the sentence that names what it measures travels
/// with it everywhere it is shown.
private struct DoseWeekRow: View {
    let week: DoseWeekBar
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: TrendsStrings.doseWeeksWeekRatio(
                week.label,
                TrendsStrings.doseWeeksTakenRatio(week.takenPercent)
            ))
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            // A week nobody measured says nothing beyond its share, and an absent average is left
            // absent rather than written as a dash the reader has to interpret.
            if let averages = averagesText {
                Spacer().frame(height: SalusSpacing.xs)
                Text(verbatim: averages)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// This week's averages, written out, or `nil` when it holds neither (`TrendsScreen.kt:500-512`).
    ///
    /// The numbers arrive canonical — the analysis averages glucose in mg/dL whatever the reader
    /// chose — so this is where they become the numbers on screen, through the one conversion
    /// `MetricDisplay` owns.
    private var averagesText: String? {
        let parts = [
            week.systolicAverage.map { averageLabel(type: .bloodPressure, stored: $0) },
            week.glucoseAverage.map { averageLabel(type: .bloodGlucose, stored: $0) }
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// One metric's weekly mean: its name, the value in the reader's unit, and that unit
    /// (`TrendsScreen.kt:514-527`).
    private func averageLabel(type: VitalType, stored: Double) -> String {
        TrendsStrings.doseWeeksAverage(
            type.metricLabel,
            MetricDisplay.format(type: type, stored: stored, glucoseUnit: glucoseUnit),
            type.unitLabel(glucoseUnit)
        )
    }
}
