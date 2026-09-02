// The twin of `feature/home/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/home/src/main/res/values-en/strings.xml` — 27 of the 29 keys `:feature:home` declares,
// name and text verbatim, resolved against this package's own bundle exactly as `R.string`
// resolves against `:feature:home`.
//
// TWO ANDROID KEYS ARE DELIBERATELY NOT HERE, and the omission is the point: `home_title` and
// `home_settings` are declared in both locales and read by nothing — `HomeScreen.kt` names neither.
// They are leftovers of Android's M9, which removed the settings gear and moved the title to the
// shell. Porting them would put two keys in the catalog and in the key-set pin that no accessor
// ever asks for, so the pin here is 27 where Android's XML is 29. If Android ever deletes them,
// nothing on this side changes.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Android's specifiers are
// Java's; five keys carry them, and each is rewritten to the Swift spelling of the same argument:
//
//   Android      Swift        Keys                        Why
//   -------------------------------------------------------------------------------------------
//   %1$d         %1$lld       today_cycle_day             Swift's `Int` is 64-bit and `%d` reads
//                                                         32, so a `%d` here is a truncation
//                                                         waiting for a bigger number.
//   %1$s         %1$@         today_vitals_weight,        `%s` under `String(format:)` reads a C
//                             today_vitals_glucose_mgdl,  string pointer, not a Swift `String`.
//                             today_vitals_glucose_mmol
//   %1$s/%2$s    %1$@/%2$@    today_vitals_bp             Same, twice: systolic and diastolic.
//
// The sentence around every specifier is unchanged, and `HomeStringsTests` pins the rendered text
// in both languages so the mapping cannot drift into a reworded string.
//
// THE TURKISH OF `today_doses_empty` IS ANDROID'S AND STAYS ANDROID'S: "Bugün için planlı doz
// yok." `planlı` is one letter short of a stem `BannedHealthClaims` rejects, so the scan passes —
// but the margin is a single editorial nudge, and the English twin already says "scheduled". Never
// lengthen that word; if the wording is ever settled, it is settled in the Android XML first and
// copied back.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE, never against a resolved string; the end-to-end
// check is the simulator run.

import Foundation
import SalusCommon

/// The strings `:feature:home` owns.
public enum HomeStrings {
    // MARK: - The header: greeting and the card action (5)

    public static var greetingMorning: String { localized(.greetingMorning) }
    public static var greetingAfternoon: String { localized(.greetingAfternoon) }
    public static var greetingEvening: String { localized(.greetingEvening) }
    public static var greetingNight: String { localized(.greetingNight) }
    public static var viewDetails: String { localized(.viewDetails) }

    // MARK: - The AI summary card (3)

    public static var aiSummaryTitle: String { localized(.aiSummaryTitle) }
    public static var aiSummaryDescription: String { localized(.aiSummaryDescription) }
    public static var aiSummaryFreeCredit: String { localized(.aiSummaryFreeCredit) }

    // MARK: - The doses card (7)

    public static var dosesTitle: String { localized(.dosesTitle) }
    public static var dosesEmpty: String { localized(.dosesEmpty) }
    public static var doseStatusTaken: String { localized(.doseStatusTaken) }
    public static var doseStatusSnoozed: String { localized(.doseStatusSnoozed) }
    public static var doseStatusPending: String { localized(.doseStatusPending) }
    public static var doseStatusMissed: String { localized(.doseStatusMissed) }
    public static var takeDose: String { localized(.takeDose) }

    // MARK: - The appointments card (2)

    public static var appointmentsTitle: String { localized(.appointmentsTitle) }
    public static var appointmentsEmpty: String { localized(.appointmentsEmpty) }

    // MARK: - The cycle card (4)

    public static var cycleTitle: String { localized(.cycleTitle) }
    public static var cycleEmpty: String { localized(.cycleEmpty) }

