// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainReduceViewModelTest.kt` (branch `feature/m17-smoking-cessation`): the REDUCE half of
// the main screen's ViewModel — +1 with undo, "none today", "ready to quit".
//
// Where Android asserts on its `UndoOffered` effect and `RecordingSnackbarController`, the snackbar
// here IS the undo: the ViewModel shows it through the shell's controller itself, with an action
// that carries the entry's id and holds no reference to the ViewModel, so the tests read
// `snackbar.current` and press `performAction()`. "The ViewModel is gone" is ``release(_:)``, which
// also proves it: a `self` captured by the write or the undo would keep it alive and fail there.

import Foundation
import SalusCommon
import SalusNavigation
import SalusSmoking
import SalusTesting
import SalusUI
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingMainViewModel REDUCE", .timeLimit(.minutes(1)))
struct SmokingMainReduceViewModelTests {
    let harness = ReduceHarness()

    /// Lets go of the ViewModel and asserts it is deallocated.
    private static func release(_ vm: inout SmokingMainViewModel?) async {
        weak var probe = vm
        vm = nil
        await Task.yield()
        #expect(probe == nil, "something in the write or the undo still holds the ViewModel")
    }

    // MARK: +1 and undo

    @Test("plus one logs one unit and offers undo for that entry")
    func plusOneOffersUndo() async throws {
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.plusOne)
        await waitUntil("the undo snackbar") { harness.snackbar.current != nil }

        let event = try #require(harness.store.input.events.first)
        #expect(harness.store.input.events.count == 1)
        #expect(event.units == 1)
        let offer = try #require(harness.snackbar.current)
        #expect(offer.message == SmokingStrings.reduceAdded)
        #expect(offer.actionLabel == SalusUIStrings.undo)
        await waitUntil("the new snapshot") { (try? vm.reduce().todayUnits) == 1 }
        #expect(!vm.state.writing)

