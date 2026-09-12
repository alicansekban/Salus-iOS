// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsScreen.kt:250-346` — the chart card and the highest/average/lowest row under it.
//
// Its own file rather than more of `VitalsListSections.swift`, because Kotlin can keep six private
// composables in one 462-line file and Swift cannot: a `View` used from another file is internal
// here, and `VitalsListSections.swift` is already the list's shape plus its sections.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The chart and everything that frames it: the latest reading as the card's header, the range
/// filter as the chart's own control, and the line itself (`VitalsScreen.kt:250-314`).
///
/// The range chips are chips rather than a second segment control on purpose — the type selector
/// above already owns that shape, and two identical-looking rows of tabs read as one repeated
/// control instead of two different questions.
struct VitalsChartCard: View {
    let state: VitalsUiState
    let onEvent: (VitalsEvent) -> Void

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick the shell publishes (`RootView+Locale.swift`).
    @Environment(\.locale) private var locale

    var body: some View {
        let latest = state.latestValue(state.selectedType, locale: locale)
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    SalusMetricTile(
                        overline: VitalsStrings.latestLabel,
                        value: latest ?? VitalsStrings.valueNone,
                        // No value means no unit to hang on it; the em dash stands alone
                        // (`VitalsScreen.kt:272-273`).
                        unit: latest.map { _ in
                            state.selectedType.vitalsUnitLabel(glucoseUnit: state.glucoseUnit)
                        },
                        large: true
                    )
                    if let newest = state.entries.first {
                        // `Text(newest.measuredAtLine(locale))` (`VitalsScreen.kt:276-282`), drawn
                        // as the `SalusStatusChip` spec §4.3 asks for: the same line, in the chip
                        // the M15 header carries.
                        SalusStatusChip(label: newest.measuredAtLine(locale: locale))
                    }
                }

                rangeChips

                if let chart = state.chart {
                    SalusLineChart(
                        model: chart,
                        lineColor: theme.extendedColors.vitals.accent,
                        // The latest-value summary doubles as the chart's spoken description
                        // (`VitalsScreen.kt:308-309`).
                        contentDescription: chartDescription(latest: latest)
                    )
                    .frame(height: VitalsChartCardDefaults.chartHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Trailing, so it reads as the chart's control rather than a second header. A flow layout
    /// because at a large font scale four chips no longer fit on one line
    /// (`VitalsScreen.kt:285-299`).
    private var rangeChips: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(ChartRange.allCases, id: \.self) { range in
                SalusChoiceChip(
                    label: range.vitalsLabel,
                    isSelected: state.selectedRange == range,
                    action: { onEvent(.rangeSelected(range)) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// `chartDescription` (`VitalsScreen.kt:348-362`) — the spoken form of the latest reading: the
    /// printed value with the unit spelled after it.
    private func chartDescription(latest: String?) -> String {
        let spoken = latest.map {
            "\($0) \(state.selectedType.vitalsUnitLabel(glucoseUnit: state.glucoseUnit))"
        } ?? VitalsStrings.valueNone
        return VitalsStrings.kpiChip(state.selectedType.vitalsKpiLabel, spoken)
    }
}

/// The highest / average / lowest of exactly what the chart draws (`VitalsScreen.kt:316-346`).
struct VitalsStatsRow: View {
    let state: VitalsUiState
    let stats: MetricStats

    /// The in-app language pick the shell publishes (`RootView+Locale.swift`).
    @Environment(\.locale) private var locale

    var body: some View {
        let unit = state.selectedType.vitalsUnitLabel(glucoseUnit: state.glucoseUnit)
        SalusCard {
            HStack(alignment: .top, spacing: SalusSpacing.md) {
                SalusMetricTile(
                    overline: VitalsStrings.metricMax,
                    value: state.formatMetric(stats.max, locale: locale),
                    unit: unit
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                SalusMetricTile(
                    overline: VitalsStrings.metricAvg,
                    value: state.formatMetric(stats.average, locale: locale),
                    unit: unit
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                SalusMetricTile(
                    overline: VitalsStrings.metricMin,
                    value: state.formatMetric(stats.min, locale: locale),
                    unit: unit
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Component dimensions, not design tokens — the one place this screen names a point size
/// (`VitalsScreen.kt:371`).
enum VitalsChartCardDefaults {
    static let chartHeight: CGFloat = 220
}
