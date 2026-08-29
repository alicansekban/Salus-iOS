// Ported from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/ui/calendar/
// CycleViewModelTest.kt` — all six cases, by name, in the Kotlin order, with four iOS-only cases
// after them (listed separately in the task report).
//
// Three mechanical differences from the Kotlin, all already settled elsewhere in this port:
// Turbine's `state.test { awaitItem() }` becomes reading `viewModel.state` after `waitUntil`,
// because the iOS state is an `@Observable` property rather than a `StateFlow`; Kotlin's first
// `awaitItem() // initial loading state` is ``loadedState(_:)``'s `isLoading` expectation, which
// every case therefore still makes; and `MainDispatcherRule` has no twin — `@MainActor` on the
// suite is the whole mechanism.
//
// The four iOS-only cases cover the three grid rules the Kotlin table leaves implicit (they are
// written into `CycleViewModel.kt:174-184` but asserted nowhere) plus the reminder dialog's
// local-only arm:
//   - out-of-month cells carry no flags, even when the day itself is recorded;
//   - an open period paints through today;
//   - predicted days that are already recorded stay recorded and are not drawn twice;
//   - opening and dismissing a reminder dialog is local state and never asks for a re-sync.

import Foundation
import SalusCommon
import SalusModel
import SalusReminder
import SalusTesting
import Testing

@testable import FeatureCycle

@Suite("CycleViewModel")
@MainActor
struct CycleViewModelTests {
    /// `CycleViewModelTest.kt:33` — Europe/Istanbul, which is `FixedSalusClock`'s own default.
    private static let zone = FixedSalusClock.defaultZone

    /// `CycleViewModelTest.kt:36-37` — 2025-08-12T11:20:00Z, which is 2025-08-12 in Istanbul.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let today = LocalDate(year: 2025, month: 8, day: 12)

    /// `CycleViewModelTest.kt:39-49`.
    private let clock = FixedSalusClock(now: CycleViewModelTests.now, timeZone: CycleViewModelTests.zone)
    private let repository = FakeCycleRepository()
    private let reminderSettings = FakeCycleReminderSettings()
    private let scheduler = FakeReminderScheduler()

    /// `CycleViewModelTest.kt:51-59`.
    private func viewModel() -> CycleViewModel {
        CycleViewModel(
            repository: repository,
            predictor: CyclePredictor(),
            startPeriod: StartPeriodUseCase(repository: repository, idGenerator: FixedIdGenerator(id: "new-period")),
            endPeriod: EndPeriodUseCase(repository: repository),
            clock: clock,
            reminderSettings: reminderSettings,
            reminderScheduler: scheduler
        )
    }

    /// `CycleViewModelTest.kt:61-62`.
    private func period(_ id: String, _ start: LocalDate, _ end: LocalDate?) -> CyclePeriod {
        CyclePeriod(id: id, startDate: start, endDate: end, flowPeak: nil, note: nil, createdAt: Self.now)
    }

    /// Turbine's `awaitItem() // initial loading state` followed by the first loaded `awaitItem()`.
    private func loadedState(_ viewModel: CycleViewModel) async -> CycleUiState {
        #expect(viewModel.state.isLoading, "the state before the first (periods, config) pair is the default")
        await waitUntil("the first loaded state") { !viewModel.state.isLoading }
        return viewModel.state
    }

    /// `CycleViewModelTest.kt:64-65`.
    private func cell(_ state: CycleUiState, _ date: LocalDate) throws -> CycleDayCell {
        try #require(state.cells.first { $0.epochDay == date.epochDay })
    }

    // MARK: - Ported from CycleViewModelTest.kt

    /// `CycleViewModelTest.kt:67-85`.
    @Test("recorded period days and today are marked on the current month")
    func recordedPeriodDaysAndTodayAreMarkedOnTheCurrentMonth() async throws {
        repository.setPeriods(
            period("p1", LocalDate(year: 2025, month: 8, day: 5), LocalDate(year: 2025, month: 8, day: 9))
        )

        let loaded = await loadedState(viewModel())

        #expect(loaded.monthFirstEpochDay == LocalDate(year: 2025, month: 8, day: 1).epochDay)
        #expect(try cell(loaded, LocalDate(year: 2025, month: 8, day: 5)).isPeriod)
        #expect(try cell(loaded, LocalDate(year: 2025, month: 8, day: 9)).isPeriod)
        #expect(try !cell(loaded, LocalDate(year: 2025, month: 8, day: 10)).isPeriod)
        #expect(try cell(loaded, Self.today).isToday)
        #expect(loaded.cells.count.isMultiple(of: 7))
    }

