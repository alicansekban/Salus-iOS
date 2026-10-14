// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/timeline/
// SmokingTimelineScreen.kt`.
//
// The health timeline: a header, one card per catalog stage and the fixed disclaimer. A pushed
// screen, so the shell has already reserved the insets and the system bar names it. In REDUCE the
// rows are the same but greyed, with the switch button pinned below; the detail and quit-date
// sheets hang off the state.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `SalusTopBar.Pushed(title, onBack)`   → `.navigationTitle` + inline mode, the back button the
//                           system's (spec §2.2).
//   `LazyColumn` + `animateScrollToItem`   → `ScrollView` + `LazyVStack` + `ScrollViewReader.scrollTo`.
//   `graphicsLayer { scaleX/Y }` pulse     → `.scaleEffect`.
//   `Settings.Global.ANIMATOR_DURATION_SCALE == 0` → `accessibilityReduceMotion`: no animated
//                           scroll and no pulse.

import SalusCommon
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The stateless screen: `state` + `onEvent` only, so it previews without a ViewModel. `clock` is
/// the app's (a fixed one in a preview), for the quit-date sheet's "not in the future" check.
struct SmokingTimelineScreen: View {
    let state: SmokingTimelineUiState
    let onEvent: (SmokingTimelineEvent) -> Void
    let clock: any SalusClock

