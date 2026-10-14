# iOS-M17 Smoking Cessation — Design (iOS delta)

**Status:** approved 2026-10-14 (owner: parallel Android + iOS delivery on frozen contracts).
**Platforms:** iOS. **Builds on:**
- `../salus-android/docs/superpowers/specs/2026-09-20-smoking-cessation-design.md` — the twin spec. It is binding, including "Design review amendments".
- `../salus-android/docs/contracts/smoking-domain-contract.md` — the contract; plans cite it as `contract §N`.
- `../salus-android/docs/contracts/smoking-health-stages.md`.
- `../salus-android/docs/design/m17-stitch-review.md` — rulings R1–R13, screenshots in `m17-stitch/`.

This file says only what differs on iOS. Behaviour, data, copy, colours and numbers are the
twin's.

## Decisions

| # | Decision | Why |
|---|---|---|
| D1 | Domain lives in a new package `Packages/SalusSmoking` (models, calculators, repository, use cases). UI lives in `Packages/Features/FeatureSmoking`. | Home, Trends, AI and the PDF report consume the snapshot. A feature-local domain (the Cycle pattern) would force feature→feature imports. |
| D2 | Storage: GRDB migration `"v5"` in `SalusMigrations`. `SmokingDao` is a plain struct in `SalusDatabase`, like `CycleDao`. `RoomSchemaParityTests` gains Android's `5.json`. | Same tables, column names and enum strings as Android (contract §1). |
| D3 | Notifications go through the existing `SalusReminder` engine as `ReminderType.smoking` (`"SMOKING"`), with category `salus.reminder.SMOKING`. There is no separate `UNCalendarNotificationTrigger` pipeline. | Twin ruling D1. The `.ios` window config is 7 days / 60 occurrences, and smoking adds at most ~9 in 7 days, within the 64-pending budget. |
| D4 | No backup code. `SalusBackup` stays a stub. | Twin ruling D3. |
| D5 | Golden vectors and `5.json` are copied from the Android branch by `scripts/dev/sync-m17-contracts.sh`. The copies sit in the test resources and are never edited by hand. | iOS tests read no files outside the repo today, and that stays true. |
| D6 | Demo data and the "shift back N days" tool reuse Android's Python scripts. `scripts/dev/seed-store-demo.sh` already delegates; a new `scripts/dev/smoking-shift.sh` wraps `smoking_shift.py` on the booted simulator's DB. | One seeder and one shift script for both platforms. |
| D7 | Reduce-motion is `@Environment(\.accessibilityReduceMotion)`. The live counter uses `TimelineView(.periodic)`: 1 s in the first hour, 60 s after. | Platform equivalents of the twin's rules. |
| D8 | Version 1.1.0 (build 6). | The twin ships 1.1.0 the same week. |

## Placement (iOS specifics)

- **More:** a "Sigara" row in `MoreSections` under the Tracking header, after Cycle. It is always visible and not sex-gated.
- **Home:** a new `HomeSmokingCard` in `HomeScreen`'s body, between `HomeSnapshotPager` and `HomeAiCard`.
- **Navigation:**
  - Keys live in `FeatureSmoking/navigation/SmokingNavigation.swift`.
  - `View.smokingDestinations()` is registered in `App/RootNavigationStack.swift` next to `.cycleDestinations()`.
  - The tab bar hides at shell level (`RootView` `tabStack`); feature screens never touch it.
- **Notification tap:** `ReminderOpenRouter` gains the SMOKING route, which opens the timeline with the stage highlighted, or Main.
