// The iOS twin of Android's `ReminderIntentExtras`
// (`core/reminder/src/main/kotlin/.../engine/ReminderNotificationPresenter.kt:13-17`).
//
// The key strings are Android-verbatim on purpose, exactly as the persisted settings keys are:
// they name the same three values on both platforms, and there is nothing to gain from two
// spellings. A rename is invisible to the compiler and would strand every request already
// scheduled with the old keys, so the strings are pinned by a test.
//
// Where Android puts them in an `Intent` that MainActivity parses on tap, iOS puts them in the
// request's `userInfo`, which arrives back in the notification-centre delegate (iOS-M3 Task 6).

import Foundation
import SalusModel

/// The `userInfo` keys that identify which occurrence a fired reminder was.
public enum ReminderUserInfo {
    public static let type = "salus.extra.REMINDER_TYPE"
    public static let entityId = "salus.extra.REMINDER_ENTITY_ID"
    public static let occurrenceKey = "salus.extra.REMINDER_OCCURRENCE_KEY"

    /// The three values a fired reminder carries, ready to assign to `UNMutableNotificationContent`.
    ///
    /// The type travels as its raw value (`MEDICATION_DOSE`, …) rather than as a Swift case, so it
    /// round-trips through the plist encoding `userInfo` is stored in and reads the same on both
    /// platforms.
    static func payload(for ref: ReminderRef) -> [String: String] {
        [
            type: ref.type.rawValue,
            entityId: ref.entityId,
            occurrenceKey: ref.occurrenceKey
        ]
    }

    /// The inverse, applied to the `userInfo` a tapped notification hands back
    /// (``ReminderNotificationDelegate``). It is the twin of Android's `dao.getByRequestCode`:
    /// where Kotlin looks the occurrence up in the ledger, iOS reads it straight off the payload.
    ///
    /// Nil for anything this engine did not schedule — a foreign notification, a payload missing a
    /// key, or a type name no build of ours knows. `userInfo` survives a reinstall inside the OS's
    /// own store, so an unreadable one is an ordinary event rather than a corrupted state.
    static func ref(from userInfo: [AnyHashable: Any]) -> ReminderRef? {
        guard
            let typeName = userInfo[type] as? String,
            let reminderType = ReminderType(rawValue: typeName),
            let entity = userInfo[entityId] as? String,
            let occurrence = userInfo[occurrenceKey] as? String
        else {
            return nil
        }
        return ReminderRef(type: reminderType, entityId: entity, occurrenceKey: occurrence)
    }
}
