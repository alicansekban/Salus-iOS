// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// ReduceContent.kt` (branch `feature/m17-smoking-cessation`).
//
// The REDUCE body of the main screen (design screen `04`): today's ring with the large "+1", the
// last seven days, the week in units and money, the greyed timeline preview and "Bırakmaya hazırım".
// A scrolling parent supplies the padding; this is only the column of cards. The savings-goal and
// insights cards sit after the weekly card; plan Task 15 adds them, with the slots they need.
//
// Over the limit is information, not an alarm (review R1/R2): the ring stays in the accent, the
// excess is a neutral lap and a neutral "+n" chip, and no part of this file names a red or a pink.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `clearAndSetSemantics { contentDescription }` → `.accessibilityElement(children: .ignore)` + a label.
//   `semantics(mergeDescendants = true)`          → `.accessibilityElement(children: .combine)`.
//   `TextStyle.SHORT` weekday names               → `SalusWeekdaySymbols.shortMondayFirst(locale:)`
//                           indexed by `LocalDate.mondayBasedWeekdayIndex`: no `Calendar` here.
//   `Icons.Outlined.*`                            → SF Symbols, named in ``ReduceSymbols``.
//   `SalusIconButton`-less "+1" semantics         → the button's label is overridden with
//                           "1 adet ekle"; VoiceOver's activate is the button's own action.

import SalusDesignSystem
import SalusModel
import SalusSmoking
import SalusUI
import SwiftUI

/// The SF Symbols the REDUCE cards use, named once.
private enum ReduceSymbols {
    static let plus = "plus"
    static let ready = "flag"
    static let week = "banknote"
    static let chevron = "chevron.right"
    static let stage = "clock"
}

private enum ReduceDefaults {
    static let permille: Float = 1000
    /// How many stages the greyed card previews.
    static let timelinePreviewStages = 3
    /// Tall enough for seven labelled columns to read, the height every card chart is given.
    static let chartHeight: CGFloat = 200
    /// How far the ring's figures may shrink before they truncate, so the ring survives large text.
    static let ringTextMinScale: CGFloat = 0.5
}

struct ReduceContent: View {
    let reduce: ReduceSnapshot
    let writing: Bool
    let onEvent: (SmokingMainEvent) -> Void

