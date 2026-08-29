// Ported 1:1 from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleUiState.kt`.
//
// `ImmutableList` is dropped rather than imitated — a Swift `Array` in a `struct` already is what
// `kotlinx.collections.immutable` promises Compose (`MedicationsUiState.swift`,
// `VitalsUiState.swift` and `AppointmentsUiState.swift` record the same ruling).
//
// Kotlin's `sealed interface CycleEvent` with nine members becomes one Swift `enum` with nine
// cases, exactly as the four features before this one spell it.

/// One cell of the month grid (`CycleUiState.kt:11-20`).
///
/// Cells outside the displayed month carry real dates but no markers and are not clickable — every
/// flag below is written as `isInMonth && …` by ``CycleCalendarBuilder``.
///
/// `Identifiable` is what `ForEach` asks for; the grid holds each date once, so `epochDay` is the
/// identity.
public struct CycleDayCell: Equatable, Hashable, Sendable, Identifiable {
    public let epochDay: Int
    public let dayOfMonth: Int
    public let isInMonth: Bool
    public let isToday: Bool
    public let isPeriod: Bool
    public let isPredictedPeriod: Bool
    public let isFertile: Bool
    public let isOvulation: Bool

    public var id: Int { epochDay }

    public init(
        epochDay: Int,
        dayOfMonth: Int,
        isInMonth: Bool,
        isToday: Bool = false,
        isPeriod: Bool = false,
        isPredictedPeriod: Bool = false,
        isFertile: Bool = false,
        isOvulation: Bool = false
    ) {
        self.epochDay = epochDay
        self.dayOfMonth = dayOfMonth
        self.isInMonth = isInMonth
        self.isToday = isToday
        self.isPeriod = isPeriod
        self.isPredictedPeriod = isPredictedPeriod
        self.isFertile = isFertile
        self.isOvulation = isOvulation
    }
}

/// Which reminder option popup is open on the Cycle screen (`CycleUiState.kt:23-26`).
public enum CycleReminderDialog: Equatable, Hashable, Sendable {
    case leadDays
    case time
}

/// What the calendar screen draws (`CycleUiState.kt:28-49`).
public struct CycleUiState: Equatable, Sendable {
    public var isLoading: Bool

    /// Epoch day of the first day of the displayed month (title formatting happens in the UI).
    public var monthFirstEpochDay: Int

    /// Full grid for the displayed month, padded to whole weeks (Monday first).
    public var cells: [CycleDayCell]

    public var hasOpenPeriod: Bool

    /// 1-based day inside the current cycle, nil before the first recorded period.
    public var cycleDayNumber: Int?

    /// Days from today until the predicted next start; negative when overdue. Nil without a
    /// prediction.
    public var daysUntilNextPeriod: Int?

    public var averageCycleLength: Int?
    public var confidence: CycleConfidence?
    public var isIrregular: Bool
    public var reminderEnabled: Bool

    /// Days before the predicted start; 0 = the predicted day itself.
    public var reminderLeadDays: Int

    public var reminderMinuteOfDay: Int

    /// True when a reminder can actually fire (prediction exists and is not LOW confidence).
    public var reminderHasUsablePrediction: Bool

    public var activeReminderDialog: CycleReminderDialog?

    /// The fourteen defaults are Kotlin's, value for value (`CycleUiState.kt:29-48`) — the state
    /// the screen draws before the first (periods, config) pair arrives.
    public init(
        isLoading: Bool = true,
        monthFirstEpochDay: Int = 0,
        cells: [CycleDayCell] = [],
        hasOpenPeriod: Bool = false,
        cycleDayNumber: Int? = nil,
        daysUntilNextPeriod: Int? = nil,
        averageCycleLength: Int? = nil,
        confidence: CycleConfidence? = nil,
        isIrregular: Bool = false,
        reminderEnabled: Bool = false,
        reminderLeadDays: Int = 1,
        reminderMinuteOfDay: Int = 9 * 60,
        reminderHasUsablePrediction: Bool = false,
        activeReminderDialog: CycleReminderDialog? = nil
    ) {
        self.isLoading = isLoading
        self.monthFirstEpochDay = monthFirstEpochDay
        self.cells = cells
        self.hasOpenPeriod = hasOpenPeriod
        self.cycleDayNumber = cycleDayNumber
        self.daysUntilNextPeriod = daysUntilNextPeriod
        self.averageCycleLength = averageCycleLength
        self.confidence = confidence
        self.isIrregular = isIrregular
        self.reminderEnabled = reminderEnabled
        self.reminderLeadDays = reminderLeadDays
        self.reminderMinuteOfDay = reminderMinuteOfDay
        self.reminderHasUsablePrediction = reminderHasUsablePrediction
        self.activeReminderDialog = activeReminderDialog
    }
}

/// Everything the screen can ask the ViewModel to do (`CycleUiState.kt:51-69`).
public enum CycleEvent: Equatable, Sendable {
    /// `CycleUiState.kt:52`.
    case previousMonthClicked

    /// `CycleUiState.kt:54`.
    case nextMonthClicked

    /// `CycleUiState.kt:56`.
    case startPeriodClicked

    /// `CycleUiState.kt:58`.
    case endPeriodClicked

    /// `CycleUiState.kt:60`.
    case reminderToggled(Bool)

    /// `CycleUiState.kt:62`.
    case reminderDialogRequested(CycleReminderDialog)

    /// `CycleUiState.kt:64`.
    case reminderDialogDismissed

    /// `CycleUiState.kt:66`.
    case reminderLeadDaysSelected(Int)

    /// `CycleUiState.kt:68`.
    case reminderTimeSelected(Int)
}
