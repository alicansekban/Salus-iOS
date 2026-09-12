// The twin of `feature/cycle/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/cycle/src/main/res/values-en/strings.xml` — all 64 keys `:feature:cycle` owns in its M15
// shape, name and text verbatim, resolved against this package's own bundle exactly as `R.string`
// resolves against `:feature:cycle`.
//
// TURKISH MIXES "Regl" AND "Dönem", and that is Android's copy, not a slip to tidy up. The
// calendar surfaces say "Regl" (`cycle_legend_period`, `cycle_period_started`,
// `cycle_days_until_period`); the reminder surfaces say "Dönem" (`cycle_reminder_title`,
// `cycle_reminder_notification_title`). Unifying them here would make the two platforms read
// differently for the same user, which is the one thing this port is not allowed to do. If the
// wording is ever settled, it is settled in the Android XML first and copied back.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. Android's specifiers are
// Java's; Android carries `%1$s` on three M15 keys, each rewritten to the Swift `%1$@` spelling
// of the same argument (a `String`), plus the two-`%1$s` `cycle_reminder_summary`:
//
//   Android      Swift        Keys                                    Why
//   -------------------------------------------------------------------------------------------
//   %1$d         %1$lld       cycle_day_number,                       Swift's `Int` is 64-bit and
//                             cycle_days_until_period,                `%d` reads 32, so a `%d`
//                             cycle_period_overdue,                   here is a truncation
//                             cycle_reminder_lead_days_before,        waiting for a bigger
//                             cycle_reminder_notification_body_days   number. `%lld` is the exact
//                                                                     width.
//   %1$s         %1$@         cycle_confidence_chip,                 `%s` under `String(format:)`
//                             cycle_reminder_summary (two)            reads a C string pointer.
//                                                                     Handed a Swift `String` it
//                                                                     prints garbage or crashes;
//                                                                     `%@` is the object form.
//
// The sentence around every specifier is unchanged, and `CycleStringsTests` pins the rendered text
// in both languages so the mapping cannot drift into a reworded string.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why the tests assert against the FILE and against the key a mapping picks, never against
// a resolved string; the end-to-end check is the simulator run.

import Foundation
import SalusCommon
import SalusModel

/// The strings `:feature:cycle` owns.
public enum CycleStrings {
    // MARK: - The calendar screen: chrome and legend (6)

    public static var title: String { localized(.title) }
    public static var previousMonth: String { localized(.previousMonth) }
    public static var nextMonth: String { localized(.nextMonth) }
    public static var legendPeriod: String { localized(.legendPeriod) }
    public static var legendPredicted: String { localized(.legendPredicted) }
    public static var legendFertile: String { localized(.legendFertile) }

    // MARK: - The M15 chrome: overline and today (2)

    public static var overline: String { localized(.overline) }

    /// `cycle_today_cd` — the "today" icon button's accessibility label.
    public static var today: String { localized(.today) }

    // MARK: - The prediction summary (9)

    /// `cycle_day_number` — "Döngünün %1$lld. günü" / "Cycle day %1$lld".
    public static func dayNumber(_ day: Int) -> String {
        formatted(.dayNumber, day)
    }

    /// `cycle_days_until_period` — "Tahmini regl %1$lld gün sonra" / "Predicted next period in %1$lld days".
    public static func daysUntilPeriod(_ days: Int) -> String {
        formatted(.daysUntilPeriod, days)
    }

    /// `cycle_period_overdue` — "Tahmini regl %1$lld gün gecikti" / "Predicted period is %1$lld days late".
    public static func periodOverdue(_ days: Int) -> String {
        formatted(.periodOverdue, days)
    }

    public static var noPrediction: String { localized(.noPrediction) }
    public static var periodDueToday: String { localized(.periodDueToday) }

    public static var confidenceLow: String { localized(.confidenceLow) }
    public static var confidenceMedium: String { localized(.confidenceMedium) }
    public static var confidenceHigh: String { localized(.confidenceHigh) }

    /// `cycle_confidence_chip` — "Güven: %1$@" / "Confidence: %1$@".
    ///
    /// The argument is the already-localized confidence label, as on Android, where the outer
    /// `stringResource` takes the inner one as its argument (`CycleAnalysisCard.kt:46-49`).
    public static func confidenceChip(_ label: String) -> String {
        formatted(.confidenceChip, label)
    }

    public static var irregular: String { localized(.irregular) }

    // MARK: - The analysis card and today's symptoms (5)

    public static var analysisTitle: String { localized(.analysisTitle) }
    public static var todaySymptoms: String { localized(.todaySymptoms) }
    public static var seeAll: String { localized(.seeAll) }
    public static var noSymptomsToday: String { localized(.noSymptomsToday) }
    public static var notePlaceholder: String { localized(.notePlaceholder) }

    // MARK: - The day screen: actions and section headers (8)

