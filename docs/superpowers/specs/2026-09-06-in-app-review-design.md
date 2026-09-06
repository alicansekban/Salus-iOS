# In-app review prompt + "Rate us" row — design pointer

The design covers both platforms and lives with the Android reference:
`salus-android/docs/superpowers/specs/2026-09-06-in-app-review-design.md`.

iOS-specific points from that spec, for the port ledger:

- Preference keys `home_open_count` / `review_last_requested_ms` in `SettingsKeys`, members on
  `SalusPreferencesDataSource`.
- `ReviewPromptPolicy` in `SalusCommon`, same thresholds (3 opens, 14 days).
- Trigger: `HomeRoute` `.task` on appear plus the foreground arm of the existing `scenePhase`
  site in `SalusApp.swift`; the effect calls `@Environment(\.requestReview)`.
- More row opens `https://apps.apple.com/app/id6807102436?action=write-review` through the
  existing `MoreEffect.openUrl`.
- No new dependency.