    var body: some View {
        let view = reduce.toView()
        VStack(spacing: SalusSpacing.md) {
            ReduceHero(view: view, enabled: !writing, onEvent: onEvent)
            WeekChartCard(view: view)
            WeekSummaryCard(view: view, currencyCode: reduce.plan.currencyCode)
            TimelinePreviewCard(
                stageIds: reduce.stagesPreview.prefix(ReduceDefaults.timelinePreviewStages).map(\.stageId),
                onTap: { onEvent(.timelinePreviewTapped) }
            )
            SalusButton(
                SmokingStrings.reduceReady,
                variant: .outlined,
                systemImage: ReduceSymbols.ready,
                enabled: !writing
            ) { onEvent(.readyToQuit) }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hero

private struct ReduceHero: View {
    let view: ReduceView
    let enabled: Bool
    let onEvent: (SmokingMainEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking

        SalusCard(tone: .elevated) {
            VStack(spacing: SalusSpacing.md) {
                if view.tone == .over {
                    // The excess is information, not an alarm (review R2): a neutral chip, no new colour.
                    SalusStatusChip(label: SmokingStrings.reduceOverChip(view.overBy), status: .neutral)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: SmokingStrings.reduceOverChipCd(view.overBy)))
                }
                ring(accent: accent.accent)
                ToneCopy(view: view)
                PlusOneButton(enabled: enabled) { onEvent(.plusOne) }
                if view.showNoneToday {
                    noneTodayButton
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The ring and its numbers, spoken once, whole.
    private func ring(accent: Color) -> some View {
        ZStack {
            SalusProgressRing(
                progress: Float(view.progressPermille) / ReduceDefaults.permille,
                label: "",
                size: SalusProgressRingDefaults.heroSize,
                strokeWidth: SalusProgressRingDefaults.heroStrokeWidth,
                accent: accent,
                overflowPermille: view.overflowPermille
            )
            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(verbatim: String(view.todayUnits))
                        .font(SalusTypography.displaySmall.font)
                        .tracking(SalusTypography.displaySmall.tracking)
                        .foregroundStyle(accent)
                    Text(verbatim: SmokingStrings.reduceRingLimit(view.limit))
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                Text(verbatim: SmokingStrings.reduceOverline)
                    .font(SalusTypography.labelSmall.font)
                    .tracking(SalusTypography.labelSmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            .lineLimit(1)
            .minimumScaleFactor(ReduceDefaults.ringTextMinScale)
            // Inside the ring's inner edge, whatever the text size.
            .padding(SalusSpacing.xl)
        }
        .frame(width: SalusProgressRingDefaults.heroSize, height: SalusProgressRingDefaults.heroSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: SmokingStrings.reduceRingSemantics(view.todayUnits, view.limit)))
    }

    private var noneTodayButton: some View {
        Button { onEvent(.noneToday) } label: {
            Text(verbatim: SmokingStrings.reduceNoneToday)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .frame(minHeight: SalusTouchTarget.min)
                .padding(.horizontal, SalusSpacing.lg)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// The state copy under the ring: supportive in every state, and in the over-limit one it says so plainly.
private struct ToneCopy: View {
    let view: ReduceView

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.xs) {
            Text(verbatim: title)
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            Text(verbatim: copy)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            if let below = view.belowBaseline {
                Text(verbatim: SmokingStrings.reduceOverBaseline(below))
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch view.tone {
        case .empty: SmokingStrings.reduceEmptyTitle
        case .under: SmokingStrings.reduceUnderTitle
        case .at: SmokingStrings.reduceAtTitle
        case .over: SmokingStrings.reduceOverTitle
        }
    }

    private var copy: String {
        switch view.tone {
        case .empty: SmokingStrings.reduceEmptyBody(view.limit)
        case .under: SmokingStrings.reduceUnderBody(view.remaining)
        case .at: SmokingStrings.reduceAtBody
        case .over: SmokingStrings.reduceOverBody(view.overBy)
        }
    }
}

/// The large "+1", in every state (review R13). Spoken as what it does, not as a sign.
private struct PlusOneButton: View {
    let enabled: Bool
    let onAdd: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusButton(
            SmokingStrings.reducePlusOne,
            systemImage: ReduceSymbols.plus,
            accent: theme.extendedColors.smoking,
            enabled: enabled,
            action: onAdd
        )
        .accessibilityLabel(Text(verbatim: SmokingStrings.reducePlusOneCd))
    }
}

// MARK: - Week

private struct WeekChartCard: View {
    let view: ReduceView

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        let names = SalusWeekdaySymbols.shortMondayFirst(locale: locale)
        let labels = view.bars.map { bar in
            names.indices.contains(weekdayIndex(bar)) ? names[weekdayIndex(bar)] : ""
        }
        let dayValues = zip(labels, view.bars).map { label, bar in
            SmokingStrings.reduceChartDayValue(label, bar.units.map { String($0) } ?? SmokingStrings.reduceChartNoData)
        }
        // A day with no data keeps its slot but draws nothing: it is not a zero (contract 3.13).
        let model = BarChartUiModel(
            bars: zip(labels, view.bars).map { label, bar in
                BarEntry(label: label, value: Float(bar.units ?? 0))
            },
            yLabel: { String(Int($0)) },
            baseline: view.baseline.map {
                BarBaseline(value: Float($0), label: SmokingStrings.reduceChartBaseline($0))
            }
        )

        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                Text(verbatim: SmokingStrings.reduceChartTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                SalusBarChart(
                    model: model,
                    contentDescription: SmokingStrings.reduceChartCd(dayValues.joined(separator: ", ")),
                    accent: theme.extendedColors.smoking.accent
                )
                .frame(height: ReduceDefaults.chartHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weekdayIndex(_ bar: ReduceBar) -> Int {
        LocalDate(epochDay: Int(bar.epochDay)).mondayBasedWeekdayIndex
    }
}

private struct WeekSummaryCard: View {
    let view: ReduceView
    let currencyCode: String

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        SalusCard {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(
                    systemImage: ReduceSymbols.week,
                    accent: theme.extendedColors.smoking,
                    size: SalusIconBadgeDefaults.small,
                    iconSize: SalusIconBadgeDefaults.smallIconSize
                )
                Text(verbatim: text)
                    .font(SalusTypography.titleSmall.font)
                    .tracking(SalusTypography.titleSmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var text: String {
        let money = formatMoney(
            minor: view.weekSavedMinor,
            currencyCode: currencyCode,
            locale: locale,
            showFraction: false
        )
        // A vape's weekly card is money only (contract 8.12): its "unit" is a session, so a unit
        // reduction would read as a claim the numbers cannot back.
        if let reduction = view.weekReductionUnits, reduction > 0 || view.weekSavedMinor > 0 {
            return SmokingStrings.reduceWeekFull(reduction, money)
        }
        if view.weekReductionUnits == nil, view.weekSavedMinor > 0 {
            return SmokingStrings.reduceWeekMoney(money)
        }
        return SmokingStrings.reduceWeekNone
    }
}

// MARK: - Timeline preview

/// "Bıraktığında seni bekleyenler": the first catalog stages, quiet, as a promise of what quitting
/// starts. Quiet means neutral text colours, not a faded opacity: a faded label would fall under AA.
private struct TimelinePreviewCard: View {
    let stageIds: [String]
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(onTap: onTap) {
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                HStack {
                    Text(verbatim: SmokingStrings.reduceTimelineTitle)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: ReduceSymbols.chevron)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .accessibilityHidden(true)
                }
                Text(verbatim: SmokingStrings.reduceTimelineBody)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                ForEach(stageIds, id: \.self) { stageId in
                    if let title = StageCopy.title(of: stageId) {
                        HStack(spacing: SalusSpacing.sm) {
                            Image(systemName: ReduceSymbols.stage)
                                .foregroundStyle(theme.colorScheme.outline)
                                .accessibilityHidden(true)
                            Text(verbatim: title)
                                .font(SalusTypography.bodySmall.font)
                                .tracking(SalusTypography.bodySmall.tracking)
                                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
