// The three enum-typed lookups the Home screen needs, kept out of `HomeStrings.swift`.
//
// No Kotlin counterpart file: `HomeScreen.kt` writes each of these as a `when` at the call site
// (`when (greeting) { MORNING -> R.string.home_greeting_morning; … }`,
// `when (status) { TAKEN -> R.string.dose_status_taken; … }`, and the mg/dL-vs-mmol/L branch inside
// the vitals card). Hoisting them here is the iOS house pattern — a screen never names a catalog key
// — and it keeps the four greeting cases, the four dose statuses and the two glucose units exhaustive
// against their enums, so a new case is a compile error rather than a missing label.
//
// **The plain accessors in `HomeStrings.swift` stay.** These add a typed door to keys that already
// have one; `HomeStringsTests` asserts against `HomeStrings.Key`, which is untouched, and the string
// pin stays at 27.
//
// This lives in a separate file rather than in `HomeStrings.swift` for one reason: the accessors
// there are a flat transcription of the Android XML, and mixing switches over feature enums into it
// would make the key list stop reading as one. It is also why this file, not that one, imports
// `SalusModel`.

import SalusModel

extension HomeStrings {
    /// The header's greeting (`HomeScreen.kt`'s `when (state.greeting)`).
    public static func greeting(_ greeting: HomeGreeting) -> String {
        switch greeting {
        case .morning: greetingMorning
        case .afternoon: greetingAfternoon
        case .evening: greetingEvening
        case .night: greetingNight
        }
    }

    /// A dose row's status chip label (`HomeScreen.kt`'s `when (dose.status)`).
    public static func doseStatus(_ status: DoseStatus) -> String {
        switch status {
        case .taken: doseStatusTaken
        case .snoozed: doseStatusSnoozed
        case .pending: doseStatusPending
        case .missed: doseStatusMissed
        }
    }

    /// The glucose line in the unit the user reads in.
    ///
    /// The value is the already-formatted number, as on Android — and already converted: the
    /// snapshot carries mg/dL, and the caller runs `GlucoseConversion.fromMgDl` before formatting
    /// (divergence (k)). This picks the sentence, not the arithmetic.
    public static func vitalsGlucose(_ value: String, unit: GlucoseUnit) -> String {
        switch unit {
        case .mgDl: vitalsGlucoseMgdl(value)
        case .mmolL: vitalsGlucoseMmol(value)
        }
    }
}
