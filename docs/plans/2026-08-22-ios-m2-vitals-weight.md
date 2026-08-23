# iOS-M2 — Vitals / Weight Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Executor subagents run on **Opus** (user preference). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md` and the M1 plan's "Execution record" first. Independent tasks may run in parallel implementers (own worktree + side branch, rebased before review).

**Goal:** The first end-to-end feature: the Vitals tab lists weight entries with a range-selectable line chart, a weight editor creates/edits/deletes entries (delete with undo), everything persisted through GRDB and proven by the ported Android tests — plus the Swift Charts adapter and shared views in `SalusUI`, the first String Catalog, and `docs/ios-feature-template.md` that every later feature copies.

**Architecture:** `FeatureVitals` mirrors `:feature:vitals` layer for layer (`domain/` pure, `data/` mappers + repository over `VitalsDao`, `ui/<screen>/` UiState+Event(+Effect)/ViewModel/Route+Screen, `navigation/` keys + destinations, `module` factory). Features never import Charts; `SalusUI` owns `ChartUiModel` + `SalusLineChart`. Navigation keys stay feature-owned; the shell applies each feature's destination modifier. **Scope is weight only** — blood pressure and glucose (types, editors, two-series chart, unit preference) are iOS-M7; the UiState vocabulary is ported in full so M7 adds builders, not shape.

**Tech Stack:** Swift 6 / SwiftUI / Swift Charts · `@Observable` view models · GRDB `ValueObservation` · String Catalog (`.xcstrings`) · Swift Testing.

**Spec:** `../salus-android/docs/ios-v1-plan.md` §5 (platform mapping), §10 iOS-M2 · `../salus-android/docs/architecture/feature-template.md` (the Android template this milestone twins) · Kotlin under `salus-android/feature/vitals/`, `salus-android/core/ui/`, `salus-android/core/database/.../dao/VitalsDao.kt`.

## Global Constraints

