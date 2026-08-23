import Testing

@testable import SalusUI

// `SalusSnackbarController.kt` has no Kotlin test: on Android the type is a three-line `Channel`
// wrapper and the whole state machine — one snackbar at a time, the queue behind it, the timeout,
// the action result — lives in Material's `SnackbarHostState`/`SnackbarHost`
// (`androidx.compose.material3.SnackbarHost`, `SnackbarHostState.showSnackbar`). iOS has no such
// component, so the iOS controller owns that machine and it is tested here.
//
// The Android behaviour being reproduced, read off the Material sources the app links
// (material3 1.5.0-alpha17, resolved through composeBom 2026.08.00):
//
//   * `SnackbarHostState.showSnackbar(message:actionLabel:withDismissAction:)` defaults the
//     duration to `Short` when there is no action label and `Indefinite` when there is one
//     (`SnackbarHost.kt:104-105`) — and `SalusApp.kt:116-119` calls exactly that overload.
//   * `SnackbarDuration.toMillis` is `Short = 4000`, `Long = 10000`, `Indefinite = Long.MAX_VALUE`
//     (`SnackbarHost.kt:302-307`); `SnackbarHost` delays that long and then dismisses
//     (`SnackbarHost.kt:226-232`).
//   * `showSnackbar` suspends until the snackbar goes away, and `SalusApp.kt:115` collects the
//     request channel sequentially, so a second request waits for the first — the queue below.
//   * The action callback runs only on `SnackbarResult.ActionPerformed` (`SalusApp.kt:121`).
@MainActor
@Suite("SalusSnackbarController")
struct SalusSnackbarControllerTests {
    @Test("the duration table is Material's (SnackbarHost.kt:302-307)")
    func durationTableIsMaterials() {
        #expect(SnackbarDuration.short.timeoutMillis == 4000)
        #expect(SnackbarDuration.long.timeoutMillis == 10000)
        // Kotlin says `Long.MAX_VALUE`, which is "never" spelled as a number; Swift says nil.
        #expect(SnackbarDuration.indefinite.timeoutMillis == nil)
    }

    @Test("an explicit timeout is carried through unchanged")
    func explicitTimeoutIsCarriedThroughUnchanged() {
        // The fourth case exists for a snackbar whose lifetime belongs to something else's clock —
        // today only the undo snackbar, which borrows `PendingDeleteController`'s window. Material
        // has no equivalent, which is why it sits beside the three ported cases rather than in them.
        #expect(SnackbarDuration.milliseconds(5000).timeoutMillis == 5000)
        #expect(SnackbarRequest(message: "Deleted", duration: .milliseconds(1234)).duration
            == .milliseconds(1234))
    }

    @Test("an action label makes the request indefinite, its absence makes it short (SnackbarHost.kt:104-105)")
    func durationDefaultFollowsTheActionLabel() {
        #expect(SnackbarRequest(message: "Deleted").duration == .short)
        #expect(SnackbarRequest(message: "Deleted", actionLabel: "Undo").duration == .indefinite)
        // An explicit duration still wins, the way passing `duration =` to `showSnackbar` does.
        #expect(SnackbarRequest(message: "Deleted", actionLabel: "Undo", duration: .long).duration == .long)
    }

    @Test("show presents the request at once")
    func showPresentsTheRequestAtOnce() {
        let controller = SalusSnackbarController(sleep: { _ in })

        controller.show(SnackbarRequest(message: "Weight deleted", actionLabel: "Geri al"))

        #expect(controller.current?.message == "Weight deleted")
        #expect(controller.current?.actionLabel == "Geri al")
    }

    @Test("a request with no action is dismissed after Android's short duration")
    func requestWithNoActionIsDismissedAfterShortDuration() async {
        let gate = SnackbarSleepGate()
        let controller = SalusSnackbarController(sleep: { try await gate.sleep($0) })

        controller.show(SnackbarRequest(message: "Saved"))
        await gate.waitForArrivals(1)
        let requested = await gate.durations

        #expect(requested == [.milliseconds(4000)])
        #expect(controller.current != nil)

        await gate.fire()
        await controller.timeoutTask?.value

        #expect(controller.current == nil)
    }

    @Test("a request with an undo action never times out")
    func requestWithAnUndoActionNeverTimesOut() async {
        let gate = SnackbarSleepGate()
        let controller = SalusSnackbarController(sleep: { try await gate.sleep($0) })

        controller.show(SnackbarRequest(message: "Weight deleted", actionLabel: "Geri al", onAction: {}))

        let requested = await gate.durations

        #expect(controller.timeoutTask == nil)
        #expect(requested.isEmpty)
        #expect(controller.current != nil)
    }

    @Test("the action runs once and takes the snackbar away (SalusApp.kt:121)")
    func actionRunsOnceAndTakesTheSnackbarAway() {
        var undone = 0
        let controller = SalusSnackbarController(sleep: { _ in })
        controller.show(
            SnackbarRequest(message: "Weight deleted", actionLabel: "Geri al", onAction: { undone += 1 })
        )

        controller.performAction()
        controller.performAction()

        #expect(undone == 1)
        #expect(controller.current == nil)
    }

    @Test("dismissing runs no action (SalusApp.kt:121 only fires on ActionPerformed)")
    func dismissingRunsNoAction() {
        var undone = 0
        let controller = SalusSnackbarController(sleep: { _ in })
        controller.show(
            SnackbarRequest(message: "Weight deleted", actionLabel: "Geri al", onAction: { undone += 1 })
        )

        controller.dismiss()

        #expect(undone == 0)
        #expect(controller.current == nil)
    }

    @Test("a second request waits for the first, then shows in order")
    func secondRequestWaitsForTheFirst() {
        let controller = SalusSnackbarController(sleep: { _ in })

        controller.show(SnackbarRequest(message: "first", actionLabel: "Geri al"))
        controller.show(SnackbarRequest(message: "second", actionLabel: "Geri al"))
        controller.show(SnackbarRequest(message: "third", actionLabel: "Geri al"))

        #expect(controller.current?.message == "first")
        controller.dismiss()
        #expect(controller.current?.message == "second")
        controller.dismiss()
        #expect(controller.current?.message == "third")
        controller.dismiss()
        #expect(controller.current == nil)
    }

    @Test("dismissing with nothing showing is a no-op")
    func dismissingWithNothingShowingIsANoOp() {
        let controller = SalusSnackbarController(sleep: { _ in })

        controller.dismiss()
        controller.performAction()

        #expect(controller.current == nil)
    }

    @Test("the queued request starts its own timeout when it comes up")
    func queuedRequestStartsItsOwnTimeout() async {
        let gate = SnackbarSleepGate()
        let controller = SalusSnackbarController(sleep: { try await gate.sleep($0) })

        controller.show(SnackbarRequest(message: "first"))
        controller.show(SnackbarRequest(message: "second", duration: .long))
        await gate.waitForArrivals(1)

        await gate.fire()
        await controller.timeoutTask?.value
        #expect(controller.current?.message == "second")

        await gate.waitForArrivals(2)
        let requested = await gate.durations
        #expect(requested == [.milliseconds(4000), .milliseconds(10000)])

        // Drain the second timer too, so no test ends with a suspended continuation.
        await gate.fire()
        await controller.timeoutTask?.value
        #expect(controller.current == nil)
    }
}