    /// `today_cycle_day` — "Döngünün %1$lld. günü" / "Cycle day %1$lld".
    public static func cycleDay(_ day: Int) -> String {
        formatted(.cycleDay, day)
    }

    public static var cyclePeriodOngoing: String { localized(.cyclePeriodOngoing) }

    // MARK: - The vitals card (6)

    public static var vitalsTitle: String { localized(.vitalsTitle) }
    public static var vitalsEmpty: String { localized(.vitalsEmpty) }

    /// `today_vitals_weight` — "Kilo: %1$@ kg" / "Weight: %1$@ kg".
    ///
    /// The argument is the already-formatted number, as on Android, where `HomeScreen.kt` hands
    /// `formatNumber(...)` to `stringResource`.
    public static func vitalsWeight(_ value: String) -> String {
        formatted(.vitalsWeight, value)
    }

    /// `today_vitals_bp` — "Tansiyon: %1$@/%2$@ mmHg" / "Blood pressure: %1$@/%2$@ mmHg".
    public static func vitalsBloodPressure(_ systolic: String, _ diastolic: String) -> String {
        formatted(.vitalsBloodPressure, systolic, diastolic)
    }

    /// `today_vitals_glucose_mgdl` — "Kan şekeri: %1$@ mg/dL" / "Blood glucose: %1$@ mg/dL".
    public static func vitalsGlucoseMgdl(_ value: String) -> String {
        formatted(.vitalsGlucoseMgdl, value)
    }

    /// `today_vitals_glucose_mmol` — "Kan şekeri: %1$@ mmol/L" / "Blood glucose: %1$@ mmol/L".
    public static func vitalsGlucoseMmol(_ value: String) -> String {
        formatted(.vitalsGlucoseMmol, value)
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    ///
    /// Android's `home_title` and `home_settings` are absent on purpose: both are dead there (no
    /// `R.string` reads either since Android's M9), so this enum has 27 cases where the XML has 29.
    enum Key: String, CaseIterable {
        // The header: greeting and the card action (5).
        case greetingMorning = "home_greeting_morning"
        case greetingAfternoon = "home_greeting_afternoon"
        case greetingEvening = "home_greeting_evening"
        case greetingNight = "home_greeting_night"
        case viewDetails = "home_view_details"

        // The AI summary card (3).
        case aiSummaryTitle = "home_ai_summary_title"
        case aiSummaryDescription = "home_ai_summary_description"
        case aiSummaryFreeCredit = "home_ai_summary_free_credit"

        // The doses card (7).
        case dosesTitle = "today_doses_title"
        case dosesEmpty = "today_doses_empty"
        case doseStatusTaken = "dose_status_taken"
        case doseStatusSnoozed = "dose_status_snoozed"
        case doseStatusPending = "dose_status_pending"
        case doseStatusMissed = "dose_status_missed"
        case takeDose = "home_take_dose"

        // The appointments card (2).
        case appointmentsTitle = "today_appointments_title"
        case appointmentsEmpty = "today_appointments_empty"

        // The cycle card (4).
        case cycleTitle = "today_cycle_title"
        case cycleEmpty = "today_cycle_empty"
        case cycleDay = "today_cycle_day"
        case cyclePeriodOngoing = "today_cycle_period_ongoing"

        // The vitals card (6).
        case vitalsTitle = "today_vitals_title"
        case vitalsEmpty = "today_vitals_empty"
        case vitalsWeight = "today_vitals_weight"
        case vitalsBloodPressure = "today_vitals_bp"
        case vitalsGlucoseMgdl = "today_vitals_glucose_mgdl"
        case vitalsGlucoseMmol = "today_vitals_glucose_mmol"
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

    /// The two-argument form, for `today_vitals_bp` — the only key Android gives two placeholders.
    private static func formatted(_ key: Key, _ first: CVarArg, _ second: CVarArg) -> String {
        String(format: localized(key), locale: .current, first, second)
    }
}
