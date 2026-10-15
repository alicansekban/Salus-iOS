// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/timeline/
// SmokingTimelineViewModelTest.kt`.
//
// The ViewModel is exercised over the real calculator and the real `SwitchMode`; only the store is
// fake. `advanceUntilIdle()` becomes `waitUntil`, and the Turbine `effects.test { awaitItem() }`
// becomes `consumeEffects()` after the write has landed.

import Foundation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingTimelineViewModel", .timeLimit(.minutes(1)))
struct SmokingTimelineViewModelTests {
    // MARK: State mapping

    @Test("nothing is on show before the first snapshot")
    func nothingBeforeTheFirstSnapshot() {
        let state = TimelineHarness(agoMs: 3 * dayMs).viewModel().state

        #expect(state.mode == .none)
        #expect(state.rows.isEmpty)
    }

    @Test("a quit snapshot lists every catalog stage in catalog order")
    func quitListsEveryCatalogStage() async {
        let state = await TimelineHarness(agoMs: 3 * dayMs).loadedViewModel().state

        #expect(state.mode == .quit)
        #expect(state.rows.map(\.stageId) == MilestoneCatalog.healthStages.map(\.id))
        // The header counts against the catalog, not a literal.
        #expect(state.totalCount == MilestoneCatalog.healthStages.count)
    }

    @Test("done count and the next stage follow the time since the last smoke")
    func doneCountAndNextStage() async throws {
        // 3 days: 20 min, 12 h, 48 h and 72 h are behind, 2 weeks is the one being counted.
        let state = await TimelineHarness(agoMs: 3 * dayMs).loadedViewModel().state

        #expect(state.doneCount == 4)
        #expect(state.nextStageId == "h_2w")
        let byId = Dictionary(uniqueKeysWithValues: state.rows.map { ($0.stageId, $0) })
        #expect(try #require(byId["h_72h"]).state == .done)
        #expect(try #require(byId["h_2w"]).state == .inProgress)
        #expect(try #require(byId["h_1mo"]).state == .pending)
        // Remaining is the snapshot's, not zero.
        #expect(try #require(byId["h_2w"]).remainingMs > 0)
    }

    @Test("with every stage done there is no next one")
    func everyStageDone() async {
        let state = await TimelineHarness(agoMs: 20 * 365 * dayMs).loadedViewModel().state

        #expect(state.doneCount == state.totalCount)
        #expect(state.nextStageId == nil)
    }

    @Test("a slip marks only the stages the attempt had already unlocked as counting again")
    func slipMarksCountingAgain() async {
        // 400 days in, the last smoke 2 days ago: 2 weeks, 1 month and 1 year would be unlocked by
        // the attempt's own length; the short stages simply restart and never carry the note.
        let rows = await TimelineHarness(agoMs: 400 * dayMs, slipAgoMs: 2 * dayMs).loadedViewModel().state.rows

        #expect(Set(rows.filter(\.countingAgain).map(\.stageId)) == ["h_2w", "h_1mo", "h_1y"])
    }

    @Test("combustion-only stages carry the note for heated tobacco and vape")
    func combustionNoteForHeatedAndVape() async {
        for product in [ProductType.heated, .vape] {
            let rows = await TimelineHarness(agoMs: 3 * dayMs, product: product).loadedViewModel().state.rows

            #expect(Set(rows.filter(\.combustionNote).map(\.stageId)) == ["h_12h", "h_48h"], "note rows for \(product)")
        }
    }

    @Test("combustion-only stages carry no note for cigarettes and rolled tobacco, and none are removed")
    func noCombustionNoteForCombustibles() async {
        for product in [ProductType.cigarette, .rolled] {
            let state = await TimelineHarness(agoMs: 3 * dayMs, product: product).loadedViewModel().state

            #expect(state.rows.allSatisfy { !$0.combustionNote }, "no note for \(product)")
        }
        let heated = await TimelineHarness(agoMs: 3 * dayMs, product: .heated).loadedViewModel().state
        #expect(heated.rows.count == MilestoneCatalog.healthStages.count, "the stages are labelled, not filtered out")
    }

    @Test("a reduce snapshot lists the stages all pending, with no count")
    func reduceListsAllPending() async {
        let state = await TimelineHarness().loadedViewModel().state

        #expect(state.mode == .reduce)
        #expect(state.rows.count == MilestoneCatalog.healthStages.count)
        #expect(state.rows.allSatisfy { $0.state == .pending && $0.permille == 0 })
        #expect(state.doneCount == 0)
        #expect(state.nextStageId == nil)
    }

    @Test("each row names the source its stage cites")
    func rowsNameTheirSource() async throws {
        let rows = await TimelineHarness(agoMs: 3 * dayMs).loadedViewModel().state.rows

        for stage in MilestoneCatalog.healthStages {
            #expect(try #require(rows.first { $0.stageId == stage.id }).source == stage.source)
        }
    }

    @Test("a plan-less snapshot shows nothing")
    func notSetUpShowsNothing() async {
        let harness = TimelineHarness(agoMs: dayMs)
        let vm = await harness.loadedViewModel()
        #expect(vm.state.mode == .quit)

        // Reset: the plan is gone and the list empties rather than keeping the last rows.
        _ = try? await harness.store.mutate { try $0.resetAll() }
        await waitUntil("the empty snapshot") { vm.state.mode == .none }

        #expect(vm.state.rows.isEmpty)
        #expect(vm.state.doneCount == 0)
        #expect(vm.state.nextStageId == nil)
    }

    // MARK: Highlight and detail

