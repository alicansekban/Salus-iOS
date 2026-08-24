// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/reminder/AndroidAppointmentNotificationTexts.kt`.
//
// Android's class takes a `Context` — the handle it needs both for `R.string` and for the
// configuration's locale. On iOS the string side is `AppointmentsStrings` (which resolves against
// this package's own bundle, the twin of `R.string` resolving against `:feature:appointments`),
// so nothing platform-shaped is left to inject and the type is named for what it does rather than
// for the platform it runs on.

import Foundation
import SalusModel

/// Resolves appointment notification texts from the feature's string catalog
/// (`AndroidAppointmentNotificationTexts.kt:11-27`).
public struct LocalizedAppointmentNotificationTexts: AppointmentNotificationTexts {
    /// `AndroidAppointmentNotificationTexts.kt:25`.
    private static let notificationDatePattern = "d MMM yyyy, HH:mm"
    /// `AndroidAppointmentNotificationTexts.kt:26` — a middle dot with a space on each side.
    private static let separator = " · "

    private let locale: Locale

    /// Android reads `context.resources.configuration.locales[0]`
    /// (`AndroidAppointmentNotificationTexts.kt:20`), which is the device locale the app is
    /// currently configured for; `.current` is its twin. The parameter exists so a test can pin a
    /// rendered date instead of reading whatever region the host is set to.
    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public func title(appointmentTitle: String) -> String {
        AppointmentsStrings.notificationTitle(appointmentTitle)
    }

    public func body(startsAt: LocalDateTime, doctorName: String?, location: String?) -> String {
        // Kotlin's `listOfNotNull(doctorName, location).filter { it.isNotBlank() }`. `isBlank()`
        // reads `Char.isWhitespace()`, so the Swift set is `.whitespacesAndNewlines` — the same
        // spelling `SaveAppointmentUseCase` already uses for the columns these two come from.
        let details = [doctorName, location]
            .compactMap(\.self)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let formattedStart = startsAt.formatted(pattern: Self.notificationDatePattern, locale: locale)
        return ([formattedStart] + details).joined(separator: Self.separator)
    }
}
