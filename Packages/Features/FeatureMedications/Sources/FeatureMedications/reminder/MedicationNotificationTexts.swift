// The iOS half of what Android reads straight off a `Context` inside
// `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/reminder/
// MedicationReminderHandler.kt:90-108` — the five `context.getString` calls the handler makes.
//
// Android has no such interface: `Context` is already the injection point, so the handler takes
// one and resolves `R.string` itself. On iOS the same seam is spelled as a protocol, which is the
// shape `AppointmentNotificationTexts` settled for the same reason.

/// Localized notification texts for medication dose reminders
/// (`MedicationReminderHandler.kt:90, 92, 97, 107-108`).
///
/// Kept behind a protocol so the handler stays free of anything that resolves a string: the
/// handler's whole job is *which* dose fires and *when*, and a test can then assert that without
/// asserting copy. The shipped implementation is ``LocalizedMedicationNotificationTexts``.
public protocol MedicationNotificationTexts: Sendable {
    /// `notification_dose_title` — the medication's name in the notification title.
    func doseTitle(medicationName: String) -> String

    /// `notification_dose_text` — the dose amount and the medication's strength.
    func doseText(amount: String, strength: String) -> String

    /// `notification_dose_text_plain` — the dose amount alone, for a medication that records no
    /// strength.
    func doseTextPlain(amount: String) -> String

    /// `notification_action_taken`.
    var actionTaken: String { get }

    /// `notification_action_snooze`.
    var actionSnooze: String { get }
}
