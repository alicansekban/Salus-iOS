// Ported 1:1 from the interface declared at the top of
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/reminder/
// CycleReminderHandler.kt:22-31`.
//
// Kotlin declares it in the handler's own file; here it is its own file, the shape
// `MedicationNotificationTexts` and `AppointmentNotificationTexts` settled — the protocol, the
// shipped implementation and the handler are three files rather than one.

/// Localized notification texts for the period-start reminder
/// (`CycleReminderHandler.kt:27, 30`).
///
/// Behind a protocol so the handler stays free of anything that resolves a string: its whole job
/// is *whether* a predicted start is worth a reminder and *when* it fires, and a test can then
/// assert that without asserting copy. The shipped implementation is
/// ``LocalizedCycleNotificationTexts``.
public protocol CycleNotificationTexts: Sendable {
    /// `cycle_reminder_notification_title`.
    func title() -> String

    /// `leadDays` = 0 means the predicted start day itself.
    func body(leadDays: Int) -> String
}
