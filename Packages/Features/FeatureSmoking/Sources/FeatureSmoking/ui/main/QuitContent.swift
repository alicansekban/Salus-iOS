// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// QuitContent.kt`.
//
// The QUIT body of the main screen: the live counter, the four metrics, the next stage and the two
// premium cards. A scrolling parent supplies the padding; this is only the column of cards.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   ViewModel `liveNowMs` + `runClock`   → `TimelineView(LiveCounterSchedule)`: the view is handed
//                           the instant it is drawn for, a second apart in the first hour after the
//                           last smoke and a minute apart after it (`SmokingMainTime.swift`).
//   `clearAndSetSemantics`               → `.accessibilityElement(children: .ignore)` + a label.
//   `semantics(mergeDescendants = true)` → `.accessibilityElement(children: .combine)`.
//   `Icons.Outlined.*`                   → SF Symbols, named in ``QuitSymbols``.

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// Where the counters get their instant. ``live`` is the screen; ``frozen`` is a preview or a
/// snapshot test, where a moving clock would make the picture depend on when it was taken.
enum CounterClock: Equatable {
    case live
    case frozen(atMs: Int64)
}

/// The SF Symbols the QUIT cards use, named once.
private enum QuitSymbols {
    static let notSmoked = "nosign"
    static let saved = "banknote"
    static let cravings = "shield"
    static let regained = "hourglass"
    static let chevron = "chevron.right"
}

struct QuitContent: View {
    let quit: QuitSnapshot
    /// What the premium cards read: the entitlement and the active goal.
    let state: SmokingMainUiState
    let counterClock: CounterClock
    let onEvent: (SmokingMainEvent) -> Void

    var body: some View {
        switch counterClock {
        case .live:
            // The schedule is fixed per view value, so a new last smoke (a slip, a restart) has to
            // be a new identity; a plain minute recompute keeps the same one and the timeline runs on.
            TimelineView(LiveCounterSchedule(lastSmokeAtMs: quit.lastSmokeAtMs)) { context in
                QuitCards(quit: quit, state: state, nowMs: context.date.epochMilliseconds, onEvent: onEvent)
            }
            .id("\(quit.attemptId)-\(quit.lastSmokeAtMs)")

        case let .frozen(atMs):
            QuitCards(quit: quit, state: state, nowMs: atMs, onEvent: onEvent)
        }
    }
}

/// The cards for one instant. Stateless: the instant is a parameter, so a preview draws any hour.
struct QuitCards: View {
    let quit: QuitSnapshot
    let state: SmokingMainUiState
    let nowMs: Int64
    let onEvent: (SmokingMainEvent) -> Void

    /// A snapshot is computed at "now", so it is a floor for the instant the counters are drawn
    /// for: a timeline entry from before a fresh snapshot must not make the counters step back.
    private var liveNowMs: Int64 {
        max(nowMs, quit.computedAtMs)
    }

