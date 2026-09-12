// The twin of `feature/appointments/src/main/res/values/strings.xml` (Turkish, the source
// language) and `feature/appointments/src/main/res/values-en/strings.xml` — the 55 keys
// `:feature:appointments` owns, name and text verbatim apart from the two recorded divergences
// below, resolved against this package's own bundle exactly as `R.string` resolves against
// `:feature:appointments`.
//
// Two keys are carried that no Android code reads: `appointments_upcoming_header` and the pair
// `appointments_ok` / `appointments_cancel`. They stay because key-set parity is the drift
// detector between the two modules — a key present on one platform and absent on the other is
// precisely the difference worth failing on — and because the unread ones are the likeliest to be
// wanted next, at which point a missing key reads as a port mistake rather than as a decision.
//
// NOTE ON THE STATUS DIVERGENCE (retired in M15): the old `appointment_status_scheduled` key is
// gone. Android deleted all three status keys in M15 when the scheduled-status chip retired from
// the detail screen, so the "Planlı" divergence the header once recorded has nothing left to
// diverge on.
//
// PLURALS ARE TWO KEYS (spec §9 (h), the M14 (e) precedent). Android's `<plurals>` resources are
// compiled into Xcode string catalogs as `pluralVariations`, which none of this repo's parity
// checks model. So each plural ships as a pair — the general key and a `_one` key for the count
// that reads differently in English — and the accessor picks between them, exactly as
// `MedicationsStrings` does for `medications_count` / `medications_count_one`:
//
//   appointment_detail_relative_in_days        "In %1$lld days"  / "%1$lld gün sonra"
//   appointment_detail_relative_in_days_one   "In %1$lld day"   / "%1$lld gün sonra"
//                                            (Turkish has one form, so both carry it.)
//
// PLACEHOLDER MAPPING, the other place the port is not byte-for-byte. Android's specifiers are
// Java's; each is rewritten to the Swift spelling of the same argument:
//
//   Android      Swift        Keys                              Why
//   ---------------------------------------------------------------------------------------------
//   %1$s         %1$@         appointments_notification_title,  `%s` under `String(format:)` reads
//                             appointment_delete_title          a C string pointer. Handed a Swift
//                                                               `String` it prints garbage or
//                                                               crashes; `%@` is the object form.
//   %1$d         %1$lld       appointments_tab_upcoming,         Swift's `Int` is 64-bit and `%d`
//                             appointments_tab_past,            reads 32, so a `%d` here is a
//                             appointment_detail_relative_      truncation waiting for a bigger
//                             in_days[_one]                     number. `%lld` is the exact width.
//
// The sentence around the specifier is unchanged, and `AppointmentsStringsTests` pins the rendered
// text in both languages so the mapping cannot drift into a reworded string.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE and never against a resolved string; the
// end-to-end check is the simulator run.

import Foundation
import SalusCommon

/// The strings `:feature:appointments` owns.
public enum AppointmentsStrings {
    // MARK: - Simple strings

    public static var title: String { localized(.title) }
    public static var empty: String { localized(.empty) }
    public static var noUpcoming: String { localized(.noUpcoming) }
    public static var noPast: String { localized(.noPast) }
    public static var upcomingHeader: String { localized(.upcomingHeader) }
    public static var new: String { localized(.new) }
    public static var newTitle: String { localized(.newTitle) }
    public static var editTitle: String { localized(.editTitle) }
    public static var titleLabel: String { localized(.titleLabel) }
    public static var titlePlaceholder: String { localized(.titlePlaceholder) }
    public static var doctorLabel: String { localized(.doctorLabel) }
    public static var doctorPlaceholder: String { localized(.doctorPlaceholder) }
    public static var locationLabel: String { localized(.locationLabel) }
    public static var locationPlaceholder: String { localized(.locationPlaceholder) }
    public static var notesLabel: String { localized(.notesLabel) }
    public static var notesPlaceholder: String { localized(.notesPlaceholder) }
    public static var datetimeLabel: String { localized(.datetimeLabel) }
    public static var selectDate: String { localized(.selectDate) }
    public static var selectTime: String { localized(.selectTime) }
    public static var remindersLabel: String { localized(.remindersLabel) }
    public static var offsetHour: String { localized(.offsetHour) }
    public static var offsetDay: String { localized(.offsetDay) }
    public static var offsetWeek: String { localized(.offsetWeek) }
    public static var missingTitle: String { localized(.missingTitle) }
    public static var missingDatetime: String { localized(.missingDatetime) }
    public static var addToCalendar: String { localized(.addToCalendar) }
    public static var save: String { localized(.save) }
    public static var delete: String { localized(.delete) }
    public static var ok: String { localized(.ok) }
    public static var cancel: String { localized(.cancel) }
    public static var tellDoctor: String { localized(.tellDoctor) }
    public static var detailTitle: String { localized(.detailTitle) }
    public static var detailMissing: String { localized(.detailMissing) }
    public static var detailSectionDetails: String { localized(.detailSectionDetails) }
    public static var detailNotes: String { localized(.detailNotes) }
    public static var detailEdit: String { localized(.detailEdit) }
    public static var detailDelete: String { localized(.detailDelete) }
    public static var detailOpenMaps: String { localized(.detailOpenMaps) }
    public static var addDoctor: String { localized(.addDoctor) }
    public static var addLocation: String { localized(.addLocation) }
    public static var addReminder: String { localized(.addReminder) }
    public static var addNote: String { localized(.addNote) }
    public static var relativeToday: String { localized(.relativeToday) }
    public static var relativeTomorrow: String { localized(.relativeTomorrow) }
    public static var relativePast: String { localized(.relativePast) }
    public static var dayToday: String { localized(.dayToday) }
    public static var dayTomorrow: String { localized(.dayTomorrow) }
    public static var deleteMessage: String { localized(.deleteMessage) }
    public static var deleted: String { localized(.deleted) }

