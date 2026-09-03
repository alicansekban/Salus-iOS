// No Kotlin twin: Android's day header is a `private @Composable` inside `AppointmentsScreen.kt`
// and Compose screens carry no test file, so every case here is iOS-only.
//
// What the suite pins is an iOS-only divergence. Android's `setApplicationLocales` moves
// `Locale.getDefault()`, so a formatter that reads the platform default already speaks the in-app
// language. Nothing moves iOS's `Locale.current`, so a `Locale.current` default wrote this header
// in the *device's* language: an English phone with Turkish picked in-app drew
// "Friday, 11 September" above a list whose Home header read "11 Eylül 2026 Perşembe". The label
// therefore takes the locale as an argument — the shell's `\.locale` — and that is what is
// asserted, without asking what language the machine running the tests is set to.

import Foundation
import SalusModel
import Testing

@testable import FeatureAppointments

@Suite("Appointments day header")
struct AppointmentsDayHeaderLabelTests {
    private static let turkish = Locale(identifier: "tr")
    private static let english = Locale(identifier: "en_US")

    /// 2026-09-11, a Friday — the day the bug report quoted.
    private static let friday = LocalDate(year: 2026, month: 9, day: 11).epochDay
    /// Far enough from `friday` that neither the "today" nor the "tomorrow" arm can be taken.
    private static let someOtherToday = LocalDate(year: 2026, month: 1, day: 1).epochDay

    @Test("a dated header is written in the locale it is handed")
    func turkishAndEnglishDiffer() {
        #expect(dated(in: Self.turkish) == "Cuma, 11 Eylül")
        #expect(dated(in: Self.english) == "Friday, 11 September")
    }

    /// The point of the parameter: the answer is decided by the argument alone. Both expectations
    /// above run in the same process, so at most one of them can be the host's language — and
    /// neither may fall back to it.
    @Test("the language comes from the argument, never from the host")
    func hostLocaleCannotReach() {
        #expect(dated(in: Self.turkish) != dated(in: Self.english))
        #expect(dated(in: Self.turkish) == dated(in: Locale(identifier: "tr_TR")))
    }

    /// The two named days are catalog strings, so they are the same answer in every locale — the
    /// locale reaches the date arm and nothing else (`AppointmentsScreen.kt:224-228`).
    @Test("today and tomorrow are named rather than dated, whatever the locale")
    func namedDays() {
        #expect(label(today: Self.friday, in: Self.turkish) == AppointmentsStrings.dayToday)
        #expect(label(today: Self.friday, in: Self.english) == AppointmentsStrings.dayToday)
        #expect(label(today: Self.friday - 1, in: Self.turkish) == AppointmentsStrings.dayTomorrow)
    }

    /// `friday` written as a date, because `today` is months away from it.
    private func dated(in locale: Locale) -> String {
        label(today: Self.someOtherToday, in: locale)
    }

    private func label(today: Int, in locale: Locale) -> String {
        appointmentsDayHeaderLabel(epochDay: Self.friday, todayEpochDay: today, locale: locale)
    }
}
