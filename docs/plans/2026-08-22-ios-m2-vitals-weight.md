# iOS-M2 — Vitals / Weight Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Executor subagents run on **Opus** (user preference). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md` and the M1 plan's "Execution record" first. Independent tasks may run in parallel implementers (own worktree + side branch, rebased before review).

**Goal:** The first end-to-end feature: the Vitals tab lists weight entries with a range-selectable line chart, a weight editor creates/edits/deletes entries (delete with undo), everything persisted through GRDB and proven by the ported Android tests — plus the Swift Charts adapter and shared views in `SalusUI`, the first String Catalog, and `docs/ios-feature-template.md` that every later feature copies.

**Architecture:** `FeatureVitals` mirrors `:feature:vitals` layer for layer (`domain/` pure, `data/` mappers + repository over `VitalsDao`, `ui/<screen>/` UiState+Event(+Effect)/ViewModel/Route+Screen, `navigation/` keys + destinations, `module` factory). Features never import Charts; `SalusUI` owns `ChartUiModel` + `SalusLineChart`. Navigation keys stay feature-owned; the shell applies each feature's destination modifier. **Scope is weight only** — blood pressure and glucose (types, editors, two-series chart, unit preference) are iOS-M7; the UiState vocabulary is ported in full so M7 adds builders, not shape.

**Tech Stack:** Swift 6 / SwiftUI / Swift Charts · `@Observable` view models · GRDB `ValueObservation` · String Catalog (`.xcstrings`) · Swift Testing.

**Spec:** `../salus-android/docs/ios-v1-plan.md` §5 (platform mapping), §10 iOS-M2 · `../salus-android/docs/architecture/feature-template.md` (the Android template this milestone twins) · Kotlin under `salus-android/feature/vitals/`, `salus-android/core/ui/`, `salus-android/core/database/.../dao/VitalsDao.kt`.

## Global Constraints

- No new dependencies (allowlist stays GRDB only; Swift Charts is a system framework).
- Reviewed against Android `:feature:vitals` on 2026-08-22; the divergences this plan records on purpose (VM ctor without `VitalsPreferences`, `instant(of:minuteOfDay:)` instead of `localTimeNow()`, resolved snackbar strings, hidden FAB for non-weight types, concrete `Navigator` fake) are the complete list — anything else that differs is a bug.
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

- [ ] TDD for all three library changes; `scripts/test-packages.sh SalusNavigation SalusModel SalusCommon SalusTesting`; `scripts/lint.sh`. Commit.

### Task 2: `VitalsDao` in `SalusDatabase`

**Files:** `Packages/SalusDatabase/Sources/SalusDatabase/VitalsDao.swift`, `Tests/SalusDatabaseTests/VitalsDaoTests.swift`.

**Kotlin:** `core/database/.../dao/VitalsDao.kt` (every `@Query` verbatim: `upsert`, `getById`, `observeRange(profileId,type,fromEpochMs,untilEpochMs)`, `observeLatest(profileId,type)`, `getMeasurementsBetween`, `deleteById`), `DaoSmokeTest.kt` case `vitals range query emits inserted measurements in order`.

**Produces:** `public struct VitalsDao: Sendable { init(database:) }` with the same shape as `ProfileDao` — async throws methods over `VitalsMeasurementRecord`; `observe*` return `AsyncThrowingStream<…, any Error>` conflated (`.bufferingNewest(1)`), ordering identical to the Kotlin SQL (`ORDER BY measured_at_epoch_ms`).

- [ ] TDD: the ported smoke test + range boundaries (inclusive/exclusive exactly as the SQL) + `observeLatest` emits on insert. Commit.

### Task 3: `SalusUI` — chart adapter, shared views, snackbar/undo

**Files:** `Packages/SalusUI/Sources/SalusUI/chart/{ChartUiModel,SalusLineChart}.swift`, `component/{SalusCard,SalusEmptyState,SalusFab,SalusConfirmDialog,SalusScreenHeader}.swift` — **exactly the `:core:ui` set `VitalsScreen.kt` and `WeightEditorScreen.kt` import** (verified 2026-08-22; `SalusListItem`, `SalusSectionHeader`, `SalusPillButton`, `SalusPillTextField`, `SalusSparkline` are *not* used by this slice and arrive with the feature that first needs them — sparkline with Home in M7), `snackbar/{SalusSnackbarController,SalusSnackbarHost,UndoableDelete}.swift`; tests; `.swiftlint.yml` custom rule `no_charts_in_features` (`included: Packages/Features/`, forbids `import Charts`, same shape as `no_ui_framework_in_domain`).

