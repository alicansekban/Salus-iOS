// Ported from Android
// `core/reminder/src/main/kotlin/com/alicansekban/salus/core/reminder/engine/HandleReminderActionUseCase.kt`.
//
// The one place the engine reacts to a user answering a fired reminder, whichever surface asked the
// question. Android has two callers — the notification's `ReminderActionReceiver` and the alarm
// screen — and both arrive with a request code; iOS has two callers with two different identities:
//
//  * the alarm surface (AlarmKit) runs an `AppIntent` that knows only the request code, so the
//    occurrence is read out of the ledger — Kotlin's `dao.getByRequestCode(...)`, verbatim;
//  * the notification surface (``ReminderNotificationDelegate``) is handed the occurrence identity
//    in `userInfo`, so there is nothing to look up and the pipeline starts one step later.
//
// Hence the two entry points over one body. Two deltas from Kotlin, both deliberate:
//
//  1. Kotlin returns early — and skips the sync — when the ledger does not carry the request code.
//     Here the refill always runs: it is a property of the event having happened, not of the
//     occurrence still being known, and skipping it leaves the rolling window one slot short until
//     the next background pass. Same reasoning as the delegate's swallowed handler error.
//  2. Kotlin's `presenter.dismiss(alarm)` has no line here. Dismissing the fired notification is the
//     OS's own doing on iOS, and stopping the alarm is AlarmKit's — the intent that ran this is
//     itself what ends the alert.

import Foundation
import os
import SalusDatabase
import SalusModel

/// Delegates one answered reminder to the feature that owns it, then refills the window.
///
/// A struct with no state of its own beyond its three collaborators, so an `AppIntent` — which the
/// system may instantiate in a process that has just been launched to run it — can build one from
/// the composition root's graph and call it without ceremony.
public struct ReminderActionDispatcher: Sendable {
    private static let logger = Logger(subsystem: "com.alicansekban.salus", category: "reminder")

    private let alarmDao: ReminderAlarmDao?
    private let registry: ReminderHandlerRegistry
    private let synchronizer: any ReminderWindowSyncing

    /// - Parameter alarmDao: the ledger a request code is resolved against, or nil for a dispatcher
    ///   that only ever serves ``perform(ref:actionId:)``. The notification path passes nil: its
    ///   occurrence identity travels in `userInfo`, so it has no request code to resolve and no
    ///   business holding a database handle to prove it.
    public init(
        alarmDao: ReminderAlarmDao?,
        registry: ReminderHandlerRegistry,
        synchronizer: any ReminderWindowSyncing
    ) {
        self.alarmDao = alarmDao
        self.registry = registry
        self.synchronizer = synchronizer
    }

    /// The alarm surface's entry point: all the OS hands back is the code the alarm was scheduled
    /// under (`HandleReminderActionUseCase.kt:18`).
    public func perform(requestCode: Int32, actionId: String) async {
        if let ref = await ref(of: requestCode) {
            await dispatch(ref: ref, actionId: actionId)
        }
        await synchronizer.sync()
    }

    /// The notification surface's entry point, which already knows which occurrence it is about.
    public func perform(ref: ReminderRef, actionId: String) async {
        await dispatch(ref: ref, actionId: actionId)
        await synchronizer.sync()
    }

    /// The occurrence one request code stands for, or nil when the ledger no longer carries it —
    /// an alarm the engine has already reconciled away, or one scheduled by a build whose window
    /// has since been rebuilt.
    private func ref(of requestCode: Int32) async -> ReminderRef? {
        guard let alarmDao else { return nil }

        do {
            guard
                let row = try await alarmDao.getByRequestCode(Int(requestCode)),
                let type = ReminderType(rawValue: row.type)
            else {
                return nil
            }
            return ReminderRef(type: type, entityId: row.entityId, occurrenceKey: row.occurrenceKey)
        } catch {
            // A ledger that cannot be read is a broken database, which nothing at this level can
            // repair. The refill below still runs and will fail the same way, loudly, in the
            // synchronizer's own log.
            Self.logger.error("reminder ledger unreadable: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    /// Kotlin's `handler?.onAction(...)`: an unregistered type is a no-op.
    private func dispatch(ref: ReminderRef, actionId: String) async {
        guard let handler = registry.forType(ref.type) else { return }

        do {
            try await handler.onAction(ref: ref, actionId: actionId)
        } catch {
            // There is nobody to report to. The notification delegate's error is discarded by the
            // OS, and an `AppIntent` that rethrew would show the user a system failure alert for a
            // dose that may well have been recorded. So it is absorbed, and the log is the only
            // trace — with the error text private, because a feature's failure can name what the
            // user recorded.
            Self.logger.error(
                """
                reminder action not handled \
                (type=\(ref.type.rawValue, privacy: .public), action=\(actionId, privacy: .public)): \
                \(String(describing: error), privacy: .private)
                """
            )
        }
    }
}
