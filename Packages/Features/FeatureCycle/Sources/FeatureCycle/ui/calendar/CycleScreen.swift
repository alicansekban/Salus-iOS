// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleScreen.kt` in its M15 shape — the screen's own chrome, the overline and the
// today icon in the top bar, and the "BUGÜNÜN BELİRTİLERİ" chips. The sections it stacks live
// beside it: `CycleCalendarSections.swift` (month header, weekday strip, grid, legend),
// `CycleSummarySections.swift` (the analysis card) and `CycleReminderSections.swift` (the
// reminder card and its two popups).
//
// Material → SwiftUI:
//   `Column(verticalScroll(rememberScrollState()))` → `ScrollView` + `VStack`.
//   `CircularProgressIndicator`                     → `ProgressView()`.
//   `SalusTopBar.Pushed(overline:actions:)`        → the iOS nav bar, with `cycle_overline` as a
//                                                    content overline above the month header —
//                                                    the iOS convention that puts overlines in
//                                                    content (Profile's "HESAP", Home's "BUGÜN"),
//                                                    because a pushed nav bar has no overline slot —
//                                                    and `cycle_today_cd` as a `.primaryAction`
//                                                    ToolbarItem that jumps the grid to today.
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

/// The stateless calendar (`CycleScreen.kt:92-170`).
struct CycleScreen: View {
    let state: CycleUiState
    let onEvent: (CycleEvent) -> Void
    let onOpenDay: (Int) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        VStack(spacing: 0) {
            if state.isLoading {
                // `CycleScreen.kt:116-119`.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }

            disclaimer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        // A PUSHED screen, not a tab root (it opens on Home's stack and on More's), so it wears the
        // system navigation bar with its own inline title and keeps the back button — the shell's
        // root toolbar is for the five roots only (spec §2.2).
        .navigationTitle(Text(verbatim: CycleStrings.title))
        .toolbar {
            // `Icons.Outlined.Today` (`CycleScreen.kt:108-113`) — the "today" action jumps the grid
            // back to the month that contains today. `.primaryAction`, not `.topBarTrailing`
            // (spec §2.2): the trailing slot by its iOS spelling, and the placement is iOS-only.
            ToolbarItem(placement: .primaryAction) {
                SalusIconButton(
                    systemImage: "calendar",
                    accessibilityLabel: CycleStrings.today,
                    action: { onEvent(.todayClicked) }
                )
            }
        }
        // `ReminderDialogs(state:onEvent:)` (`CycleScreen.kt:159`).
        .cycleReminderDialogs(state: state, onEvent: onEvent)
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard — the shape
        // `AboutScreen` has carried since M8.
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The scrolling body, in the Kotlin order (`CycleScreen.kt:121-156`).
    private var content: some View {
        ScrollView {
            VStack(spacing: SalusSpacing.lg) {
                overline
                CycleMonthHeader(monthFirstEpochDay: state.monthFirstEpochDay, onEvent: onEvent)
                CycleWeekdayHeader()
                CycleCalendarGrid(cells: state.cells, onOpenDay: onOpenDay)
                CycleCalendarLegend()
                CycleTodaySymptomsSection(state: state, onSeeAll: seeAll)
                CycleSummaryCard(state: state)
                CycleReminderCard(state: state, onEvent: onEvent)
                periodButton
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    /// `SalusTopBar.Pushed`'s overline (`CycleScreen.kt:104-107`) rendered as a content line, the
    /// iOS convention of Profile's "HESAP" / Home's "BUGÜN" — a pushed nav bar has no overline
    /// slot, so the overline is spent in content above the month header.
    private var overline: some View {
        Text(verbatim: CycleStrings.overline)
            .font(SalusTypography.labelSmall.font)
            .tracking(SalusTypography.labelSmall.tracking)
            .foregroundStyle(theme.extendedColors.overline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `TodaySymptomsSection(state, onSeeAll = onOpenToday)` (`CycleScreen.kt:87`, `:204-239`):
    /// the "Tümünü Gör" row opens today's day editor, which is the iOS twin of Kotlin's
    /// `onOpenToday` (`CycleScreen.kt:88`).
    private var seeAll: () -> Void {
        { onOpenDay(state.todayEpochDay) }
    }

    /// `SalusButton(text = …, onClick = …, accent = cycle, modifier = fillMaxWidth())`
    /// (`CycleScreen.kt:137-155`). Never disabled: "start" and "end" are the two halves of one
    /// control, and whichever it is showing is always available.
    ///
    /// `fillsWidth: true` is the `Modifier.fillMaxWidth()` at `CycleScreen.kt:154`, and it is the
    /// whole width story: an outer `.frame(maxWidth: .infinity)` would only centre a content-width
    /// capsule, since the drawn pill has to be widened from inside the component.
    private var periodButton: some View {
        SalusButton(
            state.hasOpenPeriod ? CycleStrings.periodEnded : CycleStrings.periodStarted,
            size: .large,
            accent: theme.extendedColors.cycle
        ) {
            onEvent(state.hasOpenPeriod ? .endPeriodClicked : .startPeriodClicked)
        }
    }

    /// The medical disclaimer is pinned below the scroll area so it is always visible
    /// (`CycleScreen.kt:162-169`).
    private var disclaimer: some View {
        SalusDisclaimer(CycleStrings.disclaimer)
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.sm)
    }
}

/// What the user already logged for today, as read-only chips — a summary, not a picker: editing
/// happens in the day screen behind "Tümünü Gör", so nothing here is tappable
/// (`CycleScreen.kt:204-239`).
private struct CycleTodaySymptomsSection: View {
    let state: CycleUiState
    let onSeeAll: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            SalusSectionHeader(
                title: CycleStrings.todaySymptoms,
                contentPadding: .init(top: SalusSpacing.xs, leading: 0, bottom: SalusSpacing.xs, trailing: 0)
            ) {
                Button(CycleStrings.seeAll, action: onSeeAll)
                    .buttonStyle(.plain)
                    // `labelLarge` — the action label the twin applies inside its
                    // `SalusTouchTarget.min`-high frame (`SalusSectionHeader.kt:64,70`).
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(theme.colorScheme.primary)
            }
            if state.todaySymptoms.isEmpty {
                Text(verbatim: CycleStrings.noSymptomsToday)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            } else {
                ChipFlowLayout(spacing: SalusSpacing.sm) {
                    ForEach(state.todaySymptoms, id: \.self) { nameKey in
                        SalusStatusChip(
                            label: CycleStrings.symptomLabel(nameKey: nameKey),
                            status: .accent
                        )
                    }
                }
            }
        }
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
    /// so the two option rows are drawn, and one today symptom so the "BUGÜNÜN BELİRTİLERİ" chips
    /// are drawn.
    static let loaded = CycleUiState(
        isLoading: false,
        monthFirstEpochDay: firstEpochDay,
        cells: cells,
        hasOpenPeriod: false,
        cycleDayNumber: 17,
        daysUntilNextPeriod: 12,
        averageCycleLength: 29,
        confidence: .medium,
        todaySymptoms: ["cramps", "fatigue"],
        todayEpochDay: firstEpochDay + 16,
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
        todaySymptoms: [],
        todayEpochDay: firstEpochDay + 16,
        reminderEnabled: true,
        reminderHasUsablePrediction: false
    )
}

#Preview("Cycle calendar") {
    // `@PreviewParameter(SalusPaletteProvider::class)` fan-out (`CycleScreen.kt:430-444`): one
    // render per premium palette in both modes (the 8-palette rule).
    SalusPreviewPalettes {
        CycleScreen(state: PreviewData.loaded, onEvent: { _ in }, onOpenDay: { _ in })
    }
}

#Preview("Cycle calendar — loading") {
    CycleScreen(state: CycleUiState(), onEvent: { _ in }, onOpenDay: { _ in })
}

#Preview("Cycle calendar — overdue") {
    CycleScreen(state: PreviewData.overdue, onEvent: { _ in }, onOpenDay: { _ in })
}

#Preview("Cycle calendar — xxxLarge") {
    // One `.dynamicTypeSize(.xxxLarge)` per root screen (spec §7).
    CycleScreen(state: PreviewData.loaded, onEvent: { _ in }, onOpenDay: { _ in })
        .dynamicTypeSize(.xxxLarge)
}
