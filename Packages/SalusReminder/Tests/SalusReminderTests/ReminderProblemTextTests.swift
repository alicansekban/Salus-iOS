// The twin of Android's `ReminderProblemTextTest` (`:core:reminder`), asking the one question a
// `when` over an enum cannot answer at compile time on either platform: that each arm reaches the
// string written for *it*.
//
// Kotlin's `reasonRes()` answers an `Int` resource id, so its test compares ids. Swift's ``reason``
// answers the resolved sentence — but not under `swift test`, which copies the `.xcstrings` into
// the bundle verbatim instead of compiling it, so every lookup answers with its own key
// (`SalusLocalization.string`, and the note at the top of `ReminderStrings.swift`). That quirk is
// what makes the mapping observable here: the assertions below read as "this case reaches this
// catalog key", which is exactly Kotlin's comparison in the spelling this platform allows. The
// sentences themselves are pinned in `ReminderStringsTests`, and the end-to-end resolution is
// `scripts/build-app.sh` plus a simulator run.

import Testing

@testable import SalusReminder

@Suite("ReminderProblem.reason")
struct ReminderProblemTextTests {
    @Test("each problem reaches the catalog key written for it")
    func eachProblemReachesTheKeyWrittenForIt() {
        #expect(ReminderProblem.notificationsOff.reason == "reminder_problem_notifications_off")
        #expect(ReminderProblem.alarmKitDenied.reason == "reminder_problem_full_screen_denied")
        #expect(
            ReminderProblem.backgroundRefreshOff.reason == "reminder_problem_background_refresh_off"
        )
    }

    /// The mapping is total by construction — the `switch` has no `default` — but a *distinct*
    /// answer per case is not something the compiler checks, and two arms naming one key is the
    /// way this table goes wrong.
    @Test("no two problems share a reason")
    func noTwoProblemsShareAReason() {
        let reasons = ReminderProblem.allCases.map(\.reason)

        #expect(Set(reasons).count == ReminderProblem.allCases.count)
        #expect(reasons.allSatisfy { !$0.isEmpty })
    }
}
