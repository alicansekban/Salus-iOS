// The twin of `feature/medications/src/main/res/values/strings.xml` (Turkish, the source
// language) and `feature/medications/src/main/res/values-en/strings.xml` — all 86 keys
// `:feature:medications` owns, name and text verbatim apart from the single divergence recorded
// below, resolved against this package's own bundle exactly as `R.string` resolves against
// `:feature:medications`.
//
// ONE KEY DIVERGENCE, deliberate and recorded. `medications_recorded_doses` — the seven-day
// figure on the list card — replaces an Android key whose name AND whose sentence are built on a
// word on `BannedHealthClaims.stems` (CLAUDE.md, "Copy and localisation rules"). The substance is
// the reason, not the scanner: no `MISSED` intake row is ever written, so the ratio counts the
// doses that were RECORDED and says nothing about the doses that were not. Naming it after
// treatment behaviour would turn a fact about records into a claim about someone's treatment
// (spec 7, 12). The replacement says exactly what the number is:
//
//   tr  "Son 7 gün kaydedilen doz %%%1$lld"
//   en  "Recorded doses, last 7 days: %1$lld%%"
//
// Android owes the mirror edit. Until it lands this is a recorded, temporary divergence — NOT a
// port mistake to "correct" back to the Android key, which would turn the repo-wide scan red.
//
// This comment does not spell the Android key out, and neither should any other file here:
// `assertSourcesNameNothingBanned` reads `.swift` comments as well as copy, exactly so that a
// comment cannot reintroduce the vocabulary a string was cleaned of.
//
// PLACEHOLDER MAPPING, the other place the port is not byte-for-byte. Android's specifiers are
// Java's; ten keys carry them, and each is rewritten to the Swift spelling of the same argument:
//
//   Android      Swift        Keys                                Why
//   ---------------------------------------------------------------------------------------------
//   %1$s         %1$@         medications_low_stock,              `%s` under `String(format:)`
//   %2$s         %2$@         editor_start_date, editor_end_date, reads a C string pointer. Handed
//                             notification_dose_title,            a Swift `String` it prints
//                             notification_dose_text (both args), garbage or crashes; `%@` is the
//                             notification_dose_text_plain,       object form.
//                             medication_detail_dose_value,
//                             medication_delete_title
//   %1$d         %1$lld       medications_recorded_doses,         Swift's `Int` is 64-bit and `%d`
//                             recurrence_every_n_days             reads 32, so a `%d` here is a
//                                                                 truncation waiting for a bigger
//                                                                 number. `%lld` is the exact
//                                                                 width.
//
// A literal `%%` is neither a Java nor a Swift argument and stays as it is — both platforms print
// it as one `%`. The sentence around every specifier is unchanged, and `MedicationsStringsTests`
// pins the rendered text in both languages so the mapping cannot drift into a reworded string.
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

/// The strings `:feature:medications` owns.
public enum MedicationsStrings {
    // MARK: - The list screen (7)

    public static var title: String { localized(.title) }
    public static var add: String { localized(.add) }
    public static var emptyTitle: String { localized(.emptyTitle) }
    public static var emptyBody: String { localized(.emptyBody) }

    /// `medications_recorded_doses` — "Son 7 gün kaydedilen doz %%%1$lld" / "Recorded doses, last 7 days: %1$lld%%".
    public static func recordedDoses(percent: Int) -> String {
        formatted(.recordedDoses, percent)
    }

    /// `medications_low_stock` — "Stok azaldı: %1$@ kaldı" / "Low stock: %1$@ left".
    public static func lowStock(remaining: String) -> String {
        formatted(.lowStock, remaining)
    }

    public static var noSchedule: String { localized(.noSchedule) }

    // MARK: - The editor (29)

    public static var editorTitleNew: String { localized(.editorTitleNew) }
    public static var editorTitleEdit: String { localized(.editorTitleEdit) }
    public static var editorBack: String { localized(.editorBack) }
    public static var editorSave: String { localized(.editorSave) }
    public static var editorDelete: String { localized(.editorDelete) }
    public static var editorName: String { localized(.editorName) }
    public static var editorForm: String { localized(.editorForm) }
    public static var editorStrength: String { localized(.editorStrength) }
    public static var editorStrengthUnit: String { localized(.editorStrengthUnit) }
    public static var editorInstructions: String { localized(.editorInstructions) }
    public static var editorStock: String { localized(.editorStock) }
    public static var editorStockThreshold: String { localized(.editorStockThreshold) }

    /// `editor_start_date` — "%1$@ tarihinden itibaren" / "From %1$@".
    public static func editorStartDate(_ date: String) -> String {
        formatted(.editorStartDate, date)
    }

    /// `editor_end_date` — "%1$@ tarihine kadar" / "Until %1$@".
    public static func editorEndDate(_ date: String) -> String {
        formatted(.editorEndDate, date)
    }