    // MARK: - Formatted strings

    /// `appointments_tab_upcoming` — "Yaklaşan (%1$lld)" / "Upcoming (%1$lld)".
    public static func tabUpcoming(count: Int) -> String {
        formatted(.tabUpcoming, count)
    }

    /// `appointments_tab_past` — "Geçmiş (%1$lld)" / "Past (%1$lld)".
    public static func tabPast(count: Int) -> String {
        formatted(.tabPast, count)
    }

    /// `appointments_notification_title` — "Randevu: %1$@" / "Appointment: %1$@".
    public static func notificationTitle(_ title: String) -> String {
        formatted(.notificationTitle, title)
    }

    /// The two-key plural (spec §9 (h)). `days == 1` reads the "In 1 day" English singular.
    public static func relativeInDays(_ days: Int) -> String {
        formatted(days == 1 ? .relativeInDaysOne : .relativeInDays, days)
    }

    /// `appointment_delete_title` — "%1$@ silinsin mi?" / "Delete %1$@?".
    public static func deleteTitle(_ title: String) -> String {
        formatted(.deleteTitle, title)
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case title = "appointments_title"
        case empty = "appointments_empty"
        case noUpcoming = "appointments_no_upcoming"
        case noPast = "appointments_no_past"
        case upcomingHeader = "appointments_upcoming_header"
        case new = "appointments_new"
        case tabUpcoming = "appointments_tab_upcoming"
        case tabPast = "appointments_tab_past"
        case newTitle = "appointments_new_title"
        case editTitle = "appointments_edit_title"
        case titleLabel = "appointments_title_label"
        case titlePlaceholder = "appointments_title_placeholder"
        case doctorLabel = "appointments_doctor_label"
        case doctorPlaceholder = "appointments_doctor_placeholder"
        case locationLabel = "appointments_location_label"
        case locationPlaceholder = "appointments_location_placeholder"
        case notesLabel = "appointments_notes_label"
        case notesPlaceholder = "appointments_notes_placeholder"
        case datetimeLabel = "appointments_datetime_label"
        case selectDate = "appointments_select_date"
        case selectTime = "appointments_select_time"
        case remindersLabel = "appointments_reminders_label"
        case offsetHour = "appointments_offset_hour"
        case offsetDay = "appointments_offset_day"
        case offsetWeek = "appointments_offset_week"
        case missingTitle = "appointments_missing_title"
        case missingDatetime = "appointments_missing_datetime"
        case addToCalendar = "appointments_add_to_calendar"
        case save = "appointments_save"
        case delete = "appointments_delete"
        case ok = "appointments_ok"
        case cancel = "appointments_cancel"
        case notificationTitle = "appointments_notification_title"
        case tellDoctor = "appointments_detail_tell_doctor"
        case detailTitle = "appointment_detail_title"
        case detailMissing = "appointment_detail_missing"
        case detailSectionDetails = "appointment_detail_section_details"
        case detailNotes = "appointment_detail_notes"
        case detailEdit = "appointment_detail_edit"
        case detailDelete = "appointment_detail_delete"
        case detailOpenMaps = "appointment_detail_open_maps"
        case addDoctor = "appointment_detail_add_doctor"
        case addLocation = "appointment_detail_add_location"
        case addReminder = "appointment_detail_add_reminder"
        case addNote = "appointment_detail_add_note"
        case relativeToday = "appointment_detail_relative_today"
        case relativeTomorrow = "appointment_detail_relative_tomorrow"
        case relativePast = "appointment_detail_relative_past"
        case relativeInDays = "appointment_detail_relative_in_days"
        case relativeInDaysOne = "appointment_detail_relative_in_days_one"
        case dayToday = "appointments_day_today"
        case dayTomorrow = "appointments_day_tomorrow"
        case deleteTitle = "appointment_delete_title"
        case deleteMessage = "appointment_delete_message"
        case deleted = "appointment_deleted"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }

    /// Substitutes the single argument, in the device's locale.
    ///
    /// The locale is the current one rather than `nil` because that is what Android does:
    /// `Resources.getString(int, Object...)` formats with the configuration's locale, so a grouped
    /// number reads the same on both platforms.
    private static func formatted(_ key: Key, _ argument: CVarArg) -> String {
        String(format: localized(key), locale: .current, argument)
    }
}
