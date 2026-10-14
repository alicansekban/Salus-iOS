// The accessors for the keys `:feature:smoking` owns on the history screen and the entry editor — an
// extension of ``SmokingStrings`` so the enum itself stays inside SwiftLint's 300-line
// `type_body_length`. The key names are in `SmokingStrings.Key`.
//
// Plurals (`smoking_history_journey_days`, `…_attempt_days`, `…_attempt_slips`, `…_attempt_cravings`)
// are two keys selected in code (spec §9 (h)), where Android keeps one `<plurals>`: the general key
// carries the `other` item, `_one` the `one` item.

import Foundation
import SalusCommon

extension SmokingStrings {
    public static var historyAttemptActive: String { localized(.historyAttemptActive) }
    public static var historyAttemptLongest: String { localized(.historyAttemptLongest) }
    public static var historyAttemptNoSlips: String { localized(.historyAttemptNoSlips) }
    public static var historyAttemptUnderDay: String { localized(.historyAttemptUnderDay) }
    public static var historyAttemptsTitle: String { localized(.historyAttemptsTitle) }
    public static var historyDayToday: String { localized(.historyDayToday) }
    public static var historyDayYesterday: String { localized(.historyDayYesterday) }
    public static var historyDeleteMessage: String { localized(.historyDeleteMessage) }
    public static var historyDeleteTitle: String { localized(.historyDeleteTitle) }
    public static var historyEditDelete: String { localized(.historyEditDelete) }
    public static var historyEditMarkerHint: String { localized(.historyEditMarkerHint) }
    public static var historyEditTime: String { localized(.historyEditTime) }
    public static var historyEditTitle: String { localized(.historyEditTitle) }
    public static var historyEmptyBack: String { localized(.historyEmptyBack) }
    public static var historyEmptyBody: String { localized(.historyEmptyBody) }
    public static var historyEmptyHowCraving: String { localized(.historyEmptyHowCraving) }
    public static var historyEmptyHowSmoked: String { localized(.historyEmptyHowSmoked) }
    public static var historyEmptyHowTitle: String { localized(.historyEmptyHowTitle) }
    public static var historyEmptyTitle: String { localized(.historyEmptyTitle) }
    public static var historyErrorFuture: String { localized(.historyErrorFuture) }
    public static var historyErrorInvalid: String { localized(.historyErrorInvalid) }
    public static var historyJourneyOverline: String { localized(.historyJourneyOverline) }
    public static var historyLogTitle: String { localized(.historyLogTitle) }
    public static var historyRowCraving: String { localized(.historyRowCraving) }
    public static var historyRowNone: String { localized(.historyRowNone) }
    public static var historySupportBody: String { localized(.historySupportBody) }
    public static var historySupportTitle: String { localized(.historySupportTitle) }
    public static var historyTitle: String { localized(.historyTitle) }

    // MARK: - Formatted strings

    /// `smoking_history_journey_days`.
    public static func historyJourneyDays(_ days: Int) -> String {
        String(format: localized(days == 1 ? .historyJourneyDaysOne : .historyJourneyDays), locale: .current, days)
    }

    /// `smoking_history_attempt_title`: "2. deneme".
    public static func historyAttemptTitle(_ ordinal: Int) -> String {
        String(format: localized(.historyAttemptTitle), locale: .current, ordinal)
    }

    /// `smoking_history_attempt_days`.
    public static func historyAttemptDays(_ days: Int) -> String {
        String(format: localized(days == 1 ? .historyAttemptDaysOne : .historyAttemptDays), locale: .current, days)
    }

    /// `smoking_history_attempt_range`: "10 Mar 2026 – 1 Nis 2026".
    public static func historyAttemptRange(_ started: String, _ ended: String) -> String {
        String(format: localized(.historyAttemptRange), locale: .current, started, ended)
    }

    /// `smoking_history_attempt_range_open`: "10 Mar 2026 – şimdi".
    public static func historyAttemptRangeOpen(_ started: String) -> String {
        String(format: localized(.historyAttemptRangeOpen), locale: .current, started)
    }

