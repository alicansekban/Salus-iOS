# iOS-M17 Smoking Cessation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The iOS twin of Android M17 (smoking cessation), built **in parallel** with Android on frozen contracts and shipped to both stores the same week.

**Architecture:**
- `Packages/SalusSmoking` (twin of `:core:smoking`) holds the models, the pure calculators, the repository over a GRDB `SmokingDao` (migration `"v5"`) and the use cases.
- `Packages/Features/FeatureSmoking` (twin of `:feature:smoking`) holds the UI and the `ReminderHandler`.
- Home, Trends, AI and the PDF report depend on `SalusSmoking`. Cross-feature navigation is shell callbacks.
- Task numbers match the Android plan: iOS Task N mirrors Android Task N.

**Tech stack:** Swift 6 strict concurrency, SwiftUI (`@Observable` view models, `*UiState` structs), GRDB, Swift Charts only inside `SalusUI`, Swift Testing, `FixedSalusClock`.

**Spec:**
- `docs/superpowers/specs/2026-10-14-ios-m17-smoking-design.md` (iOS delta, D1–D8).
- `../salus-android/docs/superpowers/specs/2026-09-20-smoking-cessation-design.md` (twin).
- **Contract** `../salus-android/docs/contracts/smoking-domain-contract.md`, cited as `contract §N`, binding.
- `../salus-android/docs/contracts/smoking-health-stages.md`.
- Rulings `../salus-android/docs/design/m17-stitch-review.md` (R1–R13); screenshots `../salus-android/docs/design/m17-stitch/NN-*`.

**Branch / checkout:** `m17-smoking` in `salus-ios/`, (holds the planning commit; rebased onto `main` after the agent harness merges — runbook §1). Parallel tasks run in `git worktree add ../wt-m17-i<N> -b m17-i<N> m17-smoking`.

**Status file:** `docs/superpowers/plans/STATUS-ios-m17-smoking.md`. SDD ledger: `.superpowers/sdd/2026-10-14-ios-m17-smoking/progress.md`.

**Runbook:** `../salus-android/docs/superpowers/plans/2026-10-14-m17-parallel-runbook.md`. The Android session runs at the same time; read §3 "Sync points" first.

## Global constraints

- **Gates:** `/salus-gates` (`scripts/dev/gates.sh`).
  - Per task: `lint lint-rules test` for the touched packages, plus `build` when `App/` or `project.yml` changed.
  - Close-out: `all` (= `scripts/ci.sh`).
  - Baseline: **1521 tests / 24 packages**. M17 adds 2 packages (26); every task reports its Δ.
- **Rules:** `CLAUDE.md` and `.claude/rules/*` bind. In particular:
  - no Feature→Feature edge;
  - records and DAOs only in `SalusDatabase`, mappers beside the domain type;
  - `epochDay`/`LocalDate` for days, and **no `Calendar` outside the sanctioned files** (`no_calendar_outside_clock`);
  - composition root only, no `shared`;
  - shared `SalusUI` components only, no hex or raw points outside palettes/`…Defaults`;
  - a pushed screen = `.navigationTitle` + inline + `ToolbarItem(.primaryAction)`;
  - never touch the tab bar;
  - strings via a typed `SmokingStrings` enum over `Bundle.module`;
  - overlines upper-case in the catalog;
  - `BannedHealthClaims` clean;
  - `xcodegen generate` committed with `project.yml`.
- **New packages:** `SalusSmoking` and `FeatureSmoking` declare `[.iOS(.v17), .macOS(.v14)]` (they reach GRDB) and import no SwiftUI in `SalusSmoking`.
- **Numbers:** money `Int64` minor units; progress `permille: Int` (contract §2).
- **Colour:**
  - Accent `theme.extendedColors.smoking`; values only from `../salus-android/docs/design/design-tokens.md` after sync S1.
  - No red or pink; over limit = neutral overflow + a "+n" chip (R1, R2).
- **Copy:**
  - Turkish copy verbatim from the twin spec, prompts and review.
  - Stage text only from `smoking-health-stages.md`.
  - Key names = Android resource names (snake_case). Final key/value parity is reconciled in the joint close-out (runbook §4).
