import Testing

@testable import SalusCommon

// The six Kotlin cases from
// `salus-android/core/common/src/test/.../PendingDeleteControllerTest.kt:17-98`, ported one for
// one and by name.
//
// Kotlin drives the undo window with `runTest`'s virtual clock: `advanceTimeBy` walks into the
// middle of a window and `advanceUntilIdle` closes it. Swift Testing has no virtual clock, so the
// wait itself is what the test owns — `PendingDeleteController` takes its sleep as a parameter and
// `UndoWindowGate` below holds every window open until the test opens it. Nothing here ever waits
// on wall-clock time, and no assertion depends on how fast the machine is.
//
// `advanceUntilIdle`'s other half — "all scheduled work has finished" — is the window task itself:
// the tests capture it through `windowTask(id:)` and await its value, which is a stronger
// statement than a drained scheduler because it names the one task whose result is being asserted.

/// A stand-in for the undo window's wait, opened by the test rather than by the clock.
actor UndoWindowGate {
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var arrivals = 0
    private var arrivalWatchers: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []

    /// The injected sleep: suspends until `open()`, and returns straight away once it is open.
    func wait() async {
        arrivals += 1
        releaseArrivalWatchers()
        if isOpen {
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Suspends until `count` windows have reached the gate.
    ///
    /// This is what makes "nothing is written inside the window" a real assertion rather than a
    /// vacuous one: without it the window task might simply not have started yet.
    func waitForArrivals(_ count: Int) async {
        if arrivals >= count {
            return
        }
        await withCheckedContinuation { arrivalWatchers.append((count, $0)) }
    }

    /// Closes every open window at once, and lets every later one through unimpeded.
    func open() {
        isOpen = true
        let resumed = waiting
        waiting = []
        for continuation in resumed {
            continuation.resume()
        }
    }

    private func releaseArrivalWatchers() {
        let reached = arrivalWatchers.filter { arrivals >= $0.target }
        arrivalWatchers.removeAll { arrivals >= $0.target }
        for watcher in reached {
            watcher.continuation.resume()
        }
    }
}

/// The commits that actually ran, in order — the Swift twin of Kotlin's `mutableListOf<String>()`.
actor CommitLog {
    private(set) var ids: [String] = []

    func record(_ id: String) {
        ids.append(id)
    }
}

@MainActor
@Suite("PendingDeleteController (Android parity)")
struct PendingDeleteControllerTests {
    /// The window Kotlin's test uses (`PendingDeleteControllerTest.kt:101`). Only its identity
    /// matters here — the gate, not the number, decides when a window closes.
    static let window = 5000

    @Test("the undo window is the Android constant")
    func theUndoWindowIsTheAndroidConstant() {
        // PendingDeleteController.kt:78
        #expect(PendingDeleteController.undoWindowMillis == 5000)
    }

    @Test("the commit runs only once the window closes")
    func theCommitRunsOnlyOnceTheWindowCloses() async {
        let log = CommitLog()
        let gate = UndoWindowGate()
        let controller = PendingDeleteController(windowMillis: Self.window) { _ in await gate.wait() }

        controller.schedule(id: "a") { await log.record("a") }
        let window = controller.windowTask(id: "a")

        #expect(controller.pendingIds == ["a"])
        await gate.waitForArrivals(1)
        let insideTheWindow = await log.ids
        #expect(insideTheWindow.isEmpty, "nothing is written inside the window")

        await gate.open()
        await window?.value

        let committed = await log.ids
        #expect(committed == ["a"])
        #expect(controller.pendingIds.isEmpty)
    }

    @Test("undo cancels the commit and clears the id")
    func undoCancelsTheCommitAndClearsTheId() async {
        let log = CommitLog()
        let gate = UndoWindowGate()
        let controller = PendingDeleteController(windowMillis: Self.window) { _ in await gate.wait() }

        controller.schedule(id: "a") { await log.record("a") }
        let window = controller.windowTask(id: "a")
        await gate.waitForArrivals(1)
        controller.undo(id: "a")

        // `undo` cancels the window rather than leaving it to find an empty commit map
        // (`PendingDeleteController.kt:54`).
        #expect(window?.isCancelled == true)

        // Letting the cancelled window run to completion is the assertion Kotlin gets from
        // `advanceUntilIdle`: the task finishes and still writes nothing.
        await gate.open()
        await window?.value

        let committed = await log.ids
        #expect(committed.isEmpty)
        #expect(controller.pendingIds.isEmpty)
    }

    @Test("commitAll closes every open window immediately")
    func commitAllClosesEveryOpenWindowImmediately() async {
        let log = CommitLog()
        let gate = UndoWindowGate()
        let controller = PendingDeleteController(windowMillis: Self.window) { _ in await gate.wait() }

        controller.schedule(id: "a") { await log.record("a") }
        controller.schedule(id: "b") { await log.record("b") }
        let windowA = controller.windowTask(id: "a")
        let windowB = controller.windowTask(id: "b")
        await gate.waitForArrivals(2)

        await controller.commitAll()

        let committed = await log.ids
        #expect(Set(committed) == ["a", "b"])
        #expect(controller.pendingIds.isEmpty)

        // The windows that were still open must add nothing when they finally close.
        await gate.open()
        await windowA?.value
        await windowB?.value
        let afterTheWindows = await log.ids
        #expect(afterTheWindows.count == 2)
    }

    @Test("a commit runs once even when the window would close later")
    func aCommitRunsOnceEvenWhenTheWindowWouldCloseLater() async {
        let log = CommitLog()
        let gate = UndoWindowGate()
        let controller = PendingDeleteController(windowMillis: Self.window) { _ in await gate.wait() }

        controller.schedule(id: "a") { await log.record("a") }
        let window = controller.windowTask(id: "a")
        await gate.waitForArrivals(1)

        await controller.commitNow(id: "a")
        await gate.open()
        await window?.value

        let committed = await log.ids
        #expect(committed.count == 1)
        #expect(controller.pendingIds.isEmpty)
    }

    @Test("undoing after the window closed does not resurrect anything")
    func undoingAfterTheWindowClosedDoesNotResurrectAnything() async {
        let log = CommitLog()
        let gate = UndoWindowGate()
        let controller = PendingDeleteController(windowMillis: Self.window) { _ in await gate.wait() }

        controller.schedule(id: "a") { await log.record("a") }
        let window = controller.windowTask(id: "a")
        await gate.open()
        await window?.value

        controller.undo(id: "a")

        let committed = await log.ids
        #expect(committed == ["a"])
        #expect(controller.pendingIds.isEmpty)
    }

    @Test("scheduling the same id twice keeps a single pending deletion")
    func schedulingTheSameIdTwiceKeepsASinglePendingDeletion() async {
        let log = CommitLog()
        let gate = UndoWindowGate()
        let controller = PendingDeleteController(windowMillis: Self.window) { _ in await gate.wait() }

        controller.schedule(id: "a") { await log.record("first") }
        let firstWindow = controller.windowTask(id: "a")
        await gate.waitForArrivals(1)

        // Kotlin re-schedules half a window in; here the first window is provably still open.
        controller.schedule(id: "a") { await log.record("second") }
        let secondWindow = controller.windowTask(id: "a")
        await gate.waitForArrivals(2)
        #expect(controller.pendingIds == ["a"])

        // The replaced job is cancelled, not merely orphaned (`PendingDeleteController.kt:43`).
        // Asserted on the handle because the commit map hides the difference: whichever window
        // closes first finds the one stored commit, so the counts below stay right either way and
        // only the *timing* of the write would be wrong.
        #expect(firstWindow?.isCancelled == true)
        #expect(secondWindow?.isCancelled == false)

        await gate.open()
        await firstWindow?.value
        await secondWindow?.value

        // One commit, and it is the replacement's: `schedule` overwrites the stored commit as
        // well as cancelling the job (`PendingDeleteController.kt:42-50`).
        let committed = await log.ids
        #expect(committed == ["second"])
        #expect(controller.pendingIds.isEmpty)
    }
}