    /// `smoking_history_attempt_slips`.
    public static func historyAttemptSlips(_ count: Int) -> String {
        String(format: localized(count == 1 ? .historyAttemptSlipsOne : .historyAttemptSlips), locale: .current, count)
    }

    /// `smoking_history_attempt_saved`: "Biriken: ₺3.150".
    public static func historyAttemptSaved(_ money: String) -> String {
        String(format: localized(.historyAttemptSaved), locale: .current, money)
    }

    /// `smoking_history_attempt_cravings`.
    public static func historyAttemptCravings(_ count: Int) -> String {
        String(
            format: localized(count == 1 ? .historyAttemptCravingsOne : .historyAttemptCravings),
            locale: .current,
            count
        )
    }

    /// `smoking_history_row_smoked`.
    public static func historyRowSmoked(_ units: Int) -> String {
        String(format: localized(.historyRowSmoked), locale: .current, units)
    }

    /// `smoking_history_row_intensity`: "Şiddet 4/5".
    public static func historyRowIntensity(_ level: Int) -> String {
        String(format: localized(.historyRowIntensity), locale: .current, level)
    }

    // MARK: - Keys

    /// The catalog keys of the history screen and the entry editor, named once. They sit beside their accessors, and
    /// not in
    /// ``SmokingStrings/Key``, so that enum stays inside SwiftLint's 300-line `type_body_length`;
    /// the parity test checks the union of the enums against the catalog.
    enum HistoryKey: String, CaseIterable {
        case historyAttemptActive = "smoking_history_attempt_active"
        case historyAttemptCravings = "smoking_history_attempt_cravings"
        case historyAttemptCravingsOne = "smoking_history_attempt_cravings_one"
        case historyAttemptDays = "smoking_history_attempt_days"
        case historyAttemptDaysOne = "smoking_history_attempt_days_one"
        case historyAttemptLongest = "smoking_history_attempt_longest"
        case historyAttemptNoSlips = "smoking_history_attempt_no_slips"
        case historyAttemptRange = "smoking_history_attempt_range"
        case historyAttemptRangeOpen = "smoking_history_attempt_range_open"
        case historyAttemptSaved = "smoking_history_attempt_saved"
        case historyAttemptSlips = "smoking_history_attempt_slips"
        case historyAttemptSlipsOne = "smoking_history_attempt_slips_one"
        case historyAttemptTitle = "smoking_history_attempt_title"
        case historyAttemptUnderDay = "smoking_history_attempt_under_day"
        case historyAttemptsTitle = "smoking_history_attempts_title"
        case historyDayToday = "smoking_history_day_today"
        case historyDayYesterday = "smoking_history_day_yesterday"
        case historyDeleteMessage = "smoking_history_delete_message"
        case historyDeleteTitle = "smoking_history_delete_title"
        case historyEditDelete = "smoking_history_edit_delete"
        case historyEditMarkerHint = "smoking_history_edit_marker_hint"
        case historyEditTime = "smoking_history_edit_time"
        case historyEditTitle = "smoking_history_edit_title"
        case historyEmptyBack = "smoking_history_empty_back"
        case historyEmptyBody = "smoking_history_empty_body"
        case historyEmptyHowCraving = "smoking_history_empty_how_craving"
        case historyEmptyHowSmoked = "smoking_history_empty_how_smoked"
        case historyEmptyHowTitle = "smoking_history_empty_how_title"
        case historyEmptyTitle = "smoking_history_empty_title"
        case historyErrorFuture = "smoking_history_error_future"
        case historyErrorInvalid = "smoking_history_error_invalid"
        case historyJourneyDays = "smoking_history_journey_days"
        case historyJourneyDaysOne = "smoking_history_journey_days_one"
        case historyJourneyOverline = "smoking_history_journey_overline"
        case historyLogTitle = "smoking_history_log_title"
        case historyRowCraving = "smoking_history_row_craving"
        case historyRowIntensity = "smoking_history_row_intensity"
        case historyRowNone = "smoking_history_row_none"
        case historyRowSmoked = "smoking_history_row_smoked"
        case historySupportBody = "smoking_history_support_body"
        case historySupportTitle = "smoking_history_support_title"
        case historyTitle = "smoking_history_title"
    }

    static func localized(_ key: HistoryKey) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