- **Previews:** every twin spec §3/§5 state as `#Preview` in light and dark, plus one Dynamic Type `.accessibility3` preview per screen.
- **Motion:** reduce-motion via `accessibilityReduceMotion`.
- **Commits:** conventional, English, contiguous, each one builds. Trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Status row via `/salus-handover task`.
- **Android repo:** the iOS session **never commits in `../salus-android`** while the Android session runs. Parity-ledger rows found during execution go into this repo's status file under "Ledger rows to fold" (runbook §4).

## Rulings the planner made (do not re-open)

| # | Ruling | Why |
|---|---|---|
| P1 | Calculator/scheduler tests are written from the contract's numbered rules, not ported from Kotlin. Golden-vector parity (Task 22) is the drift detector. | The Kotlin tests are being written at the same time; the contract is the shared table. |
| P2 | Instant↔day conversion goes through `SalusCommon`. If `SalusClock.swift` lacks `epochDay(of: Int64, in: TimeZone)` / `startOfDayMs(epochDay:in:)`, Task 4 adds them **there**, with tests. | `no_calendar_outside_clock` allows no third file. |
| P3 | Copied contract files (vectors, `5.json`) arrive only via `scripts/dev/sync-m17-contracts.sh`, reading `git -C ../salus-android show feature/m17-smoking-cessation:<path>`. | It reads the committed branch, not a working tree mid-edit. |
| P4 | A sync point that is not reached never blocks a task's other steps. The dependent step moves to a follow-up task (`3b`, `22`). | Keeps both sessions moving. |

## Review focus

Same as the twin plan:
1. **Craving timer:** computed from the start instant across backgrounding and termination.
2. **Writes:** a double tap writes once; undo by id across midnight.
3. **Stale notifications:** none fire after reset or a mode switch; `notificationContent` returns nil.
4. **Currency change:** keeps `savedMinor`.
5. **Long horizons:** 20-year horizons with no overflow.

Plus one iOS-only item:

6. **Pending budget:** the 64-pending budget is never exceeded with medications + appointments + cycle + smoking at their maxima. → T17.

---

### Task 1: Contract sync script

**Files:** create `scripts/dev/sync-m17-contracts.sh`. It copies the files below; a missing source → prints "not yet on branch (sync point open)" and exits 0.
- `docs/contracts/smoking-golden-vectors.json` → `Packages/SalusSmoking/Tests/SalusSmokingTests/Resources/smoking-golden-vectors.json`.
- `core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/5.json` → `Packages/SalusDatabase/Tests/SalusDatabaseTests/Resources/RoomSchemas/5.json`.

- [ ] Write the script plus a `--check` mode that diffs the copies against the branch (exit 1 on drift).
- [ ] Run it; commit `chore(dev): M17 contract sync script`.

### Task 2: Smoking accent token — **waits for S1** (Android T2 on branch)

**Files:**
- Modify: `Packages/SalusDesignSystem/Sources/SalusDesignSystem/{SalusExtendedColors,SalusPremiumExtendedColors,SalusPremiumAccents}.swift` (+ the Ocean/Sunset/Forest palette files).
- Tests: `SalusDesignTokensTests.swift` (5 → **6** `FeatureAccent` sets; token count +the new lines), `SalusPremiumExtendedColorsTests.swift`, `SalusColorSchemeContrastTests.swift`.

- [ ] Read the hexes from Android's `design-tokens.md` at the branch (`git -C ../salus-android show feature/m17-smoking-cessation:docs/design/design-tokens.md`).
- [ ] Update the pins first (red: `expected 6 FeatureAccent sets, got 5`), then add the values in `private enum` palettes.
- [ ] Add the hue test "smoking accent ≥ 25° from error", the twin of Android's.
- [ ] Gates; commit `feat(designsystem): amber smoking feature accent`.

### Task 3: GRDB migration `"v5"` + `SmokingDao` — contract §1 · parity step needs **S2**

