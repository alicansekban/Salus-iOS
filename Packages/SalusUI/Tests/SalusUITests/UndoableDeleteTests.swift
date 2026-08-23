import SalusCommon
import Testing

@testable import SalusUI

/// The commits that actually ran, and a way to wait for one without watching the clock.
actor DeleteLog {
    private(set) var ids: [String] = []
    private var watchers: [CheckedContinuation<Void, Never>] = []

    func record(_ id: String) {
        ids.append(id)
        let resumed = watchers
        watchers = []
        for continuation in resumed {
            continuation.resume()
        }
    }

    /// Suspends until at least one commit has been written.
    func waitForFirstCommit() async {
        if !ids.isEmpty {
            return
        }
        await withCheckedContinuation { watchers.append($0) }
    }
}

/// `UndoableDelete.kt` has no Kotlin test either — it is four lines of wiring, and the wiring is
/// exactly what a port can get wrong (the write happening now instead of at the end of the window,
/// the undo action not reaching `PendingDeleteController`, the action label missing so the snackbar
/// carries no way back). Those three are what this suite pins.
@MainActor
@Suite("UndoableDelete")
struct UndoableDeleteTests {
    @Test("the write is held for the undo window and the snackbar offers the way back (UndoableDelete.kt:21-29)")
    func writeIsHeldAndSnackbarOffersTheWayBack() async {
        let gate = SnackbarSleepGate()
        let log = DeleteLog()
        let pendingDeletes = PendingDeleteController(sleep: { try await gate.sleep($0) })
        let snackbar = SalusSnackbarController(sleep: { _ in })
        let delete = UndoableDelete(pendingDeletes: pendingDeletes, snackbar: snackbar)

        delete("entry-1", message: "Kilo kaydı silindi") { await log.record("entry-1") }
        await gate.waitForArrivals(1)
        let committed = await log.ids

        #expect(pendingDeletes.pendingIds == ["entry-1"])
        #expect(committed.isEmpty)
        #expect(snackbar.current?.message == "Kilo kaydı silindi")
        // Against the accessor, not against "Geri al": under `swift test` the catalog is not
        // compiled (see `SalusUIStrings.swift`), so the literal would be wrong here and right in
        // the app. What matters is that the label comes from `salus_undo` and from nowhere else;
        // `SalusUIStringsTests` pins the two translations behind that key.
        #expect(snackbar.current?.actionLabel == SalusUIStrings.undo)

        await gate.fire()
    }

    @Test("the snackbar action undoes the pending delete and nothing is written (UndoableDelete.kt:27)")
    func snackbarActionUndoesThePendingDelete() async {
        let gate = SnackbarSleepGate()
        let log = DeleteLog()
        let pendingDeletes = PendingDeleteController(sleep: { try await gate.sleep($0) })
        let snackbar = SalusSnackbarController(sleep: { _ in })
        let delete = UndoableDelete(pendingDeletes: pendingDeletes, snackbar: snackbar)

        delete("entry-1", message: "Kilo kaydı silindi") { await log.record("entry-1") }
        await gate.waitForArrivals(1)

        snackbar.performAction()
        await gate.fire()
        let committed = await log.ids

        #expect(pendingDeletes.pendingIds.isEmpty)
        #expect(committed.isEmpty)
        #expect(snackbar.current == nil)
    }

    @Test("letting the window close writes the delete (PendingDeleteController.kt:42-50)")
    func lettingTheWindowCloseWritesTheDelete() async {
        let gate = SnackbarSleepGate()
        let log = DeleteLog()
        let pendingDeletes = PendingDeleteController(sleep: { try await gate.sleep($0) })
        let snackbar = SalusSnackbarController(sleep: { _ in })
        let delete = UndoableDelete(pendingDeletes: pendingDeletes, snackbar: snackbar)

        delete("entry-1", message: "Kilo kaydı silindi") { await log.record("entry-1") }
        await gate.waitForArrivals(1)
        await gate.fire()
        await log.waitForFirstCommit()
        let committed = await log.ids

        #expect(committed == ["entry-1"])
        #expect(pendingDeletes.pendingIds.isEmpty)
    }

    @Test("the undo window is the one PendingDeleteController owns, unchanged (5000 ms)")
    func undoWindowIsTheOnePendingDeleteControllerOwns() async {
        let gate = SnackbarSleepGate()
        let pendingDeletes = PendingDeleteController(sleep: { try await gate.sleep($0) })
        let snackbar = SalusSnackbarController(sleep: { _ in })
        let delete = UndoableDelete(pendingDeletes: pendingDeletes, snackbar: snackbar)

        delete("entry-1", message: "Kilo kaydı silindi") {}
        await gate.waitForArrivals(1)
        let requested = await gate.durations

        #expect(requested == [.milliseconds(PendingDeleteController.undoWindowMillis)])

        await gate.fire()
    }
}
