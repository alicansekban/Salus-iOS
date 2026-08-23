// Ported from
// `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/TestDeletes.kt`.
//
// Two shape differences, both forced by decisions already taken in this port:
//
//   * `RecordingSnackbarController` has no twin. Kotlin's `SalusSnackbarController` is an interface
//     whose only implementation is a `Channel` wrapper, so a test that wants to see the request has
//     to substitute one. The iOS port collapsed the interface into one `@Observable` class that
//     holds the whole Material state machine (`SalusSnackbarController.swift:10-18`), and that
//     class already exposes what was recorded — `current` is the request on screen. Substituting it
//     would test a stand-in instead of the machine the app runs, which is the opposite of what
//     `TestDeletes.kt:22-25` exists for.
//   * The undo window's wait is injected. Kotlin gets a virtual clock from `runTest`; Swift Testing
//     has none, so `PendingDeleteController` takes its `sleep` as a parameter and the gate below is
//     what a test opens by hand. Same seam `PendingDeleteControllerTests` and
//     `SalusSnackbarControllerTests` already use — no test in this package waits on the clock.

import Foundation
import SalusCommon
import SalusUI

/// The real deferred-delete wiring over a test-scoped controller, so tests assert on the behaviour
/// the app actually runs rather than on a stand-in (`TestDeletes.kt:22-35`).
@MainActor
final class TestDeletes {
    let snackbar: SalusSnackbarController
    let controller: PendingDeleteController
    let undoableDelete: UndoableDelete

    /// Held open until `closeUndoWindow()`; a delete's write therefore cannot happen behind a
    /// test's back.
    private let window = SleepGate()

    /// Kotlin takes a `windowMillis` (`TestDeletes.kt:26`); this does not. The gate below ignores
    /// the duration it is handed — what a test controls is *when* the window closes, not how long
    /// it claims to be — so a parameter here would be a number with no effect.
    init() {
        let window = window
        snackbar = SalusSnackbarController(sleep: window.sleep)
        controller = PendingDeleteController(sleep: window.sleep)
        undoableDelete = UndoableDelete(pendingDeletes: controller, snackbar: snackbar)
    }

    /// What the last delete published, or nil when nothing is on screen. The twin of
    /// `RecordingSnackbarController.shown.last()`.
    var lastRequest: SnackbarRequest? {
        snackbar.current
    }

    /// Invokes the snackbar action the last delete published (`TestDeletes.kt:31-34`).
    func undoLast() {
        snackbar.performAction()
    }

    /// Lets every open undo window run to its end — the twin of `advanceUntilIdle()` closing the
    /// 5-second `delay` in `PendingDeleteController`.
    ///
    /// The commit that follows is asynchronous, so a caller still reads the repository through
    /// `waitUntil`.
    func closeUndoWindow() async {
        await window.open()
    }
}

/// A wait that blocks until it is opened, then never blocks again.
///
/// Injected as `PendingDeleteController`'s `sleep`, this is the whole undo window: while the gate
/// is shut the deletion is deferred, and opening it is the moment the window would have elapsed.
private actor SleepGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    /// The closure `PendingDeleteController(sleep:)` takes. The duration is ignored on purpose:
    /// what a test needs to control is *when* the window closes, not how long it claims to be.
    nonisolated var sleep: @Sendable (Duration) async throws -> Void {
        { _ in await self.wait() }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for waiter in pending {
            waiter.resume()
        }
    }

    private func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