**Files:**
- Modify: `Packages/SalusDatabase/Sources/SalusDatabase/Migrations.swift` (`v5Statements`, `registerMigration("v5")` after v4 at L203).
- Create: `Records/Smoking{Plan,PricePeriod,QuitAttempt,Event,SavingsGoal}Record.swift`, `SmokingDao.swift`.
- Tests: `MigrationTests.swift` ("4 to 5"; `appliedMigrations == [v1…v5]`), new `SmokingDaoTests.swift`, `RoomSchemaParityTests.swift` (+ `5.json` via the T1 script).

**Interfaces (produces):** `public struct SmokingDao` with the twin of Android's `SmokingDao`:
- `observePlan`, `observePricePeriods`, `observeAttempts`, `observeEvents`, `observeActiveGoal` as `ValueObservation`-backed `AsyncStream`s, exactly as `CycleDao.observePeriods`;
- `upsertPlan`, `insertPricePeriod`, `updatePricePeriod`, `insertAttempt`, `updateAttempt`, `insertEvent`, `updateEvent`, `deleteEvent(id:)`, `deleteZeroMarker(epochDay:)`, `upsertGoal`, `resetAll()`, `write(_:)` transaction helper.

- [ ] Tests first:
  - migration 4→5 (red: `appliedMigrations` lacks `"v5"`);
  - DAO round-trip per table, FK `SET NULL`, `deleteZeroMarker` only removes `units = 0`, `resetAll` empties all five.
- [ ] Implement the DDL from contract §1, snake_case `CodingKeys`.
- [ ] If S2 is reached: `scripts/dev/sync-m17-contracts.sh`, extend `RoomSchemaParityTests` to v5, same commit. If not: open **Task 3b** in the status file.
- [ ] Gates; commit `feat(database): schema v5 smoking tables`.

### Task 4: `SalusSmoking` package, models, `SmokingStatsCalculator` — contract §2, §3