    @Environment(\.salusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The card that is swelling right now, and by how much.
    @State private var pulsingId: String?
    @State private var pulseScale: CGFloat = 1

    private var greyed: Bool {
        state.mode == .reduce
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: SalusSpacing.md) {
                        TimelineHeader(state: state)
                        ForEach(state.rows, id: \.stageId) { row in
                            StageRowCard(row: row, greyed: greyed) { onEvent(.stageTapped(row.stageId)) }
                                .scaleEffect(row.stageId == pulsingId ? pulseScale : 1)
                                .id(row.stageId)
                        }
                        SalusDisclaimer(SmokingStrings.timelineDisclaimer)
                            .padding(.vertical, SalusSpacing.md)
                    }
                    .padding(.horizontal, SalusSpacing.lg)
                    .padding(.vertical, SalusSpacing.md)
                }
                // Scrolls to the stage a link named, pulses its card once, and reports it spent so
                // a rotation or a later snapshot does not do it again. With reduced motion the
                // scroll is a jump and there is no pulse. The key is "the row is there", not the
                // rows: a snapshot every minute must not restart a pulse in flight.
                .task(id: HighlightKey(stageId: state.highlightStageId, rowsShown: !state.rows.isEmpty)) {
                    await showHighlight(proxy)
                }
            }

            if greyed {
                SalusButton(
                    SmokingStrings.timelineSwitch,
                    accent: theme.extendedColors.smoking
                ) { onEvent(.switchTapped) }
                    .padding(.horizontal, SalusSpacing.lg)
                    .padding(.vertical, SalusSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .stageDetailSheet(row: state.detail) { onEvent(.detailDismissed) }
        .quitDateSheet(
            isPresented: Binding(
                get: { state.quitDateSheet },
                set: { presented in
                    if !presented {
                        onEvent(.quitDateDismissed)
                    }
                }
            ),
            initialMs: state.initialQuitAtMs,
            clock: clock,
            onConfirm: { onEvent(.quitDateConfirmed($0)) }
        )
        .navigationTitle(Text(verbatim: SmokingStrings.timelineTitle))
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func showHighlight(_ proxy: ScrollViewProxy) async {
        guard let id = state.highlightStageId, state.rows.contains(where: { $0.stageId == id }) else { return }
        if reduceMotion {
            proxy.scrollTo(id, anchor: .center)
        } else {
            withAnimation(.easeInOut(duration: SalusMotion.stateChangeDurationSeconds)) {
                proxy.scrollTo(id, anchor: .center)
            }
            // Let the scroll land before the card swells.
            try? await Task.sleep(for: .seconds(SalusMotion.stateChangeDurationSeconds))
            pulsingId = id
            withAnimation(.easeOut(duration: SalusMotion.feedbackDurationSeconds)) {
                pulseScale = TimelineDefaults.pulseScale
            }
            try? await Task.sleep(for: .seconds(SalusMotion.feedbackDurationSeconds))
            withAnimation(.easeInOut(duration: SalusMotion.stateChangeDurationSeconds)) {
                pulseScale = 1
            }
            try? await Task.sleep(for: .seconds(SalusMotion.stateChangeDurationSeconds))
            pulsingId = nil
        }
        guard !Task.isCancelled else { return }
        onEvent(.highlightShown)
    }
}

/// Identity of the highlight work: it restarts when the named stage changes or when the rows first
/// arrive, and not on every snapshot.
private struct HighlightKey: Hashable {
    let stageId: String?
    let rowsShown: Bool
}

// MARK: - Header

private struct TimelineHeader: View {
    let state: SmokingTimelineUiState

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(tone: .elevated) {
            if state.mode == .reduce {
                Text(verbatim: SmokingStrings.timelineReduceTitle)
                    .font(SalusTypography.titleLarge.font)
                    .tracking(SalusTypography.titleLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: SalusSpacing.md) {
                    Text(verbatim: SmokingStrings.timelineOverline)
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    // Side by side while they fit, stacked at the large text sizes.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: SalusSpacing.xl) { figures }
                        VStack(alignment: .leading, spacing: SalusSpacing.md) { figures }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var figures: some View {
        HeaderFigure(
            label: SmokingStrings.timelineDoneLabel,
            value: SmokingStrings.timelineCount(state.doneCount, state.totalCount)
        )
        if let threshold = state.nextStageId.flatMap(StageCopy.threshold(of:)) {
            HeaderFigure(label: SmokingStrings.timelineNextLabel, value: threshold)
        }
    }
}

private struct HeaderFigure: View {
    let label: String
    let value: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            Text(verbatim: label)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            Text(verbatim: value)
                .font(SalusTypography.titleLarge.font)
                .tracking(SalusTypography.titleLarge.tracking)
                .foregroundStyle(theme.extendedColors.smoking.accent)
        }
        // One reading per figure ("TAMAMLANAN 4 / 10").
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rows

private struct StageRowCard: View {
    let row: StageRow
    let greyed: Bool
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        SalusCard(onTap: onTap) {
            HStack(alignment: .top, spacing: SalusSpacing.md) {
                StageIndicator(row: row, greyed: greyed)
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    HStack(alignment: .top, spacing: SalusSpacing.sm) {
                        if let title = StageCopy.title(of: row.stageId) {
                            Text(verbatim: title)
                                .font(SalusTypography.titleMedium.font)
                                .tracking(SalusTypography.titleMedium.tracking)
                                .foregroundStyle(greyed ? theme.colorScheme.onSurfaceVariant : theme.colorScheme
                                    .onSurface)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        SalusStatusChip(label: StageCopy.sourceLabel(of: row.source), status: .neutral)
                    }
                    if let statement = StageCopy.statement(of: row.stageId) {
                        Text(verbatim: statement)
                            .font(SalusTypography.bodySmall.font)
                            .tracking(SalusTypography.bodySmall.tracking)
                            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    }
                    if row.state == .inProgress, !greyed {
                        Text(verbatim: StageRemaining(remainingMs: row.remainingMs).text)
                            .font(SalusTypography.labelMedium.font)
                            .tracking(SalusTypography.labelMedium.tracking)
                            .foregroundStyle(accent.accent)
                        SalusProgressBar(progress: Double(row.progress), accent: accent.accent)
                    }
                    StageNotes(row: row)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The leading mark of a row: a check when done, a ring while it is being counted, a lock before.
/// All three sit in a ring-wide column so the cards' text lines up whatever the state, and each
/// says its state to a screen reader instead of leaving a bare glyph.
private struct StageIndicator: View {
    let row: StageRow
    let greyed: Bool

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        let spoken = row.state.label

        Group {
            if greyed || row.state == .pending {
                SalusIconBadge(systemImage: TimelineSymbols.locked, accent: neutral)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: spoken))
            } else if row.state == .done {
                SalusIconBadge(systemImage: TimelineSymbols.done, accent: accent)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: spoken))
            } else {
                let percent = SmokingStrings.stageCardPercent(row.permille / TimelineDefaults.permillePerPercent)
                SalusProgressRing(progress: row.progress, label: percent, accent: accent.accent)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "\(spoken), \(percent)"))
            }
        }
        .frame(width: SalusProgressRingDefaults.size)
    }

    /// A lock is not the feature's colour: it says "not yet", so it takes the quiet ground.
    private var neutral: FeatureAccent {
        FeatureAccent(
            accent: theme.colorScheme.onSurfaceVariant,
            onAccent: theme.colorScheme.surface,
            container: theme.colorScheme.surfaceContainerHigh,
            onContainer: theme.colorScheme.onSurface
        )
    }
}
