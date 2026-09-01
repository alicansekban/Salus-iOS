// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// TrendsScreen.kt`.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded:
//   `TopAppBar` + `navigationIcon` (back) → `.navigationTitle(_:)` + the stack's own back button
//     (see `AiSummaryScreen.swift:4-9` for the settled reasoning — `onBack` has no parameter
//     here, and `trends_back` stays in the catalog for Android parity).
//   `FilterChip` row (ranges) → `Picker("", selection:)` with `.pickerStyle(.segmented)`. Vitals
//     maps its `ChartRange` chips the same way, so the two range selectors stay one look.
//   `CircularProgressIndicator` → `ProgressView()`.
//   `SalusEmptyState` → the same component, with the SF Symbol twin of each Material icon.
//
// No `Scaffold` twin and no `NavigationStack`: the shell owns the one stack, its insets and the
// tab bar, and a feature never writes `.toolbar(…, for: .tabBar)` (`CLAUDE.md`).

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`TrendsScreen.kt:87-100`).
///
/// The module comes from the environment, exactly as `koinViewModel()` reaches Koin's graph — see
/// `TrendsModule.swift` for what the composition root injects.
public struct TrendsRoute: View {
    @Environment(\.trendsModule) private var module
    @State private var viewModel: TrendsViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                TrendsScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(TrendsStrings.title)
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeTrendsViewModel()
        }
    }
}