**Files:**
- Create: `Packages/SalusSmoking/Package.swift` (copy `FeatureCycle`'s shape; deps `SalusModel`, `SalusCommon`, `SalusDatabase`, `SalusPremium`; test dep `SalusTesting`; `resources: [.copy("Resources")]` on the test target).
- Create: `Sources/SalusSmoking/model/{SmokingModels,SmokingSnapshot}.swift`, `stats/SmokingStatsCalculator.swift`, `milestone/HealthStage.swift`.
- Modify: `project.yml` (`packages:` + Salus target dependency) + `xcodegen generate`.
- If needed: `Packages/SalusCommon/Sources/SalusCommon/SalusClock.swift` (P2) + its tests.
- Test: `Tests/SalusSmokingTests/SmokingStatsCalculatorTests.swift`.

**Interfaces (produces):**
```swift
public enum SmokingMode: String, Sendable, CaseIterable { case quit = "QUIT", reduce = "REDUCE" }   // likewise ProductType, SmokingEventType, CravingTrigger, AttemptEndReason
public struct SmokingPlan / PricePeriod / QuitAttempt / SmokingEvent / SavingsGoal / SmokingInput: Sendable, Equatable  // fields = contract §1 camelCased, Int64 for ms/minor/epochDay
public enum SmokingSnapshot: Sendable, Equatable { case notSetUp; case quit(QuitSnapshot); case reduce(ReduceSnapshot) }
public struct DayUnits, AttemptSummary, GoalProgress, StageProgress; public enum StageState
public enum SmokingStatsCalculator { public static func snapshot(_ input: SmokingInput, nowMs: Int64, zone: TimeZone) -> SmokingSnapshot }
```

- [ ] Tests first, **one per contract §3 rule** (P1), mirroring the twin plan's list:
  - not set up;
  - QUIT day 0/42;
  - slip at the slip day's price;
  - price change;
  - VAPE;
  - clock back;
  - Europe/Berlin DST;
  - back-dated not a slip;
  - clamp;
  - REDUCE no-data / zero marker / under-at-over / first week;
  - stages + `countingAgain`;
  - goal mid-attempt and across a restart;
  - 20 y × 60/day × 10 000.
  - Red: `cannot find 'SmokingStatsCalculator' in scope`.
- [ ] Implement until green; gates (`test build`, since `project.yml` changed).
- [ ] Commit `feat(smoking): SalusSmoking package and snapshot calculator`.

### Task 5: `MilestoneCatalog` + `MilestoneScheduler` — contract §4 · after T4

**Files:** create `Sources/SalusSmoking/milestone/{MilestoneCatalog,MoneySteps,MilestoneScheduler}.swift`; test `MilestoneSchedulerTests.swift`.

**Interfaces (produces):**
```swift
public enum MilestoneKind: Sendable, Hashable { case stage(String), days(Int64), units(Int64), money(Int64), evening(Int64) }
public struct PlannedNotification: Sendable, Equatable { public let key: String; public let triggerAtMs: Int64; public let kinds: [MilestoneKind] }
public enum MilestoneScheduler { public static func plan(_ input: SmokingInput, nowMs: Int64, zone: TimeZone, limit: Int = 20) -> [PlannedNotification] }
```
- Stage ids and thresholds come from `smoking-health-stages.md`.

- [ ] Tests first, the twin list:
  - 48 h cap;
  - quiet hours;
  - merge;
  - slip shift;
  - limit;
  - off;
  - evening;
  - yearly past 15 y;
  - TRY vs EUR steps.
- [ ] Implement; gates; commit `feat(smoking): milestone catalog and scheduler`.

### Task 6: Repository + use cases — contract §6 · after T3, T4

**Files:** create `Sources/SalusSmoking/repository/SmokingRepository.swift`, `data/{SmokingMappers,SmokingRepositoryImpl}.swift`, `usecase/*.swift`, `SmokingCoreModule.swift` (factory used by the composition root). Modify `App/AppCompositionRoot.swift` (+ `+Modules.swift`): build it once in `makeInfrastructure`.

**Interfaces (produces):**
```swift
public protocol SmokingRepository: Sendable { func observeInput() -> AsyncStream<SmokingInput>; func observeSnapshot() -> AsyncStream<SmokingSnapshot>; func snapshotNow() async -> SmokingSnapshot }
public protocol SmokingChangeListener: Sendable { func smokingDataChanged() }
public enum SmokingError: Error, Equatable { case futureQuitDate, notSetUp, invalidInput }
// structs with `callAsFunction(...) async throws`: SetUpSmoking, LogSmoked(→ eventId), LogNoneToday, LogCravingResisted(→ eventId), ResolveSlip,
// SwitchMode, UpdatePrice, UpdateCurrency, UpdatePlanFields, EditQuitDate, EditEvent, DeleteEvent, SaveSavingsGoal, MarkGoalAchieved, ResetSmoking
```

- [ ] Tests first, the twin list:
  - slip keeps the attempt;
  - restart at the same instant;
  - switches keep data;
  - quit date later detaches;
  - +1 replaces the zero marker;
  - same-day price replaces;
  - reset empties and notifies;
  - repair.
  - Use `SalusDatabase.inMemory`.
- [ ] Implement; gates (`test build`); commit `feat(smoking): repository and use cases`.

### Task 7: `SmokingInsightsCalculator` — contract §5 · after T4

**Files:** `Sources/SalusSmoking/insights/{SmokingInsights,SmokingInsightsCalculator}.swift`; tests.

- [ ] Tests first:
  - not enough data;
  - 7-day threshold;
  - 22:30 → `h22_08`;
  - permille;
  - weekly buckets;
  - `aiStats` nil when not set up.
- [ ] Implement; gates; commit `feat(smoking): insights calculator`.

### Task 8: `SalusUI` additions — R2

**Files:**
- Create: `Packages/SalusUI/Sources/SalusUI/chart/SalusHeatmap.swift` (plain grid, no Charts needed; 5 accent opacity steps).
- Modify: `chart/ChartUiModel.swift` + `SalusLineChart.swift` (`markers: [ChartMarker]`, a dashed `RuleMark` in accent), `component/SalusProgressRing.swift` and `SalusProgressBar.swift` (`overflowPermille`, drawn in `outlineVariant`).
- Tests: bucket mapping; marker range filter.

- [ ] Tests red → implement → previews → gates; commit `feat(ui): heatmap, chart markers, progress overflow`.

### Task 9: `FeatureSmoking` scaffold, navigation, More row, Setup, `QuitDateSheet` — twin spec §3–§5.1 · after T6 (T2 for final colours)

**Files:**
- Create:
  - `Packages/Features/FeatureSmoking/Package.swift` (core deps only);
  - `Sources/FeatureSmoking/{SmokingModule,SmokingStrings}.swift`;
  - `Resources/Localizable.xcstrings`;
  - `navigation/SmokingNavigation.swift`;
  - `ui/setup/SmokingSetup{Screen,UiState,ViewModel,Route}.swift`;
  - `ui/sheet/QuitDateSheet.swift`.
- Modify:
  - `project.yml` + generate;
  - `App/AppCompositionRoot+Modules.swift` (build in `makeScheduledModules`, like Cycle at L340);
  - `App/RootNavigationStack.swift` (`.smokingDestinations()` next to L127);
  - `FeatureSettings/ui/more/{MoreScreen,MoreScreenSections,MoreUiState}.swift` + its view model (`smokingMode`, `onOpenSmoking`).
- Tests: `SmokingSetupViewModelTests.swift`, `SmokingStringsTests.swift` (parity, overlines, banned claims), a More view model test.

**Interfaces (produces):**
- `SmokingSetupKey`, `SmokingKey`, `SmokingCravingKey(source:)`, `SmokingTimelineKey(highlightStageId:)`, `SmokingHistoryKey`, `SmokingSettingsKey` — `Hashable, Sendable`.
- `View.smokingDestinations(onOpenTrends:onOpenReminderHealth:)`.
- `QuitDateSheet(initialMs:onConfirm:onDismiss:)`.

**Behaviour:** identical to Android T9: the More row and chip; the four setup steps; VAPE weekly/7 half-up; REDUCE suggestion; future date rejected; no taper promise.

- [ ] VM tests first; implement; previews; gates (`all` minus nothing — `App/` changed); commit `feat(smoking): FeatureSmoking module, navigation, More row and setup`.

### Task 10: Main screen + QUIT + slip and trigger sheets — after T9 · screens `03`, `06`

**Files:** `ui/main/SmokingMain{Screen,UiState,ViewModel,Route}.swift`, `ui/main/QuitContent.swift`, `ui/sheet/{TriggerSheet,SlipSheet}.swift`; tests.

**Behaviour:** identical to Android T10:
- hero, slip line + chip, 2×2 metrics with the "+n bugün" chip only, next-stage card;
- pinned "Canım çekti" + text "Sigara içtim";
- slip radio + "Devam et" / "Şimdilik kapat";
- trigger chips + intensity;
- `writing` disables buttons.
- Live counter: `TimelineView(.periodic(from:by:))` at 1 s in the first hour, 60 s after (D7).

- [ ] VM tests first: continue/restart attempt ids; dismiss writes nothing; trigger on the right event; double confirm once.
- [ ] Implement; previews; gates; commit `feat(smoking): main screen quit mode, slip and trigger sheets`.

### Task 11: Main REDUCE — after T10, T8 · screen `04`

**Files:** `ui/main/ReduceContent.swift`; modify the main state and VM.

**Behaviour:** identical to Android T11:
- ring + overflow chip, "+1" always, "Bugün hiç içmedim";
- 7-day `SalusBarChart` with baseline;
- weekly card, greyed stages card;
- "Bırakmaya hazırım" → `QuitDateSheet`;
- undo snackbar via `SalusSnackbarHost`, by event id.

- [ ] VM tests first: undo across midnight by id; double +1 once; "None today" hidden after +1; ready-to-quit opens an attempt.
- [ ] Implement; previews; gates; commit `feat(smoking): main screen reduce mode`.

### Task 12: Craving flow — after T10 · screen `06`

**Files:** `ui/craving/Craving{Screen,UiState,ViewModel,Route}.swift`, `ui/craving/BreathingRing.swift`; tests.

**Behaviour:** identical to Android T12:
- `startedAtMs` held by the VM; it survives backgrounding (`scenePhase`). The VM is recreated after termination, which writes nothing.
- 4/4/6 s phases, "Geçti" / "Sigara içtim", completed state, no R8 extras.
- `.fullScreenCover` from Main and Home.

- [ ] VM tests first: 6-minute gap → completed; early exit writes nothing; double "Geçti" once; REDUCE "İçtim" +1; 9 s → "Ver".
- [ ] Implement; previews (running, completed, reduce-motion); gates; commit `feat(smoking): craving flow`.

### Task 13: Health timeline + stage sheet — after T9, T5 · screen `05`

**Files:** `ui/timeline/SmokingTimeline{Screen,UiState,ViewModel,Route}.swift`, `ui/timeline/StageDetailSheet.swift`; stage strings in the catalog keyed by stage id.

**Behaviour:** identical to Android T13 (header, rail, notes, highlight, REDUCE preview, attribution sheet, disclaimer; no bullets, no share).

- [ ] Tests first: every `MilestoneCatalog.healthStages` id has tr + en keys; state mapping; highlight.
- [ ] Implement; gates; commit `feat(smoking): health timeline`.

### Task 14: History + settings + editor sheets — after T10, T11 · screen `07`

**Files:** `ui/history/SmokingHistory{Screen,UiState,ViewModel,Route}.swift`, `ui/history/EventEditSheet.swift`, `ui/settings/SmokingSettings{Screen,UiState,ViewModel,Route}.swift`, `ui/sheet/{PriceSheet,LimitSheet,ReasonSheet,CurrencySheet}.swift`.

**Behaviour:** identical to Android T14:
- currency confirm copy;
- evening row REDUCE-only;
- notifications on without permission → reminder health via shell callback;
- reset → `.salusConfirmDialog` → pop.

- [ ] VM tests first: edit moves a slip out; delete; currency keeps `savedMinor`; reset; evening hidden in QUIT.
- [ ] Implement; gates; commit `feat(smoking): history and settings`.

### Task 15: Savings goal + insights teaser — after T10

**Files:**
- Modify: `Packages/SalusPremium/Sources/SalusPremium/PaywallSource.swift` (`smokingInsights`, `smokingGoal`) + the FeaturePaywall mapping if exhaustive.
- Create: `ui/main/{GoalCard,InsightsTeaser}.swift`, `ui/sheet/GoalSheet.swift`.

**Behaviour:** identical to Android T15 (D4 progress, re-lock on lapse, mark achieved once, teaser → paywall or Trends).

- [ ] VM tests first; implement; gates; commit `feat(smoking): savings goal and insights teaser`.

### Task 16: Home card — after T6, T8 · screen `01`

**Files:**
- Modify: `Packages/Features/FeatureHome/Package.swift` (+`SalusSmoking`), `ui/HomeScreen.swift` (between L209 and L211), the Home view model / state.
- Create: `ui/HomeSmokingCard.swift`.
- Modify: `SalusSettings` preferences (`smoking_discovery_dismissed` — a new persisted key ⇒ a pinning test, same commit); `App/` callbacks.

**Behaviour:** identical to Android T16 (discovery dismiss-forever, QUIT and REDUCE states, undo by id, no "Dün durumu").

- [ ] VM tests first; implement; gates (`all`); commit `feat(home): smoking card`.

### Task 17: Milestone notifications — contract §4, D3 · after T5, T6, T9

**Files:**
- Modify: `Packages/SalusModel/Sources/SalusModel/Reminder.swift` (`case smoking = "SMOKING"`).
- Create: `FeatureSmoking/reminder/{SmokingReminderHandler,SmokingNotificationText}.swift`.
- Modify: `App/AppCompositionRoot.swift` L407-410 (append `scheduled.smoking.reminderHandler`), `App/AppCompositionRoot+Reminder.swift` (`ReminderOpenRouter` SMOKING route), `App/RootView.swift` consumer.
- Wiring: a `SmokingChangeListener` that calls `ReminderScheduler.requestSync()`.

**Behaviour:** identical to Android T17. The category id comes from `ReminderNotificationCategories.identifier(for:)`, with no actions.

- [ ] Tests first:
  - occurrences match the scheduler in the window;
  - reset/switch → nil;
  - evening skipped;
  - off → none;
  - **budget:** with the `.ios` window (7 days / 60) and maxed medications/appointments/cycle fixtures, total pending ≤ 64 and smoking is not starved of its nearest milestone.
- [ ] Implement; gates (`all`); commit `feat(smoking): milestone notifications`.

### Task 18: Trends section + quit markers — after T7, T8 · screen `08`

**Files:** `Packages/Features/FeatureTrends/Package.swift`, `ui/{TrendsScreen,TrendsViewModel,TrendsUiState,MetricOverlayCard}.swift`, new `ui/SmokingTrendsSection.swift` + `analysis/SmokingTrendsModel.swift`.

**Behaviour:** identical to Android T18 (hidden when not set up, under the existing lock, 4 cards, 7-day empty state, "Bıraktın" markers).

- [ ] Tests first; implement; gates; commit `feat(trends): smoking section and quit markers`.

### Task 19: AI prompt + PDF — after T7, T6

**Files:**
- `Packages/SalusAI/Sources/SalusAI/{SummaryModels,HealthStatsAggregator,PromptBuilder}.swift` (`HealthPeriodStats.smoking: SmokingAiStats?`).
- `FeatureAIHealth/report/{ReportBlocks,ReportCopy,DoctorReportRepository}.swift` (`addTobaccoUse`, tr + en in `ReportCopy`).

- [ ] Tests first:
  - the prompt holds the stats and not the planted `"KIZIM_ICIN_SENTINEL"`;
  - unchanged when not set up;
  - the PDF section has no currency symbol.
- [ ] Implement; gates; commit `feat(ai,report): smoking statistics in AI summary and doctor report`.

### Task 20: Dev tooling — **waits for S4** (Android T20 on branch)

**Files:**
- Create: `scripts/dev/smoking-shift.sh <days>`. It locates the booted simulator's `salus.db` the way `seed-store-demo.sh` does, keeps a `.bak`, and runs `../salus-android/scripts/dev/smoking_shift.py`.
- Modify: `docs/` testing note (seed + shift).

- [ ] Dry-run on a temp DB copy; commit `chore(dev): smoking shift wrapper`.

### Task 21: Sweep — QA sheet, privacy, version

**Files:**
- Create: `docs/qa/m17-manual-qa.md` (planning.md shape: one row per screen and state, light/dark, palettes, Dynamic Type xxxLarge, VoiceOver order, notification timing, quiet hours, reduce motion, known risks, known differences from Android).
- Modify: the iOS privacy copy ("tobacco use — stored on device only") — App Privacy needs no change (no collection); `project.yml` `MARKETING_VERSION: "1.1.0"`, `CURRENT_PROJECT_VERSION: "6"` + generate.

- [ ] Gates `all`; commit `chore(smoking): QA sheet, privacy, version 1.1.0 (6)`.

### Task 22: Golden-vector parity — **waits for S3** (Android T4 + T5 on branch)

**Files:** `scripts/dev/sync-m17-contracts.sh` run; test `Tests/SalusSmokingTests/GoldenVectorTests.swift` (decodes with `JSONSerialization`, asserts contract §7 fields for every snapshot and schedule case).

- [ ] Sync, write the test, run.
- [ ] For every mismatch, decide against the **contract text**:
  - if iOS is wrong, fix iOS;
  - if Android is wrong, record it under "Ledger rows to fold" and tell the owner — never edit the vectors.
- [ ] Gates; commit `test(smoking): golden-vector parity with Android`.

## Close-out (controller)

- Whole-branch review (`salus-reviewer`), one fix wave, `/salus-gates all`.
- Joint copy parity check (runbook §4).
- QA hand-off.
- After the owner's QA: `git rebase main` + `git merge --ff-only`; `STATUS.md`.
- Push only on the owner's word, the same week as Android (runbook §5).

## Task graph

Waves:
1. T1 ∥ T4 ∥ T8
2. T3 ∥ T5 ∥ T7 (T2 as soon as S1)
3. T6
4. T9 ∥ T16 ∥ T19
5. T10 ∥ T13 ∥ T17 ∥ T18
6. T11 ∥ T12 ∥ T15
7. T14 ∥ T20 (S4)
8. T22 (S3, may run any time after S3)
9. T21
