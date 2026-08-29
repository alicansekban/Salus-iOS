// Ported 1:1 from the four private helpers of `feature/cycle/src/main/kotlin/com/alicansekban/
// salus/feature/cycle/ui/calendar/CycleViewModel.kt` (`:101-207`).
//
// They are private methods on the Kotlin ViewModel, and they are a namespaced `enum` here for two
// reasons. The first is mechanical: with them inline the Swift ViewModel runs past the 300-line
// type limit, because Swift spells a `data class` copy as a fourteen-argument initialiser call.
// The second is that they are pure — the whole month grid is a function of (month, periods,
// prediction, today) and of nothing the ViewModel holds — so lifting them out makes the grid rules
// testable without driving a ViewModel through two async streams first.
//
// `clock.today()` is therefore a parameter rather than a call: Kotlin reads it at the top of
// `buildState` (`CycleViewModel.kt:107`), the ViewModel reads it in exactly the same place and
// hands it down. Same for the predictor, which is itself a pure `struct`.

import Foundation
import SalusModel

/// Builds ``CycleUiState`` and its month grid from what the two streams last produced.
enum CycleCalendarBuilder {
    /// `CycleViewModel.kt:101-152`.
    static func buildState(
        monthStart: LocalDate,
        periods: [CyclePeriod],
        reminderConfig: CycleReminderConfig,
        reminderDialog: CycleReminderDialog?,
        predictor: CyclePredictor,
        today: LocalDate
    ) -> CycleUiState {
        let prediction = predictor(periods, today: today)

        // `CycleViewModel.kt:110-113` — an open period has no end date and is painted through
        // today, so the day the user is recording is already filled in.
        var periodDays: Set<Int> = []
        for period in periods {
            let lastDay = period.endDate ?? max(period.startDate, today)
            periodDays.formUnion(epochDayRange(from: period.startDate, until: lastDay))
        }
        // `CycleViewModel.kt:114-117` — minus the recorded days, so a day that is both is drawn
        // once, as recorded.
        let predictedDays = prediction
            .map { predictedPeriodDays(for: $0, periods: periods).subtracting(periodDays) } ?? []
        let fertileDays = prediction
            .map { epochDayRange(from: $0.fertileWindowStart, until: $0.fertileWindowEnd) } ?? []
        let ovulationDay = prediction?.ovulationDate.epochDay

        // `CycleViewModel.kt:123-126` — a period recorded for a future date does not restart the
        // day count.
        let lastStart = periods.map(\.startDate).filter { $0 <= today }.max()

        return CycleUiState(
            isLoading: false,
            monthFirstEpochDay: monthStart.epochDay,
            cells: buildCells(
                monthStart: monthStart,
                today: today,
                periodDays: periodDays,
                predictedDays: predictedDays,
                fertileDays: fertileDays,
                ovulationDay: ovulationDay
            ),
            hasOpenPeriod: periods.contains(where: \.isOpen),
            // No upper clamp: a cycle that runs long keeps counting rather than sticking at the
            // average (`CycleViewModel.kt:140`).
            cycleDayNumber: lastStart.map { $0.daysUntil(today) + 1 },
            // Negative when the predicted start is already behind us, which is what the
            // "N days late" copy reads (`CycleViewModel.kt:141`).
            daysUntilNextPeriod: prediction.map { today.daysUntil($0.nextPeriodStart) },
            averageCycleLength: prediction?.averageCycleLength,
            confidence: prediction?.confidence,
            isIrregular: prediction?.isIrregular ?? false,
            reminderEnabled: reminderConfig.enabled,
            reminderLeadDays: reminderConfig.leadDays,
            reminderMinuteOfDay: reminderConfig.minuteOfDay,
            reminderHasUsablePrediction: prediction != nil && prediction?.confidence != .low,
            activeReminderDialog: reminderDialog
        )
    }

    /// `CycleViewModel.kt:154-187` — the Monday-first grid for `monthStart`'s month.
    ///
    /// The grid backs up to the Monday that opens the first week (`isoDayNumber - 1` days) and is
    /// padded forward to a whole number of weeks, so the screen never has to reason about a ragged
    /// last row. Every marker is gated on `isInMonth`: the padding days carry their real date and
    /// nothing else.
    static func buildCells(
        monthStart: LocalDate,
        today: LocalDate,
        periodDays: Set<Int>,
        predictedDays: Set<Int>,
        fertileDays: Set<Int>,
        ovulationDay: Int?
    ) -> [CycleDayCell] {
        let nextMonthStart = monthStart.plusMonths(1)
        var date = monthStart.minusDays(monthStart.isoDayNumber - 1)
        var daysInGrid: [LocalDate] = []
        while date < nextMonthStart {
            daysInGrid.append(date)
            date = date.plusDays(1)
        }
        while !daysInGrid.count.isMultiple(of: LocalDate.daysPerWeek) {
            daysInGrid.append(date)
            date = date.plusDays(1)
        }

        return daysInGrid.map { date in
            let epochDay = date.epochDay
            let isInMonth = date >= monthStart && date < nextMonthStart
            return CycleDayCell(
                epochDay: epochDay,
                dayOfMonth: date.day,
                isInMonth: isInMonth,
                isToday: isInMonth && date == today,
                isPeriod: isInMonth && periodDays.contains(epochDay),
                isPredictedPeriod: isInMonth && predictedDays.contains(epochDay),
                isFertile: isInMonth && fertileDays.contains(epochDay),
                isOvulation: isInMonth && epochDay == ovulationDay
            )
        }
    }

    /// Predicted period days for the calendar: next predicted start plus the average recorded
    /// period duration (default when nothing is completed yet) — `CycleViewModel.kt:189-204`.
    ///
    /// Kotlin's `(sum.toDouble() / size).toInt()` truncates towards zero; durations are day counts
    /// and always positive, so `Int(_:)` on the same quotient is the same rule.
    private static func predictedPeriodDays(
        for prediction: CyclePrediction,
        periods: [CyclePeriod]
    ) -> Set<Int> {
        let durations = periods.compactMap { period in
            period.endDate.map { period.startDate.daysUntil($0) + 1 }
        }
        let length: Int = if durations.isEmpty {
            defaultPredictedPeriodDays
        } else {
            min(
                max(Int(Double(durations.reduce(0, +)) / Double(durations.count)), minPredictedPeriodDays),
                maxPredictedPeriodDays
            )
        }
        let lastDay = prediction.nextPeriodStart.plusDays(length - 1)
        return epochDayRange(from: prediction.nextPeriodStart, until: lastDay)
    }

    /// `CycleViewModel.kt:206-207`. Kotlin's `(from..until)` is empty when `until` precedes `from`;
    /// a Swift `ClosedRange` traps on it, so the same case is answered with the empty set.
    private static func epochDayRange(from: LocalDate, until: LocalDate) -> Set<Int> {
        guard from <= until else { return [] }
        return Set(from.epochDay ... until.epochDay)
    }

    // `CycleViewModel.kt:212-216`. `DAYS_PER_WEEK` is `SalusModel.LocalDate.daysPerWeek`, which
    // the whole port shares.
    private static let defaultPredictedPeriodDays = 5
    private static let minPredictedPeriodDays = 2
    private static let maxPredictedPeriodDays = 10
}