    /// `CycleViewModelTest.kt:87-110`.
    @Test("two recorded periods produce prediction summary and predicted cells")
    func twoRecordedPeriodsProducePredictionSummaryAndPredictedCells() async throws {
        repository.setPeriods(
            period("p1", LocalDate(year: 2025, month: 7, day: 1), LocalDate(year: 2025, month: 7, day: 5)),
            period("p2", LocalDate(year: 2025, month: 7, day: 29), LocalDate(year: 2025, month: 8, day: 2))
        )

        let loaded = await loadedState(viewModel())

        // One 28-day cycle: next start = Jul 29 + 28 = Aug 26.
        #expect(loaded.daysUntilNextPeriod == 14)
        #expect(loaded.cycleDayNumber == 15)
        #expect(loaded.averageCycleLength == 28)
        #expect(loaded.confidence == .low)
        #expect(loaded.isIrregular)
        #expect(try cell(loaded, LocalDate(year: 2025, month: 8, day: 26)).isPredictedPeriod)
        // Ovulation = Aug 12; fertile window Aug 7..Aug 13.
        #expect(try cell(loaded, LocalDate(year: 2025, month: 8, day: 12)).isOvulation)
        #expect(try cell(loaded, LocalDate(year: 2025, month: 8, day: 7)).isFertile)
    }

    /// `CycleViewModelTest.kt:112-124`.
    @Test("no periods means no summary and no prediction")
    func noPeriodsMeansNoSummaryAndNoPrediction() async {
        let loaded = await loadedState(viewModel())

        #expect(loaded.cycleDayNumber == nil)
        #expect(loaded.daysUntilNextPeriod == nil)
        #expect(loaded.confidence == nil)
        #expect(!loaded.hasOpenPeriod)
    }

    /// `CycleViewModelTest.kt:126-143`.
    @Test("start and end period events update the open period")
    func startAndEndPeriodEventsUpdateTheOpenPeriod() async throws {
        let viewModel = viewModel()
        let initial = await loadedState(viewModel)
        #expect(!initial.hasOpenPeriod)

        viewModel.onEvent(.startPeriodClicked)
        await waitUntil("the started period") { viewModel.state.hasOpenPeriod }
        #expect(try cell(viewModel.state, Self.today).isPeriod)

        viewModel.onEvent(.endPeriodClicked)
        await waitUntil("the ended period") { !viewModel.state.hasOpenPeriod }
        #expect(repository.currentPeriods().count == 1)
        #expect(repository.currentPeriods().first?.endDate == Self.today)
    }

    /// `CycleViewModelTest.kt:145-159`.
    @Test("month navigation moves the displayed month")
    func monthNavigationMovesTheDisplayedMonth() async {
        let viewModel = viewModel()
        let initial = await loadedState(viewModel)
        #expect(initial.monthFirstEpochDay == LocalDate(year: 2025, month: 8, day: 1).epochDay)

        viewModel.onEvent(.nextMonthClicked)
        #expect(viewModel.state.monthFirstEpochDay == LocalDate(year: 2025, month: 9, day: 1).epochDay)

        viewModel.onEvent(.previousMonthClicked)
        #expect(viewModel.state.monthFirstEpochDay == LocalDate(year: 2025, month: 8, day: 1).epochDay)
    }

    /// `CycleViewModelTest.kt:161-180`.
    @Test("reminder events persist the options and request a window re-sync")
    func reminderEventsPersistTheOptionsAndRequestAWindowReSync() async {
        let viewModel = viewModel()
        let initial = await loadedState(viewModel)
        #expect(!initial.reminderEnabled)

        viewModel.onEvent(.reminderToggled(true))
        await waitUntil("the enabled reminder") { viewModel.state.reminderEnabled }

        viewModel.onEvent(.reminderLeadDaysSelected(2))
        await waitUntil("the stored lead days") { viewModel.state.reminderLeadDays == 2 }

        viewModel.onEvent(.reminderTimeSelected(20 * 60))
        await waitUntil("the stored time") { viewModel.state.reminderMinuteOfDay == 20 * 60 }

        #expect(scheduler.syncRequests == 3)
    }

    // MARK: - iOS-only

