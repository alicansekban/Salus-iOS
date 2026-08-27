// The shipped ``MedicationNotificationTexts``, the twin of Android resolving the same five
// `R.string` ids off the handler's `Context`
// (`MedicationReminderHandler.kt:90, 92, 97, 107-108`).
//
// `MedicationsStrings` resolves against this package's own bundle, which is exactly what
// `R.string` resolving against `:feature:medications` does, so nothing platform-shaped is left to
// inject and the type is named for what it does rather than for the platform it runs on — the
// naming `LocalizedAppointmentNotificationTexts` settled.

/// Resolves medication dose notification texts from the feature's string catalog.
public struct LocalizedMedicationNotificationTexts: MedicationNotificationTexts {
    public init() {}

    public func doseTitle(medicationName: String) -> String {
        MedicationsStrings.notificationDoseTitle(medicationName)
    }

    public func doseText(amount: String, strength: String) -> String {
        MedicationsStrings.notificationDoseText(amount: amount, strength: strength)
    }

    public func doseTextPlain(amount: String) -> String {
        MedicationsStrings.notificationDoseTextPlain(amount: amount)
    }

    /// Read from the catalog on every access, so a locale change is picked up — the same reason
    /// ``ScheduleSummaryStrings/localized`` is a computed property.
    public var actionTaken: String { MedicationsStrings.notificationActionTaken }

    public var actionSnooze: String { MedicationsStrings.notificationActionSnooze }
}
