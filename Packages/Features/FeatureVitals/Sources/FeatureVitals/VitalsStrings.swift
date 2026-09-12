// The twin of `feature/vitals/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/vitals/src/main/res/values-en/strings.xml` — all 56 keys `:feature:vitals` owns, name
// and text verbatim, resolved against this package's own bundle exactly as `R.string` resolves
// against `:feature:vitals`.
//
// **`vitals_title` is the one key iOS keeps that Android M15 deleted.** Compose's M15 root draws no
// title of its own, so the key had no reader left there. On iOS `.navigationTitle` is what names
// the back button of everything this root pushes and what VoiceOver reads for the screen, so the
// key stays and the value stays Android's last one. A recorded divergence, not a missed deletion.
//
// **Overlines are stored upper-case** (`vitals_weight_label`, `vitals_latest_label`,
// `vitals_chart_section`, …): spec §6's rule, and the reason no call site ever calls `uppercased()`
// — Turkish has two dotted i's and the runtime cannot know which one a label means.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Android's specifiers are
// Java's; two keys carry them, and each is rewritten to the Swift spelling of the same argument:
//
//   Android      Swift        Keys                              Why
//   ---------------------------------------------------------------------------------------------
//   %1$s %2$s    %1$@ %2$@    vitals_kpi_chip                   `%s` under `String(format:)` reads
//                                                               a C string pointer. Handed a Swift
//                                                               `String` it prints garbage or
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
import SalusCommon

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
    public static var deleteTitle: String { localized(.deleteTitle) }
    public static var deleteMessage: String { localized(.deleteMessage) }
    public static var entryDeleted: String { localized(.entryDeleted) }
    public static var openTrends: String { localized(.openTrends) }

    // MARK: - M15 list

    public static var kpiWeight: String { localized(.kpiWeight) }
    public static var kpiBloodPressure: String { localized(.kpiBloodPressure) }
    public static var kpiGlucose: String { localized(.kpiGlucose) }
    public static var valueNone: String { localized(.valueNone) }
    public static var latestLabel: String { localized(.latestLabel) }
    public static var chartSection: String { localized(.chartSection) }
    public static var historySection: String { localized(.historySection) }
    public static var metricMax: String { localized(.metricMax) }
    public static var metricAvg: String { localized(.metricAvg) }
    public static var metricMin: String { localized(.metricMin) }
    public static var edit: String { localized(.edit) }

    // MARK: - M15 editor

    public static var editorTitleNew: String { localized(.editorTitleNew) }
    public static var editorTitleEdit: String { localized(.editorTitleEdit) }
    public static var editorSubtitle: String { localized(.editorSubtitle) }
    public static var editorTip: String { localized(.editorTip) }
    public static var bpHintSys: String { localized(.bpHintSys) }
    public static var bpHintDia: String { localized(.bpHintDia) }
    public static var saveMeasurement: String { localized(.saveMeasurement) }
    public static var notePlaceholder: String { localized(.notePlaceholder) }

    // MARK: - Formatted strings

    /// `vitals_kpi_chip` — "%1$@ · %2$@" in both languages: a metric's name joined to its value.
    public static func kpiChip(_ metric: String, _ value: String) -> String {
        String(format: localized(.kpiChip), locale: .current, metric, value)
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
        case empty = "vitals_empty"
        case emptyBloodPressure = "vitals_empty_blood_pressure"
        case emptyGlucose = "vitals_empty_glucose"
        case addEntry = "vitals_add_entry"
        case rangeWeek = "vitals_range_week"
        case rangeMonth = "vitals_range_month"
        case rangeQuarter = "vitals_range_quarter"
        case rangeYear = "vitals_range_year"
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
        case deleteTitle = "vitals_delete_title"
        case deleteMessage = "vitals_delete_message"
        case entryDeleted = "vitals_entry_deleted"
        case openTrends = "vitals_open_trends"
        case kpiWeight = "vitals_kpi_weight"
        case kpiBloodPressure = "vitals_kpi_blood_pressure"
        case kpiGlucose = "vitals_kpi_glucose"
        case kpiChip = "vitals_kpi_chip"
        case valueNone = "vitals_value_none"
        case latestLabel = "vitals_latest_label"
        case chartSection = "vitals_chart_section"
        case historySection = "vitals_history_section"
        case metricMax = "vitals_metric_max"
        case metricAvg = "vitals_metric_avg"
        case metricMin = "vitals_metric_min"
        case edit = "vitals_edit"
        case editorTitleNew = "vitals_editor_title_new"
        case editorTitleEdit = "vitals_editor_title_edit"
        case editorSubtitle = "vitals_editor_subtitle"
        case editorTip = "vitals_editor_tip"
        case bpHintSys = "vitals_bp_hint_sys"
        case bpHintDia = "vitals_bp_hint_dia"
        case saveMeasurement = "vitals_save_measurement"
        case notePlaceholder = "vitals_note_placeholder"
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
