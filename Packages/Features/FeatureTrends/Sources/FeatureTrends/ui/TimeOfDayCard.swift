// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// TrendsScreen.kt` (`TimeOfDayCard` at `:118-169`, `BarEntry.valueText` at `:521-532`).
//
// Split out of `TrendsScreen.swift` into its own file so the screen stays under the 500-line
// lint limit; the overlay, dose-weeks and summary cards keep their own files' shape, and this
// one follows it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The time-of-day card: one metric's day, one column per bucket it was measured in
/// (`TrendsScreen.kt:118-169`).
///
/// `TimeOfDayBreakdown` carries plain numbers so that the analysis stays portable; resolving the
/// labels, converting to the reader's unit and handing the pair to `barChartModelOf` is the UI's
/// job, and this is the only place it happens.
///
/// The averages arrive in canonical mg/dL and the reader may have chosen mmol/L, so the bars, the
/// axis they are measured against and the spoken summary all take their numbers from one
/// conversion — and the unit is named once, next to the metric, rather than repeated on every
/// bar.
struct TimeOfDayCard: View {
    let breakdown: TimeOfDayBreakdown
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick (`RootView+Locale.swift`), not `Locale.current`, which on iOS
    /// stays on the device's language whatever the in-app setting says.
    @Environment(\.locale) private var locale

    var body: some View {
        // Bound here so the `@Sendable` axis closure captures the value and not the view.
        let locale = locale
        let type = breakdown.type
        let metricName = TrendsStrings.metricWithUnit(
            type.metricLabel,
            type.unitLabel(glucoseUnit)
        )
        let decimals = MetricDisplay.decimals(type: type, glucoseUnit: glucoseUnit)

        // The mapping itself lives in `barChartModelOf`, where it is unit-tested; nil means the
        // breakdown held nothing worth drawing, which the analysis makes unreachable today but
        // which is answered here rather than assumed away.
        if let model = barChartModelOf(
            breakdown: breakdown,
            partLabel: { $0.label },
            displayValue: { MetricDisplay.value(type: type, stored: $0, glucoseUnit: glucoseUnit) },
            // An axis tick is a number, not a sentence: no unit on it, and only as many
            // decimals as the metric is written with.
            axisLabel: { MetricDisplay.write(converted: Double($0), decimals: decimals, locale: locale) }
        ) {
            // The chart itself is silent to VoiceOver, so the numbers are spoken here instead —
            // read off the bars rather than off the breakdown, so what is described is exactly
            // what is drawn. Buckets with no measurement produced no bar and are simply not
            // mentioned: an unmeasured evening is not a reading of zero.
            let spokenParts = model.bars.map { bar in
                TrendsStrings.timeOfDayPartSummary(bar.label, bar.valueText(decimals: decimals, locale: locale))
            }

            SalusCard {
                Text(verbatim: TrendsStrings.timeOfDayTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer().frame(height: SalusSpacing.xs)
                Text(verbatim: metricName)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Spacer().frame(height: SalusSpacing.md)
                SalusBarChart(
                    model: model,
                    contentDescription: TrendsStrings.timeOfDayChartDescription(
                        metricName,
                        spokenParts.joined(separator: ", ")
                    )
                )
                .frame(height: TimeOfDayCard.chartHeight)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// `BarChartHeight` (`SalusBarChart.kt:156`) — tall enough for four labelled columns to be
    /// readable without dominating a card.
    private static let chartHeight: CGFloat = 200
}

/// A bar's value, written the way the metric is normally written (`TrendsScreen.kt:521-532`).
///
/// The bar already holds a converted number — `barChartModelOf` applied the conversion when it
/// built the chart — so this only writes it out. Converting here as well would apply the glucose
/// factor twice.
extension BarEntry {
    fileprivate func valueText(decimals: Int, locale: Locale) -> String {
        // A second value only ever comes from a systolic/diastolic pair, which is written as one
        // reading rather than as two numbers — and never in a unit the reader can change.
        guard let secondaryValue else {
            return MetricDisplay.write(converted: Double(value), decimals: decimals, locale: locale)
        }
        return TrendsStrings.valueBloodPressure(Int(value.rounded()), Int(secondaryValue.rounded()))
    }
}

extension DayPart {
    /// `DayPart.labelRes()` (`TrendsScreen.kt:889-894`).
    var label: String {
        switch self {
        case .morning: TrendsStrings.dayPartMorning
        case .midday: TrendsStrings.dayPartMidday
        case .evening: TrendsStrings.dayPartEvening
        case .night: TrendsStrings.dayPartNight
        }
    }
}