/// The stateless screen (`TrendsScreen.kt:104-164`).
struct TrendsScreen: View {
    let state: TrendsUiState
    let onEvent: (TrendsEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            RangeFilter(selected: state.range) { onEvent(.rangeSelected($0)) }

            // Only the first load gets the whole body: until it answers there is nothing on
            // screen worth keeping, and `data` still holds the locked default that an entitled
            // user must never see a frame of (`TrendsScreen.kt:140-145`). A range switch is the
            // one place a later load must not blank the screen — see the opacity below, which is
            // the reload dim Android applies (`TrendsScreen.kt:152-162`).
            if !state.hasLoaded, state.isLoading {
                bodySpacer
            } else {
                // Every load keeps the body it is replacing and dims it while the next window
                // is being read. Task 1 ships the empty `Ready` shell that draws no cards — the
                // four analyses arrive with later tasks.
                TrendsBody(state: state, onEvent: onEvent)
                    .opacity(state.isLoading ? TrendsScreen.reloadingAlpha : TrendsScreen.opaque)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
    }

    private var bodySpacer: some View {
        VStack {
            Spacer()
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `RELOADING_ALPHA` (`TrendsScreen.kt:1109`) — how far the previous body is dimmed while the
    /// next window is being read.
    private static let reloadingAlpha = 0.4

    /// `OPAQUE` (`TrendsScreen.kt:1112`) — nothing in flight, nothing dimmed.
    private static let opaque = 1.0
}

/// One body per `TrendsData` member (`TrendsScreen.kt:172-220`).
///
/// Task 1's `Ready` body is an empty scrolling column; the four cards land with their analyses
/// in later tasks, and the locked body is Android's `LockedCallout` until Task 6 fills it with
/// the sample-data backdrop.
struct TrendsBody: View {
    let state: TrendsUiState
    let onEvent: (TrendsEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        switch state.data {
        case .locked:
            LockedBody(onUpgrade: { onEvent(.upgradeClicked) })

        case .empty:
            SalusEmptyState(
                systemImage: "chart.line.uptrend.xyaxis",
                title: TrendsStrings.emptyTitle,
                message: TrendsStrings.emptyMessage,
                accent: theme.extendedColors.trends
            )

        case .failed:
            SalusEmptyState(
                systemImage: "exclamationmark.triangle",
                title: TrendsStrings.errorTitle,
                message: TrendsStrings.errorMessage,
                accent: theme.extendedColors.trends,
                actionLabel: TrendsStrings.errorAction,
                onAction: { onEvent(.retryClicked) }
            )

        case let .ready(ready):
            ReadyBody(state: state, ready: ready)
        }
    }
}

/// The scrollable column a `.ready` answer draws its cards into (`TrendsScreen.kt:234-250`).
///
/// Task 1 ships the empty shell — every analysis field is `nil`, so no card is built. Each later
/// task adds the card its own field feeds, exactly as Android's `TrendsCardStack` maps a `let`
/// per field (`TrendsScreen.kt:245-248`).
struct ReadyBody: View {
    let state: TrendsUiState
    let ready: TrendsReady

    var body: some View {
        ScrollView {
            VStack(spacing: SalusSpacing.md) {
                if let timeOfDay = ready.timeOfDay {
                    TimeOfDayCard(breakdown: timeOfDay, glucoseUnit: state.glucoseUnit)
                }
                if let overlay = ready.overlay {
                    MetricOverlayCard(overlay: overlay, glucoseUnit: state.glucoseUnit)
                }
                if let doseWeeks = ready.doseWeeks {
                    DoseWeeksCard(weeks: doseWeeks, glucoseUnit: state.glucoseUnit)
                }
                // Task 5 adds:   ready.summaries.map { MetricSummaryCard($0, unit: …) }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The time-of-day card: one metric's day, one column per bucket it was measured in
/// (`TrendsScreen.kt:264-326`).
///
/// `TimeOfDayBreakdown` carries plain numbers so that the analysis stays portable; resolving the
/// labels, converting to the reader's unit and handing the pair to `barChartModelOf` is the UI's
/// job, and this is the only place it happens.
///
/// The averages arrive in canonical mg/dL and the reader may have chosen mmol/L, so the bars, the
/// axis they are measured against and the spoken summary all take their numbers from one
/// conversion — and the unit is named once, next to the metric, rather than repeated on every
/// bar.
private struct TimeOfDayCard: View {
    let breakdown: TimeOfDayBreakdown
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme

    var body: some View {
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
            axisLabel: { MetricDisplay.write(converted: Double($0), decimals: decimals) }
        ) {
            // The chart itself is silent to VoiceOver, so the numbers are spoken here instead —
            // read off the bars rather than off the breakdown, so what is described is exactly
            // what is drawn. Buckets with no measurement produced no bar and are simply not
            // mentioned: an unmeasured evening is not a reading of zero.
            let spokenParts = model.bars.map { bar in
                TrendsStrings.timeOfDayPartSummary(bar.label, bar.valueText(decimals: decimals))
            }

            SalusCard(contentPadding: SalusSpacing.lg) {
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

/// The multi-metric overlay card: several metrics on one shared, unit-less axis
/// (`TrendsScreen.kt:330-390`).
///
/// The analysis normalizes every series onto its own 0...1 span and carries the real numbers
/// alongside, because the two belong together: this chart shows no numbers at all (a value on it
/// could not belong to any of the series), so the legend below is the only place a line is
/// attributed to a metric *and* a real range.
///
/// The subtitle names which average a point is, because "weekly average" and "daily average" are
/// different claims about the same line (`Overlay.kt` — `bucket` travels with the overlay for
/// exactly this reason).
private struct MetricOverlayCard: View {
    let overlay: MetricOverlay
    let glucoseUnit: GlucoseUnit

    @Environment(\.salusTheme) private var theme

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

            SalusCard(contentPadding: SalusSpacing.lg) {
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
        let minText = MetricDisplay.format(
            type: item.type,
            stored: item.min,
            glucoseUnit: glucoseUnit
        )
        let maxText = MetricDisplay.format(
            type: item.type,
            stored: item.max,
            glucoseUnit: glucoseUnit
        )
        return TrendsStrings.overlayLegendEntry(
            item.type.metricLabel,
            minText,
            maxText,
            item.type.unitLabel(glucoseUnit)
        )
    }

    /// A colour swatch has to stay small — bigger than the marker on the line and it dominates
    /// the row instead of keying it.
    private static let swatchSize: CGFloat = 10
}

extension OverlayBucket {
    /// The card's subtitle: the sentence that has to say which average a point is (`TrendsScreen.kt`).
    fileprivate var subtitle: String {
        switch self {
        case .daily: TrendsStrings.overlaySubtitle
        case .weekly: TrendsStrings.overlaySubtitleWeekly
        }
    }
}

extension SeriesRole {
    /// The colour the legend swatch is drawn in, the same mapping the chart uses so a swatch can
    /// never drift away from the line it stands for (`SeriesRole.chartColor()`).
    fileprivate func swatchColor(_ scheme: SalusColorScheme) -> Color {
        switch self {
        case .primary: scheme.primary
        case .secondary: scheme.tertiary
        case .tertiary: scheme.secondary
        }
    }
}

/// A bar's value, written the way the metric is normally written (`TrendsScreen.kt:717-726`).
///
/// The bar already holds a converted number — `barChartModelOf` applied the conversion when it
/// built the chart — so this only writes it out. Converting here as well would apply the glucose
/// factor twice.
extension BarEntry {
    fileprivate func valueText(decimals: Int) -> String {
        // A second value only ever comes from a systolic/diastolic pair, which is written as one
        // reading rather than as two numbers — and never in a unit the reader can change.
        guard let secondaryValue else {
            return MetricDisplay.write(converted: Double(value), decimals: decimals)
        }
        return TrendsStrings.valueBloodPressure(Int(value.rounded()), Int(secondaryValue.rounded()))
    }
}

extension DayPart {
    /// `DayPart.labelRes()` (`TrendsScreen.kt:889-894`).
    fileprivate var label: String {
        switch self {
        case .morning: TrendsStrings.dayPartMorning
        case .midday: TrendsStrings.dayPartMidday
        case .evening: TrendsStrings.dayPartEvening
        case .night: TrendsStrings.dayPartNight
        }
    }
}

extension VitalType {
    /// `VitalType.metricLabelRes()` (`TrendsScreen.kt:896-902`).
    var metricLabel: String {
        switch self {
        case .bloodPressure: TrendsStrings.metricBloodPressure
        case .bloodGlucose: TrendsStrings.metricGlucose
        // Never picked by the time-of-day analysis: when you step on the scale says nothing about
        // your weight. Mapped anyway so the switch stays exhaustive without an else.
        case .weight: TrendsStrings.metricWeight
        }
    }

    /// `VitalType.unitLabelRes(glucoseUnit)` (`TrendsScreen.kt:905-912`) — glucose is the one
    /// metric whose unit the user picks; the other two have exactly one.
    func unitLabel(_ glucoseUnit: GlucoseUnit) -> String {
        switch self {
        case .bloodPressure: TrendsStrings.unitBloodPressure

        case .bloodGlucose:
            switch glucoseUnit {
            case .mgDl: TrendsStrings.unitGlucose
            case .mmolL: TrendsStrings.unitGlucoseMmol
            }

        case .weight: TrendsStrings.unitWeight
        }
    }
}

/// The free user's whole screen: the paywall callout card (`TrendsScreen.kt:842-871`).
///
/// Task 6 replaces this plain callout with the real sample-data stack behind a blur and scrim;
/// until then the locked body is the one card this screen has to sell.
struct LockedBody: View {
    let onUpgrade: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack {
            Spacer()
            SalusCard(contentPadding: SalusSpacing.lg) {
                Text(verbatim: TrendsStrings.lockedTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer().frame(height: SalusSpacing.sm)
                Text(verbatim: TrendsStrings.lockedMessage)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Spacer().frame(height: SalusSpacing.lg)
                SalusPillButton(text: TrendsStrings.lockedAction, action: onUpgrade)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SalusSpacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The range-selector segmented control (`TrendsScreen.kt:729-750`, Android's
/// `TrendsRangeFilter`).
private struct RangeFilter: View {
    let selected: TrendsRange
    let onSelect: (TrendsRange) -> Void

    var body: some View {
        Picker("", selection: Binding(
            get: { selected },
            set: { onSelect($0) }
        )) {
            Text(verbatim: TrendsStrings.rangeMonth).tag(TrendsRange.month)
            Text(verbatim: TrendsStrings.rangeQuarter).tag(TrendsRange.quarter)
            Text(verbatim: TrendsStrings.rangeHalfYear).tag(TrendsRange.halfYear)
            Text(verbatim: TrendsStrings.rangeYear).tag(TrendsRange.year)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}
