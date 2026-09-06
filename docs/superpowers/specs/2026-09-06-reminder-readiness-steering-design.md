# Reminder readiness steering — design pointer

The design covers both platforms and lives with the Android reference:
`salus-android/docs/superpowers/specs/2026-09-06-reminder-readiness-steering-design.md`.

iOS-specific points from that spec, for the port ledger:

- `ReminderReadiness` twin goes in `SalusReminder` `api`, async
  (`readiness(alarmKitSupported:) async`), no UIKit imports.
- Hard problems on iOS: notifications denied, AlarmKit denied where supported. Soft: Background
  App Refresh off. No Restricted-battery twin (Android-only).
- Reminder Health screen: unchanged on iOS.
- Medication editor dialog and Home card: same states/events as Android; the Home refresh hooks
  into the single `scenePhase` site in `SalusApp.swift`.
