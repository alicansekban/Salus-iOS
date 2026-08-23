// Ported from `core/ui/.../snackbar/UndoableDelete.kt:12-31`, with one recorded behaviour
// difference — the snackbar's duration.
//
// Android passes an action label and no duration, and Material3 reads that as
// `SnackbarDuration.Indefinite` (`SnackbarHost.kt:104-105`), so the undo snackbar outlives the 5 s
// undo window: from the sixth second it offers an "UNDO" that has already committed, and it holds
// the host's queue while it does. iOS-M2 shipped that faithfully and opened the fix as Android
// §11 A10; the 2026-08-23 simulator pass confirmed how bad it reads, and the user ruled that the
// undo snackbar auto-dismisses when the undo window closes. iOS lands its half here. A10 stays
// open for Android, and until it closes this is a divergence, not a port bug.

import SalusCommon

/// The one call every delete site makes after the user confirms: hold the write for the
/// undo window and offer the undo. Keeping it in one place is what stops six screens from
/// each growing their own copy of the schedule/snackbar/undo wiring (`UndoableDelete.kt:7-11`).
@MainActor
public struct UndoableDelete {
    private let pendingDeletes: PendingDeleteController
    private let snackbar: SalusSnackbarController

    public init(pendingDeletes: PendingDeleteController, snackbar: SalusSnackbarController) {
        self.pendingDeletes = pendingDeletes
        self.snackbar = snackbar
    }

    /// - Parameters:
    ///   - id: the record's id; list screens filter it out while the window is open.
    ///   - message: what the snackbar says, e.g. "Kilo kaydı silindi". Kotlin takes a
    ///     `@StringRes messageRes` (`UndoableDelete.kt:21`); the iOS twin takes the already
    ///     localised text, because the feature owns the `Bundle.module` it comes from and the
    ///     shell that draws the snackbar cannot reach it.
    ///   - commit: the repository call that actually deletes, run when the window closes.
    ///
    /// `operator fun invoke` becomes `callAsFunction`, so the call site reads the same on both
    /// platforms: `undoableDelete(id, message: …) { … }`.
    public func callAsFunction(
        _ id: String,
        message: String,
        commit: @escaping @Sendable () async -> Void
    ) {
        pendingDeletes.schedule(id: id, commit: commit)
        snackbar.show(
            SnackbarRequest(
                message: message,
                actionLabel: SalusUIStrings.undo,
                onAction: { pendingDeletes.undo(id: id) },
                // The snackbar lives exactly as long as the thing it offers to take back.
                // Naming the duration here — rather than changing the controller's default — is
                // what keeps `SalusSnackbarController` a generic host: Material's rule (an action
                // label means indefinite) is still right for a snackbar that waits for the user,
                // and wrong only for this one, whose action expires on someone else's clock.
                // Derived from the window itself, never a second literal 5000: the two cannot
                // drift apart because there is only one number.
                duration: .milliseconds(PendingDeleteController.undoWindowMillis)
            )
        )
    }
}
