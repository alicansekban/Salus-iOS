// Ported from the timer, rhythm and lines cases of `feature/smoking/src/test/kotlin/com/alicansekban/
// salus/feature/smoking/ui/craving/CravingViewModelTest.kt`. The writes and exits are in
// `CravingWriteTests`.
//
// Two Kotlin cases change meaning. Android keeps the start instant in `SavedStateHandle`, so a
// ViewModel rebuilt after process death carries on from the original start; iOS keeps nothing across
// a termination (plan Task 12: "the VM is recreated after termination, which writes nothing"), so
// the rebuilt ViewModel begins a fresh five minutes and writes nothing. What survives is
// BACKGROUNDING: the start instant is held, the clock keeps running, and the first read after the
// app comes back is what carries the time spent away (review focus 1).

import Foundation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("CravingViewModel timer and lines", .timeLimit(.minutes(1)))
struct CravingTimerTests {
    let harness = CravingHarness()

    // MARK: Timer

    @Test("a fresh screen has the whole five minutes left and starts on the in-breath")
    func freshScreen() async {
        let vm = await harness.readyViewModel()

        #expect(vm.state.remainingMs == 300_000)
        #expect(vm.state.phase == .inhale)
        #expect(!vm.state.completed)
    }

    @Test("the remaining time follows the clock, not a counter")
    func followsTheClock() async {
        let vm = await harness.readyViewModel()

        harness.setClock(secondsAfterStart: 100)
        vm.refreshClock()

        #expect(vm.state.remainingMs == 200_000)
    }

    @Test("backgrounding does not stop the timer: the first read after coming back catches up")
    func backgroundingCatchesUp() async {
        let vm = await harness.readyViewModel()
        harness.setClock(secondsAfterStart: 30)
        vm.refreshClock()

        // The app is in the background for two and a half minutes: the ticker is not running, nothing reads the
        // clock, and the state is as it was.
        harness.setClock(secondsAfterStart: 180)
        #expect(vm.state.remainingMs == 270_000)

        // Foreground again: one read, and the time spent away is in it.
        vm.refreshClock()
        #expect(vm.state.remainingMs == 120_000)
    }

    @Test("six minutes away leaves the flow completed and writes nothing")
    func sixMinutesAwayCompletes() async {
        let vm = await harness.readyViewModel()

        harness.setClock(secondsAfterStart: 6 * 60)
        vm.refreshClock()

        #expect(vm.state.remainingMs == 0)
        #expect(vm.state.completed)
        // Completed to look at only: nothing was written on the person's behalf.
        #expect(harness.store.commits == 0)
        #expect(!vm.state.logged)
    }

    @Test("a ViewModel recreated after termination starts afresh and writes nothing")
    func recreatedAfterTerminationWritesNothing() async {
        let first = await harness.readyViewModel()
        harness.setClock(secondsAfterStart: 6 * 60)
        first.refreshClock()
        #expect(first.state.completed)

        // The process was killed and the screen is opened again: a new ViewModel, a new start.
        let second = await harness.readyViewModel()

        #expect(second.state.remainingMs == 300_000)
        #expect(!second.state.completed)
        #expect(!second.state.logged)
        #expect(harness.store.calls == 0)
    }

    @Test("a clock set back past the start reads as the beginning")
    func clockSetBack() async {
        let vm = await harness.readyViewModel()

        harness.setClock(secondsAfterStart: -60)
        vm.refreshClock()

        #expect(vm.state.elapsedMs == 0)
        #expect(vm.state.remainingMs == 300_000)
    }

    @Test("the ticker stops once the five minutes are up")
    func tickerStopsAtTheEnd() async {
        let vm = await harness.readyViewModel()
        harness.setClock(secondsAfterStart: 300)

        await vm.runClock()

        #expect(vm.state.completed)
    }

    @Test("the ticker reads the clock as soon as it starts")
    func tickerReadsFirst() async {
        let vm = await harness.readyViewModel()
        harness.setClock(secondsAfterStart: 100)

        let ticker = Task { await vm.runClock() }
        await waitUntil("the first read") { vm.state.elapsedMs == 100_000 }
        ticker.cancel()
        await ticker.value

        #expect(vm.state.remainingMs == 200_000)
    }

    // MARK: Breathing rhythm

    @Test("the phases are 4 seconds in, 4 held and 6 out")
    func phaseBoundaries() {
        let phases = [0, 3999, 4000, 7999, 8000, 13999].map { breathPhaseAt(elapsedMs: Int64($0)) }

        #expect(phases == [.inhale, .inhale, .hold, .hold, .exhale, .exhale])
    }

    @Test("the countdown reads minutes and seconds and rounds a part second up")
    func countdownFormat() {
        #expect(countdownText(remainingMs: 300_000) == "05:00")
        #expect(countdownText(remainingMs: 299_000) == "04:59")
        #expect(countdownText(remainingMs: 298_001) == "04:59")
        #expect(countdownText(remainingMs: 1) == "00:01")
        #expect(countdownText(remainingMs: 0) == "00:00")
        #expect(countdownText(remainingMs: -5) == "00:00")
    }

    @Test("nine seconds in is the out-breath")
    func nineSecondsIsTheOutBreath() async {
        let vm = await harness.readyViewModel()

        harness.setClock(secondsAfterStart: 9)
        vm.refreshClock()

        #expect(vm.state.phase == .exhale)
    }

    @Test("the rhythm restarts every 14 seconds")
    func rhythmRestarts() async {
        let vm = await harness.readyViewModel()

        harness.setClock(secondsAfterStart: 14)
        vm.refreshClock()

        #expect(vm.state.phase == .inhale)
    }

    // MARK: Lines

    @Test("the lines are built from the snapshot and end with the breath reminder")
    func linesFromTheSnapshot() async {
        let quit = CravingHarness(reason: "Kızım için")
        let vm = await quit.readyViewModel()

        let lines = vm.state.lines
        #expect(lines.count == 4)
        #expect(lines[0] == .smokeFreeDays(42))
        guard case let .saved(minor, currencyCode) = lines[1] else {
            Issue.record("the second line is not the savings")
            return
        }
        #expect(currencyCode == "TRY")
        #expect(minor > 0)
        guard case .nextStage = lines[2] else {
            Issue.record("the third line is not the next stage")
            return
        }
        #expect(lines.last == .focus)
        #expect(vm.state.reason == "Kızım için")
    }

    @Test("the shown line moves on every 8 seconds")
    func lineRotates() async {
        let vm = await harness.readyViewModel()
        #expect(vm.state.line == vm.state.lines[0])

        harness.setClock(secondsAfterStart: 8)
        vm.refreshClock()
        #expect(vm.state.line == vm.state.lines[1])

        harness.setClock(secondsAfterStart: 16)
        vm.refreshClock()
        #expect(vm.state.line == vm.state.lines[2])
    }

    @Test("a blank reason is no reason")
    func blankReason() async {
        let blank = CravingHarness(reason: "  ")
        let vm = await blank.readyViewModel()

        #expect(vm.state.reason == nil)
    }

    @Test("a REDUCE plan has no stage line and no days line, and the mode is known")
    func reduceLines() async {
        let reduce = CravingHarness(mode: .reduce)
        let vm = await reduce.readyViewModel()

        #expect(vm.state.mode == .reduce)
        #expect(vm.state.lines.allSatisfy { line in
            switch line {
            case .nextStage, .smokeFreeDays: false
            case .focus, .saved: true
            }
        })
        #expect(vm.state.lines.last == .focus)
    }
}
