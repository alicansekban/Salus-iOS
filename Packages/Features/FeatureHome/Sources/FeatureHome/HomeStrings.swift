// The twin of `feature/home/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/home/src/main/res/values-en/strings.xml` — all 42 keys `:feature:home` declares, name
// and text verbatim, resolved against this package's own bundle exactly as `R.string` resolves
// against `:feature:home`.
//
// THE M15 SWEEP, key for key (Android `3391896..529a30f`). The table grew from 34 to 42: nine keys
// were added (`home_overline_today`, `home_see_all`, `home_ai_new_summary`, the three
// `home_pager_*` page labels, `home_next_dose`, `home_next_dose_none`, `home_last_dose`), exactly
// one was deleted (`home_ai_summary_free_credit` — the AI card announces a new summary with a
// control now, not with a credit line), and three kept their name while their text changed
// (`home_view_details` in Turkish only, `today_appointments_title` and `home_take_dose` in both).
// A `git diff` of the XML lists four `-` lines for that last group plus the deletion; only the
// deletion is a key that left, which is why the count here is 34 + 9 − 1.
//
// ONE OF THE 42 IS CARRIED FOR PARITY AND READ BY NOTHING ON iOS, and it is a component
// divergence rather than a screen decision: `SalusHeroBand` does not port Kotlin's
// `trailingOverline` slot (`SalusHeroBand.swift`'s header, spec §3.3), so Home's band spends its
// one overline on the date and never draws `home_overline_today`. It stays in the catalog because
// the key-set pin is Android's key set, not iOS's call sites — dropping it would make the next
// Android string sweep look like a divergence.
//
// TWO ANDROID KEYS WERE DELIBERATELY NOT PORTED, and the omission is still the point: `home_title`
// and `home_settings` were declared in both locales and read by nothing — `HomeScreen.kt` named
// neither. They were leftovers of Android's M9, which removed the settings gear and moved the
// title to the shell. Porting them would have put two keys in the catalog and in the key-set pin
// that no accessor ever asks for. Android deleted them itself in `aebb056`, so the two key sets
// agree; `HomeStringsTests` keeps the guard that neither comes back here alone.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Android's specifiers are
// Java's; ten keys carry them, and each is rewritten to the Swift spelling of the same argument:
//
//   Android      Swift        Keys                        Why
//   -------------------------------------------------------------------------------------------
//   %1$d         %1$lld       today_cycle_day,            Swift's `Int` is 64-bit and `%d` reads
//                             home_dose_progress          32, so a `%d` here is a truncation
//                                                         waiting for a bigger number.
//   %1$s         %1$@         today_vitals_weight,        `%s` under `String(format:)` reads a C
//                             today_vitals_glucose_mgdl,  string pointer, not a Swift `String`.
//                             today_vitals_glucose_mmol,
//                             home_greeting_morning,
//                             home_greeting_afternoon,
//                             home_greeting_evening,
//                             home_greeting_night
//   %1$s/%2$s    %1$@/%2$@    today_vitals_bp,            Same, twice: systolic and diastolic;
//                             home_next_dose              medication name and time.
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
    // MARK: - The hero band (10)

    /// `home_overline_today` — "BUGÜN" / "TODAY", stored upper-case (spec §6).
    ///
    /// Kotlin's hero puts this in the overline and the date in `trailingOverline`
    /// (`HomeScreen.kt:196-199`); iOS's `SalusHeroBand` has one overline slot and spends it on the
    /// date, so nothing reads this today. See the file header.
    public static var overlineToday: String { localized(.overlineToday) }

    /// `home_greeting_morning` — "Günaydın, %1$@" / "Good morning, %1$@".
    public static func greetingMorning(_ name: String) -> String {
        formatted(.greetingMorning, name)
    }

    /// `home_greeting_afternoon` — "İyi günler, %1$@" / "Good afternoon, %1$@".
    public static func greetingAfternoon(_ name: String) -> String {
        formatted(.greetingAfternoon, name)
    }

    /// `home_greeting_evening` — "İyi akşamlar, %1$@" / "Good evening, %1$@".
    public static func greetingEvening(_ name: String) -> String {
        formatted(.greetingEvening, name)
    }

    /// `home_greeting_night` — "İyi geceler, %1$@" / "Good night, %1$@".
    public static func greetingNight(_ name: String) -> String {
        formatted(.greetingNight, name)
    }

    /// `home_greeting_morning_plain` — "Günaydın" / "Good morning".
    public static var greetingMorningPlain: String { localized(.greetingMorningPlain) }
    /// `home_greeting_afternoon_plain` — "İyi günler" / "Good afternoon".
    public static var greetingAfternoonPlain: String { localized(.greetingAfternoonPlain) }
    /// `home_greeting_evening_plain` — "İyi akşamlar" / "Good evening".
    public static var greetingEveningPlain: String { localized(.greetingEveningPlain) }
    /// `home_greeting_night_plain` — "İyi geceler" / "Good night".
    public static var greetingNightPlain: String { localized(.greetingNightPlain) }

    /// `home_dose_progress` — "Bugünün ilerlemesi %1$lld/%2$lld" / "Today's progress %1$lld/%2$lld".
    public static func doseProgress(_ taken: Int, _ total: Int) -> String {
        formatted(.doseProgress, taken, total)
    }

    // MARK: - The reminder readiness card (2)

    /// `home_reminders_broken_title` — "Alarmlar çalışmayacak" / "Alarms will not fire".
    public static var remindersBrokenTitle: String { localized(.remindersBrokenTitle) }
    /// `home_reminders_degraded_title` — "Alarmlar gecikebilir" / "Alarms may be late".
    public static var remindersDegradedTitle: String { localized(.remindersDegradedTitle) }

    // MARK: - The AI summary card (4)

    public static var aiSummaryTitle: String { localized(.aiSummaryTitle) }
    public static var aiSummaryDescription: String { localized(.aiSummaryDescription) }
    /// `home_ai_new_summary` — "Yeni Özet" / "New summary", the chip that announces an unspent free
    /// summary (`HomeCards.kt:79-84`).
    public static var aiNewSummary: String { localized(.aiNewSummary) }
    /// `home_view_details` — "Detaylı İncele" / "View details", the card's trailing affordance
    /// (`HomeCards.kt:98-102`).
    public static var viewDetails: String { localized(.viewDetails) }

    // MARK: - The doses page (10)

    public static var dosesTitle: String { localized(.dosesTitle) }
    public static var dosesEmpty: String { localized(.dosesEmpty) }
    public static var doseStatusTaken: String { localized(.doseStatusTaken) }
    public static var doseStatusSnoozed: String { localized(.doseStatusSnoozed) }
    public static var doseStatusPending: String { localized(.doseStatusPending) }
    public static var doseStatusMissed: String { localized(.doseStatusMissed) }
    public static var takeDose: String { localized(.takeDose) }

    /// `home_next_dose` — "Sıradaki: %1$@ · %2$@" / "Next: %1$@ · %2$@".
    ///
    /// Both arguments are already-resolved text, as on Android: the medication's own name and the
    /// time `HomeFormatting.minutes(_:locale:)` rendered.
    public static func nextDose(_ medicationName: String, _ time: String) -> String {
        formatted(.nextDose, medicationName, time)
    }

    /// `home_next_dose_none` — "Bugün bekleyen doz kalmadı." / "Nothing left to take today.".
    public static var nextDoseNone: String { localized(.nextDoseNone) }
    /// `home_last_dose` — "SON DOZ" / "LAST DOSE", stored upper-case (spec §6).
    public static var lastDose: String { localized(.lastDose) }

    // MARK: - The appointments section (3)

    public static var appointmentsTitle: String { localized(.appointmentsTitle) }
    public static var appointmentsEmpty: String { localized(.appointmentsEmpty) }
    /// `home_see_all` — "Tümünü Gör" / "See all", the section header's trailing action.
    public static var seeAll: String { localized(.seeAll) }

    // MARK: - The pager page labels (3)

    /// `home_pager_doses` — the doses page's accessibility label (`HomePager.kt:98`).
    public static var pagerDoses: String { localized(.pagerDoses) }
    /// `home_pager_vitals` — the vitals page's accessibility label (`HomePager.kt:110`).
    public static var pagerVitals: String { localized(.pagerVitals) }
    /// `home_pager_cycle` — the cycle page's accessibility label (`HomePager.kt:114`).
    public static var pagerCycle: String { localized(.pagerCycle) }

    // MARK: - The cycle page (4)

    public static var cycleTitle: String { localized(.cycleTitle) }
    public static var cycleEmpty: String { localized(.cycleEmpty) }

    /// `today_cycle_day` — "Döngünün %1$lld. günü" / "Cycle day %1$lld".
    public static func cycleDay(_ day: Int) -> String {
        formatted(.cycleDay, day)
    }

    public static var cyclePeriodOngoing: String { localized(.cyclePeriodOngoing) }

    // MARK: - The vitals page (6)

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
    /// Android's `home_title` and `home_settings` were never ported (both were dead there, and
    /// Android has since deleted them), so this enum and the XML are the same 42 keys.
    enum Key: String, CaseIterable {
        // The hero band (10).
        case overlineToday = "home_overline_today"
        case greetingMorning = "home_greeting_morning"
        case greetingAfternoon = "home_greeting_afternoon"
        case greetingEvening = "home_greeting_evening"
        case greetingNight = "home_greeting_night"
        case greetingMorningPlain = "home_greeting_morning_plain"
        case greetingAfternoonPlain = "home_greeting_afternoon_plain"
        case greetingEveningPlain = "home_greeting_evening_plain"
        case greetingNightPlain = "home_greeting_night_plain"
        case doseProgress = "home_dose_progress"

        // The reminder readiness card (2).
        case remindersBrokenTitle = "home_reminders_broken_title"
        case remindersDegradedTitle = "home_reminders_degraded_title"

        // The AI summary card (4).
        case aiSummaryTitle = "home_ai_summary_title"
        case aiSummaryDescription = "home_ai_summary_description"
        case aiNewSummary = "home_ai_new_summary"
        case viewDetails = "home_view_details"

        // The doses page (10).
        case dosesTitle = "today_doses_title"
        case dosesEmpty = "today_doses_empty"
        case doseStatusTaken = "dose_status_taken"
        case doseStatusSnoozed = "dose_status_snoozed"
        case doseStatusPending = "dose_status_pending"
        case doseStatusMissed = "dose_status_missed"
        case takeDose = "home_take_dose"
        case nextDose = "home_next_dose"
        case nextDoseNone = "home_next_dose_none"
        case lastDose = "home_last_dose"

        // The appointments section (3).
        case appointmentsTitle = "today_appointments_title"
        case appointmentsEmpty = "today_appointments_empty"
        case seeAll = "home_see_all"

        // The pager page labels (3).
        case pagerDoses = "home_pager_doses"
        case pagerVitals = "home_pager_vitals"
        case pagerCycle = "home_pager_cycle"

        // The cycle page (4).
        case cycleTitle = "today_cycle_title"
        case cycleEmpty = "today_cycle_empty"
        case cycleDay = "today_cycle_day"
        case cyclePeriodOngoing = "today_cycle_period_ongoing"

        // The vitals page (6).
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

    /// The two-argument form, for `today_vitals_bp`, `home_dose_progress` and `home_next_dose` —
    /// the three keys Android gives two placeholders.
    private static func formatted(_ key: Key, _ first: CVarArg, _ second: CVarArg) -> String {
        String(format: localized(key), locale: .current, first, second)
    }
}