    public static var editorNoEndDate: String { localized(.editorNoEndDate) }
    public static var editorClearEndDate: String { localized(.editorClearEndDate) }
    public static var editorScheduleSection: String { localized(.editorScheduleSection) }
    public static var editorTimesSection: String { localized(.editorTimesSection) }
    public static var editorIntervalDays: String { localized(.editorIntervalDays) }
    public static var editorDoseAmount: String { localized(.editorDoseAmount) }
    public static var editorAddTime: String { localized(.editorAddTime) }
    public static var editorRemoveTime: String { localized(.editorRemoveTime) }
    public static var editorConfirm: String { localized(.editorConfirm) }
    public static var editorCancel: String { localized(.editorCancel) }
    public static var editorErrorEmptyName: String { localized(.editorErrorEmptyName) }
    public static var editorErrorNoTimes: String { localized(.editorErrorNoTimes) }
    public static var editorErrorInvalidInterval: String { localized(.editorErrorInvalidInterval) }
    public static var editorErrorNoDays: String { localized(.editorErrorNoDays) }
    public static var editorErrorEndBeforeStart: String { localized(.editorErrorEndBeforeStart) }

    // MARK: - The dosage forms (8)

    public static var formTablet: String { localized(.formTablet) }
    public static var formCapsule: String { localized(.formCapsule) }
    public static var formSyrup: String { localized(.formSyrup) }
    public static var formInjection: String { localized(.formInjection) }
    public static var formDrop: String { localized(.formDrop) }
    public static var formInhaler: String { localized(.formInhaler) }
    public static var formCream: String { localized(.formCream) }
    public static var formOther: String { localized(.formOther) }

    // MARK: - The recurrence kinds (5)

    public static var recurrenceDaily: String { localized(.recurrenceDaily) }
    public static var recurrenceDaysOfWeek: String { localized(.recurrenceDaysOfWeek) }
    public static var recurrenceInterval: String { localized(.recurrenceInterval) }

    /// `recurrence_every_n_days` — "%1$lld günde bir" / "Every %1$lld days".
    public static func recurrenceEveryNDays(days: Int) -> String {
        formatted(.recurrenceEveryNDays, days)
    }

    public static var recurrenceAsNeeded: String { localized(.recurrenceAsNeeded) }

    // MARK: - The weekday abbreviations (7)

    public static var dayMon: String { localized(.dayMon) }
    public static var dayTue: String { localized(.dayTue) }
    public static var dayWed: String { localized(.dayWed) }
    public static var dayThu: String { localized(.dayThu) }
    public static var dayFri: String { localized(.dayFri) }
    public static var daySat: String { localized(.daySat) }
    public static var daySun: String { localized(.daySun) }

    // MARK: - The dose notification (5)

    /// `notification_dose_title` — "%1$@ zamanı" / "Time for %1$@".
    public static func notificationDoseTitle(_ name: String) -> String {
        formatted(.notificationDoseTitle, name)
    }

    /// `notification_dose_text` — "%1$@ × %2$@ al" / "Take %1$@ × %2$@".
    public static func notificationDoseText(amount: String, strength: String) -> String {
        String(format: localized(.notificationDoseText), locale: .current, amount, strength)
    }

    /// `notification_dose_text_plain` — "%1$@ doz al" / "Take %1$@ dose(s)".
    public static func notificationDoseTextPlain(amount: String) -> String {
        formatted(.notificationDoseTextPlain, amount)
    }

    public static var notificationActionTaken: String { localized(.notificationActionTaken) }
    public static var notificationActionSnooze: String { localized(.notificationActionSnooze) }

    // MARK: - The detail screen (13)

    public static var detailTitle: String { localized(.detailTitle) }
    public static var detailMissing: String { localized(.detailMissing) }
    public static var detailSchedule: String { localized(.detailSchedule) }
    public static var detailWhen: String { localized(.detailWhen) }
    public static var detailDose: String { localized(.detailDose) }

    /// `medication_detail_dose_value` — "%1$@ birim" / "%1$@ unit(s)".
    public static func detailDoseValue(amount: String) -> String {
        formatted(.detailDoseValue, amount)
    }

    public static var detailInstructions: String { localized(.detailInstructions) }
    public static var detailSupply: String { localized(.detailSupply) }
    public static var detailStock: String { localized(.detailStock) }
    public static var detailHistory: String { localized(.detailHistory) }
    public static var detailHistoryEmpty: String { localized(.detailHistoryEmpty) }
    public static var detailEdit: String { localized(.detailEdit) }
    public static var detailDelete: String { localized(.detailDelete) }

    // MARK: - The intake statuses (4)

    public static var intakeStatusTaken: String { localized(.intakeStatusTaken) }
    public static var intakeStatusSkipped: String { localized(.intakeStatusSkipped) }
    public static var intakeStatusMissed: String { localized(.intakeStatusMissed) }
    public static var intakeStatusPending: String { localized(.intakeStatusPending) }

    // MARK: - Delete and its undo snackbar (4)

    /// `medication_delete_title` — "%1$@ silinsin mi?" / "Delete %1$@?".
    public static func deleteTitle(_ name: String) -> String {
        formatted(.deleteTitle, name)
    }

    public static var deleteMessage: String { localized(.deleteMessage) }
    public static var deleted: String { localized(.deleted) }
    public static var delete: String { localized(.delete) }

    // MARK: - The per-medication reminder toggle (4)