**Kotlin:** `core/ui/.../chart/{ChartUiModel,SalusLineChart}.kt`, `component/{SalusCard,SalusEmptyState,SalusFab,SalusConfirmDialog,SalusScreenHeader}.kt`, `snackbar/{SalusSnackbarController,UndoableDelete}.kt`; design values only from `design-tokens.md` via `SalusDesignSystem`.

**Material twins the feature uses directly (no `SalusUI` wrapper, decided here so nobody improvises):** `FilterChip` (type selector) → a `SalusUI` `SalusFilterChip` is *not* added; use a `Button` with `.buttonStyle` driven by tokens inside the feature **only if** the design-tokens doc has a chip spec, otherwise `Picker` `.segmented`; `SingleChoiceSegmentedButtonRow` (range) → `Picker(.segmented)`; `CircularProgressIndicator` → `ProgressView()`; `OutlinedTextField`/`Button`/`TopAppBar` (editor) → `TextField` with `.textFieldStyle(.roundedBorder)`, `Button`, `.toolbar` + `navigationTitle`. The executor records the chosen mapping in the feature template's Charts/Components section.

**Produces:** `ChartPoint(xEpochDay: Int, y: Float)`, `ChartUiModel(points:xLabel:yLabel:secondaryPoints:)` (closures `@Sendable`), `SalusLineChart(model:lineColor:contentDescription:)` rendering with Swift Charts (`LineMark` + secondary series in secondary colour; x axis labelled through `xLabel`; VoiceOver summary from `contentDescription`); `@MainActor @Observable SalusSnackbarController` (message + optional undo action, auto-dismiss per Android duration — Android's is a `Channel`-backed request stream consumed by one host; the iOS twin keeps the `SnackbarRequest(message:actionLabel:onAction:)` shape with **resolved `String`s, not keys**, because the host is mounted in the shell and a feature's strings live in its own `Bundle.module`), `SalusSnackbarHost` overlay the shell mounts once; `UndoableDelete(pendingDeletes:snackbar:)` callable `(id, message: String, commit)` — the twin of `UndoableDelete.kt` (`@StringRes messageRes` becomes the already-localised text) over M1's `PendingDeleteController`.

- [ ] TDD for the non-view logic (`ChartUiModel` equality/defaults, snackbar controller state machine, `UndoableDelete` schedules + undo); views verified by `#Preview` build. Lint rule proven by a negative fixture test like M0's. Commit.

### Task 4: `FeatureVitals` domain + data

**Files:** `Packages/Features/FeatureVitals/Sources/FeatureVitals/domain/{model/WeightEntry,repository/VitalsRepository,usecase/SaveWeightEntryUseCase}.swift`, `data/{WeightEntryMapper,VitalsRepositoryImpl}.swift`; tests `FakeVitalsRepository.swift`, `SaveWeightEntryUseCaseTests.swift` (6 cases by name), `WeightEntryMapperTests.swift` (round trip + unit/type pins — **no Android twin today**; tracked as spec §11 A8 so Android gets the same table), `VitalsRepositoryImplTests.swift` (in-memory DB: save/observe/delete; iOS-only, no Android twin needed — Android covers it through `DaoSmokeTest`).

**Kotlin:** `feature/vitals/.../domain/**`, `data/{WeightEntryMapper,VitalsRepositoryImpl}.kt`, `test/domain/usecase/SaveWeightEntryUseCaseTest.kt`, `test/FakeVitalsRepository.kt`.

**Produces:** `WeightEntry(id:measuredAt: Date, timeZone: TimeZone, kilograms:note:)`; `protocol VitalsRepository` with the weight members only (`observeWeightHistory(from:until:) -> AsyncThrowingStream<[WeightEntry], any Error>`, `observeLatestWeight()`, `getWeightEntry(id:)`, `saveWeightEntry(_:)`, `deleteWeightEntry(id:)`) — BP/glucose members arrive in M7; `SaveWeightEntryUseCase(repository:idGenerator:)` with `enum Result { saved(WeightEntry), invalidWeight }`, `callAsFunction(existingId:kilograms:measuredAt:timeZone:note:)`, conforming to `SalusModel.VitalsQuickEntry` (`recordWeight` shares the validation); `VitalsRepositoryImpl(vitalsDao:profileId:)` (profile id = `SalusDatabase.defaultProfileId`).

