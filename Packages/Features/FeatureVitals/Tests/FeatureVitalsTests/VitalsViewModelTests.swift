// Ported from
// `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/ui/list/VitalsViewModelTest.kt`.
//
// The Android table has seven cases. The five weight ones are below, with the Kotlin names, inputs
// and expectations. The other two are OWED BY iOS-M7, which brings `VitalsPreferences`, the blood
// pressure and glucose repository members and the state builders that read them:
//
//   * `switching to blood pressure shows its entries with a two series chart`
//     (`VitalsViewModelTest.kt:168-198`)
//   * `glucose entries are displayed in the preferred unit while storage stays mg dL`
//     (`VitalsViewModelTest.kt:200-229`)
//
// They are named here rather than dropped so the M7 plan cannot lose them: a ported type without
// its ported test table is an unfinished port (`CLAUDE.md`, port fidelity rules).
//
// Two mechanical differences from the Kotlin, both already settled elsewhere in this port:
// Turbine's `state.test { awaitItem() }` becomes reading `viewModel.state` after `waitUntil`,
// because the iOS state is an `@Observable` property rather than a `StateFlow`; and
// `advanceUntilIdle()` becomes `waitUntil` plus `TestDeletes.closeUndoWindow()`.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import SalusUI
import Testing

@testable import FeatureVitals

@Suite("VitalsViewModel")
@MainActor
struct VitalsViewModelTests {
    /// `VitalsViewModelTest.kt:40-42` — the same instant and zone.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let zone = FixedSalusClock.defaultZone

    private let clock = FixedSalusClock(now: VitalsViewModelTests.now, timeZone: VitalsViewModelTests.zone)
    private let repository = FakeVitalsRepository()
    private let deletes = TestDeletes()

    /// `VitalsViewModelTest.kt:46`, minus `preferences`: `VitalsPreferences` is M7 work, so M2's
    /// constructor has five parameters where Android's has six. Recorded on purpose — M7 changes
    /// this signature, not only the state builders.
    private func viewModel() -> VitalsViewModel {
        VitalsViewModel(
            repository: repository,
            pendingDeletes: deletes.controller,
            undoableDelete: deletes.undoableDelete,
            clock: clock
        )
    }

    /// `VitalsViewModelTest.kt:48-54`.
    private func entry(_ id: String, daysAgo: Int, kg: Double) -> WeightEntry {
        WeightEntry(
            id: id,
            measuredAt: Self.now.addingTimeInterval(-Double(daysAgo) * 86400),
            timeZone: Self.zone,
            kilograms: kg,
            note: nil
        )
    }

    /// `VitalsViewModelTest.kt:76-95`.
    @Test("entries inside range are listed newest first with chart")
    func entriesInsideRangeAreListedNewestFirstWithChart() async throws {
        repository.setEntries(
            entry("old", daysAgo: 45, kg: 85.0),
            entry("mid", daysAgo: 10, kg: 82.0),
            entry("new", daysAgo: 1, kg: 81.0)
        )
        let viewModel = viewModel()

        await waitUntil("the first history emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.entries.map(\.id) == ["new", "mid"])
        #expect(viewModel.state.latestKilograms == 81.0)
        let chart = try #require(viewModel.state.chart)
        #expect(chart.points.count == 2)
    }

    /// `VitalsViewModelTest.kt:97-116`.
    @Test("year range includes older entries")
    func yearRangeIncludesOlderEntries() async {
        repository.setEntries(
            entry("old", daysAgo: 45, kg: 85.0),
            entry("new", daysAgo: 1, kg: 81.0)
        )
        let viewModel = viewModel()

        await waitUntil("the first history emission") { !viewModel.state.isLoading }
        // The 30-day default excludes "old" (`VitalsViewModelTest.kt:107`).
        #expect(viewModel.state.entries.map(\.id) == ["new"])

        viewModel.onEvent(.rangeSelected(.year))
        await waitUntil("the year window") { viewModel.state.entries.count == 2 }

        #expect(viewModel.state.selectedRange == .year)
        #expect(viewModel.state.entries.map(\.id) == ["new", "old"])
    }

    /// `VitalsViewModelTest.kt:118-131`.
    @Test("single entry produces no chart")
    func singleEntryProducesNoChart() async {
        repository.setEntries(entry("only", daysAgo: 2, kg: 80.0))
        let viewModel = viewModel()

        await waitUntil("the first history emission") { !viewModel.state.isLoading }

        #expect(viewModel.state.chart == nil)
        #expect(viewModel.state.entries.count == 1)
    }

    /// `VitalsViewModelTest.kt:133-150`.
    ///
    /// Stronger than the Kotlin in one place: Android asserts the repository is empty *after*
    /// `advanceUntilIdle()` has closed the window, which cannot tell "deferred then written" from
    /// "written immediately". The undo window here is a gate the test holds shut, so the deferral
    /// itself is asserted before it is opened.
    @Test("delete confirms first, then defers the write")
    func deleteConfirmsFirstThenDefersTheWrite() async {
        repository.setEntries(entry("victim", daysAgo: 3, kg: 90.0))
        let viewModel = viewModel()
        await waitUntil("the first history emission") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteRequested("victim"))
        #expect(viewModel.state.pendingDeleteId == "victim")
        #expect(viewModel.state.entries.count == 1)

        viewModel.onEvent(.deleteConfirmed)
        await waitUntil("the row to vanish") { viewModel.state.entries.isEmpty }
        #expect(viewModel.state.pendingDeleteId == nil)
        #expect(repository.current().count == 1, "the write waits for the undo window")
        // `VitalsViewModel.kt:109` attaches `R.string.vitals_entry_deleted`; the iOS twin resolves
        // it in the feature and hands `UndoableDelete` the text (`UndoableDelete.swift:18-24`).
        #expect(deletes.lastRequest?.message == VitalsStrings.entryDeleted)

        await deletes.closeUndoWindow()
        await waitUntil("the deferred write") { repository.current().isEmpty }
    }

