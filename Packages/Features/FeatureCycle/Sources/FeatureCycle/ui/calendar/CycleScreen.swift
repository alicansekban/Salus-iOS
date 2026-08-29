// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleScreen.kt:92-155` — the screen's own shape. The sections it stacks live beside
// it: `CycleCalendarSections.swift` (month header, weekday strip, grid, legend),
// `CycleSummarySections.swift` (the prediction card) and `CycleReminderSections.swift` (the
// reminder card and its two popups).
//
// Material → SwiftUI:
//   `Column(verticalScroll(rememberScrollState()))` → `ScrollView` + `VStack`.
//   `CircularProgressIndicator`                     → `ProgressView()`.
//   `Modifier.weight(1f)` on the scroll area        → nothing: a `ScrollView` between a header and
//                                                     a pinned footer already takes the space the
//                                                     two leave it.
//
// The disclaimer sits **outside** the `ScrollView`, below it, exactly where Kotlin puts it: it is
// the one line on this screen that must not be scrollable away, because everything above it is a
// prediction.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The stateless calendar (`CycleScreen.kt:92-155`).
struct CycleScreen: View {
    let state: CycleUiState
    let onEvent: (CycleEvent) -> Void
    let onOpenDay: (Int) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        VStack(spacing: 0) {
            SalusScreenHeader(title: CycleStrings.title)

            if state.isLoading {
                // `CycleScreen.kt:102-104`.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }

            disclaimer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        // `ReminderDialogs(state:onEvent:)` (`CycleScreen.kt:142`).
        .cycleReminderDialogs(state: state, onEvent: onEvent)
    }

    /// The scrolling body, in the Kotlin order (`CycleScreen.kt:106-139`).
    private var content: some View {
        ScrollView {
            VStack(spacing: SalusSpacing.lg) {
                CycleMonthHeader(monthFirstEpochDay: state.monthFirstEpochDay, onEvent: onEvent)
                CycleWeekdayHeader()
                CycleCalendarGrid(cells: state.cells, onOpenDay: onOpenDay)
                CycleCalendarLegend()
                CycleSummaryCard(state: state)
                CycleReminderCard(state: state, onEvent: onEvent)
                periodButton
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    /// `SalusPillButton(text = …, onClick = …, accent = cycle, modifier = fillMaxWidth())`
    /// (`CycleScreen.kt:119-138`). Never disabled: "start" and "end" are the two halves of one
    /// control, and whichever it is showing is always available.
    ///
    /// `fillsWidth: true` is the `Modifier.fillMaxWidth()` at `CycleScreen.kt:137`, and it is the
    /// whole width story: an outer `.frame(maxWidth: .infinity)` would only centre a content-width
    /// capsule, since the drawn pill has to be widened from inside the component.
    private var periodButton: some View {
        SalusPillButton(
            text: state.hasOpenPeriod ? CycleStrings.periodEnded : CycleStrings.periodStarted,
            accent: theme.extendedColors.cycle,
            fillsWidth: true
        ) {
            onEvent(state.hasOpenPeriod ? .endPeriodClicked : .startPeriodClicked)
        }
    }

    /// The medical disclaimer is pinned below the scroll area so it is always visible
    /// (`CycleScreen.kt:144-153`).
    private var disclaimer: some View {
        Text(CycleStrings.disclaimer)
            .font(SalusTypography.bodySmall.font)
            .tracking(SalusTypography.bodySmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.sm)
    }
}

// MARK: - Previews

/// The fixtures the previews share (`CycleScreen.kt:549-581`, which needs only one preview because
/// Compose renders light and dark from a single `@PreviewLightDark`).
///
/// A namespace rather than loose file-scope constants: everything preview-only is then one
/// `private enum` a reader can skip, and nothing here can be mistaken for screen state.
private enum PreviewData {
    /// `val firstEpochDay = 20_666` (`CycleScreen.kt:554`) — a Monday-aligned sample month.
    static let firstEpochDay = 20666

    /// The 35 cells of `CycleScreen.kt:559-570`, marker for marker.
    static let cells: [CycleDayCell] = (0 ..< 35).map { index in
        CycleDayCell(
            epochDay: firstEpochDay + index,
            dayOfMonth: index + 1,
            isInMonth: index < 31,
            isToday: index == 16,
            isPeriod: (0 ... 4).contains(index),
            isPredictedPeriod: (28 ... 30).contains(index),
            isFertile: (11 ... 16).contains(index),
            isOvulation: index == 14
        )
    }

    /// `CycleScreen.kt:556-576`, plus the reminder rows Kotlin's preview leaves at their defaults
    /// so the two option rows are drawn.
    static let loaded = CycleUiState(
        isLoading: false,
        monthFirstEpochDay: firstEpochDay,
        cells: cells,
        hasOpenPeriod: false,
        cycleDayNumber: 17,
        daysUntilNextPeriod: 12,
        averageCycleLength: 29,
        confidence: .medium,
        reminderEnabled: true,
        reminderHasUsablePrediction: true
    )

    /// No Kotlin twin: the overdue arm of `CycleScreen.kt:341-357`, with a period already open, an
    /// irregular history and a reminder that cannot fire yet.
    static let overdue = CycleUiState(
        isLoading: false,
        monthFirstEpochDay: firstEpochDay,
        cells: cells,
        hasOpenPeriod: true,
        cycleDayNumber: 34,
        daysUntilNextPeriod: -3,
        averageCycleLength: 31,
        confidence: .low,
        isIrregular: true,
        reminderEnabled: true,
        reminderHasUsablePrediction: false
    )
}

#Preview("Cycle calendar") {
    CycleScreen(state: PreviewData.loaded, onEvent: { _ in }, onOpenDay: { _ in })
}

#Preview("Cycle calendar — loading") {
    CycleScreen(state: CycleUiState(), onEvent: { _ in }, onOpenDay: { _ in })
}

#Preview("Cycle calendar — overdue") {
    CycleScreen(state: PreviewData.overdue, onEvent: { _ in }, onOpenDay: { _ in })
}