    @Test("the stage a link named is on the state from the start")
    func highlightFromTheStart() async {
        let vm = TimelineHarness(agoMs: 3 * dayMs).viewModel(highlightStageId: "h_1mo")

        #expect(vm.state.highlightStageId == "h_1mo")
        await waitUntil("the first snapshot") { vm.state.mode != .none }
        #expect(vm.state.highlightStageId == "h_1mo", "the snapshot does not drop it")
    }

    @Test("an id outside the catalog highlights nothing")
    func unknownIdHighlightsNothing() {
        let vm = TimelineHarness(agoMs: 3 * dayMs).viewModel(highlightStageId: "h_9mo")

        #expect(vm.state.highlightStageId == nil)
    }

    @Test("no link, no highlight")
    func noLinkNoHighlight() {
        #expect(TimelineHarness(agoMs: 3 * dayMs).viewModel().state.highlightStageId == nil)
    }

    @Test("the highlight is spent once the screen has shown it")
    func highlightIsSpent() async {
        let vm = await TimelineHarness(agoMs: 3 * dayMs).loadedViewModel(highlightStageId: "h_1mo")

        vm.onEvent(.highlightShown)

        #expect(vm.state.highlightStageId == nil)
    }

    @Test("tapping a stage opens its detail and dismissing closes it")
    func tapOpensDetail() async {
        let vm = await TimelineHarness(agoMs: 3 * dayMs).loadedViewModel()

        vm.onEvent(.stageTapped("h_1y"))
        #expect(vm.state.detailStageId == "h_1y")
        #expect(vm.state.detail?.stageId == "h_1y")

        vm.onEvent(.detailDismissed)
        #expect(vm.state.detailStageId == nil)
        #expect(vm.state.detail == nil)
    }

    @Test("a stage outside the catalog opens no detail")
    func unknownStageOpensNoDetail() async {
        let vm = await TimelineHarness(agoMs: 3 * dayMs).loadedViewModel()

        vm.onEvent(.stageTapped("h_9mo"))

        #expect(vm.state.detailStageId == nil)
    }

    // MARK: Switch to quitting

    @Test("the switch button opens the quit-date sheet starting at now")
    func switchOpensTheSheetAtNow() async {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()

        vm.onEvent(.switchTapped)

        #expect(vm.state.quitDateSheet)
        #expect(vm.state.initialQuitAtMs == harness.nowMs)
    }

    @Test("dismissing the quit-date sheet writes nothing")
    func dismissWritesNothing() async {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchTapped)

        vm.onEvent(.quitDateDismissed)

        #expect(!vm.state.quitDateSheet)
        #expect(harness.store.calls == 0)
    }

    @Test("a confirmed quit date switches to quit mode and the list turns live")
    func confirmedDateSwitchesToQuit() async throws {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchTapped)

        vm.onEvent(.quitDateConfirmed(harness.nowMs - 3 * dayMs))
        await waitUntil("quit mode") { vm.state.mode == .quit }

        #expect(harness.store.input.plan?.mode == .quit)
        #expect(try #require(harness.store.input.attempts.first).startedAtMs == harness.nowMs - 3 * dayMs)
        #expect(harness.store.input.attempts.count == 1)
        #expect(vm.state.doneCount == 4)
        await waitUntil("the sheet to close") { !vm.state.quitDateSheet }
        #expect(!vm.state.writing)
    }

    @Test("a future quit date is refused with a message and the sheet stays")
    func futureDateIsRefused() async {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchTapped)

        vm.onEvent(.quitDateConfirmed(harness.nowMs + dayMs))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.futureDate)])
        #expect(vm.state.quitDateSheet)
        #expect(!vm.state.writing)
        #expect(vm.state.mode == .reduce)
        #expect(harness.store.commits == 0)
    }

    @Test("a quit date before the last attempt ended is refused with the one overlap sentence")
    func dateBeforeTheLastAttemptIsRefused() async {
        let harness = TimelineHarness(reduceClosedAgoMs: 5 * dayMs)
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchTapped)

        vm.onEvent(.quitDateConfirmed(harness.nowMs - 10 * dayMs))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.overlap)])
        #expect(vm.state.quitDateSheet)
        #expect(harness.store.commits == 0)
    }

    @Test("a storage fault is reported generically and the sheet stays")
    func storageFaultIsGeneric() async {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchTapped)
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.quitDateConfirmed(harness.nowMs - dayMs))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(vm.state.quitDateSheet)
        #expect(!vm.state.writing)
    }

    @Test("a double tap on the confirm writes once")
    func doubleTapWritesOnce() async {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchTapped)
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.quitDateConfirmed(harness.nowMs - dayMs))
        vm.onEvent(.quitDateConfirmed(harness.nowMs - dayMs))
        #expect(vm.state.writing)
        gate.open()
        await waitUntil("quit mode") { vm.state.mode == .quit }

        #expect(harness.store.calls == 1, "one write was started")
        #expect(harness.store.input.attempts.count == 1)
    }

    @Test("the sheet cannot be dismissed while the switch is in flight")
    func sheetStaysWhileWriting() async {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()
        vm.onEvent(.switchTapped)
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.quitDateConfirmed(harness.nowMs - dayMs))

        vm.onEvent(.quitDateDismissed)

        #expect(vm.state.quitDateSheet)
        gate.open()
        await waitUntil("quit mode") { vm.state.mode == .quit }
    }

    @Test("a confirm with no sheet open writes nothing")
    func confirmWithoutSheetWritesNothing() async {
        let harness = TimelineHarness()
        let vm = await harness.loadedViewModel()

        vm.onEvent(.quitDateConfirmed(harness.nowMs - dayMs))

        #expect(!vm.state.writing)
        #expect(harness.store.calls == 0)
    }
}