    /// `CycleViewModel.kt:174-184` — every marker is `isInMonth && …`, so a recorded day that only
    /// appears in the grid as leading padding is drawn blank. Aug 1 2025 is a Friday, so the grid
    /// opens on Mon Jul 28 and the period below straddles the boundary.
    @Test("out-of-month cells carry no flags")
    func outOfMonthCellsCarryNoFlags() async throws {
        repository.setPeriods(
            period("p1", LocalDate(year: 2025, month: 7, day: 28), LocalDate(year: 2025, month: 8, day: 1))
        )

        let loaded = await loadedState(viewModel())

        #expect(loaded.cells.first?.epochDay == LocalDate(year: 2025, month: 7, day: 28).epochDay)
        let paddingDay = try cell(loaded, LocalDate(year: 2025, month: 7, day: 28))
        #expect(!paddingDay.isInMonth)
        #expect(!paddingDay.isPeriod)
        #expect(try !cell(loaded, LocalDate(year: 2025, month: 7, day: 31)).isPeriod)
        // The same record, one day later and inside the month, is drawn.
        let firstOfMonth = try cell(loaded, LocalDate(year: 2025, month: 8, day: 1))
        #expect(firstOfMonth.isInMonth)
        #expect(firstOfMonth.isPeriod)
    }

    /// `CycleViewModel.kt:110-113` — an open period has no end date, so it is painted to
    /// `max(startDate, today)` and stops there rather than running to the end of the month.
    @Test("an open period paints through today")
    func anOpenPeriodPaintsThroughToday() async throws {
        repository.setPeriods(period("open", LocalDate(year: 2025, month: 8, day: 10), nil))

        let loaded = await loadedState(viewModel())

        #expect(loaded.hasOpenPeriod)
        #expect(try cell(loaded, LocalDate(year: 2025, month: 8, day: 10)).isPeriod)
        #expect(try cell(loaded, LocalDate(year: 2025, month: 8, day: 11)).isPeriod)
        #expect(try cell(loaded, Self.today).isPeriod)
        #expect(try !cell(loaded, LocalDate(year: 2025, month: 8, day: 13)).isPeriod)
    }

    /// `CycleViewModel.kt:114-117` — `predictedDays` is the predicted range **minus** the recorded
    /// one, so a day that is both is drawn as recorded and only the rest of the range is predicted.
    ///
    /// The fixture: one completed 5-day period from May 31 and an open one from Jul 5, which is a
    /// single 35-day cycle, so the next start is predicted for Aug 9 and the range runs Aug 9…13.
    /// The open period paints Jul 5 through today (Aug 12), so Aug 9…12 are recorded days and only
    /// Aug 13 is left to draw as predicted.
    @Test("predicted days that are already recorded stay recorded")
    func predictedDaysThatAreAlreadyRecordedStayRecorded() async throws {
        repository.setPeriods(
            period("p1", LocalDate(year: 2025, month: 5, day: 31), LocalDate(year: 2025, month: 6, day: 4)),
            period("open", LocalDate(year: 2025, month: 7, day: 5), nil)
        )

        let loaded = await loadedState(viewModel())

        #expect(loaded.daysUntilNextPeriod == -3)
        let overlapping = try cell(loaded, LocalDate(year: 2025, month: 8, day: 9))
        #expect(overlapping.isPeriod)
        #expect(!overlapping.isPredictedPeriod)
        let remaining = try cell(loaded, LocalDate(year: 2025, month: 8, day: 13))
        #expect(remaining.isPredictedPeriod)
        #expect(!remaining.isPeriod)
    }

    /// `CycleViewModel.kt:83-85` — the two dialog events are the only ones that neither write a
    /// setting nor ask for a re-sync; a selection then closes the dialog and syncs once.
    @Test("reminder dialog requests are local state and never request a re-sync")
    func reminderDialogRequestsAreLocalStateAndNeverRequestAReSync() async {
        let viewModel = viewModel()
        let initial = await loadedState(viewModel)
        #expect(initial.activeReminderDialog == nil)

        viewModel.onEvent(.reminderDialogRequested(.leadDays))
        #expect(viewModel.state.activeReminderDialog == .leadDays)
        #expect(scheduler.syncRequests == 0)

        viewModel.onEvent(.reminderDialogDismissed)
        #expect(viewModel.state.activeReminderDialog == nil)
        #expect(scheduler.syncRequests == 0)

        viewModel.onEvent(.reminderDialogRequested(.time))
        viewModel.onEvent(.reminderTimeSelected(7 * 60))
        #expect(viewModel.state.activeReminderDialog == nil)
        #expect(scheduler.syncRequests == 1)
    }
}

/// `CycleViewModelTest.kt:43-49` — the anonymous `ReminderScheduler` that counts what it was asked
/// for. A class rather than a struct, because the ViewModel holds it as `any ReminderScheduler` and
/// the count has to be readable through that reference after the call.
final class FakeReminderScheduler: ReminderScheduler, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    init() {}

    /// `CycleViewModelTest.kt:44`.
    var syncRequests: Int {
        lock.withLock { count }
    }

    /// `CycleViewModelTest.kt:46-48`.
    func requestSync() {
        lock.withLock { count += 1 }
    }
}