- [ ] TDD; `scripts/test-packages.sh FeatureVitals`. Commit.

### Task 5: First String Catalog + string tests

**Files:** `Packages/Features/FeatureVitals/Sources/FeatureVitals/Resources/Localizable.xcstrings` (48 keys, `tr` source + `en`), `Package.swift` (`defaultLocalization: "tr"`, resources), `Sources/FeatureVitals/VitalsStrings.swift` (typed accessors, `Bundle.module`), tests `VitalsStringsTests.swift`; `Packages/SalusTesting` gains `StringCatalogParity` (parse an `.xcstrings`, assert every key has both `tr` and `en` values, no extra locales, and pinned key set) and `BannedHealthClaims.assertCatalogsNameNothingBanned(paths:)`.

**Kotlin/XML:** `feature/vitals/src/main/res/values/strings.xml` + `values-en/strings.xml` (48/48) — port name and text verbatim; `core/testing/.../BannedHealthClaims.kt` (`assertFilesNameNothingBanned`).

- [ ] Tests: key-set pin (48 literal names copied from the XML), TR/EN parity, banned-claims scan over every `.xcstrings` under `Packages/` (must scan ≥ 1 file). Commit.

### Task 6: `FeatureVitals` UI — list + weight editor

**Files:** `ui/list/{VitalsUiState,VitalsViewModel,VitalsScreen}.swift`, `ui/editor/{WeightEditorUiState,WeightEditorViewModel,WeightEditorScreen,EditorMeasuredAt,EditorDateField}.swift`, `navigation/VitalsNavigation.swift`, `VitalsModule.swift`; tests `VitalsViewModelTests.swift` (weight cases: `entries inside range are listed newest first with chart`, `year range includes older entries`, `single entry produces no chart`, `delete confirms first, then defers the write`, `undo brings the row back without touching the repository`; the Android table's remaining two — `switching to blood pressure shows its entries with a two series chart`, `glucose entries are displayed in the preferred unit while storage stays mg dL` — are **owed by iOS-M7** and named here so that plan cannot drop them), `WeightEditorViewModelTests.swift` (4 cases by name), `EditorMeasuredAtTests.swift` (today → now; past → 12:00; unchanged date keeps the original instant; zone from the existing entry — no Android twin today, spec §11 A8), `FakeNavigator.swift` (iOS `Navigator` is a concrete `final class`, not a protocol — the fake is a `Navigator` instance whose `NavCommand` stream the test records; **do not introduce a `Navigator` protocol** for this), `TestDeletes.swift`.

**Kotlin:** `ui/list/{VitalsUiState,VitalsViewModel,VitalsScreen}.kt`, `ui/editor/{WeightEditor*,EditorMeasuredAt,EditorDateField}.kt`, `navigation/VitalsNavigation.kt`, `di/VitalsModule.kt`, the tests named above.

**Produces:**
- `VitalsUiState`/`VitalsEvent` ported in full (all three `VitalsListItem` cases, `ChartRange`, `selectedType`, `glucoseUnit` …); `VitalsViewModel` builds **weight state only** (`buildWeightState`, `dailyPoints`, `chartOrNull` verbatim — `chartOrNull`'s `"d MMM"` axis label is produced from `LocalDate` through a `DateFormatter` on `Locale.current`, never via `Calendar`; selecting another type yields the empty state — M7 fills it). **Constructor divergence, recorded on purpose:** Android's is `VitalsViewModel(repository, preferences: VitalsPreferences, pendingDeletes, undoableDelete, clock)`; M2 omits `preferences` because `VitalsPreferences` (+ `VitalsPreferencesImpl` over the `glucose_unit` key in `SalusSettings`) is M7 work, so **M7 changes the ctor signature**, not only the state builders. `@MainActor @Observable final class`, `state`, `onEvent(_:)`, observation task started in `init`/`start()` and cancelled in `deinit`; the list is `combine(repository.observeWeightHistory, pendingDeletes.pendingIds)` filtering pending ids exactly as Kotlin, so rows vanish immediately and come back on undo; delete goes through `UndoableDelete` + `PendingDeleteController`.
- **Non-weight types in M2:** the type chips stay visible (UiState parity), but for `BLOOD_PRESSURE`/`BLOOD_GLUCOSE` the FAB is **hidden** (`onAddEntry` has no key to push yet) and rows cannot exist, so `onEditEntry` is unreachable. A `// TODO(M7)` marks the FAB condition; M7 removes it rather than adding a branch.
- `WeightEditorViewModel(entryId:repository:saveWeightEntry:clock:navigator:undoableDelete:)` — verbatim port incl. `','→'.'` parsing, `formatValue`, `pop()` after save, deferred delete then `pop()`; `resolveEditorMeasuredAt(clock:selectedEpochDay:existingMeasuredAt:existingTimeZone:)` uses the Task 1 `SalusClock.instant(of:minuteOfDay:)` boundary (today → `minuteOfDayNow()`, past → `12 * 60`), the existing-entry day computed with `LocalDate(epochDay:)` integer math from the entry's `epochMs + tz_id`. The delete snackbar message is `VitalsStrings` text resolved inside the feature and handed to `UndoableDelete` as a `String` (Task 3).
- Views: `VitalsRoute(onOpenTrends:)` (owns the VM via `@State`, reads `AppCompositionRoot` from the environment for dependencies), `VitalsScreen(state:onEvent:…)` stateless; `WeightEditorRoute(entryId:)`/`WeightEditorScreen`; `EditorDateField` → SwiftUI `DatePicker(.date)` bound to `epochDay`; formatting via `Locale.current` (`formatKg`).
- `VitalsKey`, `WeightEditorKey(entryId: String?)` as `Hashable & Sendable` enums/structs; `public extension View { func vitalsDestinations() -> some View }` registering `navigationDestination(for: WeightEditorKey.self)`; `public func makeVitalsModule(root dependencies…)` returning the feature's factories (repository singleton, use case factory, VM factories) — the Koin-module twin, built by the composition root.

- [ ] TDD the VMs against `FakeVitalsRepository` + `FixedSalusClock` + `FakeNavigator`; views by preview build. Banned-claims scan on Swift sources stays green. Commit.

### Task 7: Shell integration + launch verification

**Files:** `App/{AppCompositionRoot,RootView,RootTab,PlaceholderScreen}.swift`, `project.yml` (+ regenerated project: link `FeatureVitals`, `SalusUI`).

- [ ] Root builds `VitalsDao`, the vitals module (repository singleton, `SaveWeightEntryUseCase` also exposed as `any VitalsQuickEntry` for onboarding later), `SalusSnackbarController`, `UndoableDelete`. `RootView` mounts `SalusSnackbarHost` once, hosts `VitalsRoute` in the Vitals tab with `.vitalsDestinations()`, `onOpenTrends` is a no-op callback with a TODO(M11) comment; other tabs keep `PlaceholderScreen`.
- [ ] Verify: `scripts/ci.sh` green; simulator run — add two weights on different days, see list newest-first and chart, edit one, delete with undo (row returns), delete and let the window close (row gone after relaunch); screenshots light/dark into the workspace; boot log unchanged.
- [ ] Commit (`feat(app): …`).

### Task 8: Feature template doc, rules, record, merge

**Files:** `docs/ios-feature-template.md` (new; the section-for-section twin of the Android template: Package setup · Directory structure · UDF state types · Shell/navigation-container rule · Route/Screen split · Navigation (keys, `…Destinations()`, `Navigator`) · Module factory · Testing standard · Charts · Strings), `CLAUDE.md` (Charts lint rule now mechanical; String Catalog parity + banned-claims tests now mechanical; feature template is the reference), `README.md`, this plan's execution record.

- [ ] Write the template from the shipped `FeatureVitals` (cite files), update rules, append the execution record (rulings, deferred findings), rebase on `main`, `scripts/ci.sh`, `--ff-only` merge, push, watch CI.

## Done criterion (spec §10, iOS-M2)

✅ *End-to-end weight feature plus the Swift Charts adapter; `docs/ios-feature-template.md` produced* — plus the Android vitals/weight test tables green on iOS and the first TR/EN catalog parity test in CI.
