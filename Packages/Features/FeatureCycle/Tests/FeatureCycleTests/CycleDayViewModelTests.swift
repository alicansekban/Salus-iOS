// Ported from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/ui/day/
// CycleDayViewModelTest.kt` — all four cases, by name, in the Kotlin order. No iOS-only case is
// added.
//
// The mechanical differences are the ones this target has already settled in
// `CycleViewModelTests`: `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole
// mechanism — and `advanceUntilIdle()` becomes ``waitUntil``, a bounded yield loop, because the iOS
// state is an `@Observable` property rather than a `StateFlow` and Swift Testing has no virtual
// scheduler.
//
// `IdGenerator { "new-id" }` (`CycleDayViewModelTest.kt:29`) is `FixedIdGenerator(id: "new-id")`,
// the fixture `StartPeriodUseCaseTests` already carries. The use case is built inside
// ``viewModel()`` rather than as a stored property because one stored property cannot read another
// in a `struct`'s memberwise defaults.

import SalusModel
import SalusNavigation
import Testing

@testable import FeatureCycle

@Suite("CycleDayViewModel")
@MainActor
struct CycleDayViewModelTests {
    /// `CycleDayViewModelTest.kt:27-28`.
    private let repository = FakeCycleRepository()
    private let navigator = FakeNavigator()

    /// `CycleDayViewModelTest.kt:31-32`.
    private static let date = LocalDate(year: 2026, month: 8, day: 16)
    private let date = CycleDayViewModelTests.date
    private let epochDay = CycleDayViewModelTests.date.epochDay

    /// `CycleDayViewModelTest.kt:34`.
    private func viewModel() -> CycleDayViewModel {
        CycleDayViewModel(
            epochDay: epochDay,
            repository: repository,
            saveCycleDay: SaveCycleDayUseCase(
                repository: repository,
                idGenerator: FixedIdGenerator(id: "new-id")
            ),
            navigator: navigator.navigator
        )
    }

    /// `CycleDayViewModelTest.kt:36-47`.
    @Test("catalog loads with nothing selected for an empty day")
    func catalogLoadsWithNothingSelectedForAnEmptyDay() async {
        let viewModel = viewModel()
        await waitUntil("the day to load") { !viewModel.state.isLoading }

        let state = viewModel.state
        #expect(!state.isLoading)
        #expect(state.symptoms.count == 3)
        #expect(state.symptoms.allSatisfy { !$0.isSelected })
        #expect(state.flow == nil)
        #expect(state.noteText.isEmpty)
        navigator.stop()
    }

    /// `CycleDayViewModelTest.kt:49-71`.
    @Test("existing day log preselects symptoms flow mood and note")
    func existingDayLogPreselectsSymptomsFlowMoodAndNote() async throws {
        try await repository.saveDayLog(
            CycleDayLog(
                id: "e1",
                date: date,
                flow: .medium,
                mood: .low,
                note: "rough day",
                symptomIds: ["symptom-cramps"]
            )
        )

        let viewModel = viewModel()
        await waitUntil("the day to load") { !viewModel.state.isLoading }

        let state = viewModel.state
        #expect(state.symptoms.first { $0.id == "symptom-cramps" }?.isSelected == true)
        #expect(state.symptoms.first { $0.id == "symptom-headache" }?.isSelected == false)
        #expect(state.flow == .medium)
        #expect(state.mood == .low)
        #expect(state.noteText == "rough day")
        navigator.stop()
    }

    /// `CycleDayViewModelTest.kt:73-83`.
    @Test("selecting the same flow level twice clears it")
    func selectingTheSameFlowLevelTwiceClearsIt() async {
        let viewModel = viewModel()
        await waitUntil("the day to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.flowSelected(.heavy))
        #expect(viewModel.state.flow == .heavy)

        viewModel.onEvent(.flowSelected(.heavy))
        #expect(viewModel.state.flow == nil)
        navigator.stop()
    }

    /// `CycleDayViewModelTest.kt:85-105`.
    @Test("saving stores the day log and pops the back stack")
    func savingStoresTheDayLogAndPopsTheBackStack() async throws {
        let viewModel = viewModel()
        await waitUntil("the day to load") { !viewModel.state.isLoading }

        viewModel.onEvent(.symptomToggled("symptom-fatigue"))
        viewModel.onEvent(.flowSelected(.light))
        viewModel.onEvent(.moodSelected(.good))
        viewModel.onEvent(.noteChanged("better"))

        viewModel.onEvent(.saveClicked)
        await waitUntil("the back stack to pop") { navigator.commandLog == [.pop] }
        #expect(navigator.commandLog == [.pop])

        let logs = repository.currentDayLogs()
        #expect(logs.count == 1)
        let saved = try #require(logs.first)
        #expect(saved.date == date)
        #expect(saved.symptomIds == ["symptom-fatigue"])
        #expect(saved.flow == .light)
        #expect(saved.mood == .good)
        #expect(saved.note == "better")
        navigator.stop()
    }
}
