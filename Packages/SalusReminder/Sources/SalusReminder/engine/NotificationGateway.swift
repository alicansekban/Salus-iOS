// The iOS twin of Android
// `core/reminder/src/main/kotlin/.../engine/AlarmGateway.kt`, widened where the two platforms
// genuinely differ. Implemented in `SalusNotifications` over `UNUserNotificationCenter`; nothing
// in this package imports UserNotifications, which is the whole reason the seam exists.
//
// Three shape differences from `AlarmGateway`, each forced by the platform:
//
//  * `schedule` carries the **content**. An AlarmManager alarm is an empty PendingIntent whose
//    receiver builds the notification when it fires; on iOS nothing of ours runs at fire time, so
//    the text has to be baked into the request at sync time.
//  * `cancel` takes a **batch**. `removePendingNotificationRequests(withIdentifiers:)` is one call
//    for many identifiers, and a sync cancels in groups.
//  * `pendingRequestCodes` has no Android counterpart at all. `AlarmManager` cannot be asked what
//    it holds; `getPendingNotificationRequests` can, which lets a sync reconcile against what the
//    OS actually has rather than against the ledger's belief about it.

import Foundation

/// Thin seam over the notification centre so the synchronizer stays testable and framework-free.
///
/// Request codes are the ledger's stable per-occurrence identity (`AlarmGateway.kt:7`). Scheduling
/// the same code twice replaces the request, exactly as re-using a PendingIntent request code
/// replaces the alarm — which is what makes a sync idempotent by identity.
public protocol NotificationGateway: Sendable {
    /// Adds — or replaces — the request for `requestCode`.
    func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws

    /// Drops every listed request. Codes the centre does not hold are ignored, not an error.
    func cancel(requestCodes: [Int32]) async

    /// What the centre is holding right now — reality, as opposed to the ledger.
    func pendingRequestCodes() async -> Set<Int32>
}
