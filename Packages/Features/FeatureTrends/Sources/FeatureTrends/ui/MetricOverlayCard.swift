// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// TrendsScreen.kt` (`MetricOverlayCard` at `:180-222`, `OverlayLegendItem.legendLabel` at
// `:503-512`).
//
// Split out of `TrendsScreen.swift` into its own file so the screen stays under the 500-line
// lint limit; the time-of-day, dose-weeks and summary cards keep their own files' shape, and
// this one follows it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The multi-metric overlay card: several metrics on one shared, unit-less axis
/// (`TrendsScreen.kt:180-222`).
///
/// The analysis normalizes every series onto its own 0...1 span and carries the real numbers
/// alongside, because the two belong together: this chart shows no numbers at all (a value on it
/// could not belong to any of the series), so the legend below is the only place a line is
/// attributed to a metric *and* a real range.
///
/// The subtitle names which average a point is, because "weekly average" and "daily average" are
/// different claims about the same line (`Overlay.kt` — `bucket` travels with the overlay for
/// exactly this reason).
struct MetricOverlayCard: View {
    let overlay: MetricOverlay
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick (`RootView+Locale.swift`); the legend's ranges are written in it.
    @Environment(\.locale) private var locale

    var body: some View {
        // The mapping from series to a chart is tested on its own (`OverlayChartModelTests`);
        // nil here means fewer than two series remain, which the analysis makes unreachable
        // today but which is answered rather than assumed away.
        if let model = overlayChartModelOf(
            overlay: overlay,
            xLabel: { String($0) }
        ) {
            // The chart is silent to VoiceOver, so the legend is spoken as one summary — each
            // line named with the metric and its real range, exactly as it is drawn.
            let spokenLegend = model.legend.map { legendLine(for: $0) }

            SalusCard {
                Text(verbatim: TrendsStrings.overlayTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer().frame(height: SalusSpacing.xs)
                Text(verbatim: overlay.bucket.subtitle)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Spacer().frame(height: SalusSpacing.md)
                SalusMultiSeriesChart(
                    model: model.chart,
                    contentDescription: TrendsStrings.overlayChartDescription(
                        spokenLegend.joined(separator: ", ")
                    )
                )
                Spacer().frame(height: SalusSpacing.md)
                ForEach(model.legend, id: \.type) { item in
                    legendRow(for: item)
                        .foregroundStyle(item.role.swatchColor(theme.colorScheme))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// One legend row: the line's colour swatch, then the metric name and its real range with the
    /// unit (`trends_overlay_legend_entry`).
    private func legendRow(for item: OverlayLegendItem) -> some View {
        HStack(spacing: SalusSpacing.sm) {
            Circle()
                .fill(item.role.swatchColor(theme.colorScheme))
                .frame(width: Self.swatchSize, height: Self.swatchSize)
            Text(verbatim: legendLine(for: item))
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// The line's text: `%1$s · %2$s–%3$s %4$s` — metric, then the real range it covered, with
    /// its unit. The min and max are written in the reader's unit (`MetricDisplay`), the way
    /// every other number on this screen is.
    private func legendLine(for item: OverlayLegendItem) -> String {
        func written(_ stored: Double) -> String {
            MetricDisplay.format(type: item.type, stored: stored, glucoseUnit: glucoseUnit, locale: locale)
        }
        return TrendsStrings.overlayLegendEntry(
            item.type.metricLabel,
            written(item.min),
            written(item.max),
            item.type.unitLabel(glucoseUnit)
        )
    }

    /// A colour swatch has to stay small — bigger than the marker on the line and it dominates
    /// the row instead of keying it.
    private static let swatchSize: CGFloat = 10
}

extension OverlayBucket {
    /// The card's subtitle: the sentence that has to say which average a point is (`TrendsScreen.kt`).
    var subtitle: String {
        switch self {
        case .daily: TrendsStrings.overlaySubtitle
        case .weekly: TrendsStrings.overlaySubtitleWeekly
        }
    }
}

extension SeriesRole {
    /// The colour the legend swatch is drawn in, the same mapping the chart uses so a swatch can
    /// never drift away from the line it stands for (`SeriesRole.chartColor()`).
    func swatchColor(_ scheme: SalusColorScheme) -> Color {
        switch self {
        case .primary: scheme.primary
        case .secondary: scheme.tertiary
        case .tertiary: scheme.secondary
        }
    }
}
