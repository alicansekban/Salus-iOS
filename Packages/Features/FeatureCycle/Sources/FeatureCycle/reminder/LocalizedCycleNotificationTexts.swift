// The shipped ``CycleNotificationTexts``, the twin of
// `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/reminder/
// AndroidCycleNotificationTexts.kt` resolving the same three `R.string` ids off a `Context`.
//
// `CycleStrings` resolves against this package's own bundle, which is exactly what `R.string`
// does against `:feature:cycle`, so nothing platform-shaped is left to inject and the type is
// named for what it does rather than for the platform it runs on — the naming
// `LocalizedMedicationNotificationTexts` settled.

/// Resolves the period-reminder notification texts from the feature's string catalog
/// (`AndroidCycleNotificationTexts.kt:7-18`).
public struct LocalizedCycleNotificationTexts: CycleNotificationTexts {
    public init() {}

    /// `AndroidCycleNotificationTexts.kt:11`.
    public func title() -> String {
        CycleStrings.reminderNotificationTitle
    }

    /// `AndroidCycleNotificationTexts.kt:13-17` — the predicted day itself gets its own sentence
    /// rather than "in 0 days".
    public func body(leadDays: Int) -> String {
        leadDays == 0
            ? CycleStrings.reminderNotificationBodyToday
            : CycleStrings.reminderNotificationBodyDays(leadDays)
    }
}