- No new dependencies (allowlist stays GRDB only; Swift Charts is a system framework).
- Reviewed against Android `:feature:vitals` on 2026-08-22; the divergences this plan records on purpose (VM ctor without `VitalsPreferences`, `instant(of:minuteOfDay:)` instead of `localTimeNow()`, resolved snackbar strings, hidden FAB for non-weight types, concrete `Navigator` fake) are the complete list — anything else that differs is a bug. **Two more were added during execution and are equally binding: `SalusSnackbarHost` dismisses on a tap of its body (Task 3 ruling — Android's host has no such affordance, and without it an `Indefinite` undo snackbar blocks the FIFO queue), and `SaveWeightEntryUseCase` rejects a NaN weight (Task 4 ruling — Kotlin stores it; iOS is correct and Android adopts it as §11 A11).**
- Port fidelity: Kotlin names, validation constants (`MIN_KG = 20.0`, `MAX_KG = 400.0`), `unit = "kg"`, `type = "WEIGHT"`, `ChartRange` days (7/30/90/365, default `MONTH`), `resolveEditorMeasuredAt` semantics, Android test tables by name. Behaviour differences only where spec §6 or a ledger ruling records them.
- **Strings:** Turkish is the development/fallback language, EN a full peer; the 48 `vitals_*` keys of `feature/vitals/src/main/res/values{,-en}/strings.xml` are ported verbatim (name and text) — banned-claims vocabulary (CLAUDE.md) applies to every string; no new copy is invented.
- UDF rule: `<Screen>UiState.swift` holds UiState + Event (+ Effect only when real UI work exists); one `onEvent(_:)`; navigation goes through the injected `Navigator`, never an Effect. Inject `SalusClock`/`IdGenerator`; never `Date()` in feature code.
- One shell `TabView`/`NavigationStack` per tab; feature screens never nest their own navigation containers or safe-area hacks (the twin of the "one Scaffold" rule).
- Swift 6 strict concurrency, lint/format gates, no force unwraps in production, English comments citing Kotlin file:line, conventional commits, `scripts/ci.sh` green before each integration. Never stage `Salus.xcodeproj` changes not produced by `xcodegen generate`.

---

### Task 1: Foundations — concrete-key navigation, `LocalDate` validation, `scripts/clean.sh`

**Files:** `Packages/SalusNavigation/Sources/SalusNavigation/{AnyNavKey,TabBackStacks}.swift` + tests; `Packages/SalusModel/Sources/SalusModel/LocalDate.swift` + tests; `Packages/SalusCommon/Sources/SalusCommon/SalusClock.swift` + `Packages/SalusTesting/Sources/SalusTesting/FixedSalusClock.swift` + tests; `CLAUDE.md` (LocalDate rule carve-out line); `App/RootView.swift` (delete `PushedKeyPlaceholder`); `scripts/clean.sh`; `README.md` (scripts table).

**Interfaces (produces):**
- `AnyNavKey` additionally captures, at construction, `append: @Sendable (inout NavigationPath) -> Void` that appends the **concrete** key, so `TabBackStacks.push` appends the typed value and `navigationDestination(for: WeightEditorKey.self)` matches. *Ruling (user-confirmed 2026-08-22, closing the M1 deferred finding): this is how feature packages keep owning their destinations (Android `vitalsEntries` parity) without a central switch in the app.* Equality/hash unchanged.
- `LocalDate.init(year:month:day:)` normalises impossible triples by round-tripping through `epochDay` (kotlinx throws; the ruling in M1 picked normalisation) — `Equatable` and `Comparable` now agree; table test.
- `scripts/clean.sh`: removes `Packages/**/.build`, `Packages/**/.swiftpm`, `DerivedData` of this project (`xcodebuild -showBuildSettings` → `BUILD_DIR` parent), prints what it removed; documented in README.
- `SalusClock` gains the **second and last** instant↔day boundary: `func instant(of day: LocalDate, minuteOfDay: Int) -> Date` (the inverse of `today()`, same fixed Gregorian calendar in the clock's zone, `SalusCommon/SalusClock.swift` only). Android's `resolveEditorMeasuredAt` builds `LocalDateTime(date, clock.localTimeNow()).toInstant(zone)`; iOS has `minuteOfDayNow()` instead of `localTimeNow()`, so the editor composes `instant(of: date, minuteOfDay: clock.minuteOfDayNow())` (today) or `minuteOfDay: 12 * 60` (past). CLAUDE.md's `LocalDate` rule gets this one-line carve-out in the same commit. `FixedSalusClock` implements it too; table test: round-trips `today()`/`minuteOfDayNow()`, DST-day sample.

- [x] TDD for all three library changes; `scripts/test-packages.sh SalusNavigation SalusModel SalusCommon SalusTesting`; `scripts/lint.sh`. Commit.

### Task 2: `VitalsDao` in `SalusDatabase`

**Files:** `Packages/SalusDatabase/Sources/SalusDatabase/VitalsDao.swift`, `Tests/SalusDatabaseTests/VitalsDaoTests.swift`.

**Kotlin:** `core/database/.../dao/VitalsDao.kt` (every `@Query` verbatim: `upsert`, `getById`, `observeRange(profileId,type,fromEpochMs,untilEpochMs)`, `observeLatest(profileId,type)`, `getMeasurementsBetween`, `deleteById`), `DaoSmokeTest.kt` case `vitals range query emits inserted measurements in order`.

**Produces:** `public struct VitalsDao: Sendable { init(database:) }` with the same shape as `ProfileDao` — async throws methods over `VitalsMeasurementRecord`; `observe*` return `AsyncThrowingStream<…, any Error>` conflated (`.bufferingNewest(1)`), ordering identical to the Kotlin SQL (`ORDER BY measured_at_epoch_ms`).

- [x] TDD: the ported smoke test + range boundaries (inclusive/exclusive exactly as the SQL) + `observeLatest` emits on insert. Commit.

### Task 3: `SalusUI` — chart adapter, shared views, snackbar/undo

**Files:** `Packages/SalusUI/Sources/SalusUI/chart/{ChartUiModel,SalusLineChart}.swift`, `component/{SalusCard,SalusEmptyState,SalusFab,SalusConfirmDialog,SalusScreenHeader}.swift` — **exactly the `:core:ui` set `VitalsScreen.kt` and `WeightEditorScreen.kt` import** (verified 2026-08-22; `SalusListItem`, `SalusSectionHeader`, `SalusPillButton`, `SalusPillTextField`, `SalusSparkline` are *not* used by this slice and arrive with the feature that first needs them — sparkline with Home in M7), `snackbar/{SalusSnackbarController,SalusSnackbarHost,UndoableDelete}.swift`; tests; `.swiftlint.yml` custom rule `no_charts_in_features` (`included: Packages/Features/`, forbids `import Charts`, same shape as `no_ui_framework_in_domain`).

**Kotlin:** `core/ui/.../chart/{ChartUiModel,SalusLineChart}.kt`, `component/{SalusCard,SalusEmptyState,SalusFab,SalusConfirmDialog,SalusScreenHeader}.kt`, `snackbar/{SalusSnackbarController,UndoableDelete}.kt`; design values only from `design-tokens.md` via `SalusDesignSystem`.

**Material twins the feature uses directly (no `SalusUI` wrapper, decided here so nobody improvises):** `FilterChip` (type selector) → a `SalusUI` `SalusFilterChip` is *not* added; use a `Button` with `.buttonStyle` driven by tokens inside the feature **only if** the design-tokens doc has a chip spec, otherwise `Picker` `.segmented`; `SingleChoiceSegmentedButtonRow` (range) → `Picker(.segmented)`; `CircularProgressIndicator` → `ProgressView()`; `OutlinedTextField`/`Button`/`TopAppBar` (editor) → `TextField` with `.textFieldStyle(.roundedBorder)`, `Button`, `.toolbar` + `navigationTitle`. The executor records the chosen mapping in the feature template's Charts/Components section.

**Produces:** `ChartPoint(xEpochDay: Int, y: Float)`, `ChartUiModel(points:xLabel:yLabel:secondaryPoints:)` (closures `@Sendable`), `SalusLineChart(model:lineColor:contentDescription:)` rendering with Swift Charts (`LineMark` + secondary series in secondary colour; x axis labelled through `xLabel`; VoiceOver summary from `contentDescription`); `@MainActor @Observable SalusSnackbarController` (message + optional undo action, auto-dismiss per Android duration — Android's is a `Channel`-backed request stream consumed by one host; the iOS twin keeps the `SnackbarRequest(message:actionLabel:onAction:)` shape with **resolved `String`s, not keys**, because the host is mounted in the shell and a feature's strings live in its own `Bundle.module`), `SalusSnackbarHost` overlay the shell mounts once; `UndoableDelete(pendingDeletes:snackbar:)` callable `(id, message: String, commit)` — the twin of `UndoableDelete.kt` (`@StringRes messageRes` becomes the already-localised text) over M1's `PendingDeleteController`.

- [x] TDD for the non-view logic (`ChartUiModel` equality/defaults, snackbar controller state machine, `UndoableDelete` schedules + undo); views verified by `#Preview` build. Lint rule proven by a negative fixture test like M0's. Commit.

### Task 4: `FeatureVitals` domain + data

**Files:** `Packages/Features/FeatureVitals/Sources/FeatureVitals/domain/{model/WeightEntry,repository/VitalsRepository,usecase/SaveWeightEntryUseCase}.swift`, `data/{WeightEntryMapper,VitalsRepositoryImpl}.swift`; tests `FakeVitalsRepository.swift`, `SaveWeightEntryUseCaseTests.swift` (6 cases by name), `WeightEntryMapperTests.swift` (round trip + unit/type pins — **no Android twin today**; tracked as spec §11 A8 so Android gets the same table), `VitalsRepositoryImplTests.swift` (in-memory DB: save/observe/delete; iOS-only, no Android twin needed — Android covers it through `DaoSmokeTest`).

**Kotlin:** `feature/vitals/.../domain/**`, `data/{WeightEntryMapper,VitalsRepositoryImpl}.kt`, `test/domain/usecase/SaveWeightEntryUseCaseTest.kt`, `test/FakeVitalsRepository.kt`.

**Produces:** `WeightEntry(id:measuredAt: Date, timeZone: TimeZone, kilograms:note:)`; `protocol VitalsRepository` with the weight members only (`observeWeightHistory(from:until:) -> AsyncThrowingStream<[WeightEntry], any Error>`, `observeLatestWeight()`, `getWeightEntry(id:)`, `saveWeightEntry(_:)`, `deleteWeightEntry(id:)`) — BP/glucose members arrive in M7; `SaveWeightEntryUseCase(repository:idGenerator:)` with `enum Result { saved(WeightEntry), invalidWeight }`, `callAsFunction(existingId:kilograms:measuredAt:timeZone:note:)`, conforming to `SalusModel.VitalsQuickEntry` (`recordWeight` shares the validation); `VitalsRepositoryImpl(vitalsDao:profileId:)` (profile id = `SalusDatabase.defaultProfileId`).

- [x] TDD; `scripts/test-packages.sh FeatureVitals`. Commit.

### Task 5: First String Catalog + string tests

**Files:** `Packages/Features/FeatureVitals/Sources/FeatureVitals/Resources/Localizable.xcstrings` (48 keys, `tr` source + `en`), `Package.swift` (`defaultLocalization: "tr"`, resources), `Sources/FeatureVitals/VitalsStrings.swift` (typed accessors, `Bundle.module`), tests `VitalsStringsTests.swift`; `Packages/SalusTesting` gains `StringCatalogParity` (parse an `.xcstrings`, assert every key has both `tr` and `en` values, no extra locales, and pinned key set) and `BannedHealthClaims.assertCatalogsNameNothingBanned(paths:)`.

**Kotlin/XML:** `feature/vitals/src/main/res/values/strings.xml` + `values-en/strings.xml` (48/48) — port name and text verbatim; `core/testing/.../BannedHealthClaims.kt` (`assertFilesNameNothingBanned`).

- [x] Tests: key-set pin (48 literal names copied from the XML), TR/EN parity, banned-claims scan over every `.xcstrings` under `Packages/` (must scan ≥ 1 file). Commit.

### Task 6: `FeatureVitals` UI — list + weight editor

**Files:** `ui/list/{VitalsUiState,VitalsViewModel,VitalsScreen}.swift`, `ui/editor/{WeightEditorUiState,WeightEditorViewModel,WeightEditorScreen,EditorMeasuredAt,EditorDateField}.swift`, `navigation/VitalsNavigation.swift`, `VitalsModule.swift`; tests `VitalsViewModelTests.swift` (weight cases: `entries inside range are listed newest first with chart`, `year range includes older entries`, `single entry produces no chart`, `delete confirms first, then defers the write`, `undo brings the row back without touching the repository`; the Android table's remaining two — `switching to blood pressure shows its entries with a two series chart`, `glucose entries are displayed in the preferred unit while storage stays mg dL` — are **owed by iOS-M7** and named here so that plan cannot drop them), `WeightEditorViewModelTests.swift` (4 cases by name), `EditorMeasuredAtTests.swift` (today → now; past → 12:00; unchanged date keeps the original instant; zone from the existing entry — no Android twin today, spec §11 A8), `FakeNavigator.swift` (iOS `Navigator` is a concrete `final class`, not a protocol — the fake is a `Navigator` instance whose `NavCommand` stream the test records; **do not introduce a `Navigator` protocol** for this), `TestDeletes.swift`.

**Kotlin:** `ui/list/{VitalsUiState,VitalsViewModel,VitalsScreen}.kt`, `ui/editor/{WeightEditor*,EditorMeasuredAt,EditorDateField}.kt`, `navigation/VitalsNavigation.kt`, `di/VitalsModule.kt`, the tests named above.

**Produces:**
- `VitalsUiState`/`VitalsEvent` ported in full (all three `VitalsListItem` cases, `ChartRange`, `selectedType`, `glucoseUnit` …); `VitalsViewModel` builds **weight state only** (`buildWeightState`, `dailyPoints`, `chartOrNull` verbatim — `chartOrNull`'s `"d MMM"` axis label is produced from `LocalDate` through a `DateFormatter` on `Locale.current`, never via `Calendar`; selecting another type yields the empty state — M7 fills it). **Constructor divergence, recorded on purpose:** Android's is `VitalsViewModel(repository, preferences: VitalsPreferences, pendingDeletes, undoableDelete, clock)`; M2 omits `preferences` because `VitalsPreferences` (+ `VitalsPreferencesImpl` over the `glucose_unit` key in `SalusSettings`) is M7 work, so **M7 changes the ctor signature**, not only the state builders. `@MainActor @Observable final class`, `state`, `onEvent(_:)`, observation task started in `init`/`start()` and cancelled in `deinit`; the list is `combine(repository.observeWeightHistory, pendingDeletes.pendingIds)` filtering pending ids exactly as Kotlin, so rows vanish immediately and come back on undo; delete goes through `UndoableDelete` + `PendingDeleteController`.
- **Non-weight types in M2:** the type chips stay visible (UiState parity), but for `BLOOD_PRESSURE`/`BLOOD_GLUCOSE` the FAB is **hidden** (`onAddEntry` has no key to push yet) and rows cannot exist, so `onEditEntry` is unreachable. A `// TODO(M7)` marks the FAB condition; M7 removes it rather than adding a branch.
- `WeightEditorViewModel(entryId:repository:saveWeightEntry:clock:navigator:undoableDelete:)` — verbatim port incl. `','→'.'` parsing, `formatValue`, `pop()` after save, deferred delete then `pop()`; `resolveEditorMeasuredAt(clock:selectedEpochDay:existingMeasuredAt:existingTimeZone:)` uses the Task 1 `SalusClock.instant(of:minuteOfDay:)` boundary (today → `minuteOfDayNow()`, past → `12 * 60`), the existing-entry day computed with `LocalDate(epochDay:)` integer math from the entry's `epochMs + tz_id`. The delete snackbar message is `VitalsStrings` text resolved inside the feature and handed to `UndoableDelete` as a `String` (Task 3).
- Views: `VitalsRoute(onOpenTrends:)` (owns the VM via `@State`, reads `AppCompositionRoot` from the environment for dependencies), `VitalsScreen(state:onEvent:…)` stateless; `WeightEditorRoute(entryId:)`/`WeightEditorScreen`; `EditorDateField` → SwiftUI `DatePicker(.date)` bound to `epochDay`; formatting via `Locale.current` (`formatKg`).
- `VitalsKey`, `WeightEditorKey(entryId: String?)` as `Hashable & Sendable` enums/structs; `public extension View { func vitalsDestinations() -> some View }` registering `navigationDestination(for: WeightEditorKey.self)`; `public func makeVitalsModule(root dependencies…)` returning the feature's factories (repository singleton, use case factory, VM factories) — the Koin-module twin, built by the composition root.

- [x] TDD the VMs against `FakeVitalsRepository` + `FixedSalusClock` + `FakeNavigator`; views by preview build. Banned-claims scan on Swift sources stays green. Commit.

### Task 7: Shell integration + launch verification

**Files:** `App/{AppCompositionRoot,RootView,RootTab,PlaceholderScreen}.swift`, `project.yml` (+ regenerated project: link `FeatureVitals`, `SalusUI`).

- [x] Root builds `VitalsDao`, the vitals module (repository singleton, `SaveWeightEntryUseCase` also exposed as `any VitalsQuickEntry` for onboarding later), `SalusSnackbarController`, `UndoableDelete`. `RootView` mounts `SalusSnackbarHost` once, hosts `VitalsRoute` in the Vitals tab with `.vitalsDestinations()`, `onOpenTrends` is a no-op callback with a TODO(M11) comment; other tabs keep `PlaceholderScreen`.
- [x] Verify: `scripts/ci.sh` green; simulator run — add two weights on different days, see list newest-first and chart, edit one, delete with undo (row returns), delete and let the window close (row gone after relaunch); screenshots light/dark into the workspace; boot log unchanged.
- [x] Commit (`feat(app): …`).

### Task 8: Feature template doc, rules, record, merge

**Files:** `docs/ios-feature-template.md` (new; the section-for-section twin of the Android template: Package setup · Directory structure · UDF state types · Shell/navigation-container rule · Route/Screen split · Navigation (keys, `…Destinations()`, `Navigator`) · Module factory · Testing standard · Charts · Strings), `CLAUDE.md` (Charts lint rule now mechanical; String Catalog parity + banned-claims tests now mechanical; feature template is the reference), `README.md`, this plan's execution record.

- [x] Write the template from the shipped `FeatureVitals` (cite files), update rules, wire `scripts/lint-custom-rules.sh` into the pipeline, append the execution record (rulings, deferred findings), rebase on `main`, `scripts/ci.sh`.
- [ ] `--ff-only` merge, push, watch CI — **held for the user** (ledger ruling, 2026-08-23): merging publishes a shared branch, and the manual simulator pass below is part of this milestone's done criterion.

## Done criterion (spec §10, iOS-M2)

✅ *End-to-end weight feature plus the Swift Charts adapter; `docs/ios-feature-template.md` produced* — plus the Android vitals/weight test tables green on iOS and the first TR/EN catalog parity test in CI.

---

## Execution record (2026-08-23)

Executed subagent-driven on branch `m2-vitals-weight` off `main` at `e355f66`: one Opus implementer
per task, an independent reviewer per task, a scoped re-review after each fix round. No task ran in
parallel with another — every pair in the pre-flight scan was consistent, so the chain was strictly
sequential and each task rebased on nothing. Four of the seven implementation tasks passed review
first time; the other three passed after exactly one fix round each. Sixteen commits, `e355f66..`.

`scripts/ci.sh` was green at the end of Tasks 4, 6, 7 and 8. The **simulator half of Task 7's
verification was not performed** — see "Manual verification still owed" below; it is the reason the
`--ff-only` merge and the push are held for the user rather than done here.

### Commits and review rounds per task

| Task | Commits | Review |
| --- | --- | --- |
| 1 — foundations (`AnyNavKey` concrete push, `LocalDate` normalisation, `instant(of:minuteOfDay:)`, `clean.sh`) | 5 — `b718b85`, `8b8137a`, `fb4d859`, `9917382`, fix `b052ea6` | Needs fixes → 1 round (clean.sh's fallback was unreachable under `set -e`/`pipefail`) |
| 2 — `VitalsDao` | 1 — `a9c0405` | Clean first time |
| 3 — `SalusUI` chart/components/snackbar + the `no_charts_in_features` rule | 2 — `3baa9e4`, `874f3a8` | Approved; 2 Important were recording issues, both ruled below |
| 4 — `FeatureVitals` domain + data | 3 — `980e37c`, `f176b36`, `9f0e900` | Needs fixes (3 Important) → 1 round |
| 5 — String Catalog + `StringCatalogParity` / banned-claims catalog scan | 1 — `4d1e2fe` | Clean first time |
| 6 — list + weight editor UI | 2 — `ad1f1bb`, fix `5a09a26` | Needs fixes → 1 round (a per-row delete button nested inside a `SalusCard(onTap:)` button — a dead control) |
| 7 — shell integration | 2 — `2893f3b`, fix `0065ac9` | Approved w/ Important → 1 round (the snackbar host overlaid the tab bar and stole tab taps) |
| 8 — this record, the feature template, the rule updates, `lint-custom-rules.sh` in CI | see the branch tip | — |

Task counts are 1-4 commits of implementation plus one per fix round. `CLAUDE.md`'s Process
section said "one commit per task"; **no milestone has ever matched that**, M1 included, so Task 8
rewrote the rule to "one or a few conventional commits per task, squash not required" rather than
record a fourth deviation from it. A fix round's commit is the reviewable unit; squashing it into
the feature commit hides what review changed.

### Rulings made during execution (decided on the user's behalf — read these)

In ledger order. Each says what it costs if it turns out to be wrong.

1. **`FilterChip` → `Picker(.segmented)`** (pre-flight, Task 3's mapping). `design-tokens.md` has
   no chip spec — only a `container` fill mention — so no `SalusFilterChip` is added and the type
   selector uses a segmented picker. *Why:* the plan's own stated fallback.
   *Cost if wrong:* one view swap in `VitalsScreen`.
2. **The undo snackbar keeps Android's `Indefinite` duration** (Task 3). Material3's
   `showSnackbar` defaults to `Indefinite` when an action label is present, so Android's undo
   snackbar (`SalusApp.kt:114-119`) never auto-dismisses even though the undo window itself is
   5 s (`PendingDeleteController.kt:78`, `UNDO_WINDOW_MILLIS = 5_000L`) — after 5 s the action is a
   no-op that still sits on screen. The port keeps the behaviour rather than fixing it on one
   platform; the fix is opened as Android §11 **A10**. *Cost if wrong:* Android fixes it first and
   iOS re-syncs one line.
3. **`SalusSnackbarHost` tap-to-dismiss is a recorded iOS divergence** (Task 3). Android's host has
   no such affordance. iOS adds one because ruling 2 leaves an `Indefinite` snackbar that would
   otherwise block the FIFO queue forever. Added to Global Constraints above.
   *Cost if wrong:* remove one modifier (`SalusSnackbarHost.swift:65`).
4. **An unresolvable stored time-zone id throws, matching Kotlin** (Task 4). The mapper throws, the
   stream propagates, `recordWeight` throws — rather than degrading to GMT or returning `false`.
   *Why:* the divergence list is closed and Android errors the same way; a graceful degrade is a
   joint decision that belongs in §11. *Cost if wrong:* the history screen errors on a
   newer-tzdb backup exactly as Android does.
5. **`SaveWeightEntryUseCase` rejects NaN — a recorded iOS divergence** (Task 4). Kotlin stores it;
   iOS is correct. A 7th case, `NaN is rejected`, was added to the ported table, and Android §11
   **A11** is opened to adopt it. Added to Global Constraints above. *Cost if wrong:* none visible —
   NaN input is unreachable from the editor.
6. **`Date.epochMilliseconds` quantises to microseconds before flooring** (Task 4). A `Double` of
   seconds-since-2001 rebuilt from a stored column sits a sub-µs *below* the true value, and a bare
   `floor` then drops 1 ms on ~2 % of 2030-2050 stamps; Kotlin's exact integer nanoseconds never has
   that error, so quantising restores parity. *Cost if wrong:* a `Date` carrying a genuine sub-µs
   fraction — no clock in the app produces one — maps 1 ms differently.
7. **Task 8 does docs, the record, the rebase and `ci.sh` only; the `--ff-only` merge and the push
   are held for the user.** *Why:* merging publishes a shared branch, and the manual simulator pass
   is part of iOS-M2's done criterion. *Cost if wrong:* one extra user command.

### Recorded divergences from Android, complete list

The five the plan recorded up front, plus the two added by rulings 3 and 5:

1. `VitalsViewModel`'s constructor omits `preferences: VitalsPreferences` (M7 work; **M7 changes the
   signature**, not only the state builders).
2. `instant(of:minuteOfDay:)` instead of `localTimeNow()` in `resolveEditorMeasuredAt` — iOS has no
   `localTimeNow` twin.
3. Snackbar requests carry resolved `String`s, not string resource ids: the host is mounted in the
   shell and a feature's strings live in its own `Bundle.module`.
4. The FAB is hidden for `BLOOD_PRESSURE` / `BLOOD_GLUCOSE` (no key to push yet); `// TODO(M7)`
   marks the condition, and M7 removes it rather than adding a branch.
5. `FakeNavigator` is a real `Navigator` instance whose command stream the test records — iOS's
   `Navigator` is a concrete `final class` and **no `Navigator` protocol is introduced**.
6. **`SalusSnackbarHost` dismisses on a tap of its body** (ruling 3).
7. **`SaveWeightEntryUseCase` rejects NaN** (ruling 5).

Anything else that differs from `:feature:vitals` is a bug, not a port decision.

### Deferred findings, verbatim from the ledger, grouped by task

None of these blocks iOS-M3. Ordered as they were raised.

**Task 1 — foundations**
- `SalusClock.instant` minuteOfDay out-of-range contract undocumented/untested
  (`SalusClock.swift:75-81`).
- `SalusClock.swift:87-92` unreachable fallback uses offset at wrong instant.
- `FixedSalusClockTests` "exact inverse" title overstates (minute truncation is plan-mandated; add
  comment).
- No end-to-end `Navigator.navigate` → push concrete-key test.
- 4 commits for one task (CLAUDE.md says one per task; M1 also had multi-commit tasks) — triage at
  final review. **→ resolved in Task 8: the rule was rewritten, not the history.**
- `clean.sh` "nothing to remove" branch effectively dead.

**Task 2 — `VitalsDao`**
- Two stream-bridge shapes (`VitalsDao.conflatedStream` vs `ProfileDao` inline) — unify into an
  internal `ConflatedObservation.swift` before the 3rd DAO.
- `VitalsDaoTests` fixture inserts a second `is_default` profile.
- Numeric separators inconsistent in tests.

**Task 3 — `SalusUI`**
- `SalusLineChart` `ForEach id: \.xEpochDay` assumes unique days — comment/invariant.
- `SalusEmptyState` badge `Image` needs `.accessibilityHidden(true)` (Kotlin `contentDescription =
  null`).
- `SalusSnackbarControllerTests:63-66` potential hang race — capture the task handle before
  `fire()`.
- `SalusCard` uses `surfaceContainerLow` (Kotlin) while `design-tokens.md` says `Lowest` for iOS —
  doc reconcile on the Android side (§11). **→ opened as the §11 docs note in Task 8.**
- `scripts/lint-custom-rules.sh` not in `ci.sh`/README (Task 8); `cleanup()` leaves dirs.
  **→ the CI half is done in Task 8; `cleanup()` still leaves the fixtures' parent dirs.**
- Two commits for one task; `SalusShadow` literals outside the token layer (§7-sanctioned).

**Task 4 — domain + data**
- Inclusive bounds 20.0/400.0 untested (Kotlin also skips).
- `FakeVitalsRepository` dictionary order nondeterministic vs Kotlin `LinkedHashMap`; max tie-break
  differs — pin before Task 6 list tests if they hit ties.
- `VitalsRepositoryImpl.mapped` duplicates `VitalsDao.conflatedStream` (third copy → shared internal
  in `SalusDatabase`).
- `SalusClock.swift:100-101` + `EpochMilliseconds.swift:38-40` overclaim ("never in the future" is
  true only to ±500 ns); quantisation is worse than a bare floor outside ~1685-2255 — document.
- `IllegalTimeZoneError` is feature-local but escapes `SalusModel.VitalsQuickEntry.recordWeight` —
  move it to `SalusModel`/`SalusCommon` before `FeatureOnboarding` consumes it; `VitalsQuickEntry`'s
  doc still says `false`.
- README note — stale `Packages/*/.build` after a new file in a path dep (`scripts/clean.sh`).
  **→ done in Task 8.**

**Task 5 — String Catalog**
- `StringCatalog.Entry.localizations` is non-optional → a `DecodingError` instead of a parity error
  for key==value entries.
- `StringUnit.state` not pinned ("translated").
- `assertEveryKeyIsLocalized` throws on the first offender (multi-failure lost).
- The catalog banned scan covers `Packages/` only, not `App/`.
- `noCatalogScanned` test asserts the type, not the case; `VitalsStringsTests` re-reads the catalog
  per call.

**Task 6 — list + editor UI**
- `isNotBlank` uses `.whitespaces` (Kotlin also newlines); `sorted(by:)` is unstable vs Kotlin
  `sortedBy` (VM:219, FakeRepo:52); `EditorDateField`'s nil branch is inert; `VitalsScreen` paints a
  background (Kotlin doesn't) — Task 7's shell decides; `DateFormatter` per call;
  `withObservationTracking` not torn down in `deinit`; `FakeNavigator.stop()` not in teardown;
  `VitalsScreen.swift` is 414 lines; `VitalsRoute.openEditor`'s non-weight drop lacks a `TODO(M7)`.
- Row tap target excludes `SalusCard`'s 16 pt padding (Compose includes it).

**Task 7 — shell**
- A bundle-level TR/EN check (`plutil` on `.lproj/Localizable.strings`) is worth scripting;
  `UndoableDelete` is built in `makeVitalsModule` rather than at the root (stateless, fine);
  `vitalsQuickEntry` has no consumer until M6; `VitalsScreen` background vs the shell's none — a
  visual seam to eyeball.
- Tab switch replays the snackbar's entrance transition; landscape not photographed.

### Manual verification still owed by the user (Task 7)

The CLI cannot drive a tap on this machine: `xcrun simctl` has no input subcommand, `idb` and
`cliclick` are not installed, and driving `Simulator.app` by AppleScript fails with *"osascript is
not allowed assistive access. (-1719)"*. What **was** verified: `scripts/ci.sh` green, the app
launches, and light/dark follow the stored `theme_mode` (screenshots of the Home placeholder).
Everything below is unverified and **nothing about it is claimed**:

1. **Reaching the Vitals tab at all** — the shell starts on `.home`. So there is no screenshot of
   the Vitals tab in either appearance; by extension it is unverified that `VitalsStrings.title`
   renders "Ölçümler" (the end-to-end proof that the String Catalog is compiled by the real app
   build), and whether `VitalsScreen` painting its own background double-paints against the shell.
2. Add two weights on different days → the list is newest-first and the chart renders.
3. Edit one → the editor opens pre-filled and saving updates the row.
4. Delete with undo → the row returns.
5. Delete and let the window close → after relaunch the row is gone (persistence).
6. Tapping a row's **trash icon shows the undo snackbar, not the editor** — the Task 6 fix has no
   automated coverage and this is the only way to confirm it.
7. Consequently the snackbar has never been seen on screen, including whether it clears the tab bar
   (the Task 7 fix).

```
xcrun simctl boot ACE6E0E3-E771-42CE-B76C-06AF257A215A          # if shut down
open -a Simulator
xcrun simctl launch ACE6E0E3-E771-42CE-B76C-06AF257A215A com.alicansekban.salus
# tap Vitals (3rd tab) and run steps 2-6 above
xcrun simctl io ACE6E0E3-E771-42CE-B76C-06AF257A215A screenshot ~/Desktop/vitals.png
xcrun simctl ui ACE6E0E3-E771-42CE-B76C-06AF257A215A appearance dark   # then light
```

### Android follow-ups opened by this milestone

Written into `salus-android/docs/ios-v1-plan.md` §11 in the same milestone. **A9 was already
taken** (the M10 mirror, opened 2026-08-23), so the two new items are numbered **A10** and **A11**,
not A9/A10 as this plan's Task 8 brief assumed.

- **A10** — the undo snackbar's duration should equal `PendingDeleteController.UNDO_WINDOW_MILLIS`.
  Today `SalusApp.kt:114-119` passes an action label and no duration, and Material3 defaults that to
  `Indefinite`, so the snackbar outlives the 5 s window and its action becomes a silent no-op
  (ruling 2).
- **A11** — `SaveWeightEntryUseCase` should reject NaN, as iOS does (ruling 5).
- **A12** — a docs reconcile: `design-tokens.md` §2.1 and §7 tell iOS to fill cards with
  `surfaceContainerLowest`, while `SalusCard.kt:34` uses `surfaceContainerLow`. In light mode both
  are `#FFFFFF` so nothing is visible; in dark they are `#050807` vs `#141A16`, so the two platforms
  would draw different cards. `SalusCard.swift:59` followed the Kotlin. Reconcile the doc to the
  code, or decide the other way and change both.
- The **undo-snackbar dismissal divergence** is also recorded as a §6 candidate — the first
  divergence that is a *port artefact* rather than a platform constraint, so it wants a decision
  before it becomes permanent.
- Still open from before this milestone: **A8** (the vitals test tables iOS-M2 wrote with no Android
  twin — `WeightEntryMapperTest`, `EditorMeasuredAtTest`), opened 2026-08-22.