    var body: some View {
        let elapsedMs = quit.liveElapsedMs(at: liveNowMs)
        VStack(spacing: SalusSpacing.md) {
            QuitHero(
                elapsedMs: elapsedMs,
                sinceLastSmokeMs: quit.liveSinceLastSmokeMs(at: liveNowMs),
                slipCount: quit.slipCount
            )
            QuitMetrics(quit: quit, firstHour: elapsedMs < QuitDefaults.firstHourMs)
            if let stage = quit.nextStage {
                NextStageCard(
                    stage: stage,
                    remainingMs: max(0, stage.remainingMs - (liveNowMs - quit.computedAtMs)),
                    onTap: { onEvent(.stageTapped) }
                )
            }
            PremiumCards(state: state, currencyCode: quit.plan.currencyCode, onEvent: onEvent)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum QuitDefaults {
    static let firstHourMs: Int64 = 60 * 60 * 1000
    static let msPerMinute: Int64 = 60 * 1000
    static let permillePerPercent = 10
    static let permille: Float = 1000
    /// How far a metric value may shrink before it truncates, so "₺315.000" fits a narrow tile.
    static let metricMinScale: CGFloat = 0.6
}

// MARK: - Hero

private struct QuitHero: View {
    let elapsedMs: Int64
    let sinceLastSmokeMs: Int64
    let slipCount: Int

    @Environment(\.salusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let (headline, detail) = heroText(timeLabelOf(elapsedMs))
        let spoken = SmokingStrings.heroSemantics([headline, detail].compactMap(\.self).joined(separator: " "))

        SalusCard(tone: .elevated) {
            VStack(spacing: SalusSpacing.xs) {
                Text(verbatim: headline)
                    .font(SalusTypography.displaySmall.font)
                    .tracking(SalusTypography.displaySmall.tracking)
                    .foregroundStyle(theme.extendedColors.smoking.accent)
                if let detail {
                    Text(verbatim: detail)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                }
                Text(verbatim: SmokingStrings.heroOverline)
                    .font(SalusTypography.labelSmall.font)
                    .tracking(SalusTypography.labelSmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            // Digits roll instead of cutting, unless the person asked for less motion.
            .contentTransition(.numericText())
            .animation(
                reduceMotion ? nil : .easeInOut(duration: SalusMotion.stateChangeDurationSeconds),
                value: headline + (detail ?? "")
            )
            // The counter is spoken once, whole: its parts change every second in the first hour
            // and a screen reader should not be handed them one by one.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))

            if slipCount > 0 {
                slipLine
            }
        }
    }

    private var slipLine: some View {
        let since = SmokingStrings.sinceLast(sinceText(timeLabelOf(sinceLastSmokeMs)))
        let slips = SmokingStrings.slips(slipCount)
        return HStack(spacing: SalusSpacing.sm) {
            Text(verbatim: since)
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            SalusStatusChip(label: slips, status: .neutral)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SalusSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(since), \(slips)"))
    }

    /// The large line and the smaller one under it; the first hour is one line of minutes and seconds.
    private func heroText(_ label: TimeLabel) -> (String, String?) {
        switch label {
        case let .days(days, hours, minutes):
            (SmokingStrings.heroDays(Int(days)), SmokingStrings.heroHoursMinutes(hours, minutes))
        case let .hours(hours, minutes):
            (SmokingStrings.heroHours(hours), SmokingStrings.heroMinutes(minutes))
        case let .minSec(minutes, seconds):
            (SmokingStrings.heroMinSec(minutes, seconds), nil)
        }
    }

    private func sinceText(_ label: TimeLabel) -> String {
        switch label {
        case let .days(days, _, _): SmokingStrings.heroDays(Int(days))
        case let .hours(hours, _): SmokingStrings.heroHours(hours)
        case let .minSec(minutes, seconds): SmokingStrings.heroMinSec(minutes, seconds)
        }
    }
}

// MARK: - Metrics

private struct QuitMetrics: View {
    let quit: QuitSnapshot
    let firstHour: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        let product = quit.plan.productType
        // R8: a metric chip is only ever a snapshot value. "Today" is one; a vape's "unit" is a day,
        // so its today figure would read as a second copy of the headline number.
        let todayChip: String? = quit.unitsNotSmokedToday > 0 && product != .vape
            ? SmokingStrings.metricToday(quit.unitsNotSmokedToday)
            : nil

        VStack(spacing: SalusSpacing.md) {
            row(
                MetricCard(
                    systemImage: QuitSymbols.notSmoked,
                    value: String(quit.unitsNotSmoked),
                    label: notSmokedLabel(product),
                    chip: todayChip,
                    caption: firstHour ? SmokingStrings.captionNotSmoked : nil
                ),
                MetricCard(
                    systemImage: QuitSymbols.saved,
                    value: formatMoney(
                        minor: quit.savedMinor,
                        currencyCode: quit.plan.currencyCode,
                        locale: locale,
                        showFraction: false
                    ),
                    label: SmokingStrings.metricSaved,
                    caption: firstHour ? SmokingStrings.captionSaved : nil
                )
            )
            row(
                MetricCard(
                    systemImage: QuitSymbols.cravings,
                    value: String(quit.cravingsBeaten),
                    label: SmokingStrings.metricCravings,
                    caption: firstHour ? SmokingStrings.captionCravings : nil
                ),
                MetricCard(
                    systemImage: QuitSymbols.regained,
                    // Contract §3.8: nil for a vape, whose "unit" is a day, not a cigarette.
                    value: quit.timeRegainedMinutes.map(regainedText) ?? SmokingStrings.metricNone,
                    label: SmokingStrings.metricRegained,
                    caption: firstHour ? SmokingStrings.captionRegained : nil
                )
            )
        }
    }

    /// Two tiles of one height, whichever is taller.
    private func row(_ leading: MetricCard, _ trailing: MetricCard) -> some View {
        HStack(spacing: SalusSpacing.md) {
            leading.frame(maxWidth: .infinity, maxHeight: .infinity)
            trailing.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func notSmokedLabel(_ product: ProductType) -> String {
        switch product {
        case .cigarette, .rolled: SmokingStrings.metricNotSmoked
        case .heated: SmokingStrings.metricNotSmokedHeated
        case .vape: SmokingStrings.metricNotSmokedVape
        }
    }

    private func regainedText(_ minutes: Int64) -> String {
        switch timeLabelOf(minutes * QuitDefaults.msPerMinute) {
        case let .days(days, hours, _): SmokingStrings.regainedDaysHours(days, hours)
        case let .hours(hours, minutes): SmokingStrings.regainedHoursMinutes(hours, minutes)
        case let .minSec(minutes, _): SmokingStrings.regainedMinutes(minutes)
        }
    }
}

private struct MetricCard: View {
    let systemImage: String
    let value: String
    let label: String
    var chip: String?
    var caption: String?

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(
            contentPadding: EdgeInsets(
                top: SalusSpacing.md,
                leading: SalusSpacing.md,
                bottom: SalusSpacing.md,
                trailing: SalusSpacing.md
            )
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SalusIconBadge(
                        systemImage: systemImage,
                        accent: theme.extendedColors.smoking,
                        size: SalusIconBadgeDefaults.small,
                        iconSize: SalusIconBadgeDefaults.smallIconSize
                    )
                    Spacer(minLength: SalusSpacing.sm)
                    if let chip {
                        SalusStatusChip(label: chip, status: .neutral)
                    }
                }
                Text(verbatim: value)
                    .font(SalusTypography.headlineMedium.font)
                    .tracking(SalusTypography.headlineMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(QuitDefaults.metricMinScale)
                Text(verbatim: label)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                if let caption {
                    Text(verbatim: caption)
                        .font(SalusTypography.labelMedium.font)
                        .tracking(SalusTypography.labelMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // One reading per tile ("840 içilmeyen sigara"), not a stop for the icon, the chip, the
        // number and the caption.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Next stage

private struct NextStageCard: View {
    let stage: StageProgress
    let remainingMs: Int64
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        let percent = stage.permille / QuitDefaults.permillePerPercent
        let ringLabel = SmokingStrings.stageCardPercent(percent)

        SalusCard(onTap: onTap) {
            HStack(spacing: SalusSpacing.md) {
                SalusProgressRing(
                    progress: Float(stage.permille) / QuitDefaults.permille,
                    label: ringLabel,
                    accent: accent.accent
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: ringLabel))
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: SmokingStrings.stageCardOverline)
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    if let title = StageCopy.title(of: stage.stageId) {
                        Text(verbatim: title)
                            .font(SalusTypography.titleMedium.font)
                            .tracking(SalusTypography.titleMedium.tracking)
                            .foregroundStyle(theme.colorScheme.onSurface)
                    }
                    if let statement = StageCopy.statement(of: stage.stageId) {
                        Text(verbatim: statement)
                            .font(SalusTypography.bodySmall.font)
                            .tracking(SalusTypography.bodySmall.tracking)
                            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    }
                    Text(verbatim: remainingText)
                        .font(SalusTypography.labelMedium.font)
                        .tracking(SalusTypography.labelMedium.tracking)
                        .foregroundStyle(accent.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: QuitSymbols.chevron)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Shared with the health timeline's rows (``StageRemaining``).
    private var remainingText: String {
        StageRemaining(remainingMs: remainingMs).text
    }
}
