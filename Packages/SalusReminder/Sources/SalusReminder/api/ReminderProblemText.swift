// The twin of Android
// `core/reminder/src/main/kotlin/com/alicansekban/salus/core/reminder/ui/ReminderProblemText.kt`
// (`ReminderProblem.reasonRes()`), which answers the one-line sentence a steering surface shows
// under "reminders will not work" — the medication editor's post-save dialog and Home's reminder
// card both draw `problems.first`'s.
//
// It sits in `api/` rather than in a `ui/` folder of its own, where Kotlin has to put it: Android's
// version answers a `@StringRes Int` and therefore imports `androidx.annotation`, while a Swift
// accessor on ``ReminderStrings`` already *is* the resolved sentence, so this file imports nothing
// and stays as pure as the classification it sits beside (no UserNotifications, no AlarmKit, no
// SwiftUI, no UIKit — `SalusReminder` is host-built for the macOS test runner).
//
// The wording, and why the keys are not named after the cases: see the header of
// `ReminderStrings.swift`.

extension ReminderProblem {
    /// One line saying what this problem costs the user, ready to draw.
    ///
    /// Exhaustive without a `default`, so a fourth ``ReminderProblem`` fails to compile here
    /// rather than shipping a surface that silently says nothing about it.
    public var reason: String {
        switch self {
        case .alarmKitDenied: ReminderStrings.reminderProblemAlarmKitDenied
        case .backgroundRefreshOff: ReminderStrings.reminderProblemBackgroundRefreshOff
        case .notificationsOff: ReminderStrings.reminderProblemNotificationsOff
        }
    }
}