    public static var periodStarted: String { localized(.periodStarted) }
    public static var periodEnded: String { localized(.periodEnded) }
    public static var disclaimer: String { localized(.disclaimer) }
    public static var symptomsTitle: String { localized(.symptomsTitle) }
    public static var flowTitle: String { localized(.flowTitle) }
    public static var moodTitle: String { localized(.moodTitle) }
    public static var noteLabel: String { localized(.noteLabel) }
    public static var save: String { localized(.save) }

    // MARK: - The symptom catalog (8)

    public static var symptomCramps: String { localized(.symptomCramps) }
    public static var symptomHeadache: String { localized(.symptomHeadache) }
    public static var symptomMoodSwings: String { localized(.symptomMoodSwings) }
    public static var symptomBloating: String { localized(.symptomBloating) }
    public static var symptomFatigue: String { localized(.symptomFatigue) }
    public static var symptomTenderBreasts: String { localized(.symptomTenderBreasts) }
    public static var symptomAcne: String { localized(.symptomAcne) }
    public static var symptomBackPain: String { localized(.symptomBackPain) }

    // MARK: - The flow levels (4)

    public static var flowSpotting: String { localized(.flowSpotting) }
    public static var flowLight: String { localized(.flowLight) }
    public static var flowMedium: String { localized(.flowMedium) }
    public static var flowHeavy: String { localized(.flowHeavy) }

    // MARK: - The moods (6)

    public static var moodGreat: String { localized(.moodGreat) }
    public static var moodGood: String { localized(.moodGood) }
    public static var moodNeutral: String { localized(.moodNeutral) }
    public static var moodLow: String { localized(.moodLow) }
    public static var moodIrritable: String { localized(.moodIrritable) }
    public static var moodAnxious: String { localized(.moodAnxious) }

    // MARK: - The period reminder settings card (10)

    public static var reminderTitle: String { localized(.reminderTitle) }
    public static var reminderDescription: String { localized(.reminderDescription) }
    public static var reminderNeedsData: String { localized(.reminderNeedsData) }
    public static var reminderLeadLabel: String { localized(.reminderLeadLabel) }
    public static var reminderTimeLabel: String { localized(.reminderTimeLabel) }
    public static var reminderLeadSameDay: String { localized(.reminderLeadSameDay) }

    /// `cycle_reminder_lead_days_before` — "%1$lld gün önce" / "%1$lld days before".
    public static func reminderLeadDaysBefore(_ days: Int) -> String {
        formatted(.reminderLeadDaysBefore, days)
    }

    public static var reminderCancel: String { localized(.reminderCancel) }
    public static var reminderTimeConfirm: String { localized(.reminderTimeConfirm) }

    /// `cycle_reminder_summary` — "%1$@ · %2$@" / "%1$@ · %2$@", for the reminder card's subtitle
    /// when a usable prediction exists. The arguments are the lead-day label and the time.
    public static func reminderSummary(_ leadLabel: String, _ time: String) -> String {
        String(format: localized(.reminderSummary), locale: .current, leadLabel, time)
    }

    // MARK: - The reminder notification (3)

    public static var reminderNotificationTitle: String { localized(.reminderNotificationTitle) }
    public static var reminderNotificationBodyToday: String { localized(.reminderNotificationBodyToday) }

    /// `cycle_reminder_notification_body_days` — the predicted start is `days` away.
    public static func reminderNotificationBodyDays(_ days: Int) -> String {
        formatted(.reminderNotificationBodyDays, days)
    }

    // MARK: - What VoiceOver says on a calendar day (2)

    public static var a11yToday: String { localized(.a11yToday) }
    public static var a11yOvulation: String { localized(.a11yOvulation) }

    // MARK: - The label lookups

    /// The label for a symptom catalog entry, the twin of `CycleDayScreen.kt:181-191`.
    ///
    /// A day's symptoms are stored by name key, and the eight seeded entries have a translation.
    /// Anything else is a symptom the user typed, which exists in no catalog and is shown exactly
    /// as it was written.
    public static func symptomLabel(nameKey: String) -> String {
        guard let key = symptomKey(nameKey: nameKey) else { return nameKey }
        return localized(key)
    }

    /// The label for a flow level, the twin of `CycleDayScreen.kt:194-199`.
    public static func flowLabel(_ level: FlowLevel) -> String {
        localized(flowKey(level))
    }

    /// The label for a mood, the twin of `CycleDayScreen.kt:202-209`.
    public static func moodLabel(_ mood: Mood) -> String {
        localized(moodKey(mood))
    }

    /// The label for a prediction's confidence, the twin of `CycleScreen.kt:536-540`.
    public static func confidenceLabel(_ confidence: CycleConfidence) -> String {
        localized(confidenceKey(confidence))
    }

    /// The catalog key of a seeded symptom, or `nil` for an entry the user added.
    ///
    /// Split out of `symptomLabel` so the mapping can be asserted without resolving a string —
    /// `swift test` does not compile the catalog (see the toolchain note above).
    static func symptomKey(nameKey: String) -> Key? {
        switch nameKey {
        case "cramps": .symptomCramps
        case "headache": .symptomHeadache
        case "mood_swings": .symptomMoodSwings
        case "bloating": .symptomBloating
        case "fatigue": .symptomFatigue
        case "tender_breasts": .symptomTenderBreasts
        case "acne": .symptomAcne
        case "back_pain": .symptomBackPain
        default: nil
        }
    }

