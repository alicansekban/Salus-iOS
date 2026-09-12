// The twin of `feature/medications/src/main/res/values/strings.xml` (Turkish, the source
// language) and `feature/medications/src/main/res/values-en/strings.xml` — all 113 keys
// `:feature:medications` owns after the Android M15 sweep (`529a30f`), name and text verbatim
// apart from the divergences recorded below, resolved against this package's own bundle exactly as
// `R.string` resolves against `:feature:medications`.
//
// TWO KEY-SET DIVERGENCES, deliberate and recorded.
//
// 1. `medications_title` is KEPT where Android M15 deleted it, and native chrome is the reason: the
//    system navigation bar labels a pushed screen's back button with the *previous* screen's
//    `.navigationTitle`, and it is what VoiceOver reads for the root. Compose's custom top bar had
//    no such need, which is why Android could drop the key when the title moved into the content.
//    Ruled by iOS-M16 Task 7; the other sixteen keys M15 retired are gone here too.
//
// 2. `medications_count` had no `<plurals>` twin here, so it shipped as two keys
//    (`medications_count` / `medications_count_one`, divergence (e)). M15 retired the count chip
//    into the list's own metric tiles, so BOTH are deleted — the plural divergence retires with the
//    key it was about.
//
// This comment does not spell out the banned vocabulary any retired key carried, and neither should
// any other file here: `assertSourcesNameNothingBanned` reads `.swift` comments as well as copy,
// exactly so that a comment cannot reintroduce the wording a string was cleaned of.
//
// PLACEHOLDER MAPPING, the other place the port is not byte-for-byte. Android's specifiers are
// Java's; nine keys carry them, and each is rewritten to the Swift spelling of the same argument:
//
//   Android      Swift        Keys                                  Why
//   ---------------------------------------------------------------------------------------------
//   %1$s         %1$@         medications_overline_today,           `%s` under `String(format:)`
//   %2$s         %2$@         medications_stock_left,               reads a C string pointer.
//                             medication_detail_threshold,          Handed a Swift `String` it
//                             medication_detail_record_now,         prints garbage or crashes;
//                             notification_dose_title,              `%@` is the object form.
//                             notification_dose_text (both args),
//                             notification_dose_text_plain,
//                             medication_delete_title
//   %1$d         %1$lld       medications_detail_days_of_supply,    Swift's `Int` is 64-bit and
//                             medications_detail_per_day,           `%d` reads 32, so a `%d` here
//                             recurrence_every_n_days               is a truncation waiting for a
//                                                                   bigger number. `%lld` is the
//                                                                   exact width.
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
    // MARK: - The list screen (14)

    /// `medications_title` — the only key Android M15 deleted that iOS keeps, and the reason is
    /// native chrome: the system navigation bar labels a pushed screen's back button with the
    /// *previous* screen's `.navigationTitle`, so the root still needs one where Compose's custom
    /// top bar did not. Recorded as an iOS divergence by iOS-M16 Task 7.
    public static var title: String { localized(.title) }
    public static var add: String { localized(.add) }
    public static var emptyTitle: String { localized(.emptyTitle) }
    public static var emptyBody: String { localized(.emptyBody) }
    public static var noSchedule: String { localized(.noSchedule) }

    /// `medications_overline_today` — "BUGÜN • %1$@" / "TODAY • %1$@". Stored upper-case; never
    /// `uppercased()` at runtime (spec §6).
    public static func overlineToday(date: String) -> String {
        formatted(.overlineToday, date)
    }

    public static var titleRoutine: String { localized(.titleRoutine) }
    public static var metricActive: String { localized(.metricActive) }
    public static var metricRecorded: String { localized(.metricRecorded) }
    public static var metricNext: String { localized(.metricNext) }
    public static var metricNone: String { localized(.metricNone) }
    public static var takeNow: String { localized(.takeNow) }
    /// `medications_fab_add` — carried for key-set parity and read by nothing on iOS since Task 9
    /// switched this list from the icon FAB to `SalusExtendedFab`, whose label is
    /// `medications_add`. Android still declares the key at `529a30f`
    /// (`feature/medications/src/main/res/values/strings.xml`), so the M16 orphan sweep kept it:
    /// the key-set pin is Android's key set, not iOS's call sites.
    public static var fabAdd: String { localized(.fabAdd) }
    public static var statusAsNeeded: String { localized(.statusAsNeeded) }

    /// `medications_stock_left` — "Stok: %1$@" / "Stock: %1$@".
    public static func stockLeft(remaining: String) -> String {
        formatted(.stockLeft, remaining)
    }

    // MARK: - The editor (38)

    public static var editorTitleNew: String { localized(.editorTitleNew) }
    public static var editorTitleEdit: String { localized(.editorTitleEdit) }
    public static var editorSubtitleNew: String { localized(.editorSubtitleNew) }
    public static var editorSubtitleEdit: String { localized(.editorSubtitleEdit) }
    public static var editorSectionBasics: String { localized(.editorSectionBasics) }
    public static var editorSectionDates: String { localized(.editorSectionDates) }
    public static var editorSectionStock: String { localized(.editorSectionStock) }
    public static var editorStockTrackingDescription: String { localized(.editorStockTrackingDescription) }
    public static var editorNamePlaceholder: String { localized(.editorNamePlaceholder) }
    public static var editorStrengthPlaceholder: String { localized(.editorStrengthPlaceholder) }
    public static var editorStrengthUnitPlaceholder: String { localized(.editorStrengthUnitPlaceholder) }
    public static var editorInstructionsPlaceholder: String { localized(.editorInstructionsPlaceholder) }
    public static var editorStockPlaceholder: String { localized(.editorStockPlaceholder) }
    public static var editorStockThresholdPlaceholder: String { localized(.editorStockThresholdPlaceholder) }
    public static var editorStartDateLabel: String { localized(.editorStartDateLabel) }
    public static var editorEndDateLabel: String { localized(.editorEndDateLabel) }
    public static var editorStartDatePlaceholder: String { localized(.editorStartDatePlaceholder) }
    public static var addDoseTime: String { localized(.addDoseTime) }
    public static var editorSave: String { localized(.editorSave) }
    public static var editorName: String { localized(.editorName) }
    public static var editorForm: String { localized(.editorForm) }
    public static var editorStrength: String { localized(.editorStrength) }
    public static var editorStrengthUnit: String { localized(.editorStrengthUnit) }
    public static var editorInstructions: String { localized(.editorInstructions) }
    public static var editorStock: String { localized(.editorStock) }
    public static var editorStockThreshold: String { localized(.editorStockThreshold) }

    public static var editorNoEndDate: String { localized(.editorNoEndDate) }
    public static var editorClearEndDate: String { localized(.editorClearEndDate) }
    public static var editorScheduleSection: String { localized(.editorScheduleSection) }
    public static var editorTimesSection: String { localized(.editorTimesSection) }
    public static var editorIntervalDays: String { localized(.editorIntervalDays) }
    public static var editorDoseAmount: String { localized(.editorDoseAmount) }
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

    // MARK: - The recurrence kinds (6)

    public static var recurrenceDaily: String { localized(.recurrenceDaily) }
    public static var recurrenceDaysOfWeek: String { localized(.recurrenceDaysOfWeek) }

    /// The two short labels the M15 segmented control needs: the long names stay on the cards
    /// (`MedicationEditorSections.kt:398-403`).
    public static var recurrenceTabDays: String { localized(.recurrenceTabDays) }
    public static var recurrenceTabInterval: String { localized(.recurrenceTabInterval) }

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

    // MARK: - The detail screen (21)

    public static var detailTitle: String { localized(.detailTitle) }
    public static var detailMissing: String { localized(.detailMissing) }
    public static var detailActiveTracking: String { localized(.detailActiveTracking) }
    public static var detailPlan: String { localized(.detailPlan) }
    public static var detailSupplyTitle: String { localized(.detailSupplyTitle) }
    public static var detailMetricTime: String { localized(.detailMetricTime) }
    public static var detailMetricAmount: String { localized(.detailMetricAmount) }
    public static var detailRhythm: String { localized(.detailRhythm) }
    public static var detailRhythmNone: String { localized(.detailRhythmNone) }
    public static var detailDeleteMedication: String { localized(.detailDeleteMedication) }
    public static var detailReminderSubtitle: String { localized(.detailReminderSubtitle) }

    /// `medications_detail_days_of_supply` — "≈ %1$lld gün yetecek" / "≈ %1$lld day(s) left".
    public static func detailDaysOfSupply(days: Int) -> String {
        formatted(.detailDaysOfSupply, days)
    }

    /// `medications_detail_per_day` — "Günde %1$lld kez" / "%1$lld time(s) a day".
    public static func detailPerDay(times: Int) -> String {
        formatted(.detailPerDay, times)
    }

    /// `medication_detail_threshold` — "Uyarı eşiği: %1$@" / "Alert at: %1$@".
    public static func detailThreshold(amount: String) -> String {
        formatted(.detailThreshold, amount)
    }

    /// `medication_detail_record_now` — "Dozu Şimdi Kaydet (%1$@)" / "Record dose now (%1$@)".
    public static func detailRecordNow(time: String) -> String {
        formatted(.detailRecordNow, time)
    }

    public static var detailInstructions: String { localized(.detailInstructions) }
    public static var detailStock: String { localized(.detailStock) }
    public static var detailHistory: String { localized(.detailHistory) }
    public static var detailHistoryEmpty: String { localized(.detailHistoryEmpty) }
    public static var detailEdit: String { localized(.detailEdit) }

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

    // MARK: - The per-medication reminder toggle (3)

    public static var remindersTitle: String { localized(.remindersTitle) }
    public static var remindersOffDescription: String { localized(.remindersOffDescription) }
    public static var remindersOff: String { localized(.remindersOff) }

    // MARK: - The post-save reminder warning (1)

    /// `medication_saved_reminders_blocked_title` — the title of the dialog the editor shows after
    /// a save that succeeded on a device where the dose alarm cannot reach the user. The message
    /// under it is the problem's own `ReminderProblem.reason`, and the two answers are
    /// `ReminderStrings.reminderFix` / `.reminderNotNow`, so this is the one line the warning owns.
    public static var savedRemindersBlockedTitle: String { localized(.savedRemindersBlockedTitle) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        // The list screen (14).
        case title = "medications_title"
        case add = "medications_add"
        case emptyTitle = "medications_empty_title"
        case emptyBody = "medications_empty_body"
        case noSchedule = "medications_no_schedule"
        case overlineToday = "medications_overline_today"
        case titleRoutine = "medications_title_routine"
        case metricActive = "medications_metric_active"
        case metricRecorded = "medications_metric_recorded"
        case metricNext = "medications_metric_next"
        case metricNone = "medications_metric_none"
        case takeNow = "medications_take_now"
        case fabAdd = "medications_fab_add"
        case statusAsNeeded = "medications_status_as_needed"
        case stockLeft = "medications_stock_left"

        // The editor (38).
        case editorTitleNew = "editor_title_new"
        case editorTitleEdit = "editor_title_edit"
        case editorSubtitleNew = "editor_subtitle_new"
        case editorSubtitleEdit = "editor_subtitle_edit"
        case editorSectionBasics = "editor_section_basics"
        case editorSectionDates = "editor_section_dates"
        case editorSectionStock = "editor_section_stock"
        case editorStockTrackingDescription = "editor_stock_tracking_desc"
        case editorNamePlaceholder = "editor_name_placeholder"
        case editorStrengthPlaceholder = "editor_strength_placeholder"
        case editorStrengthUnitPlaceholder = "editor_strength_unit_placeholder"
        case editorInstructionsPlaceholder = "editor_instructions_placeholder"
        case editorStockPlaceholder = "editor_stock_placeholder"
        case editorStockThresholdPlaceholder = "editor_stock_threshold_placeholder"
        case editorStartDateLabel = "editor_start_date_label"
        case editorEndDateLabel = "editor_end_date_label"
        case editorStartDatePlaceholder = "editor_start_date_placeholder"
        case addDoseTime = "medications_add_dose_time"
        case editorSave = "editor_save"
        case editorName = "editor_name"
        case editorForm = "editor_form"
        case editorStrength = "editor_strength"
        case editorStrengthUnit = "editor_strength_unit"
        case editorInstructions = "editor_instructions"
        case editorStock = "editor_stock"
        case editorStockThreshold = "editor_stock_threshold"
        case editorNoEndDate = "editor_no_end_date"
        case editorClearEndDate = "editor_clear_end_date"
        case editorScheduleSection = "editor_schedule_section"
        case editorTimesSection = "editor_times_section"
        case editorIntervalDays = "editor_interval_days"
        case editorDoseAmount = "editor_dose_amount"
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

        // The recurrence kinds (6).
        case recurrenceDaily = "recurrence_daily"
        case recurrenceDaysOfWeek = "recurrence_days_of_week"
        case recurrenceTabDays = "recurrence_tab_days"
        case recurrenceTabInterval = "recurrence_tab_interval"
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

        // The detail screen (21).
        case detailTitle = "medication_detail_title"
        case detailMissing = "medication_detail_missing"
        case detailActiveTracking = "medication_detail_active_tracking"
        case detailPlan = "medication_detail_plan"
        case detailSupplyTitle = "medication_detail_supply_title"
        case detailMetricTime = "medication_detail_metric_time"
        case detailMetricAmount = "medication_detail_metric_amount"
        case detailRhythm = "medication_detail_rhythm"
        case detailRhythmNone = "medication_detail_rhythm_none"
        case detailDeleteMedication = "medication_detail_delete_medication"
        case detailReminderSubtitle = "medications_detail_reminder_subtitle"
        case detailDaysOfSupply = "medications_detail_days_of_supply"
        case detailPerDay = "medications_detail_per_day"
        case detailThreshold = "medication_detail_threshold"
        case detailRecordNow = "medication_detail_record_now"
        case detailInstructions = "medication_detail_instructions"
        case detailStock = "medication_detail_stock"
        case detailHistory = "medication_detail_history"
        case detailHistoryEmpty = "medication_detail_history_empty"
        case detailEdit = "medication_detail_edit"

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

        // The per-medication reminder toggle (3).
        case remindersTitle = "medication_reminders_title"
        case remindersOffDescription = "medication_reminders_off_desc"
        case remindersOff = "medication_reminders_off"

        /// The post-save reminder warning (1).
        case savedRemindersBlockedTitle = "medication_saved_reminders_blocked_title"
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