    /// `VitalsViewModelTest.kt:152-166`.
    @Test("undo brings the row back without touching the repository")
    func undoBringsTheRowBackWithoutTouchingTheRepository() async {
        repository.setEntries(entry("victim", daysAgo: 3, kg: 90.0))
        let viewModel = viewModel()
        await waitUntil("the first history emission") { !viewModel.state.isLoading }

        viewModel.onEvent(.deleteRequested("victim"))
        viewModel.onEvent(.deleteConfirmed)
        await waitUntil("the row to vanish") { viewModel.state.entries.isEmpty }

        deletes.undoLast()
        await waitUntil("the row to come back") { viewModel.state.entries.count == 1 }

        // The window would have closed by now on Android's virtual clock; opening it here proves
        // the undo cancelled the write rather than merely outrunning it.
        await deletes.closeUndoWindow()
        await waitUntil("the undo window to pass") { deletes.controller.pendingIds.isEmpty }
        #expect(viewModel.state.entries.count == 1)
        #expect(repository.current().count == 1)
    }

    /// No Kotlin twin — this pins the hand-ported half of `WhileSubscribed`.
    ///
    /// The DAO query is `BETWEEN from AND until`, and `until` is the `clock.now()` taken when the
    /// window opened (`VitalsViewModel.kt:53`). An entry saved afterwards carries
    /// `measuredAt = instant(today, minuteOfDayNow())`, which is *past* that `until`, so the open
    /// window never yields it. Android is saved by
    /// `.stateIn(scope, SharingStarted.WhileSubscribed(5_000), …)` (`VitalsViewModel.kt:87-90`):
    /// the list unsubscribes while the editor is on top and re-subscribing re-runs
    /// `combine(selectedType, selectedRange).flatMapLatest { … }` (`VitalsViewModel.kt:51-52`)
    /// with a fresh `now`. `VitalsRoute.task` calls `restartHistoryObservation()` on every
    /// appearance to do the same; this test is that call.
    @Test("an entry saved after the window opened is listed")
    func anEntrySavedAfterTheWindowOpenedIsListed() async throws {
        repository.setEntries(entry("existing", daysAgo: 1, kg: 80.0))
        let viewModel = viewModel()
        await waitUntil("the first history emission") { !viewModel.state.isLoading }
        #expect(viewModel.state.entries.map(\.id) == ["existing"])

        // The editor round trip: the clock moves past the window's `until`, and the entry it saves
        // is stamped with the new instant.
        let later = Self.now.addingTimeInterval(10 * 60)
        clock.advanceTo(later)
        try await repository.saveWeightEntry(
            WeightEntry(id: "fresh", measuredAt: later, timeZone: Self.zone, kilograms: 79.4, note: nil)
        )

        // The save re-emits on the still-open stream, and the row falls outside `until`.
        await waitUntil("the save to land in the repository") { repository.current().count == 2 }
        #expect(
            viewModel.state.entries.map(\.id) == ["existing"],
            "the window that is already open cannot reach past its own `until`"
        )

        viewModel.restartHistoryObservation()

        await waitUntil("the reopened window") { viewModel.state.entries.count == 2 }
        #expect(viewModel.state.entries.map(\.id) == ["fresh", "existing"], "newest first")
        #expect(viewModel.state.latestKilograms == 79.4)
        // The restart keeps the current selection rather than resetting it.
        #expect(viewModel.state.selectedType == .weight)
        #expect(viewModel.state.selectedRange == .month)
    }
}