        harness.snackbar.performAction()
        await waitUntil("the entry is gone") { harness.store.input.events.isEmpty }
    }

    @Test("a second plus one while the first write is in flight writes once")
    func secondPlusOneWritesOnce() async {
        let vm = await harness.subscribedViewModel()
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.plusOne)
        #expect(vm.state.writing, "the buttons are off from the first tap on")
        vm.onEvent(.plusOne)
        await waitUntil("the first write is started") { harness.store.calls == 1 }
        gate.open()
        await waitUntil("the write ends") { !vm.state.writing }

        #expect(harness.store.calls == 1)
        #expect(harness.store.input.events.count == 1)
    }

    @Test("undo deletes the entry by id after the clock has crossed midnight")
    func undoAcrossMidnight() async throws {
        let late = ReduceHarness(atMs: 1_773_176_370_000) // 2026-03-10T23:59:30 Europe/Istanbul
        let vm = await late.subscribedViewModel()
        vm.onEvent(.plusOne)
        await waitUntil("the undo snackbar") { late.snackbar.current != nil }
        let written = try #require(late.store.input.events.first)
        let firstDay = localEpochDay(of: late.clock.nowEpochMilliseconds(), in: late.zone)
        #expect(written.epochDay == firstDay, "the entry is on the first day")

        // The snackbar is still up when the day turns; the entry belongs to yesterday now.
        late.clock.advanceTo(Date(timeIntervalSince1970: 1_773_176_410)) // 2026-03-11T00:00:10
        #expect(
            localEpochDay(of: late.clock.nowEpochMilliseconds(), in: late.zone) == firstDay + 1,
            "the day has turned"
        )
        late.snackbar.performAction()
        await waitUntil("the entry is gone, found by its id") { late.store.input.events.isEmpty }
    }

    @Test("undo still deletes the entry after the screen's ViewModel is gone")
    func undoOutlivesTheViewModel() async {
        var vm: SmokingMainViewModel? = await harness.subscribedViewModel()
        vm?.onEvent(.plusOne)
        await waitUntil("the undo snackbar") { harness.snackbar.current != nil }

        // Back was pressed: the screen's ViewModel is released, the shell's snackbar is still up.
        await Self.release(&vm)
        harness.snackbar.performAction()

        await waitUntil("the undo ran without the ViewModel") { harness.store.input.events.isEmpty }
    }

    @Test("a plus one in flight when the ViewModel goes away still lands")
    func plusOneOutlivesTheViewModel() async {
        var vm: SmokingMainViewModel? = await harness.subscribedViewModel()
        let gate = WriteGate()
        harness.store.gate = gate
        vm?.onEvent(.plusOne)
        await waitUntil("the write is started") { harness.store.calls == 1 }

        await Self.release(&vm)
        gate.open()

        await waitUntil("the entry lands") { harness.store.input.events.count == 1 }
    }

    @Test("a refused plus one is reported through the shell snackbar")
    func refusedPlusOneIsReported() async {
        let vm = await harness.subscribedViewModel()
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.plusOne)
        await waitUntil("the error snackbar") { harness.snackbar.current != nil }

        #expect(harness.snackbar.current?.message == SmokingStrings.errorGeneric)
        #expect(harness.snackbar.current?.actionLabel == nil)
        #expect(!vm.state.writing)
        #expect(vm.pendingEffects.isEmpty, "the Route is not asked: nobody may be listening")
    }

    @Test("a refused undo is reported through the shell snackbar, even with the ViewModel gone")
    func refusedUndoIsReported() async {
        var vm: SmokingMainViewModel? = await harness.subscribedViewModel()
        vm?.onEvent(.plusOne)
        await waitUntil("the undo snackbar") { harness.snackbar.current != nil }
        await Self.release(&vm)
        harness.store.failure = FakeStorageFault()

        harness.snackbar.performAction()
        await waitUntil("the error snackbar") { harness.snackbar.current != nil }

        #expect(harness.snackbar.current?.message == SmokingStrings.errorGeneric)
    }

    @Test("undo removes the entry it names and not the latest one")
    func undoNamesItsEntry() async {
        let vm = await harness.subscribedViewModel()
        for round in 1 ... 2 {
            vm.onEvent(.plusOne)
            await waitUntil("entry \(round)") { harness.store.input.events.count == round }
            await waitUntil("idle") { !vm.state.writing }
        }
        let ids = harness.store.input.events.map(\.id)

        vm.onEvent(.undoPlusOne(eventId: ids[0]))
        await waitUntil("the first entry is gone") { harness.store.input.events.count == 1 }

        #expect(harness.store.input.events.map(\.id) == [ids[1]])
    }

    @Test("undoing twice is harmless")
    func undoingTwiceIsHarmless() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.plusOne)
        await waitUntil("the entry") { harness.store.input.events.count == 1 }
        await waitUntil("idle") { !vm.state.writing }
        let id = harness.store.input.events[0].id
        harness.snackbar.dismiss()

        vm.onEvent(.undoPlusOne(eventId: id))
        vm.onEvent(.undoPlusOne(eventId: id))
        await waitUntil("both undos have run") { harness.store.calls == 3 }
        await Task.yield()

        #expect(harness.store.input.events.isEmpty)
        #expect(harness.snackbar.current == nil, "a repeated undo is not an error")
    }

    @Test("plus one does nothing outside REDUCE")
    func plusOneOutsideReduce() async {
        let quit = ReduceHarness(
            mode: .quit,
            attempts: [QuitAttempt(
                id: "a",
                startedAtMs: 1_773_133_200_000 - dayMs,
                tzId: "Europe/Istanbul",
                endedAtMs: nil,
                endReason: nil
            )]
        )
        let vm = await quit.subscribedViewModel()

        vm.onEvent(.plusOne)
        await Task.yield()

        #expect(quit.store.calls == 0)
        #expect(!vm.state.writing)
    }

    // MARK: None today

    @Test("none today does nothing outside REDUCE")
    func noneTodayOutsideReduce() async {
        let quit = ReduceHarness(
            mode: .quit,
            attempts: [QuitAttempt(
                id: "a",
                startedAtMs: 1_773_133_200_000 - dayMs,
                tzId: "Europe/Istanbul",
                endedAtMs: nil,
                endReason: nil
            )]
        )
        let vm = await quit.subscribedViewModel()

        vm.onEvent(.noneToday)
        await Task.yield()

        #expect(quit.store.calls == 0)
        #expect(!vm.state.writing)
    }

    @Test("none today writes a marker and the offer goes away")
    func noneTodayWritesAMarker() async throws {
        let vm = await harness.subscribedViewModel()
        #expect(try vm.reduce().toView().showNoneToday)

        vm.onEvent(.noneToday)
        await waitUntil("the marker") { (try? vm.reduce().todayHasEntry) == true }

        #expect(harness.store.input.events.first?.units == 0)
        #expect(try !vm.reduce().toView().showNoneToday, "the day has an entry now")
        #expect(try vm.reduce().todayUnits == 0)
    }

    @Test("none today is hidden after a plus one")
    func noneTodayHiddenAfterPlusOne() async throws {
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.plusOne)
        await waitUntil("the entry") { (try? vm.reduce().todayHasEntry) == true }

        #expect(try !vm.reduce().toView().showNoneToday)
    }

    @Test("a plus one after none today replaces the marker")
    func plusOneReplacesTheMarker() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.noneToday)
        await waitUntil("the marker") { (try? vm.reduce().todayHasEntry) == true && !vm.state.writing }

        vm.onEvent(.plusOne)
        await waitUntil("the unit") { (try? vm.reduce().todayUnits) == 1 }

        #expect(harness.store.input.events.map(\.units) == [1])
    }

    @Test("a double tap on none today writes once")
    func doubleTapNoneTodayWritesOnce() async {
        let vm = await harness.subscribedViewModel()
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.noneToday)
        vm.onEvent(.noneToday)
        await waitUntil("the first write is started") { harness.store.calls == 1 }
        gate.open()
        await waitUntil("the write ends") { !vm.state.writing }

        #expect(harness.store.calls == 1)
        #expect(harness.store.input.events.count == 1)
    }

    // MARK: Ready to quit

    @Test("ready to quit opens the date sheet and writes nothing")
    func readyToQuitOpensTheSheet() async {
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.readyToQuit)

        #expect(vm.state.sheet == .quitDate)
        #expect(harness.store.calls == 0)
    }

    @Test("closing the date sheet writes nothing")
    func closingTheSheetWritesNothing() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.readyToQuit)

        vm.onEvent(.quitDateDismissed)

        #expect(vm.state.sheet == nil)
        #expect(harness.store.calls == 0)
    }

    @Test("confirming a date opens a quit attempt at that instant")
    func confirmingOpensAnAttempt() async throws {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.readyToQuit)
        let picked = harness.noon - 2 * dayMs

        vm.onEvent(.quitDateConfirmed(quitAtMs: picked))
        await waitUntil("the screen follows the plan to QUIT") {
            if case .quit = vm.state.snapshot {
                true
            } else {
                false
            }
        }

        #expect(harness.store.input.plan?.mode == .quit)
        let attempt = try #require(harness.store.input.attempts.first)
        #expect(harness.store.input.attempts.count == 1)
        #expect(attempt.startedAtMs == picked)
        #expect(attempt.endedAtMs == nil)
        #expect(vm.state.sheet == nil)
        #expect(!vm.state.writing)
    }

    @Test("a date before the last closed attempt ended is refused and nothing changes")
    func overlapIsRefused() async {
        let overlap = ReduceHarness(attempts: [ReduceHarness().closedAttempt(endedAtMs: 1_773_133_200_000 - dayMs)])
        let vm = await overlap.subscribedViewModel()
        vm.onEvent(.readyToQuit)

        vm.onEvent(.quitDateConfirmed(quitAtMs: overlap.noon - 3 * dayMs))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.quitOverlap)])
        #expect(overlap.store.input.plan?.mode == .reduce)
        #expect(overlap.store.input.attempts.count == 1)
        #expect(vm.state.sheet == .quitDate, "the sheet stays for another try")
        #expect(!vm.state.writing)
    }

    @Test("a future date is refused with its own message")
    func futureIsRefused() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.readyToQuit)

        vm.onEvent(.quitDateConfirmed(quitAtMs: harness.noon + dayMs))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.quitFuture)])
        #expect(harness.store.input.plan?.mode == .reduce)
        #expect(harness.store.input.attempts.isEmpty)
    }

    @Test("a second confirm while the first write is in flight writes once")
    func secondConfirmWritesOnce() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.readyToQuit)
        let gate = WriteGate()
        harness.store.gate = gate

        vm.onEvent(.quitDateConfirmed(quitAtMs: harness.noon))
        vm.onEvent(.quitDateConfirmed(quitAtMs: harness.noon))
        await waitUntil("the first write is started") { harness.store.calls == 1 }
        gate.open()
        await waitUntil("the write ends") { !vm.state.writing }

        #expect(harness.store.calls == 1)
        #expect(harness.store.input.attempts.count == 1)
    }

    @Test("closing the date sheet while its write is in flight is ignored")
    func dismissingDuringTheWriteIsIgnored() async {
        let vm = await harness.subscribedViewModel()
        vm.onEvent(.readyToQuit)
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.quitDateConfirmed(quitAtMs: harness.noon))

        vm.onEvent(.quitDateDismissed)
        #expect(vm.state.sheet == .quitDate)
        gate.open()
        await waitUntil("the sheet closes") { vm.state.sheet == nil }
    }

    @Test("ready to quit opens nothing outside REDUCE")
    func readyToQuitOutsideReduce() async {
        let vm = await MainHarness().subscribedViewModel()

        vm.onEvent(.readyToQuit)

        #expect(vm.state.sheet == nil)
    }

    // MARK: Timeline preview

    @Test("the timeline preview opens the timeline")
    func timelinePreviewNavigates() async {
        let vm = await harness.subscribedViewModel()

        vm.onEvent(.timelinePreviewTapped)
        await waitUntil("the command") { harness.navigator.commandLog.count == 1 }

        #expect(harness.navigator.commandLog == [.navigate(AnyNavKey(SmokingTimelineKey()))])
    }
}
