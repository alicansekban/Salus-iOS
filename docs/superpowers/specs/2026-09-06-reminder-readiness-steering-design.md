# Reminder readiness steering — design pointer

The design covers both platforms and lives with the Android reference:
`salus-android/docs/superpowers/specs/2026-09-06-reminder-readiness-steering-design.md`.

iOS-specific points from that spec, for the port ledger:

- `ReminderReadiness` twin goes in `SalusReminder` `api`, async
  (`readiness(alarmKitSupported:) async`), no UIKit imports.
- **Hard problems on iOS: notifications denied, and nothing else.** Soft: AlarmKit denied where
  supported, Background App Refresh off. No Restricted-battery twin (Android-only).
  - **Deviation from the line above as this spec first stated it**, ruled while implementing and
    recorded here (the ruling's own instruction): the spec listed a denied AlarmKit as *hard*.
    On iOS it is **soft**, so the report is `degraded` and the Home card reads "Alarmlar
    gecikebilir" rather than "Alarmlar çalışmayacak". The reason is that AlarmKit is not the
    delivery path, only the presentation of one: with it denied a dose still posts as a
    time-sensitive notification carrying the alarm sound, so the reminder reaches the user and
    merely stops taking over the lock screen. That makes it the twin of Android's soft
    `FULL_SCREEN_DENIED`, not of its hard `EXACT_ALARMS_DENIED` — iOS has no exact-alarm
    permission at all. Only a denied notification authorization silences the pipeline outright,
    which is why it is the only problem that can make a report `broken`
    (`ReminderReadiness.swift`, `ReminderProblem.isHard`).
- Reminder Health screen: unchanged on iOS.
- Medication editor dialog and Home card: same states/events as Android. The Home refresh reaches
  the dashboard from the single `scenePhase` site in `SalusApp.swift` **through
  `AppForegroundSignal`** — the shell's one `.active` arm fans out to the ViewModels that count a
  foreground arrival, so the readiness re-read and the in-app review prompt share one
  subscription and one locked-arrival rule rather than each adding a line to the arm.
- Manual QA: `docs/qa/reminder-readiness-manual-qa.md`, which also carries the proposed
  parity-ledger rows for `salus-android/docs/parity-ledger.md`.
