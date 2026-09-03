// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// TrendsScreen.kt` (`MetricSummaryCard` at `:543-566`, `MetricSummaryRowBody` at `:574-630`).
//
// Split out of `TrendsScreen.swift` into its own file so the screen stays under the 500-line
// lint limit as the four cards land; the time-of-day, overlay and dose-weeks cards keep their
// own files' shape, and this one follows it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The summary card: what each metric amounted to, and how its average moved against the window
/// before this one (`TrendsScreen.kt:543-566`).
///
/// Nothing on this card is coloured, ranked or called good or bad, and that is the design rather
/// than an omission. A rise in one metric and a fall in another can both be what a person's doctor
/// asked for, and an app that painted one of them red would be giving medical advice through a
/// palette. The card writes a direction and a magnitude, and stops there.
///
/// Two absences are kept apart for the same reason. A metric with no earlier readings is told as
/// having nothing to compare against rather than as having held still, and a move too small to
/// write at this card's precision is told as nearly the same rather than as a rise of nothing.
/// Which sentence a row gets is decided in `metricSummaryRowsOf`, where it is unit-tested.
struct MetricSummaryCard: View {
    let summaries: MetricSummaries
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let rows = metricSummaryRowsOf(summaries: summaries)

        SalusCard(contentPadding: SalusSpacing.lg) {
            Text(verbatim: TrendsStrings.summaryTitle)
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            Spacer().frame(height: SalusSpacing.xs)
            Text(verbatim: TrendsStrings.summarySubtitle)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            Spacer().frame(height: SalusSpacing.md)
            VStack(spacing: SalusSpacing.md) {
                ForEach(rows, id: \.type) { row in
                    MetricSummaryRowBody(row: row, glucoseUnit: glucoseUnit)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// One metric's block: its name and direction on one line, its numbers under them
/// (`TrendsScreen.kt:574-630`).
///
/// The direction arrow carries no description of its own — the label beside it is the same fact in
/// words, and describing both would have a screen reader say it twice.
private struct MetricSummaryRowBody: View {
    let row: MetricSummaryRow
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick (`RootView+Locale.swift`). Android reads the same pick off
    /// `Locale.getDefault()`; iOS's `Locale.current` never moves, so it is carried here instead.
    @Environment(\.locale) private var locale

    var body: some View {
        let unit = row.type.unitLabel(glucoseUnit)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: row.type.metricLabel)
                    .font(SalusTypography.titleSmall.font)
                    .tracking(SalusTypography.titleSmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer()
                HStack(spacing: SalusSpacing.xs) {
                    Image(systemName: row.trend.symbol)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    Text(verbatim: row.trend.label)
                        .font(SalusTypography.labelLarge.font)
                        .tracking(SalusTypography.labelLarge.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(height: SalusSpacing.xs)
            Text(verbatim: TrendsStrings.summaryStats(
                row.count,
                MetricDisplay.format(type: row.type, stored: row.average, glucoseUnit: glucoseUnit, locale: locale),
                unit
            ))
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            Text(verbatim: TrendsStrings.summaryMinMax(
                MetricDisplay.format(type: row.type, stored: row.min, glucoseUnit: glucoseUnit, locale: locale),
                MetricDisplay.format(type: row.type, stored: row.max, glucoseUnit: glucoseUnit, locale: locale),
                unit
            ))
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            Text(verbatim: row.change.sentence(locale: locale))
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The one sentence a row's change is written as (`TrendsScreen.kt:640-662`).
///
/// The magnitude arrives unsigned and already rounded to `changeDecimals`, so this only writes it
/// out: the direction is carried by the wording, which is what keeps a minus sign from being read
/// twice. It is a percentage rather than a measurement, so it goes through `MetricDisplay.write`
/// and never through the metric conversion.
extension SummaryChange {
    fileprivate func sentence(locale: Locale) -> String {
        switch self {
        case .noPreviousRecords:
            return TrendsStrings.summaryChangeNoPrevious

        case .notComputable:
            return TrendsStrings.summaryChangeNotComputable

        case let .moved(direction, magnitudePercent):
            let percent = MetricDisplay.write(
                converted: magnitudePercent,
                decimals: changeDecimals,
                locale: locale
            )
            switch direction {
            case .up: return TrendsStrings.summaryChangeUp(percent)
            case .down: return TrendsStrings.summaryChangeDown(percent)
            case .flat: return TrendsStrings.summaryChangeFlat
            }
        }
    }
}

extension Trend {
    /// The arrow a direction is drawn with (`TrendsScreen.kt:670-674`).
    fileprivate var symbol: String {
        switch self {
        case .rising: "arrow.up.right"
        case .falling: "arrow.down.right"
        case .stable: "arrow.right"
        }
    }

    /// What a direction is called (`TrendsScreen.kt:683-687`).
    ///
    /// `.stable` is also the answer for a series too short to tell a direction from day-to-day
    /// variation, so its label says only that no direction stands out — a wording that stays true
    /// for three readings as well as for three hundred.
    fileprivate var label: String {
        switch self {
        case .rising: TrendsStrings.summaryDirectionRising
        case .falling: TrendsStrings.summaryDirectionFalling
        case .stable: TrendsStrings.summaryDirectionStable
        }
    }
}
