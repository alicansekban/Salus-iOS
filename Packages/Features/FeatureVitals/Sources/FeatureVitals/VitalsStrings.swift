// The twin of `feature/vitals/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/vitals/src/main/res/values-en/strings.xml` — all 48 keys `:feature:vitals` owns, name
// and text verbatim, resolved against this package's own bundle exactly as `R.string` resolves
// against `:feature:vitals`.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Android's specifiers are
// Java's; four keys carry one each, and each is rewritten to the Swift spelling of the same
// argument:
//
//   Android      Swift        Keys                              Why
//   ---------------------------------------------------------------------------------------------
//   %1$s         %1$@         vitals_latest_weight,             `%s` under `String(format:)` reads
//                             vitals_latest_blood_pressure,     a C string pointer. Handed a Swift
//                             vitals_latest_glucose             `String` it prints garbage or
//                                                               crashes; `%@` is the object form.
//   %1$d         %1$lld       vitals_pulse_value                Swift's `Int` is 64-bit and `%d`
//                                                               reads 32, so a `%d` here is a
//                                                               truncation waiting for a bigger
//                                                               number. `%lld` is the exact width.
//
// The sentence around the specifier is unchanged, and `VitalsStringsTests` pins the rendered text
// in both languages so the mapping cannot drift into a reworded string.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE and never against a resolved string; the
// end-to-end check is the simulator run.

import Foundation

/// The strings `:feature:vitals` owns.
public enum VitalsStrings {
    public static var title: String { localized(.title) }
    public static var typeWeight: String { localized(.typeWeight) }
    public static var typeBloodPressure: String { localized(.typeBloodPressure) }
    public static var typeGlucose: String { localized(.typeGlucose) }
    public static var empty: String { localized(.empty) }
    public static var emptyBloodPressure: String { localized(.emptyBloodPressure) }
    public static var emptyGlucose: String { localized(.emptyGlucose) }
    public static var addEntry: String { localized(.addEntry) }
    public static var rangeWeek: String { localized(.rangeWeek) }
    public static var rangeMonth: String { localized(.rangeMonth) }
    public static var rangeQuarter: String { localized(.rangeQuarter) }
    public static var rangeYear: String { localized(.rangeYear) }
    public static var newTitle: String { localized(.newTitle) }
    public static var editTitle: String { localized(.editTitle) }
    public static var bloodPressureNewTitle: String { localized(.bloodPressureNewTitle) }
    public static var bloodPressureEditTitle: String { localized(.bloodPressureEditTitle) }
    public static var glucoseNewTitle: String { localized(.glucoseNewTitle) }
    public static var glucoseEditTitle: String { localized(.glucoseEditTitle) }
    public static var weightLabel: String { localized(.weightLabel) }
    public static var systolicLabel: String { localized(.systolicLabel) }
    public static var diastolicLabel: String { localized(.diastolicLabel) }
    public static var pulseLabel: String { localized(.pulseLabel) }
    public static var glucoseValueLabel: String { localized(.glucoseValueLabel) }
    public static var noteLabel: String { localized(.noteLabel) }
    public static var invalidWeight: String { localized(.invalidWeight) }
    public static var invalidSystolic: String { localized(.invalidSystolic) }
    public static var invalidDiastolic: String { localized(.invalidDiastolic) }
    public static var invalidPulse: String { localized(.invalidPulse) }
    public static var invalidBpDifference: String { localized(.invalidBpDifference) }
    public static var invalidGlucose: String { localized(.invalidGlucose) }
    public static var contextFasting: String { localized(.contextFasting) }
    public static var contextPostMeal: String { localized(.contextPostMeal) }
    public static var contextBedtime: String { localized(.contextBedtime) }
    public static var contextRandom: String { localized(.contextRandom) }
    public static var selectDate: String { localized(.selectDate) }
    public static var save: String { localized(.save) }
    public static var delete: String { localized(.delete) }
    public static var back: String { localized(.back) }
    public static var ok: String { localized(.ok) }
    public static var cancel: String { localized(.cancel) }
    public static var deleteTitle: String { localized(.deleteTitle) }
    public static var deleteMessage: String { localized(.deleteMessage) }
    public static var entryDeleted: String { localized(.entryDeleted) }
    public static var openTrends: String { localized(.openTrends) }

    // MARK: - Formatted strings

    /// `vitals_latest_weight` — "Son kilo: %1$@" / "Latest weight: %1$@".
    public static func latestWeight(_ value: String) -> String {
        formatted(.latestWeight, value)
    }

    /// `vitals_latest_blood_pressure` — "Son ölçüm: %1$@" / "Latest: %1$@".
    public static func latestBloodPressure(_ value: String) -> String {
        formatted(.latestBloodPressure, value)
    }

    /// `vitals_latest_glucose` — "Son ölçüm: %1$@" / "Latest: %1$@".
    public static func latestGlucose(_ value: String) -> String {
        formatted(.latestGlucose, value)
    }

    /// `vitals_pulse_value` — "Nabız: %1$lld bpm" / "Pulse: %1$lld bpm".
    public static func pulseValue(_ bpm: Int) -> String {
        formatted(.pulseValue, bpm)
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case title = "vitals_title"
        case typeWeight = "vitals_type_weight"
        case typeBloodPressure = "vitals_type_blood_pressure"
        case typeGlucose = "vitals_type_glucose"
        case latestWeight = "vitals_latest_weight"
        case latestBloodPressure = "vitals_latest_blood_pressure"
        case latestGlucose = "vitals_latest_glucose"
        case empty = "vitals_empty"
        case emptyBloodPressure = "vitals_empty_blood_pressure"
        case emptyGlucose = "vitals_empty_glucose"
        case addEntry = "vitals_add_entry"
        case rangeWeek = "vitals_range_week"
        case rangeMonth = "vitals_range_month"
        case rangeQuarter = "vitals_range_quarter"
        case rangeYear = "vitals_range_year"
        case newTitle = "vitals_new_title"
        case editTitle = "vitals_edit_title"
        case bloodPressureNewTitle = "vitals_blood_pressure_new_title"
        case bloodPressureEditTitle = "vitals_blood_pressure_edit_title"
        case glucoseNewTitle = "vitals_glucose_new_title"
        case glucoseEditTitle = "vitals_glucose_edit_title"
        case weightLabel = "vitals_weight_label"
        case systolicLabel = "vitals_systolic_label"
        case diastolicLabel = "vitals_diastolic_label"
        case pulseLabel = "vitals_pulse_label"
        case pulseValue = "vitals_pulse_value"
        case glucoseValueLabel = "vitals_glucose_value_label"
        case noteLabel = "vitals_note_label"
        case invalidWeight = "vitals_invalid_weight"
        case invalidSystolic = "vitals_invalid_systolic"
        case invalidDiastolic = "vitals_invalid_diastolic"
        case invalidPulse = "vitals_invalid_pulse"
        case invalidBpDifference = "vitals_invalid_bp_difference"
        case invalidGlucose = "vitals_invalid_glucose"
        case contextFasting = "vitals_context_fasting"
        case contextPostMeal = "vitals_context_post_meal"
        case contextBedtime = "vitals_context_bedtime"
        case contextRandom = "vitals_context_random"
        case selectDate = "vitals_select_date"
        case save = "vitals_save"
        case delete = "vitals_delete"
        case back = "vitals_back"
        case ok = "vitals_ok"
        case cancel = "vitals_cancel"
        case deleteTitle = "vitals_delete_title"
        case deleteMessage = "vitals_delete_message"
        case entryDeleted = "vitals_entry_deleted"
        case openTrends = "vitals_open_trends"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .module)
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
