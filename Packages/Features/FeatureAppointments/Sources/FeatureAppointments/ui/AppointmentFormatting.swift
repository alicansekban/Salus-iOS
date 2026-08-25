// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/ui/AppointmentFormatting.kt`.
//
// Kotlin returns a `@StringRes Int` and the composable resolves it; a Swift accessor already *is*
// the resolved string (`AppointmentsStrings`), so the function returns one. Same three arms, same
// `else` catch-all.

/// Shared by the editor's offset chips and the detail screen's reminder chips
/// (`AppointmentFormatting.kt:7-12`).
///
/// The two cases are `ReminderOffsets.ONE_HOUR` and `ONE_DAY` on Android and the editor's own
/// constants here, rather than a second spelling of the same two numbers.
func offsetLabel(_ minutes: Int) -> String {
    switch minutes {
    case ReminderOffsets.oneHour: AppointmentsStrings.offsetHour
    case ReminderOffsets.oneDay: AppointmentsStrings.offsetDay
    // Every other offset reads as a week, exactly as Kotlin's `else` arm does: the preset list is
    // closed at three, so nothing else can reach this.
    default: AppointmentsStrings.offsetWeek
    }
}
