// Ported 1:1 from `core/ui/.../snackbar/UndoableDelete.kt:12-31`.

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
                onAction: { pendingDeletes.undo(id: id) }
            )
        )
    }
}
