// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleScreen.kt:157-329` — the month header, the weekday strip, the grid and its
// cells, and the legend.
//
// Split out of `CycleScreen.swift` the way `MedicationDetailSections.swift` was split out of its
// screen, and for the same reason: Kotlin keeps everything in one file because a
// `private @Composable` is invisible outside it, where Swift has no per-file privacy for a `View`
// another file draws. These are therefore internal types rather than private functions — nothing
// outside this package can name them, since the package exports the Route and nothing else.
//
// Material → SwiftUI, the table the four features before this one already list:
//   `Icons.AutoMirrored.Filled.KeyboardArrowLeft/Right` → the `chevron.left` / `chevron.right`
//                                                         SF Symbols, which mirror themselves in
//                                                         a right-to-left layout exactly as
//                                                         `AutoMirrored` does.
//   `IconButton`                                        → `Button` + `.buttonStyle(.plain)` with
//                                                         the 48-pt touch target spelled out,
//                                                         which is what `IconButton` reserves.
//   `contentDescription`                                → `.accessibilityLabel(_:)`.
//   `Modifier.weight(1f)`                               → `.frame(maxWidth: .infinity)`.
//   `Modifier.border(width:color:shape:)`               → `.overlay(Circle().strokeBorder(…))`,
//                                                         which like Compose's border draws
//                                                         *inside* the bounds rather than
//                                                         straddling them.
//   `DateTimeFormatter.ofPattern("LLLL yyyy", locale)`  → `LocalDate.formatted(pattern:locale:)`.
//
// ONE DIVERGENCE, the weekday strip (iOS-M6 divergence (f)). Kotlin walks `DayOfWeek.entries` and
// asks each for its `TextStyle.NARROW` display name, which is Monday-first by definition of the
// enum. Foundation has no `DayOfWeek`, so the narrow letters come from a `Calendar`, which is
// Sunday-first and has to be rotated. That read does not live here: it is
// `SalusUI`'s ``SalusWeekdaySymbols/narrowMondayFirst(locale:)``, the one place in the tree
// `CLAUDE.md`'s `LocalDate` rule sanctions a `Calendar` for a localized *symbol* — fixed Gregorian,
// the view's own locale, and never a `Date`. This file passes `@Environment(\.locale)` and draws
// what comes back.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Chevron, month title, chevron (`CycleScreen.kt:157-184`).
struct CycleMonthHeader: View {
    let monthFirstEpochDay: Int
    let onEvent: (CycleEvent) -> Void

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`CycleScreen.kt:159`).
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            chevron("chevron.left", label: CycleStrings.previousMonth) {
                onEvent(.previousMonthClicked)
            }
            // `titleLarge`'s tracking is 0.0, so no `.tracking(_:)` — `SalusTypography.swift`'s
            // rule 4.
            Text(verbatim: title)
                .font(SalusTypography.titleLarge.font)
                .foregroundStyle(theme.colorScheme.onSurface)
                .multilineTextAlignment(.center)
                // `Modifier.weight(1f)` (`CycleScreen.kt:175`).
                .frame(maxWidth: .infinity)
            chevron("chevron.right", label: CycleStrings.nextMonth) {
                onEvent(.nextMonthClicked)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// `java.time.LocalDate.ofEpochDay(…).format(monthFormatter)` (`CycleScreen.kt:172`).
    private var title: String {
        LocalDate(epochDay: monthFirstEpochDay).formatted(pattern: monthTitlePattern, locale: locale)
    }

    /// `IconButton { Icon(…, contentDescription = …) }` (`CycleScreen.kt:165-170`, `:177-182`).
    private func chevron(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.colorScheme.onSurface)
                // What `IconButton` reserves around its 24-dp icon, spelled out because a `.plain`
                // button draws nothing of its own.
                .frame(width: SalusTouchTarget.min, height: SalusTouchTarget.min)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The seven narrow weekday letters, Monday first (`CycleScreen.kt:186-203`).
struct CycleWeekdayHeader: View {
    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`CycleScreen.kt:188`), the locale the letters are
    /// named in.
    @Environment(\.locale) private var locale

    var body: some View {
        let labels = SalusWeekdaySymbols.narrowMondayFirst(locale: locale)
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                Text(verbatim: labels[index])
                    .font(SalusTypography.labelMedium.font)
                    .tracking(SalusTypography.labelMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    // `Modifier.weight(1f)` (`CycleScreen.kt:199`).
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The month grid, one row per week (`CycleScreen.kt:205-223`).
struct CycleCalendarGrid: View {
    let cells: [CycleDayCell]
    let onOpenDay: (Int) -> Void

    var body: some View {
        VStack(spacing: SalusSpacing.xs) {
            // `state.cells.chunked(DAYS_PER_WEEK)` (`CycleScreen.kt:208`). Foundation has no
            // `chunked`, so the weeks are the slices between every seventh index; the builder pads
            // the grid to whole weeks, so the last slice is full too.
            ForEach(weekStartIndices, id: \.self) { start in
                HStack(spacing: SalusSpacing.xs) {
                    ForEach(cells[start ..< min(start + LocalDate.daysPerWeek, cells.count)]) { cell in
                        CycleDayCellView(cell: cell) { onOpenDay(cell.epochDay) }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekStartIndices: [Int] {
        Array(stride(from: 0, to: cells.count, by: LocalDate.daysPerWeek))
    }
}

/// One day of the month (`CycleCalendarGrid.kt:100-190`).
///
/// Marker language (spec 4.14, `CycleCalendarGrid.kt:42-49`): a recorded period day is filled with
/// the cycle accent's **container**, a predicted one only wears a dashed ring of the same hue — a
/// prediction never looks like a record — the fertile window is a soft **primary** fill, ovulation
/// adds a dot and today wears a primary ring.
struct CycleDayCellView: View {
    let cell: CycleDayCell
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            // `Modifier.weight(1f).aspectRatio(1f)` (`CycleCalendarGrid.kt:160`): a square whose
            // side is the column width. `Color.clear` is what carries the aspect ratio, because a
            // `Text` would size the cell to its own glyphs instead.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .background(Circle().fill(backgroundColor))
                .overlay { predictedRing }
                .overlay { todayRing }
                .overlay { ovulationDot }
                .overlay { number }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // `clickable(enabled = cell.isInMonth)` (`CycleCalendarGrid.kt:165`).
        .disabled(!cell.isInMonth)
        // `semantics(mergeDescendants = true) { contentDescription = label }`
        // (`CycleCalendarGrid.kt:168`) — one element that reads the whole cell, with the tap
        // intact. `semantics`, not `clearAndSetSemantics`: the latter would take the click action
        // down with the label and leave the cell unusable under VoiceOver.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// `CycleCalendarGrid.kt:171-178`. Kotlin hides the number from the screen reader
    /// (`clearAndSetSemantics`) because it is already the first word of the merged label; here the
    /// merge above does that, so the number carries no label of its own.
    private var number: some View {
        Text(verbatim: String(cell.dayOfMonth))
            .font(SalusTypography.bodyMedium.font)
            .fontWeight(cell.isToday ? .semibold : .regular)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(textColor)
            .accessibilityHidden(true)
    }

    /// `CycleCalendarGrid.kt:108-113`.
    private var backgroundColor: Color {
        if !cell.isInMonth {
            return .clear
        }
        if cell.isPeriod {
            return theme.extendedColors.cycle.container
        }
        if cell.isFertile {
            return theme.colorScheme.primaryContainer
        }
        return .clear
    }

    /// `CycleCalendarGrid.kt:114-121`.
    private var textColor: Color {
        if !cell.isInMonth {
            return theme.colorScheme.onSurfaceVariant.opacity(outOfMonthTextAlpha)
        }
        if cell.isPeriod {
            return theme.extendedColors.cycle.onContainer
        }
        if cell.isFertile {
            return theme.colorScheme.onPrimaryContainer
        }
        return theme.colorScheme.onSurface
    }

    /// A prediction is drawn, never filled: the dashed ring is the whole marker, so a predicted
    /// day can never be mistaken for a day the user recorded (`CycleCalendarGrid.kt:125-140`).
    @ViewBuilder
    private var predictedRing: some View {
        if cell.isPredictedPeriod {
            Circle()
                .strokeBorder(
                    theme.extendedColors.cycle.accent,
                    style: StrokeStyle(lineWidth: predictedRingWidth, dash: [predictedDashLength, predictedDashLength])
                )
        }
    }

    /// `CycleCalendarGrid.kt:141-145` — `Modifier.border(width: TodayRingWidth, color: primary,
    /// shape = CircleShape)`.
    @ViewBuilder
    private var todayRing: some View {
        if cell.isToday {
            Circle().strokeBorder(theme.colorScheme.primary, lineWidth: todayRingWidth)
        }
    }

    /// The 4 dp primary ovulation dot, at the cell's bottom (`CycleCalendarGrid.kt:179-188`).
    @ViewBuilder
    private var ovulationDot: some View {
        if cell.isOvulation, cell.isInMonth {
            VStack {
                Spacer()
                Circle()
                    .fill(theme.colorScheme.primary)
                    .frame(width: ovulationDotSize, height: ovulationDotSize)
                    .padding(.bottom, SalusSpacing.xs)
            }
        }
    }

    /// A bare "14" tells a screen reader nothing: the colour is what carries the meaning here, so
    /// the markers are spelled out and replace the number entirely (`CycleCalendarGrid.kt:149-156`).
    private var accessibilityLabel: String {
        var parts = [String(cell.dayOfMonth)]
        if cell.isToday {
            parts.append(CycleStrings.a11yToday)
        }
        if cell.isPeriod {
            parts.append(CycleStrings.legendPeriod)
        }
        if cell.isPredictedPeriod {
            parts.append(CycleStrings.legendPredicted)
        }
        if cell.isFertile {
            parts.append(CycleStrings.legendFertile)
        }
        if cell.isOvulation {
            parts.append(CycleStrings.a11yOvulation)
        }
        return parts.joined(separator: ", ")
    }
}

/// What the three fills mean (`CycleCalendarGrid.kt:192-215`).
///
/// There is deliberately no ovulation entry: the ring/dot is a detail inside the fertile window,
/// and Kotlin's legend names the window rather than the day.
struct CycleCalendarLegend: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        // FlowRow, not Row, so three labels still share a line at a large system font scale
        // (`CycleCalendarGrid.kt:195-200` and `:196`'s note).
        let legendColors = [
            CycleStrings.legendPeriod: theme.extendedColors.cycle.container,
            CycleStrings.legendPredicted: theme.extendedColors.cycle.accent,
            CycleStrings.legendFertile: theme.colorScheme.primaryContainer
        ]
        ChipFlowLayout(spacing: SalusSpacing.lg) {
            ForEach(Array(legendColors.keys), id: \.self) { label in
                CycleLegendItem(
                    color: legendColors[label] ?? .clear,
                    label: label,
                    outlined: label == CycleStrings.legendPredicted
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A dot and its word (`CycleCalendarGrid.kt:217-242`); the predicted legend dot wears a ring to
/// mirror the predicted cell's ring (`outlined`).
struct CycleLegendItem: View {
    let color: Color
    let label: String
    var outlined = false

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.xs) {
            if outlined {
                Circle()
                    .strokeBorder(color, lineWidth: legendRingWidth)
                    .frame(width: legendDotSize, height: legendDotSize)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: legendDotSize, height: legendDotSize)
            }
            Text(verbatim: label)
                .font(SalusTypography.labelMedium.font)
                .tracking(SalusTypography.labelMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        }
    }
}

// MARK: - Component dimensions

// The values `CycleCalendarGrid.kt:244-251` keep beside the calendar, under the same names. They
// are Material component dimensions, not `design-tokens.md` tokens, which is why they live here
// rather than in `SalusDesignSystem`.
//
// `DAYS_PER_WEEK` (`CycleCalendarGrid.kt:244`) used to sit in this list; iOS-M7 hoisted it to
// `SalusModel.LocalDate.daysPerWeek`, which the grid above reads, because a week's length is a
// fact about the calendar rather than a dimension of this screen.

/// `OutOfMonthTextAlpha` (`CycleCalendarGrid.kt:245`).
private let outOfMonthTextAlpha = 0.38
/// `TodayRingWidth` (`CycleCalendarGrid.kt:246`).
private let todayRingWidth: CGFloat = 2
/// `PredictedRingWidth` (`CycleCalendarGrid.kt:247`).
private let predictedRingWidth: CGFloat = 1
/// `PredictedDashLength` (`CycleCalendarGrid.kt:248`).
private let predictedDashLength: CGFloat = 3
/// `OvulationDotSize` (`CycleCalendarGrid.kt:249`).
private let ovulationDotSize: CGFloat = 4
/// `LegendDotSize` (`CycleCalendarGrid.kt:250`).
private let legendDotSize: CGFloat = 8
/// `LegendRingWidth` (`CycleCalendarGrid.kt:251`).
private let legendRingWidth: CGFloat = 1

/// `DateTimeFormatter.ofPattern("LLLL yyyy", locale)` (`CycleScreen.kt:160`).
private let monthTitlePattern = "LLLL yyyy"