    public static var remindersTitle: String { localized(.remindersTitle) }
    public static var remindersOnDescription: String { localized(.remindersOnDescription) }
    public static var remindersOffDescription: String { localized(.remindersOffDescription) }
    public static var remindersOff: String { localized(.remindersOff) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        // The list screen (7).
        case title = "medications_title"
        case add = "medications_add"
        case emptyTitle = "medications_empty_title"
        case emptyBody = "medications_empty_body"
        case recordedDoses = "medications_recorded_doses"
        case lowStock = "medications_low_stock"
        case noSchedule = "medications_no_schedule"

        // The editor (29).
        case editorTitleNew = "editor_title_new"
        case editorTitleEdit = "editor_title_edit"
        case editorBack = "editor_back"
        case editorSave = "editor_save"
        case editorDelete = "editor_delete"
        case editorName = "editor_name"
        case editorForm = "editor_form"
        case editorStrength = "editor_strength"
        case editorStrengthUnit = "editor_strength_unit"
        case editorInstructions = "editor_instructions"
        case editorStock = "editor_stock"
        case editorStockThreshold = "editor_stock_threshold"
        case editorStartDate = "editor_start_date"
        case editorEndDate = "editor_end_date"
        case editorNoEndDate = "editor_no_end_date"
        case editorClearEndDate = "editor_clear_end_date"
        case editorScheduleSection = "editor_schedule_section"
        case editorTimesSection = "editor_times_section"
        case editorIntervalDays = "editor_interval_days"
        case editorDoseAmount = "editor_dose_amount"
        case editorAddTime = "editor_add_time"
        case editorRemoveTime = "editor_remove_time"
        case editorConfirm = "editor_confirm"
        case editorCancel = "editor_cancel"
        case editorErrorEmptyName = "editor_error_empty_name"
        case editorErrorNoTimes = "editor_error_no_times"
        case editorErrorInvalidInterval = "editor_error_invalid_interval"
        case editorErrorNoDays = "editor_error_no_days"
        case editorErrorEndBeforeStart = "editor_error_end_before_start"

        // The dosage forms (8).
        case formTablet = "form_tablet"
        case formCapsule = "form_capsule"
        case formSyrup = "form_syrup"
        case formInjection = "form_injection"
        case formDrop = "form_drop"
        case formInhaler = "form_inhaler"
        case formCream = "form_cream"
        case formOther = "form_other"

        // The recurrence kinds (5).
        case recurrenceDaily = "recurrence_daily"
        case recurrenceDaysOfWeek = "recurrence_days_of_week"
        case recurrenceInterval = "recurrence_interval"
        case recurrenceEveryNDays = "recurrence_every_n_days"
        case recurrenceAsNeeded = "recurrence_as_needed"

        // The weekday abbreviations (7).
        case dayMon = "day_mon"
        case dayTue = "day_tue"
        case dayWed = "day_wed"
        case dayThu = "day_thu"
        case dayFri = "day_fri"
        case daySat = "day_sat"
        case daySun = "day_sun"

        // The dose notification (5).
        case notificationDoseTitle = "notification_dose_title"
        case notificationDoseText = "notification_dose_text"
        case notificationDoseTextPlain = "notification_dose_text_plain"
        case notificationActionTaken = "notification_action_taken"
        case notificationActionSnooze = "notification_action_snooze"

        // The detail screen (13).
        case detailTitle = "medication_detail_title"
        case detailMissing = "medication_detail_missing"
        case detailSchedule = "medication_detail_schedule"
        case detailWhen = "medication_detail_when"
        case detailDose = "medication_detail_dose"
        case detailDoseValue = "medication_detail_dose_value"
        case detailInstructions = "medication_detail_instructions"
        case detailSupply = "medication_detail_supply"
        case detailStock = "medication_detail_stock"
        case detailHistory = "medication_detail_history"
        case detailHistoryEmpty = "medication_detail_history_empty"
        case detailEdit = "medication_detail_edit"
        case detailDelete = "medication_detail_delete"

        // The intake statuses (4).
        case intakeStatusTaken = "intake_status_taken"
        case intakeStatusSkipped = "intake_status_skipped"
        case intakeStatusMissed = "intake_status_missed"
        case intakeStatusPending = "intake_status_pending"

        // Delete and its undo snackbar (4).
        case deleteTitle = "medication_delete_title"
        case deleteMessage = "medication_delete_message"
        case deleted = "medication_deleted"
        case delete = "medications_delete"

        // The per-medication reminder toggle (4).
        case remindersTitle = "medication_reminders_title"
        case remindersOnDescription = "medication_reminders_on_desc"
        case remindersOffDescription = "medication_reminders_off_desc"
        case remindersOff = "medication_reminders_off"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }

    // Substitutes the single argument, in the device's locale.
    //
    // The locale is the current one rather than `nil` because that is what Android does:

    /// `Resources.getString(int, Object...)` formats with the configuration's locale, so a grouped
    /// number reads the same on both platforms.
    private static func formatted(_ key: Key, _ argument: CVarArg) -> String {
        String(format: localized(key), locale: .current, argument)
    }
}