    static func flowKey(_ level: FlowLevel) -> Key {
        switch level {
        case .spotting: .flowSpotting
        case .light: .flowLight
        case .medium: .flowMedium
        case .heavy: .flowHeavy
        }
    }

    static func moodKey(_ mood: Mood) -> Key {
        switch mood {
        case .great: .moodGreat
        case .good: .moodGood
        case .neutral: .moodNeutral
        case .low: .moodLow
        case .irritable: .moodIrritable
        case .anxious: .moodAnxious
        }
    }

    static func confidenceKey(_ confidence: CycleConfidence) -> Key {
        switch confidence {
        case .low: .confidenceLow
        case .medium: .confidenceMedium
        case .high: .confidenceHigh
        }
    }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        // The calendar screen: chrome and legend (8).
        case title = "cycle_title"
        case previousMonth = "cycle_previous_month"
        case nextMonth = "cycle_next_month"
        case legendPeriod = "cycle_legend_period"
        case legendPredicted = "cycle_legend_predicted"
        case legendFertile = "cycle_legend_fertile"
        case overline = "cycle_overline"
        case today = "cycle_today_cd"

        // The prediction summary (9).
        case dayNumber = "cycle_day_number"
        case daysUntilPeriod = "cycle_days_until_period"
        case periodOverdue = "cycle_period_overdue"
        case noPrediction = "cycle_no_prediction"
        case periodDueToday = "cycle_period_due_today"
        case confidenceLow = "cycle_confidence_low"
        case confidenceMedium = "cycle_confidence_medium"
        case confidenceHigh = "cycle_confidence_high"
        case confidenceChip = "cycle_confidence_chip"
        case irregular = "cycle_irregular"

        // The analysis card and today's symptoms (5).
        case analysisTitle = "cycle_analysis_title"
        case todaySymptoms = "cycle_today_symptoms"
        case seeAll = "cycle_see_all"
        case noSymptomsToday = "cycle_no_symptoms_today"
        case notePlaceholder = "cycle_note_placeholder"

        // The day screen: actions and section headers (8).
        case periodStarted = "cycle_period_started"
        case periodEnded = "cycle_period_ended"
        case disclaimer = "cycle_disclaimer"
        case symptomsTitle = "cycle_symptoms_title"
        case flowTitle = "cycle_flow_title"
        case moodTitle = "cycle_mood_title"
        case noteLabel = "cycle_note_label"
        case save = "cycle_save"

        // The symptom catalog (8).
        case symptomCramps = "cycle_symptom_cramps"
        case symptomHeadache = "cycle_symptom_headache"
        case symptomMoodSwings = "cycle_symptom_mood_swings"
        case symptomBloating = "cycle_symptom_bloating"
        case symptomFatigue = "cycle_symptom_fatigue"
        case symptomTenderBreasts = "cycle_symptom_tender_breasts"
        case symptomAcne = "cycle_symptom_acne"
        case symptomBackPain = "cycle_symptom_back_pain"

        // The flow levels (4).
        case flowSpotting = "cycle_flow_spotting"
        case flowLight = "cycle_flow_light"
        case flowMedium = "cycle_flow_medium"
        case flowHeavy = "cycle_flow_heavy"

        // The moods (6).
        case moodGreat = "cycle_mood_great"
        case moodGood = "cycle_mood_good"
        case moodNeutral = "cycle_mood_neutral"
        case moodLow = "cycle_mood_low"
        case moodIrritable = "cycle_mood_irritable"
        case moodAnxious = "cycle_mood_anxious"

        // The period reminder settings card (10).
        case reminderTitle = "cycle_reminder_title"
        case reminderDescription = "cycle_reminder_desc"
        case reminderNeedsData = "cycle_reminder_needs_data"
        case reminderLeadLabel = "cycle_reminder_lead_label"
        case reminderTimeLabel = "cycle_reminder_time_label"
        case reminderLeadSameDay = "cycle_reminder_lead_same_day"
        case reminderLeadDaysBefore = "cycle_reminder_lead_days_before"
        case reminderSummary = "cycle_reminder_summary"
        case reminderCancel = "cycle_reminder_cancel"
        case reminderTimeConfirm = "cycle_reminder_time_confirm"

        // The reminder notification (3).
        case reminderNotificationTitle = "cycle_reminder_notification_title"
        case reminderNotificationBodyToday = "cycle_reminder_notification_body_today"
        case reminderNotificationBodyDays = "cycle_reminder_notification_body_days"

        // What VoiceOver says on a calendar day (2).
        case a11yToday = "cycle_a11y_today"
        case a11yOvulation = "cycle_a11y_ovulation"
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
