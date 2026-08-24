// Ported 1:1 from the interface declared at the top of `feature/appointments/src/main/kotlin/
// com/alicansekban/salus/feature/appointments/reminder/AppointmentReminderHandler.kt`.
//
// It sits in its own file rather than above the handler because the file-per-responsibility rule
// is this tree's, not Kotlin's; the pairing is otherwise identical.

import Foundation
import SalusModel

/// Localized notification texts for appointment reminders (`AppointmentReminderHandler.kt:24-28`).
///
/// Kept behind a protocol so the handler stays free of anything that resolves a string: the
/// handler's whole job is *which* appointment fires and *when*, and a test can then assert that
/// without asserting copy. The shipped implementation is
/// ``LocalizedAppointmentNotificationTexts``.
public protocol AppointmentNotificationTexts: Sendable {
    func title(appointmentTitle: String) -> String

    func body(startsAt: LocalDateTime, doctorName: String?, location: String?) -> String
}
