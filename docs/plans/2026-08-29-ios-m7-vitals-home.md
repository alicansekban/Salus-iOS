# iOS-M7 — Vitals completion + Home dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Executor subagents run on **Opus** (user preference). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md`, `docs/ios-feature-template.md` and the research inventories in `.superpowers/sdd/2026-08-29-ios-m7-vitals-home/research-{android-vitals,android-home,ios-state}.md` (git-ignored; they hold every signature, constant and test-case name this plan cites) before touching a task.

**Goal:** Finish `FeatureVitals` (blood pressure + glucose: 8 repository members, 2 mappers, 2 use cases, 2 editors, the two-series BP chart and the app-wide `glucose_unit` preference — 32 owed Kotlin cases + the 2 owed `VitalsViewModelTest` cases green) and build `FeatureHome` (the dashboard: greeting band, today's doses with "Al", upcoming appointments, cycle card, vitals aggregate card with a hand-drawn `SalusSparkline` — 9 Kotlin cases green), plus the chores M6 carried here: the `no_calendar_outside_clock` lint rule, the three inline pills → `SalusPillButton`, the `throwingStream(over:)` hoist, the sub-1-base `ChartAxisScale` row.

**Architecture:** Vitals: *builders, not shape* — `VitalsUiState`/`VitalsListItem`/`VitalsEvent`, all 48 strings, `VitalsDao`, `ChartUiModel.secondaryPoints`, `SalusLineChart`'s second series, `GlucoseUnit`/`GlucoseConversion`/`SettingsKeys.glucoseUnit` are all in the tree; M7 adds `domain/{model,usecase}`, `data/` mappers + repository members, `VitalsPreferences(Impl)` (the `CycleReminderSettings` shape), the two `ui/editor/` verticals and the list-screen branches. Home: twin of Android `:feature:home`, which depends on **zero** feature modules — it reads the four DAOs (`SalusDatabase`) directly, writes doses through `SalusModel.DoseActions` (already bound at the composition root), and navigates only through shell closures (three tab switches + one `CycleKey` push already registered on the Home stack). `FeatureHome/Package.swift` already declares that graph.

**Tech Stack:** Swift 6 / SwiftUI, Swift Charts (inside `SalusUI` only), GRDB (`SalusDatabase`), `SalusSettings`, swift-testing.

**Spec:** `salus-android/docs/ios-v1-plan.md` — §4, §7 (banned claims), §8 (`VitalsScreen` editors, `HomeScreen`), iOS-M7 entry ("Blood pressure, glucose with mg/dL↔mmol/L, two-series BP chart, sparklines, the Home aggregate card"); `salus-android/docs/parity-ledger.md` D-M2-a, D-M2-d, D-M6-f, S-8, S-23, roadmap rows `Vitals (weight)` (2 cases owed) and `Home | iOS-M7`. **Do not modify Android code** — the only Android-repo write is the parity-ledger docs commit in Task 13.

## Global Constraints

- **Rulings (coordinator, 2026-08-29 — the user asked for the plan and the start of execution in one go; flagged for confirmation, applied unless overruled):**
  1. **AI summary card is absent in M7** (its section header too) — a tap target that opens nothing (`AiSummaryKey` is iOS-M10) is a dead end. `HomeUiState.freeAiSummaryAvailable`/`isPremium` are carried from day one behind two feature-local protocols (`HomeAiSummaryAvailability` over `AiUsageDataSource`, real; `HomePremiumStatus` bound to a `FreeOnlyPremiumStatus` that emits `false` until M9 — recorded divergence). The three `home_ai_summary_*` keys are ported now so the key-set pin moves once; `home_title`/`home_settings` (dead on Android since M9) are **not** ported → 27 keys, recorded.
  2. **Queued-second-delete dead-UNDO edge stays as recorded parity.** Android's queue blocks identically (M2 ruling 2); ledger O-4/S-5/D-M2-f already track it. M7 does not touch `SalusSnackbarController`/`PendingDeleteController`. Left for the user to overrule.
  3. **`WhileSubscribed(5_000)` twin = re-subscribe on appearance.** `HomeViewModel.restartObservation()` is called from `HomeRoute`'s `.task` on every appearance (the A13 `restartHistoryObservation()` precedent), re-capturing `today`/`nowMinute`/`nowMs`. Divergence: Android re-captures after a 5 s unsubscribed grace, iOS on every appearance.
  4. **`SalusCommon` gains `latestOfThree/Four/Five`** as documented nestings of `latestOfBoth` (flattened tuples), plus the hoisted `throwingStream(over:)`. Home's 3-, 4- and 5-way `combine`s use them; no parameter-pack cleverness.
  5. **NaN/non-finite input is rejected** by `SaveBloodPressureEntryUseCase` and `SaveGlucoseEntryUseCase` (mirrors M2 ruling 5 / A11 for weight; Kotlin lets NaN through). Recorded divergence + Android follow-up.
  6. **Locale quirks are ported verbatim**: glucose editor `formatValue` uses `en_US_POSIX` while the list uses the view locale; Home's `formatNumber` uses `en_US_POSIX` (Kotlin `Locale.ROOT`) while `formatMinutes` uses the view locale. Recorded, not "fixed".
  7. **Sparkline is `.accessibilityHidden(true)`** — the weight row's text already speaks the value; Compose gives it no `contentDescription`. Recorded as an iOS-only a11y choice.
  8. **Home has no `homeDestinations()`**: nothing pushes into Home from Home (Android `homeEntries` registers only the tab root). `HomeKey` exists for name parity. `RootView` keeps `.cycleDestinations()` + `.environment(\.cycleModule)` on the Home stack.
  9. **Cycle card is not sex-gated** (Android: `TodayOverview.cycle` is non-nullable; the gate is the More hub row, M8). Parity.
  10. **`VitalsScreen.swift` (460 lines) is split** before it crosses 500: list rows/header/empty into `VitalsListSections.swift`, the `MedicationDetailSections` precedent.
- **Recorded iOS divergences (write into the execution record, not silently):** (a) `VitalsPreferences.setGlucoseUnit` is synchronous and `glucoseUnit` a non-throwing `AsyncStream` (M6 (b) twin) — but **with** Kotlin's `distinctUntilChanged` (a `last`-value guard in the stream builder), unlike `CycleReminderSettingsImpl`; (b) NaN rejection (ruling 5); (c) repository write failures swallowed into UI state / `try? await` for the new editors and delete arms (M2 divergence 8, kept for consistency); (d) `HomePremiumStatus` pinned `false` (ruling 1); (e) re-subscribe on appearance (ruling 3); (f) AI card absent (ruling 1); (g) two dead string keys omitted (ruling 1); (h) sparkline hidden from VoiceOver (ruling 7); (i) cycle progress track drawn as a `Capsule` background under a `.linear` `ProgressView` (Compose sets the track colour directly); (j) `FakeNavigator`/`waitUntil` copied into `FeatureHomeTests` (template-sanctioned); (k) Home vitals card reads `GlucoseConversion.fromMgDl` (Android inlines `/ MG_DL_PER_MMOL_L`) — same arithmetic.
- **Never** invent a BP/glucose "normal range" hint, and never reword `vitals_invalid_glucose` / `today_doses_empty` ("planlı doz yok" — one edit from the `planlan` stem). `BannedHealthClaims` scans Swift sources, comments and catalogs repo-wide; say "accepted values", never "target range".
- Strings: Vitals adds **zero** keys (48 already pinned). Home: **27 keys** of the 29 in `feature/home/src/main/res/values{,-en}/strings.xml` (all but `home_title`, `home_settings`), TR source + EN, copied from the XML; `%1$s`→`%1$@`, `%1$d`→`%1$lld`; EN `Today\'s doses` → `Today's doses`. Unit symbols `"mmHg"`, `"bpm"`, `"mg/dL"`, `"mmol/L"` stay hardcoded (Android hardcodes them; a key would break the 48-pin).
- `Calendar` rule (CLAUDE.md): days are `LocalDate`/`epochDay`; the Home header formats `LocalDate` through `LocalDate.formatted(pattern:locale:)`; the appointment time is an instant → `Date.FormatStyle(date: .abbreviated, time: .shortened)` with `.timeZone` from `timeZoneId` (`TimeZone(identifier:) ?? .current`, Android's `runCatching{}.getOrDefault`). The new lint rule (Task 1) is the mechanical check.
- Colors: `theme.extendedColors.vitals` (chart line, sparkline), `.medications` (dose time, "Al" pill), `.cycle` (progress + ongoing text); `colorScheme.primaryContainer`/`onPrimaryContainer` header band; `colorScheme.tertiary` second series (already in `SalusLineChart`). No new tokens; `SparklineWidth = 96`, `SparklineHeight = 32`, `padY = 10 %`, stroke 2 pt round stay file-private.
- Every task: `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` green before commit; SwiftFormat/SwiftLint clean (file 500, type 300, function 60, params 6); `scripts/clean.sh` after adding a file to a path dependency; `project.yml` + regenerated `pbxproj` in the same commit. Ported test files = Kotlin file name + `Tests.swift`; case names = Kotlin backtick names in camelCase. Tab bar: a feature never writes `.toolbar(…, for: .tabBar)`.
- Executors report: test names verified against the Kotlin files, every divergence from the Kotlin twin listed, nothing "fixed while passing" outside the task's files. Parallel tasks run in their own worktrees on `m7-t<N>` branches and are rebased onto `m7-vitals-home` before review.

**Dependency graph:** T0 ∥ T1 ∥ T2 ∥ T3 ∥ T8 (independent, parallel) → T4 (needs T3) ∥ T5 (needs T3) → T6 (needs T5) → T7 (needs T4 + T6) ; T9 (needs T0 + T8) → T10 (needs T9) → T11 (needs T10 + T2) → T12 (needs T7 + T11) → T13.

---

### Task 0: Branch + `SalusCommon` chores (hoist + N-way latest)

**Files:** Modify `Packages/SalusCommon/Sources/SalusCommon/LatestOfBoth.swift` (fix the header: four callers, `mapped` copies were not byte-identical); create `Packages/SalusCommon/Sources/SalusCommon/LatestOfAll.swift`, `ThrowingStream.swift`; tests `Tests/SalusCommonTests/{LatestOfAllTests,ThrowingStreamTests}.swift`. Modify `Packages/Features/FeatureCycle/Sources/FeatureCycle/ui/calendar/CycleViewModel.swift:203-221` (delete the private copy, call the shared one).

**Produces:** `public func throwingStream<Value: Sendable>(over source: AsyncStream<Value>) -> AsyncThrowingStream<Value, any Error>` (byte-moved from `CycleViewModel`: `.bufferingNewest(1)`, forwarding `Task`, `finish()` on source end, `onTermination` cancels); `latestOfThree(_:_:_:) -> AsyncThrowingStream<(A, B, C), any Error>`, `latestOfFour`, `latestOfFive` — each a nesting of `latestOfBoth` + `mapped` that flattens the tuple, emitting only once every source has produced a value and under the same "emit under the lock" invariant `LatestOfBoth.swift` documents.

- [ ] `git checkout -b m7-vitals-home` from `main` (`4abb26d`). Commit this plan first: `docs(plan): iOS-M7 vitals completion + home dashboard plan`.
- [ ] Tests first: `throwingStream` forwards values in order and finishes when the source finishes, cancelling the consumer cancels the forwarder; `latestOfThree/Four/Five` emit nothing until every source has a value, then the latest tuple on each change, and propagate the first error.
- [ ] `scripts/test-packages.sh SalusCommon FeatureCycle` + build green. Commits: `refactor(common): hoist throwingStream(over:) from FeatureCycle`, `feat(common): latestOfThree/Four/Five over latestOfBoth`.

### Task 1: `no_calendar_outside_clock` lint rule + riding comment chores

**Files:** Modify `.swiftlint.yml` (custom rule after `no_tab_bar_toolbar_in_features`), `scripts/lint-custom-rules.sh` (a `check` block, same commit), `CLAUDE.md:113-117` (the rule is no longer "owed"); modify `Packages/SalusCommon/Tests/SalusCommonTests/LocalDateTimeInstantTests.swift:8` and `Packages/Features/FeatureSettings/Sources/FeatureSettings/ui/reminderhealth/ReminderHealthLastSync.swift:34` (stale "only `Calendar`" claims → "one of the three sanctioned"); hoist the triplicated `daysPerWeek = 7` (`FeatureCycle` + `SalusUI`) to `public static let daysPerWeek = 7` on `SalusModel.LocalDate`.

**Reference:** research-ios-state §1a — the five construction sites, the substring traps (`UNCalendarNotificationTrigger`, `CalendarEventDraft`, `CycleCalendarBuilder`, `addToCalendar`…), and the proposed YAML: regex `(\bCalendar\s*\(|\bCalendar\.current\b|(->|:)\s*Calendar\b)`, `excluded_match_kinds: [comment, doccomment, string]`, `severity: error`, `included: App/.*\.swift, Packages/.*\.swift`, `excluded:` the three production files + the two test files.

- [ ] Prove the shape with the fixture **before** trusting it: `check` plants a `Calendar(identifier: .gregorian)` line in `Packages/Features/FeatureVitals/…/LintFixtureDoNotCommit.swift` (must fire once) and asserts the three real sanctioned files stay quiet in the same repo-wide run. If `excluded:` is not honoured on a custom rule, fall back to `// swiftlint:disable:next no_calendar_outside_clock` at the five sites and say so in the rule's comment.
- [ ] `scripts/lint.sh` + `scripts/lint-custom-rules.sh` + `scripts/test-packages.sh SalusModel SalusUI FeatureCycle` green. Commits: `build(lint): no_calendar_outside_clock custom rule with its planted fixture`, `chore: LocalDate.daysPerWeek and the stale Calendar comments`.

### Task 2: `SalusUI` — `SalusSparkline`, the sub-1-base axis row, three pills → `SalusPillButton`

**Files:** Create `Packages/SalusUI/Sources/SalusUI/chart/SalusSparkline.swift`, `Tests/SalusUITests/SalusSparklineTests.swift`; modify `Tests/SalusUITests/ChartAxisScaleTests.swift` (+1); modify `Packages/Features/FeatureAppointments/Sources/FeatureAppointments/ui/detail/AppointmentDetailScreen.swift:225-261`, `Packages/Features/FeatureMedications/Sources/FeatureMedications/ui/detail/MedicationDetailSections.swift:269-299`, `Packages/SalusUI/Sources/SalusUI/component/SalusEmptyState.swift:87-100` (+ `.accessibilityHidden(true)` on its decorative symbol, M6 Task 8 finding), `SalusPillButton.swift:14-17` header (the three sites are migrated).

**Android reference:** `core/ui/.../chart/SalusSparkline.kt` — `values.count < 2` → draws nothing; `span = max(max − min, >0 ? : 1)`; `stepX = width / (count − 1)`; `padY = height × 0.1`; `y = padY + (1 − (v − min)/span) × (height − 2·padY)`; stroke 2 pt, round cap/join, `colorScheme.primary` default; no fill/markers.

**Produces:** `public struct SalusSparkline: View { init(values: [Float], lineColor: Color? = nil) }` (`Canvas` + `Path`; `nil` → `theme.colorScheme.primary`; `.accessibilityHidden(true)`, ruling 7) and the pure `enum SparklineGeometry { static func points(for values: [Float], in size: CGSize) -> [CGPoint] }` so the rules are table-testable.

- [ ] Table tests: `< 2` values → empty; flat series → all y at centre (`padY + 0.5·drawable`); ascending pair → first at bottom pad, last at top pad; x spacing even. `ChartAxisScaleTests`: positive sub-1 base — points `4.2…9.75` → upper `9.8`, `5.6/5.6` → `≈ 5.6` **with tolerance** (`5.600000000000001` is what `ceil(magnitude / 0.1) * 0.1` returns), lower `0`.
- [ ] Migrate the three pills: sites 1–2 pass `fillsWidth: true` (never an outer `.frame(maxWidth:)`, `SalusPillButton.swift:35-42`), `tonal: true` where the Kotlin twin is tonal, keep `.disabled(state.startEpochMs <= 0)` semantics via `enabled:`; site 3 is a straight substitution. Screenshot-diff by eye in the simulator previews.
- [ ] `scripts/test-packages.sh SalusUI FeatureAppointments FeatureMedications` + build green. Commits: `feat(ui): SalusSparkline — the dashboard trend line as a Path`, `test(ui): ChartAxisScale sub-1 base row (mmol/L)`, `refactor(ui): the three inline pills use SalusPillButton`.

### Task 3: Vitals domain + data — BP/glucose models, 8 repository members, mappers, preferences, two use cases

**Files:** Create `Packages/Features/FeatureVitals/Sources/FeatureVitals/domain/model/{BloodPressureEntry,GlucoseEntry}.swift`, `domain/repository/VitalsPreferences.swift`, `domain/usecase/{SaveBloodPressureEntryUseCase,SaveGlucoseEntryUseCase}.swift`, `data/{BloodPressureEntryMapper,GlucoseEntryMapper,VitalsPreferencesImpl}.swift`; modify `domain/repository/VitalsRepository.swift` (+8), `data/VitalsRepositoryImpl.swift` (+8). Tests: create `Tests/FeatureVitalsTests/{BloodPressureEntryMapperTests,GlucoseEntryMapperTests,SaveBloodPressureEntryUseCaseTests,SaveGlucoseEntryUseCaseTests,VitalsPreferencesImplTests,FakeVitalsPreferences}.swift`; modify `FakeVitalsRepository.swift` (+8 members, `setBloodPressureEntries`, `setGlucoseEntries`, `currentBloodPressure()`, `currentGlucose()`; pin insertion order — the M2 finding on dictionary order), `VitalsRepositoryImplTests.swift` (BP/glucose twins of the 9 weight cases).

**Android reference:** research-android-vitals §1, §3, §4. Models: `BloodPressureEntry(id, measuredAt: Date, timeZone, systolic: Double, diastolic: Double, pulse: Double?, note: String?)`, `GlucoseEntry(id, measuredAt, timeZone, mgDl: Double, measurementContext: MeasurementContext?, note)`. Constants `MIN/MAX_SYSTOLIC 60/250`, `MIN/MAX_DIASTOLIC 30/150`, `MIN/MAX_PULSE 20/250`, `MIN/MAX_MG_DL 20/600`. BP validation order: systolic → diastolic → pulse (only when present) → `systolic <= diastolic` → save; `id = existingId ?? idGenerator.newId()`, note trimmed, blank → nil. Glucose: convert `toMgDl(value, unit)` **first**, range-check the mg/dL value. Mappers: `BLOOD_PRESSURE_UNIT = "mmHg"`, `MISSING_DIASTOLIC = 0.0` (`valueSecondary ?? 0`), `GLUCOSE_STORAGE_UNIT = "mg/dL"`, unknown stored context → `nil` never throw, unknown `tz_id` → `IllegalTimeZoneError.unknownTimeZone` (the weight mapper's precedent). Repository: `observe…History` = `observeRange(type:)` mapped; `get…Entry` = `getById` filtered by type; `delete` = `deleteById` with no type clause; **no `observeLatestBloodPressure/Glucose`** (Android has none). `VitalsPreferencesImpl` = `dataSource.userSettings` → `glucoseUnit`, `distinctUntilChanged`; setter → `setGlucoseUnit`.

**Produces:** `protocol VitalsRepository` +8 under the Kotlin names (`observeBloodPressureHistory(from:until:)`, `getBloodPressureEntry(id:)`, `saveBloodPressureEntry(_:)`, `deleteBloodPressureEntry(id:)`, and the four glucose twins); `public protocol VitalsPreferences: Sendable { var glucoseUnit: AsyncStream<GlucoseUnit> { get }; func setGlucoseUnit(_ unit: GlucoseUnit) }`; `final class VitalsPreferencesImpl: VitalsPreferences { init(dataSource: SalusPreferencesDataSource) }`; `struct SaveBloodPressureEntryUseCase { init(repository:idGenerator:); enum Result: Equatable { saved(BloodPressureEntry), invalidSystolic, invalidDiastolic, invalidPulse, systolicNotAboveDiastolic }; func callAsFunction(existingId:systolic:diastolic:pulse:measuredAt:timeZone:note:) async throws -> Result }`; `struct SaveGlucoseEntryUseCase { enum Result { saved(GlucoseEntry), invalidValue }; callAsFunction(existingId:value:unit:measuredAt:timeZone:measurementContext:note:) }`; `FakeVitalsPreferences(initialUnit: .mgDl)` with `currentUnit()`.

- [ ] Port by name: mapper 4 + 3, use case 7 + 6 (+ one iOS-only `NaN is rejected` per use case, ruling 5), preferences (default `.mgDl`, setter writes through, equal consecutive units are dropped), repository twins over in-memory GRDB (BP row round-trip incl. nil pulse; glucose context; `get` of the wrong type is nil; delete by id).
- [ ] `scripts/test-packages.sh FeatureVitals` green. Commits: `feat(vitals): blood pressure and glucose entries, mappers and the eight repository members`, `feat(vitals): VitalsPreferences over glucose_unit and the two save use cases`.

### Task 4: `VitalsViewModel` completion + module/composition-root signature

**Files:** Modify `ui/list/VitalsViewModel.swift` (ctor gains `preferences:`; BP + glucose branches; `wholeYLabel`; delete arms), `VitalsModule.swift` (`makeVitalsModule(vitalsDao:preferences:clock:idGenerator:pendingDeletes:snackbar:navigator:)`, `makeVitalsViewModel` passes the preferences), `App/AppCompositionRoot.swift:358` (pass `infrastructure.preferences`); tests `VitalsViewModelTests.swift` (+2).

**Android reference:** `ui/list/VitalsViewModel.kt` (research-android-vitals §5): per type — weight (history + pendingIds), BP (history + pendingIds → `buildBloodPressureState`), glucose (history + **`preferences.glucoseUnit`** + pendingIds → `buildGlucoseState`). BP: `items` newest-first with `roundToInt` systolic/diastolic/pulse; `chart = chartOrNull(systolicPoints, wholeYLabel)` then attach `secondaryPoints = diastolicPoints` — the `MIN_CHART_POINTS = 2` gate applies to systolic only; `latestBloodPressure = items.first`. Glucose: `value = fromMgDl(mgDl, unit)` per row, `yLabel = unit == .mgDl ? wholeYLabel : decimalYLabel`, `glucoseUnit = unit`, no secondary. `confirmDelete` switches on `selectedType`, message `vitals_entry_deleted`. `wholeYLabel = { String(Int($0.rounded())) }`.

- [ ] Extend the `republish()` fold with `loadedUnit: GlucoseUnit?` and a third observation task for the glucose branch (the "return until every source has a value" rule the file documents). Port the 2 owed cases by name: `switchingToBloodPressureShowsItsEntriesWithATwoSeriesChart` (`["bp-new","bp-old"]`, latest 120/80, `points.count == 2`, `secondaryPoints.count == 2`, first y 130 / 85) and `glucoseEntriesAreDisplayedInThePreferredUnitWhileStorageStaysMgDl` (fake preference `.mmolL` **before** the VM exists; latest `108.0 / 18.0182` ±1e-9, `.fasting`, no secondary, repository still holds 108 mg/dL).
- [ ] `scripts/test-packages.sh FeatureVitals` + `scripts/build-app.sh` green. Commit `feat(vitals): VitalsViewModel takes VitalsPreferences and builds the blood pressure and glucose states`.

### Task 5: Blood pressure editor

**Files:** Create `ui/editor/{BloodPressureEditorUiState,BloodPressureEditorViewModel,BloodPressureEditorScreen}.swift`; modify `navigation/VitalsNavigation.swift` (`BloodPressureEditorKey(entryId: String?)` + `navigationDestination`), `VitalsModule.swift` (`makeSaveBloodPressureEntryUseCase`, `makeBloodPressureEditorViewModel: (String?) -> …`); test `Tests/FeatureVitalsTests/BloodPressureEditorViewModelTests.swift` (6).

**Android reference:** research-android-vitals §5–§6. State `(isNew, systolicText, diastolicText, pulseText, noteText, dateEpochDay: Int?, isSaving, error: BloodPressureError?, showDeleteConfirm)`, `enum BloodPressureError { invalidSystolic, invalidDiastolic, invalidPulse, systolicNotAboveDiastolic }`; events `systolicChanged, diastolicChanged, pulseChanged, noteChanged, dateSelected(epochDay), saveClicked, deleteClicked, deleteDismissed, deleteConfirmed`. New → `dateEpochDay = clock.todayEpochDay()`; edit → prefill `Int(rounded)` strings (pulse `""` when nil), `dateEpochDay` from the entry's own zone; typing a number clears `error`, typing the note does not; `toValueOrNull` = `replacingOccurrences(",", ".")` + `Double(_:)`; save → `resolveEditorMeasuredAt` (already ported), `timeZone = clock.timeZone()`, `.saved` → `navigator.pop()`, else set error + `isSaving = false`; delete → `undoableDelete(id, VitalsStrings.entryDeleted) { … }` then `pop()` immediately. Screen: title `bloodPressureNewTitle/EditTitle`, back `vitals_back`, trash only when `!isNew`; two number fields in a row (`"mmHg"` suffix, `.numberPad`), full-width pulse (`"bpm"`), one error `Text` in `colorScheme.error` (both systolic & diastolic red on `systolicNotAboveDiastolic`), `SalusDateField`, ≥2-line note, save enabled `!isSaving && !systolic.isBlank && !diastolic.isBlank`; `.salusDismissesKeyboardOnTap()` + `.scrollDismissesKeyboard(.interactively)`.

- [ ] Port the 6 cases by name; `BloodPressureEditorRoute(entryId:)` = template Route. `scripts/test-packages.sh FeatureVitals` + build green. Commit `feat(vitals): blood pressure editor — state, view model, screen, key`.

### Task 6: Glucose editor

**Files:** Create `ui/editor/{GlucoseEditorUiState,GlucoseEditorViewModel,GlucoseEditorScreen}.swift`; modify `navigation/VitalsNavigation.swift` (`GlucoseEditorKey`), `VitalsModule.swift` (`makeSaveGlucoseEntryUseCase`, `makeGlucoseEditorViewModel`); test `GlucoseEditorViewModelTests.swift` (6).

**Android reference:** ctor `(entryId, repository, saveGlucoseEntry, preferences, clock, navigator, undoableDelete)`. State `(isNew, valueText, unit: GlucoseUnit = .mgDl, measurementContext: MeasurementContext?, noteText, dateEpochDay, isSaving, showInvalidValue: Bool, showDeleteConfirm)` — a Bool, not an enum; events `valueChanged, unitSelected(GlucoseUnit), contextSelected(MeasurementContext?), noteChanged, dateSelected, saveClicked, deleteClicked, deleteDismissed, deleteConfirmed`. `init` is one task: first value of `preferences.glucoseUnit`, then defaults or load + `valueText = formatValue(fromMgDl(mgDl, unit), unit)`. `switchUnit`: equal → no-op; convert the typed text through mg/dL and reformat, unparseable text kept verbatim, clear `showInvalidValue`, **persist globally** (`preferences.setGlucoseUnit`). `formatValue` (`en_US_POSIX`, ruling 6): mg/dL integer when whole else `%.1f`; mmol/L always `%.1f`. Screen: one decimal field (`glucoseValueLabel`, suffix `unit.label` hardcoded `"mg/dL"`/`"mmol/L"`, supporting `invalidGlucose` while flagged), `.segmented` `Picker` over `GlucoseUnit.allCases` → `.unitSelected`, four `SalusFilterChip`s over `MeasurementContext.allCases` with deselect-on-retap, `SalusDateField`, note, save enabled `!isSaving && !valueText.isBlank`.

- [ ] Port the 6 cases by name (the unit-toggle case asserts the fake preference's `currentUnit()` changed). `scripts/test-packages.sh FeatureVitals` + build green. Commit `feat(vitals): glucose editor — unit toggle writes the app-wide preference`.

### Task 7: Vitals list wiring — FAB, three-way editor switch, screen split

**Files:** Modify `ui/list/VitalsScreen.swift:64-72` (`openEditor` three-way switch over `VitalType` → `WeightEditorKey`/`BloodPressureEditorKey`/`GlucoseEditorKey`), `:93-101` (drop the `selectedType == .weight` guard — D-M2-d closes), split rows/header/empty into `ui/list/VitalsListSections.swift` (ruling 10); remove the six `TODO(M7)` markers (research-ios-state §1e table).

- [ ] Build + `scripts/test-packages.sh FeatureVitals`; simulator smoke: Tansiyon tab → FAB → save 120/80/70 → row "120/80 mmHg" + "Nabız: 70 bpm" + two-series chart after a second entry; Kan şekeri → editor unit toggle to mmol/L → list shows "5,6 mmol/L"-style rows and the chart's `%.1f` axis; a pushed editor hides the tab bar. Commit `feat(vitals): FAB and editor routing for all three types; list sections split`.

### Task 8: `FeatureHome` package setup + strings

**Files:** Modify `Packages/Features/FeatureHome/Package.swift` (`defaultLocalization: "tr"`, `resources: [.process("Resources")]`); delete the M0 stub `FeatureHome.swift` + its test; create `Sources/FeatureHome/Resources/Localizable.xcstrings`, `Sources/FeatureHome/HomeStrings.swift`, `Tests/FeatureHomeTests/HomeStringsTests.swift`; modify `project.yml` (`packages:` + app target `dependencies:` + an M7 header paragraph) and regenerate `Salus.xcodeproj`.

**Android reference:** the 27 keys (ruling 1) in XML order: `home_greeting_{morning,afternoon,evening,night}`, `home_view_details`, `home_ai_summary_{title,description,free_credit}`, `today_doses_title`, `today_doses_empty`, `dose_status_{taken,snoozed,pending,missed}`, `today_appointments_{title,empty}`, `today_cycle_{title,empty,day (%1$lld),period_ongoing}`, `today_vitals_{title,empty,weight (%1$@),bp (%1$@/%2$@),glucose_mgdl (%1$@),glucose_mmol (%1$@)}`, `home_take_dose`. Copy TR/EN **from the XML files**.

**Produces:** `public enum HomeStrings` (one accessor per key; `greeting(_ g: HomeGreeting)`, `doseStatus(_ s: DoseStatus)`, `cycleDay(_:)`, `vitalsWeight(_:)`, `vitalsBloodPressure(_:_:)`, `vitalsGlucose(_ value: String, unit: GlucoseUnit)`), test-visible `Key` enum.

- [ ] `HomeStringsTests`: `assertSourceLanguage("tr")`, `assertKeys(of:are:)` with the literal 27-key set, `assertEveryKeyIsLocalized`, value table TR + EN; `BannedHealthClaims` repo-wide scan stays green. `scripts/test-packages.sh FeatureHome` + `scripts/build-app.sh` (the app now links the package). Commit `feat(home): package manifest, string catalog and typed HomeStrings (27 keys)`.

### Task 9: Home domain + data — `TodayModels`, `TodayRepository`, `TodayDoseAssembler`, `TodayRepositoryImpl`, availability/premium contracts

**Files:** Create `Sources/FeatureHome/domain/model/TodayModels.swift`, `domain/repository/{TodayRepository,HomeAiSummaryAvailability,HomePremiumStatus}.swift`, `data/{TodayDoseAssembler,TodayRepositoryImpl,AiUsageSummaryAvailability,FreeOnlyPremiumStatus}.swift`; tests `Tests/FeatureHomeTests/{TodayDoseAssemblerTests,TodayRepositoryImplTests,AiUsageSummaryAvailabilityTests}.swift`.

**Android reference:** research-android-home §2. Models verbatim: `enum DoseStatus { taken, snoozed, pending, missed }`, `TodayDose(scheduleId, medicationId, medicationName, minuteOfDay, doseAmount, status)`, `UpcomingAppointment(id, title, doctorName?, startsAtEpochMs: Int64, timeZoneId)`, `CycleSnapshot(cycleDay: Int?, isPeriodOpen, averageCycleLengthDays: Int?)`, `VitalsSnapshot(latestWeightKg?, weightTrend: [Float], latestSystolic?, latestDiastolic?, latestGlucoseMgdl?, glucoseUnit)`, `TodayOverview(doses, appointments, cycle, vitals)` (cycle/vitals non-optional). Constants `MAX_APPOINTMENTS = 3`, `MAX_MEANINGFUL_CYCLE_DAY = 60`, `MIN/MAX_CYCLE_LENGTH 21/45`, `WEIGHT_TREND_WINDOW = 30 d`, `GRACE_MINUTES = 60`. `observeTodayOverview()` captures `today`/`nowMinute`/`nowMs` **once, eagerly**, then `latestOfFour(doses, appointments, cycle, vitals)`. Doses = `latestOfThree(observeActive, observeAllActiveSchedules, observeIntakeLogsBetween(today, today))` → assembler. Assembler: index meds by id, logs by `(scheduleId, scheduledMinutes)`; drop when med missing / `today < start` / `end != nil && today > end` / recurrence unparsable / `RecurrenceRule.occursOn(...)` false; status precedence `TAKEN` log → `.taken`; `snoozedUntilEpochMs != nil && status == PENDING` → `.snoozed`; `nowMinute > time + 60` → `.missed` (strict); else `.pending`; sort `(minuteOfDay, medicationName)`. Appointments = `observeUpcoming(nowMs)` → `prefix(3)`. Cycle = `observePeriods` → latest by start; `cycleDay = today − start + 1` only when `today >= start && cycleDay <= 60`; `isPeriodOpen = latest?.endDateEpochDay == nil`; `averageCycleLength` = consecutive gaps in `21…45`, integer mean (truncating) or nil. Vitals = `latestOfFive(observeRange(WEIGHT, nowMs − 30 d, nowMs), observeLatest(WEIGHT), observeLatest(BP), observeLatest(GLUCOSE), throwingStream(over: preferences.userSettings))`; `weightTrend` = every row's `valuePrimary` as `Float`, no cap. `freeSummaryAvailable` = `aiUsage.usage` → `!freeSummaryUsed`, distinct.

**Produces:** `protocol TodayRepository: Sendable { func observeTodayOverview() -> AsyncThrowingStream<TodayOverview, any Error> }`; `struct TodayRepositoryImpl: TodayRepository { init(medicationDao:appointmentDao:cycleDao:vitalsDao:preferences: SalusPreferencesDataSource, clock:profileId:) }`; `enum TodayDoseAssembler { static let graceMinutes = 60; static func assemble(medications: [MedicationRecord], schedules: [MedicationScheduleRecord], logs: [MedicationIntakeLogRecord], today: Int, nowMinute: Int) -> [TodayDose] }` (internal — the only Home file besides the repository that sees records); `protocol HomeAiSummaryAvailability: Sendable { var freeSummaryAvailable: AsyncStream<Bool> { get } }`; `protocol HomePremiumStatus: Sendable { var isPremium: AsyncStream<Bool> { get } }`; `struct AiUsageSummaryAvailability(aiUsage: AiUsageDataSource)`; `struct FreeOnlyPremiumStatus` (emits `false` once, never finishes — ruling 1).

- [ ] Port `TodayDoseAssemblerTest` (5) by name with the `today = 20_000` fixture and the three record builders. iOS-only repository tests over in-memory `SalusDatabase`: cycle day 12 for a start 11 days ago, `nil` beyond 60 days, `isPeriodOpen`, average of `[28, 30]` = 29 and `nil` when only a 60-day gap; upcoming capped at 3; weight trend excludes a 31-day-old row; glucose unit follows the preference. Availability: `freeSummaryUsed` false → `true`, after `markFreeSummaryUsed()` → `false`.
- [ ] `scripts/test-packages.sh FeatureHome` green. Commits: `feat(home): today models, dose assembler and the repository contracts`, `feat(home): TodayRepositoryImpl over the four DAOs`.

### Task 10: `HomeViewModel`, `HomeUiState`, `HomeModule`, `HomeKey`

**Files:** Create `Sources/FeatureHome/ui/{HomeUiState,HomeViewModel}.swift`, `navigation/HomeNavigation.swift` (`public struct HomeKey: Hashable, Sendable { init() }` only — ruling 8), `HomeModule.swift`; tests `Tests/FeatureHomeTests/{HomeViewModelTests,FakeTodayRepository,RecordingDoseActions,WaitUntil}.swift`.

**Android reference:** `ui/HomeUiState.kt` verbatim (`enum HomeGreeting { morning, afternoon, evening, night }`, `HomeEvent.takeDose(scheduleId:minuteOfDay:)`, `HomeUiState(isLoading = true, todayEpochDay = 0, greeting = .morning, doses = [], appointments = [], cycle: CycleSnapshot?, vitals: VitalsSnapshot?, freeAiSummaryAvailable = false, isPremium = false)`); `ui/HomeViewModel.kt`: state = `latestOfThree(overview, freeSummaryAvailable, isPremium)`; `todayEpochDay = clock.todayEpochDay()`, `greeting = greetingFor(clock.minuteOfDayNow() / 60)` with buckets `5…11 morning, 12…17 afternoon, 18…22 evening, else night`; `takeDose` → `doseActions.markTaken(scheduleId:epochDay: clock.todayEpochDay(), minuteOfDay:)` (`try? await`, divergence (c)). `HomeViewModelTest.kt` (4): `FixedSalusClock(now: Date(timeIntervalSince1970: 1_760_000_000))`, overview with one "Aspirin" dose, `cycleDay 12`, `latestWeightKg 80.0`; the AI fake's `getSummary` asserting "Home must never request a summary" has no iOS surface (Home never sees `SalusAI`) — note it in the report.

**Produces:** `@MainActor @Observable public final class HomeViewModel { init(repository:aiSummaryAvailability:premiumStatus:clock:doseActions:); state; onEvent(_:); func restartObservation() }` (ruling 3: `restartObservation()` cancels and re-runs `observeTodayOverview()`; observation starts in `init`, `CancellationBox`, cancelled in `deinit`); `@MainActor public struct HomeModule { let makeHomeViewModel: @MainActor () -> HomeViewModel }`; `@MainActor public func makeHomeModule(medicationDao:appointmentDao:cycleDao:vitalsDao:preferences:aiUsage:clock:doseActions:profileId:) -> HomeModule`; `@Entry public var homeModule: HomeModule?`.

- [ ] Port the 4 cases by name (`stateMirrorsTheRepositoryOverview`, `repositoryUpdatesFlowThroughToTheState`, `takeDoseEventRoutesToTheSharedWritePathWithTodaysDate` → `[("sch-1", todayEpochDay, 480)]`, `aiCardFlagsFollowTheFreeCreditAndTheEntitlement` — fully portable with fakes for both protocols) + iOS-only: `restartObservation()` re-captures today after `clock.advanceTo` past midnight; greeting table for hours 5/11/12/17/18/22/23/0/4.
- [ ] `scripts/test-packages.sh FeatureHome` green. Commit `feat(home): HomeViewModel, module factory and HomeKey`.

### Task 11: `HomeScreen` + `HomeRoute`

**Files:** Create `Sources/FeatureHome/ui/{HomeScreen,HomeHeader,HomeDosesCard,HomeAppointmentsCard,HomeCycleCard,HomeVitalsCard,HomeFormatting}.swift` (≤ 500 lines each, functions ≤ 60).

**Android reference:** `ui/HomeScreen.kt` (research-android-home §1). `HomeRoute(onOpenMedications:onOpenAppointments:onOpenCycle:onOpenVitals:)` = template Route (module from environment, VM in `@State`, `.task { vm.restartObservation() }` — ruling 3). `HomeScreen(state, onEvent, callbacks)`: no scaffold/`NavigationStack`; `isLoading` → centred `ProgressView`; else `ScrollView { VStack }` in this order — **HomeHeader** (`primaryContainer` band, `padding(.horizontal, lg) .padding(.vertical, xl)`, full localized date `LocalDate(epochDay:).formatted(pattern: <the locale's full-date template>, locale:)` `headlineMedium` + greeting `bodyLarge`, both `onPrimaryContainer`); `SalusSectionHeader(title: todayDosesTitle)` + **DosesCard** (`SalusCard(onTap: onOpenMedications)`; empty → `EmptyLine(todayDosesEmpty)` = `bodyMedium` `onSurfaceVariant`; rows: `HH:mm` `labelLarge` in `medications.accent` · name `bodyMedium` · trailing `SalusPillButton(homeTakeDose, tonal: true, accent: .medications)` when `.pending` else `SalusStatusChip(label: doseStatus, status:)` with `taken→.success, snoozed→.warning, pending→.neutral, missed→.error`); `SalusSectionHeader` + **AppointmentsCard** (`onTap: onOpenAppointments`; per row `[title, doctorName].compactMap.joined(" · ")` `titleMedium` over the formatted start `bodyMedium` `onSurfaceVariant`; trailing `SalusPillButton(homeViewDetails, tonal: true)` aligned end); `SalusSectionHeader` + **CycleCard** (`onTap: onOpenCycle`; `cycleDay == nil` → `EmptyLine(todayCycleEmpty)`; else `todayCycleDay(n)` `titleMedium`, when `averageCycleLengthDays > 0` a `.linear` `ProgressView(value: min(max(day/len, 0), 1))` tinted `cycle.accent` over a `cycle.container` capsule track (divergence (i)), when `isPeriodOpen` `todayCyclePeriodOngoing` in `cycle.accent`); `SalusSectionHeader` + **VitalsCard** (`onTap: onOpenVitals`; nothing recorded → `EmptyLine(todayVitalsEmpty)`; weight row = `vitalsWeight(formatNumber(kg))` + `SalusSparkline(values: weightTrend, lineColor: vitals.accent).frame(width: 96, height: 32)` only when `count >= 2`; BP line only when both present (`formatNumber` each); glucose line in the preferred unit, `vitalsGlucose(formatNumber(value), unit:)`; later lines `padding(.top, xs)`); **no AI section** (ruling 1); `Spacer(sm)`. `formatMinutes(minutes, locale) = "%02d:%02d"`; `formatNumber(v)` = integer when whole else `%.1f` `en_US_POSIX` (ruling 6).

- [ ] Build the sections + `#Preview`s (loaded, loading, all-empty). `scripts/build-app.sh` + lint green (a screen never writes `.toolbar(…, for: .tabBar)`). Commit `feat(home): dashboard screen — header, doses, appointments, cycle and vitals cards`.

### Task 12: App wiring — composition root + Home stack

**Files:** Modify `App/AppCompositionRoot.swift` (`let homeModule: HomeModule` in the root and `FeatureModules`; built in `makeFeatureModules` **after** medications so `doseActions` exists: `makeHomeModule(medicationDao:appointmentDao:cycleDao:vitalsDao:preferences: infrastructure.preferences, aiUsage: infrastructure.aiUsage, clock:doseActions: medications.makeMarkDoseTakenUseCase(), profileId: SalusDatabase.defaultProfileId)`), `App/RootView.swift:221-231` (`HomeRoute(onOpenMedications: { backStacks.switchTopLevel(.medications) }, onOpenAppointments: { … .appointments }, onOpenCycle: { root.navigator.navigate(CycleKey()) }, onOpenVitals: { … .vitals })` as the stack root with `.cycleDestinations()` kept; `.environment(\.homeModule, root.homeModule)` **on the stack** beside `.environment(\.cycleModule, …)`), `App/RootTab.swift` doc comment; delete `App/PlaceholderScreen.swift`'s Home usage only if nothing else renders it (More still does — keep the file).

- [ ] Build + full `scripts/test-packages.sh`; simulator smoke: launch → greeting band with today's full date; add a medication with a dose today → row with "Al" → tap → chip "İçildi"; add an appointment → card row; More → Regl Takibi → start period → Home cycle card "Döngünün 1. günü" + "Dönem devam ediyor"; Home cycle card tap → calendar pushed, tab bar hidden, back returns; add ≥ 2 weights → sparkline; vitals card tap → Vitals tab. Commit `feat(app): mount the Home dashboard; bind DoseActions, AiUsage and the four DAOs into HomeModule`.

### Task 13: Acceptance sweep + execution record + manual QA + parity ledger

**Files:** Modify this plan (execution record: commits per task, review rounds, divergences (a)–(k) + any found, rulings 1–10 with the user's verdicts, deferred findings, Android follow-ups); create `scripts/m7-manual-qa.md` (§1 BP editor + two-series chart, §2 glucose editor + unit toggle persists across the list and Home, §3 Home cards incl. "Al" writes an intake log visible in Medications, §4 cycle card push + tab bar hidden, §5 device: nothing new — note that M6 §5 is still unrun); modify `docs/ios-feature-template.md` if a rule changed (`no_calendar_outside_clock` now mechanical; `latestOfN` + `throwingStream` in `SalusCommon`); Android docs-only commit on `salus-android/docs/parity-ledger.md`: `D-M7-a…k` rows, close `D-M2-a` and `D-M2-d`, `D-M6-f`'s lint half landed, roadmap rows `Vitals | iOS-M7 ✓` (all 49 + 2 cases) and `Home | iOS-M7 ✓` (9 cases), proposed follow-ups unnumbered (`A?`): BP/glucose NaN rejection (ruling 5), dead `home_title`/`home_settings` keys + dead `HomeScreen.kt` imports, `today_doses_empty` one edit from the banned stem, Home re-subscribe semantics (ruling 3), sparkline a11y.

- [ ] `scripts/ci.sh` end to end at the branch tip (5/5 green; paste the summary into the record). Whole-branch final review by the coordinator (Fable). Commit `docs(vitals,home): M7 execution record and manual QA script`; Android: `docs(parity): iOS-M7 vitals completion + home divergences and follow-ups`.

## Self-review notes (written at planning time)

- Spec coverage: BP ✓ (T3–T5, T7), glucose + mg/dL↔mmol/L ✓ (T3, T4, T6, T7), two-series chart ✓ (T4 — `SalusUI` already draws it), sparklines ✓ (T2, T11), Home aggregate card ✓ (T9–T12), 2 owed VM cases ✓ (T4), 32 owed Kotlin vitals cases ✓ (T3, T5, T6), 9 Home cases ✓ (T9, T10), sub-1 base row ✓ (T2), lint rule ✓ (T1), pills ✓ (T2), hoist ✓ (T0), dead-UNDO edge = ruling 2 (decision, no code).
- Type consistency: `VitalsPreferences.glucoseUnit` is `AsyncStream` everywhere (T3, T4, T6); `latestOfThree/Four/Five` (T0) are what T9/T10 call; `HomeViewModel.restartObservation()` (T10) is what T11's `.task` calls; `makeHomeModule` parameter list (T10) is what T12 passes.
- Open for the user: rulings 1–10 (esp. 1 — AI card absent vs placeholder; 2 — leave the dead-UNDO edge; 3 — re-subscribe on appearance).
- Not in scope: `SalusListItem`/`SalusPillTextField` (still unused), settings-hub unit toggle (Android has none), Trends' multi-series chart/legend (iOS-M11), `AiSummaryKey` (M10), premium entitlement (M9), the More row sex gate (M8).

---

## Execution record (2026-08-30)

Executed subagent-driven on branch `m7-vitals-home` off `main` at `4abb26d`: one Opus implementer
per task, an independent Opus reviewer per task, a scoped Sonnet re-review for each fix diff.
Parallelism was the default and the pre-flight scan (in the ledger) set the waves: **T0 ∥ T1 ∥ T2 ∥
T3 ∥ T8** first, then **T4 ∥ T5**, then T6 and T9/T10/T11 interleaved with them, each in its own
worktree on `m7-t<N>`, rebased onto the branch tip before review and fast-forward merged as its
review closed. **Twenty-eight commits** carry the plan and Tasks 0-12 (`a0dbfdb..b9b58b1`); this
record, `scripts/m7-manual-qa.md` and the template touch-ups are Task 13's.

**Eight of the thirteen tasks passed review first time** (T0 took a round for one test, T1, T4, T5,
T9, T10 and T11 each took exactly one). No task took two. Only one review raised an *Important*
finding: T11's — a pill nested inside `SalusCard(onTap:)`'s `Button` label, which the house pattern
already answered elsewhere.

**One rebase conflicted**, exactly where the pre-flight scan predicted it would: T6 and T4 both edit
`VitalsModule.swift`. The T6 implementer resolved it in its own worktree and the rebased head was
re-verified (93/93, build and lint green) before review.

**The plan was amended five times during execution** (each is a ruling below): the
`no_calendar_outside_clock` regex widened to `Calendar.autoupdatingCurrent`; the flat-sparkline
"centre" expectation was superseded by Kotlin's own arithmetic; divergence (i) became the platform
progress track; divergence (e) narrowed to re-capture timing only; and the Task 12/13 simulator
smoke lines were superseded by the user's decision that manual QA is the user's job.

Two session interruptions, neither of which is a fix round:

1. **2026-08-30 ~00:00 — the session rate limit** (reset 01:00 Istanbul) killed T7's implementer
   (after commit `2117dd5`, no report written, its smoke unknown) and T10's fix round (no changes
   made). The user resumed the session and both agents were resumed by message with their remaining
   steps.
2. **2026-08-30 — the Claude Code process restarted**, stopping T7 again (clean at `2117dd5`, still
   no report) and T11 (seven untracked `ui/` files, nothing committed). Both were resumed by
   message; nothing was lost and nothing was re-implemented.

### `scripts/ci.sh`, run end to end at the branch tip (`b9b58b1`)

```
# 1/5  toolchain    ==> Toolchain matches README.md.
# 2/5  lint         swiftformat --lint .  clean
                    Done linting! Found 0 violations, 0 serious in 469 files.
# 3/5  custom rules PASS  no_ui_framework_in_domain        fired in scope / quiet outside
                    PASS  no_charts_in_features            fired in scope / quiet outside
                    PASS  no_tab_bar_toolbar_in_features   fired in scope / quiet outside  (×2 spellings)
                    PASS  no_calendar_outside_clock        fired exactly 2 time(s) on the fixture
                    PASS  no_calendar_outside_clock        stayed quiet on all five carve-out files
                    ==> every custom rule fired in scope and stayed quiet outside it.
# 4/5  test         ==> summary: 24/24 packages passed          (895 tests)
# 5/5  build        ** BUILD SUCCEEDED **
==> CI pipeline passed.
```

`no_calendar_outside_clock` is new in this milestone (Task 1) and is why stage 3 now prints
fourteen lines rather than eight: it asserts an **exact hit count** on its planted fixture and
silence on each of the five carve-out files individually, because a custom rule's `excluded:` fails
as silently as its regex does.

**895 tests across 24 packages**, up from **785** at `main` (`4abb26d`). Only four packages moved;
the other twenty are untouched by M7 and were not re-measured.

| Package | Now | Was at `4abb26d` | What moved |
| --- | --- | --- | --- |
| `FeatureVitals` | 93 | 41 | +52: T3 +38 (mappers 5+4, use cases 8+7, `VitalsPreferencesImpl` 4, repository +10), T5 +6 (BP editor VM), T4 +2 (the two owed `VitalsViewModel` cases), T6 +6 (glucose editor VM), T7 +0 |
| `FeatureHome` | 37 | 1 (the M0 placeholder smoke test, replaced) | +36: T8 +6 strings, T9 +19 (`TodayDoseAssembler` 5, `TodayRepositoryImpl` 11, `AiUsageSummaryAvailability` 3), T10 +6 (`HomeViewModel`), T11 +5 (`HomeFormatting`) |
| `SalusCommon` | 37 | 25 | +12: `latestOfThree/Four/Five` 9, `throwingStream(over:)` 2, and the cancellation-propagation case the T0 fix round added |
| `SalusUI` | 78 | 68 | +10: `SalusSparkline` 9, the sub-1-base `ChartAxisScale` row 1 |

+110 is the sum of that column, and 785 + 110 = 895 closes.

### Acceptance evidence

iOS-M7's criterion is *blood pressure, glucose with mg/dL↔mmol/L, the two-series BP chart,
sparklines, and the Home aggregate card.*

**Vitals: 49 of 49 Kotlin cases across the nine `:feature:vitals` test files.** iOS-M2 ported 15
(weight); M7 closed the remaining **34** — the 32 the ledger recorded as owed plus the 2
`VitalsViewModelTest` cases. Every name was read out of the Swift file it lives in and matches the
Kotlin backtick name in camelCase.

| Kotlin table | iOS twin | Cases | Notes |
| --- | --- | --- | --- |
| `data/BloodPressureEntryMapperTest.kt` | `BloodPressureEntryMapperTests.swift` | 4 of 4 (+1 iOS-only) | `domain to entity maps type unit and value slots` · `entity to domain round trip preserves all fields` · `nil pulse survives the round trip` · `missing secondary value falls back to zero diastolic`. iOS-only: `an unresolvable stored time zone id throws` |
| `data/GlucoseEntryMapperTest.kt` | `GlucoseEntryMapperTests.swift` | 3 of 3 (+1 iOS-only) | `domain to entity stores canonical mg dL unit and context name` · `entity to domain round trip preserves all fields` · `nil context and unknown stored context map to nil`. iOS-only: the same tz case |
| `domain/usecase/SaveBloodPressureEntryUseCaseTest.kt` | `SaveBloodPressureEntryUseCaseTests.swift` | 7 of 7 (+1 iOS-only) | both boundary tables, `systolic must be strictly above diastolic`, the optional pulse, id generation and preservation. iOS-only: `NaN is rejected` (ruling 5) |
| `domain/usecase/SaveGlucoseEntryUseCaseTest.kt` | `SaveGlucoseEntryUseCaseTests.swift` | 6 of 6 (+1 iOS-only) | including `mmol L values are converted to canonical mg dL before validation` and `unit conversion round trip is lossless`. iOS-only: `NaN is rejected`, pinned in both units |
| `ui/editor/BloodPressureEditorViewModelTest.kt` | `BloodPressureEditorViewModelTests.swift` | 6 of 6 | `systolic not above diastolic maps to its own error and typing clears it` and `delete confirms first, then defers the write and closes` are the two that carry the milestone's behaviour |
| `ui/editor/GlucoseEditorViewModelTest.kt` | `GlucoseEditorViewModelTests.swift` | 6 of 6 | including `unit toggle converts the typed value and persists the preference` and `value typed in mmol L is stored canonically in mg dL` |
| `ui/list/VitalsViewModelTest.kt` | `VitalsViewModelTests.swift` | 7 of 7 (+1 iOS-only) | the **two owed**: `switching to blood pressure shows its entries with a two series chart` (`points`/`secondaryPoints` both 2, 130 and 85 first) and `glucose entries are displayed in the preferred unit while storage stays mg dL` |
| `ui/editor/WeightEditorViewModelTest.kt`, `domain/usecase/SaveWeightEntryUseCaseTest.kt` | unchanged from iOS-M2 | 4 + 6 | carried, not re-ported |

**Home: 9 of 9 Kotlin cases across the two `:feature:home` test files.**

| Kotlin table | iOS twin | Cases |
| --- | --- | --- |
| `data/TodayDoseAssemblerTest.kt` | `TodayDoseAssemblerTests.swift` | 5 of 5 |
| `ui/HomeViewModelTest.kt` | `HomeViewModelTests.swift` | 4 of 4 (+2 iOS-only: the restart's re-capture, and a deterministic dedup case) |

Kotlin's `HomeViewModelTest.kt:76-80` turns "Home must never request a summary" into a fake that
throws `AssertionError`; on iOS the method is not reachable at all — `HomeAiSummaryAvailability`
exposes availability and nothing else — so the contract is a type rather than an assertion.

The iOS-only tables, which have no Android twin and are an Android follow-up below:

| Criterion | Evidence | Where |
| --- | --- | --- |
| The app-wide glucose unit | defaults to `MG_DL`, reads the Android-verbatim `glucose_unit` key, the setter writes through, a live collector sees the change, equal consecutive units are dropped (Kotlin's `distinctUntilChanged`) | `VitalsPreferencesImplTests` (4) |
| The eight new repository members over a real database | BP and glucose observe/upsert/delete round trips, ordering, profile isolation, re-emission after a write | `VitalsRepositoryImplTests` (19 total, +10 in M7) |
| The dashboard's five-way join | the four DAOs plus the settings stream, dose assembly with the 60-minute grace, an unparsable recurrence, tie-breaking, and cancellation | `TodayRepositoryImplTests` (11) |
| The AI availability narrowing | free-credit availability deduplicates over the AI counter's own writes | `AiUsageSummaryAvailabilityTests` (3) |
| Home's formatting | `formatNumber`'s fixed-root locale vs `formatMinutes`' view locale, `%02lld`, the whole-number arm | `HomeFormattingTests` (5) |
| Home's strings | 27 keys, TR source + EN, both placeholder specifiers rendered, the two dead Android keys asserted **absent**, the banned-claims scan | `HomeStringsTests` (7) |
| The sparkline geometry | the flat-series bottom pad, the vertical padding, endpoints, single-point and empty inputs | `SalusSparklineTests` (9, `SalusUI`) |
| The sub-1 axis base | a mmol/L range that needs a 0.1 base | `ChartAxisScaleTests` (+1, `SalusUI`) |
| The N-way combinators | nothing until every source has a value, argument order, first error, and cancellation through every nested layer | `LatestOfAllTests` + `ThrowingStreamTests` (12, `SalusCommon`) |
| The `Calendar` guard | the rule fires exactly twice on a planted fixture and stays silent on all five carve-out files, in one repo-wide run | `scripts/lint-custom-rules.sh` |

**Manual, and what it does and does not prove.** Task 7 drove a real simulator through the macOS
accessibility API and captured **eleven screenshots**: the FAB on BP and glucose (closing `D-M2-d`),
both editors pushed with the tab bar gone, 120/80/70 saved and rendered, the same-day collapse, the
**two-series chart** across two days, the unit toggle converting 100 mg/dL → 5,6 mmol/L, and the
mmol/L rows with their `%.1f` axis. Task 12 captured **two**: the cold launch onto the real
dashboard (greeting band + four empty cards) and a medication added in `FeatureMedications`
appearing on Home **with no relaunch**.

It did **not** prove the "Al" write, the card-body-vs-pill distinction, the cycle or appointment
cards with data, the sparkline in any form, the cycle push from Home, or the migrated pills in
either theme — and did not claim to. Task 12's run stalled on the wheel time picker, which the
accessibility API cannot flick, so no `pending` dose was ever on screen. All of it is
`scripts/m7-manual-qa.md`, step by step, with the two traps written at the top of that file (set the
dose time later than "now"; the first medication save raises an AlarmKit sheet).

### Commits and review rounds per task

SHAs are the ones on `m7-vitals-home` after rebase, not the side-branch ones the reports quote.

| Task | Commits | Review |
| --- | --- | --- |
| — the plan itself | 1 — `a0dbfdb` | — |
| 8 — `FeatureHome` package + 27-key catalog | 1 — `4f141df` | Clean first time |
| 0 — `SalusCommon` chores | 3 — `1a313bf` (hoist `throwingStream`), `8a2e8e2` (`latestOfThree/Four/Five`), `4f803fd` (fix 1: cancellation through every layer) | Approved, 0 Important, 5 Minor; one Minor promoted to a fix round because it is load-bearing for ruling 3 |
| 1 — `no_calendar_outside_clock` | 3 — `c5f0c27` (rule + fixture), `67afd9b` (`LocalDate.daysPerWeek` + stale comments), `ad37c40` (fix 1: `autoupdatingCurrent` + the exact-count assertion) | Approved with 1 plan-mandated Important (the regex missed a spelling) → one round |
| 2 — `SalusSparkline`, axis row, pills | 4 — `c7d0ac7`, `21411d2`, `f5deaa1` (three pills), `b8d795f` (the fourth: the maps pill) | Approved, 0 Important, 3 Minor; the fourth pill accepted on merit |
| 3 — vitals domain + data | 2 — `84a3172` (models, mappers, 8 repository members), `ae916b1` (`VitalsPreferences` + the two use cases) | Approved, 0 Important, 6 Minor |
| 5 — blood pressure editor | 2 — `fa947b7`, `e71e712` (fix 1: persistent field captions) | Approved with 1 template-inherited Important → one round (ruling: the caption) |
| 4 — `VitalsViewModel` completion | 2 — `e2cd736`, `aa20756` (fix 1: state builders moved out) | Approved, 0 Important, 4 Minor; the split was ordered because the file sat at 499/500 and the type at 300/300 |
| 9 — Home domain + data | 3 — `990a7ae`, `6b43848`, `3e02bd8` (fix 1: deterministic dedup, pinned clock capture) | Approved, 0 Important, 3 Minor; two Minors promoted because they pin ruling 3 |
| 6 — glucose editor | 1 — `5de83c1` | Approved, 0 Important, 4 Minor. The one rebase conflict of the milestone (`VitalsModule.swift`, T4 overlap) was resolved and the rebased head re-verified before review |
| 10 — `HomeViewModel` + module | 2 — `7ab0d6b`, `51ad19e` (fix 1: cancel before re-subscribing, pin state across a restart, citations) | Approved, 0 Important, 4 Minor → one round |
| 11 — `HomeScreen` + `HomeRoute` | 2 — `03b9ecb`, `90b3ad4` (fix 1: sibling pills, platform progress track, formatting tests) | **Needs fixes** — 1 Important (pill nested in the card's `Button` label), 5 Minor → one round |
| 7 — vitals list wiring | 1 — `b28ee29` | Approved, 0 Important, 3 Minor. Carries the eleven-screenshot simulator smoke |
| 12 — app wiring | 1 — `b9b58b1` | Approved (in flight when Task 13 was dispatched); `DONE_WITH_CONCERNS` for the stopped smoke |
| 13 — this record, `scripts/m7-manual-qa.md`, the template, the ledger | 1 here + 1 in `salus-android` | — |

Integration was continuous: every task was rebased onto `m7-vitals-home` and fast-forward merged as
its review closed, so the branch was green at each of the thirteen points above.

### Rulings made during execution (decided on the user's behalf — read these)

In ledger order. Each says what it costs if it turns out to be wrong. The plan's own rulings 1-10
are in Global Constraints above and are **not** repeated here; all ten survived execution, and
ruling 10's split standard was applied a second time (T4's state builders).

1. **`HomeStrings` ships plain accessors; the enum-typed helpers come with the enums** (pre-flight).
   T8 must not define `HomeGreeting`/`DoseStatus`; T10 adds `greeting(_:)`/`doseStatus(_:)` **beside**
   the plain accessors in `HomeStrings+Enums.swift` when the enums exist. *Cost if wrong: one small
   file moves.*
2. **Reviewer models** (pre-flight): Opus for feature diffs, Sonnet for scoped re-reviews of small
   fix diffs, final whole-branch review by the coordinator — the M6 precedent. *Cost if wrong: a
   re-review at a higher model.*
3. **The `Calendar` regex is widened to `\bCalendar\.(current|autoupdatingCurrent)\b`** (T1 review),
   amending the plan's own regex. *Cost if wrong: none — it is strictly wider.*
4. **`NSCalendar` stays documented as a known limit, not matched** (T1 fix round) — the tree has no
   `NSCalendar` and Swift code has no reason to reach for one. *Cost if wrong: one `(NS)?` edit.*
5. **T0's missing cancellation test is fixed now, not deferred** (T0 review) — it is load-bearing
   for ruling 3, which re-subscribes on every appearance. *Cost if wrong: one extra test.*
6. **A flat sparkline sits at the bottom pad, not the centre** (T2). Kotlin's `span` fallback only
   avoids a divide-by-zero; every value equals the minimum, so `y = padY + drawableHeight`. The
   plan's "centre" wording is superseded. *Cost if wrong: none — Kotlin is the spec.*
7. **The fourth inline pill is migrated too** (T2). `OpenMapsButton` in the appointment detail is a
   fourth copy the brief did not list; it moved in its own commit, and **its drawn height grows** to
   the component's 48-pt floor. *Cost if wrong: revert one commit.*
8. **The pills' visual check is owed to manual QA**, not to a test (T2). *Cost if wrong: a visual
   regression nothing mechanical catches — hence `m7-manual-qa.md` §3.19.*
9. **The BP editor's number fields get a persistent caption above the field** (T5 review):
   `labelMedium`/`onSurfaceVariant`, error-tinted. SwiftUI's placeholder vanishes when filled and
   two adjacent mmHg fields then lose their identity. T6 copies the shape for glucose. *Cost if
   wrong: a caption row to remove.*
10. **`FeatureHome/Package.swift` keeps its `SalusAI` / `SalusPremium` dependencies** although
    ruling 1 leaves them unused (T9 review) — the manifest mirrors Android's `:feature:home` graph
    1:1 (spec §4), and M9/M10 rebind there. *Cost if wrong: two unused edges.*
11. **T9's two non-deterministic Minors are fixed now** (T9 review) — the dedup case and the eager
    clock capture both pin ruling 3's semantics. *Cost if wrong: two tests.*
12. **`VitalsViewModel`'s state builders move to `ui/list/VitalsStateBuilders.swift` immediately**
    (T4 review): the file sat at 499/500 lines and the type body at 300/300 — zero headroom on two
    `--strict`-fatal gates. A pure move. *Cost if wrong: one file move.*
13. **`isLoading` staying false across a restart is parity, not a divergence** (T10 review). Kotlin's
    `stateIn` + `WhileSubscribed` has `replayExpiration = MAX`, so the last state is replayed
    immediately. **Divergence (e) is narrowed to re-capture timing only.** *Cost if wrong: none — it
    is a documentation narrowing.*
14. **A card's pill is a sibling of `SalusCard(onTap:)`, for the doses card and the appointments
    card alike** (T11 review), and **divergence (i) is amended to the platform progress track**
    (tinted with the cycle accent, the `MedicationCard` precedent — one house answer instead of a
    hand-drawn `Capsule`). `HomeFormattingTests` was added in the same round. *Cost if wrong:
    layout-only.*
15. **`AppCompositionRoot+Modules.swift` is accepted** (T12): the root file was at 491/500 and the
    `+Reminder.swift` split is the precedent. The regenerated `pbxproj` from an unchanged
    `project.yml` is also accepted — XcodeGen globs `App/`. *Cost if wrong: one file merged back.*
16. **The Android parity-ledger commit is local only** (pre-flight, T13): a write outside this
    worktree is a stop-class side effect, so it is committed and never pushed — the established
    M4-M6 practice. *Cost if wrong: the user reverts one docs commit.*

And the user's own decision, which supersedes the plan's Task 12 and Task 13 smoke lines
(2026-08-30, recorded in the ledger): **simulator and device QA are the user's job.** Agents run
tests, lint and the build, and write `scripts/m<N>-manual-qa.md`; Task 12 stopped its smoke
mid-flight because of it.

### Recorded divergences from Android — `D-M7-a` … `D-M7-x`

The plan's letters (a)-(k) are merged with what the tasks actually recorded and renumbered cleanly;
each row says which plan letter it came from. All of these are rows in
`salus-android/docs/parity-ledger.md`.

| ID | From | Divergence |
| --- | --- | --- |
| `D-M7-a` | plan (a) | `VitalsPreferences.setGlucoseUnit` is synchronous and `glucoseUnit` a non-throwing `AsyncStream` (`UserDefaults` cannot fail the way DataStore can) — **but with** Kotlin's `distinctUntilChanged`, unlike the M6 `CycleReminderSettings` twin, because Kotlin has one here and not there |
| `D-M7-b` | plan (b), ruling 5 | NaN/non-finite input is **rejected** by both new save use cases; Kotlin's `x < MIN \|\| x > MAX` is false for NaN and stores it. One iOS-only case per use case. → Android follow-up (the `A11` twin) |
| `D-M7-c` | plan (c) | Repository write failures are swallowed into UI state — `catch { isSaving = false }` in both editors' `save()`, `try? await` on the delete arms and on `takeDose`. Kotlin lets the throw reach the coroutine handler. Neither platform tells the user; iOS-M2 divergence 8, kept for consistency |
| `D-M7-d` | plan (d), ruling 1 | `HomePremiumStatus` is bound to a `FreeOnlyPremiumStatus` that emits `false` **once and never finishes** (a placeholder that completed would change what "the dashboard's stream is still open" means). Pinned until iOS-M9; the test flips it `true`, so the Kotlin case is fully asserted |
| `D-M7-e` | plan (e), ruling 3, narrowed by ruling 13 | Home re-subscribes on **every appearance** (`HomeRoute`'s `.task` → `restartObservation()`), re-capturing `today` / `nowMinute` / `nowMs`; Android re-captures after `WhileSubscribed(5_000)`'s grace. **`isLoading` staying false across the restart is parity, not part of this row** |
| `D-M7-f` | plan (f), ruling 1 | The AI summary card and its section header are **absent**. `HomeUiState.freeAiSummaryAvailable` / `isPremium` are computed and carried but unread, so iOS-M10 changes only `sections`; there is no `onOpenAiSummary` anywhere |
| `D-M7-g` | plan (g), ruling 1 | The catalog holds **27 of Android's 29** home keys: `home_title` and `home_settings` are dead on Android since its M9 (the removed settings gear, whose `Icons.Outlined.Settings` / `IconButton` / `Icon` imports are still there) and are not ported. Pinned by `androidsDeadKeysAreAbsent` |
| `D-M7-h` | plan (h), ruling 7 | The sparkline is `.accessibilityHidden(true)` — the weight row already speaks its value and Compose gives the chart no `contentDescription` |
| `D-M7-i` | plan (i), **amended** by ruling 14 | The cycle progress bar is the **platform `ProgressView`** tinted with the cycle accent. The plan said a hand-drawn `Capsule` behind a `.linear` style; T11's review replaced it with the `MedicationCard` answer, so the whole tree has one |
| `D-M7-j` | plan (j) | `FakeNavigator` and `waitUntil` are copied into `FeatureHomeTests` rather than shared from a test module (template-sanctioned; Android has a shared one) |
| `D-M7-k` | plan (k) | Home's vitals card converts through `GlucoseConversion.fromMgDl`; Android inlines `/ MG_DL_PER_MMOL_L`. Same arithmetic, one implementation |
| `D-M7-l` | new (T5 review, ruling 9) | Every editor number field carries a **persistent caption above** the field. Material's `label` floats and stays; SwiftUI's placeholder vanishes when filled, which would leave two adjacent unlabelled mmHg fields |
| `D-M7-m` | new (T5) | `isError` is a stroked `RoundedRectangle(SalusShapes.extraSmall)` overlay in the error role — SwiftUI's `.roundedBorder` has no error state. It matters because `systolicNotAboveDiastolic` reddens **both** fields and the message is a single shared `Text` |
| `D-M7-n` | new (T6) | The glucose editor's four context chips use `ChipFlowLayout`; Kotlin's plain `Row` does not wrap and the Turkish labels do not fit one phone line. Selection semantics, deselect-on-retap included, are identical |
| `D-M7-o` | new (T6, T11) | Whole-number formatting is guarded: `Int(exactly:)` in the glucose editor's `formatValue` and `%.0f` in Home's `formatNumber`, where Kotlin's `toInt()` saturates. Swift's `Int(_:)` **traps**, and `1e20` is typeable. Same digits inside every accepted range |
| `D-M7-p` | new (T11 review, ruling 14) | A card's pill is a **sibling** of `SalusCard(onTap:)`, never nested in its `Button` label — SwiftUI swallows the inner tap and VoiceOver reads one element. Android nests (`MedicationsScreen.kt:218`, follow-up `A32`) |
| `D-M7-q` | new (T11) | The Home header is a `VStack`, not Android's `Row` + `weight(1f)`: the `Row`'s second child was the settings gear its M9 removed. Nothing was ported from the dead imports |
| `D-M7-r` | new (T11) | `appointmentStart` renders through `Date.FormatStyle` with an explicit locale **and** zone (`TimeZone(identifier:) ?? .current`, the `runCatching{}.getOrDefault` twin) but the autoupdating **calendar**; `fullDate` derives the FULL pattern from `DateFormatter.dateFormat(fromTemplate:)` because there is no style-without-a-`Date` API. Identical text for tr and en |
| `D-M7-s` | new (T9) | Home's `combine`s are `latestOfThree/Four/Five` + `mapped` (they take no transform, so the map is afterwards), `preferences.userSettings` joins them through `throwingStream(over:)`, and `TodayDoseAssembler` is its own file rather than an `internal object` at the bottom of the repository |
| `D-M7-t` | new (T9) | Home's two AI/premium dependencies are **feature-local protocols** (`HomeAiSummaryAvailability`, `HomePremiumStatus`), not Android's whole `AiSummaryRepository` / `PremiumRepository`. Kotlin's "never request a summary" `AssertionError` fake becomes unreachability, and `SalusAI`/premium stay out of Home's `domain/` |
| `D-M7-u` | new (T10) | `clock.today()` is read at **event** time, not inside the launched task. The difference shows only for a tap that crosses midnight, where the tap belongs to the day it happened on |
| `D-M7-v` | new (T2, ruling 7) | The fourth inline pill (`OpenMapsButton`, appointment detail) is now a `SalusPillButton`, so **its drawn height grows to 48 pt**. This closes `D-M6-d`'s "three inline sites still bypass it" |
| `D-M7-w` | new (T12, ruling 15) | The composition root is split: `App/AppCompositionRoot+Modules.swift` holds the module factories, `Infrastructure` loses `private` as a parameter of the sibling file. No Kotlin twin — `HomeModule.kt`'s `module { … }` is `makeHomeGraph` calling `makeHomeModule` |
| `D-M7-x` | new (grouped) | Mechanical and language rows, recorded once: `roundToInt()` → `Int(x.rounded())` (they differ only on negative halves); `ImmutableList`/`persistentListOf()` → Swift arrays; `sealed interface HomeEvent` → `enum`; `Recurrence.entries.firstOrNull { it.name == … }` → `Recurrence(rawValue:)`; `max(by:)` keeps the **last** maximal element where `maxByOrNull` keeps the first; `%1$d` → `%1$lld` and `%02d` → `%02lld`; `Form` instead of `Column` + `verticalScroll`, and no `onBack` (the stack owns the back button); `function_parameter_count` waived on both save use cases, `makeVitalsModule` and `makeHomeModule` (the `SaveAppointmentUseCase` precedent); `FakeVitalsRepository` is insertion-ordered and publishes outside its lock; `FakeVitalsPreferences` drops an equal set, as a Kotlin `MutableStateFlow` does |

### Deferred minors, verbatim from the ledger, grouped by task

None of these blocks the milestone; each is recorded so it is not rediscovered as a surprise.

**Task 0 — `SalusCommon`** · no early-finishing-source case · error arrival is positional, not
chronological (doc wording, `LatestOfAll.swift:12`) · `ThrowingStream.swift:17` does not mention
`LatestOfAll` · the bare public free-function names in `SalusCommon` grew from one (`mapped`) to
five.

**Task 1 — the lint rule** · `UNCalendarNotificationTrigger` in the decoy fixture is inert by
construction · the rule cannot see a `typealias`, a stored property or `NSCalendar` (ruling 4).

**Task 2 — `SalusUI`** · stale Kotlin citations in `AppointmentDetailScreen.swift:342` and `:362` ·
an inline `0.0001` literal in `theLineStaysInsideTheVerticalPadding` · `SparklineGeometry` shadows
`min`/`max` · observation: SwiftUI's `Canvas` clips the round caps at x=0/width where Compose does
not (sub-pixel, parity-irrelevant) · observation: `ChartAxisScale`'s upper bound for a max of
exactly 9.8 lands on 9.9 (`9.8/0.1 == 98.00000000000001`) — Vico's `Float` arithmetic has the same
artifact, treated as parity.

**Task 3 — vitals domain/data** · the repository suites are 5+5, not 9+9 twins (upsert-by-id,
re-emit-after-save and tz-throw-in-stream have no BP/glucose twin; the behaviour is covered
elsewhere, the disclosure was missing) · the fake's `mutate`/`stream` publish-outside-lock leaves a
stale-list window (inherited M6 shape — watch for `waitUntil` flakes; a monotonic version counter is
the fix if one appears) · `drain()`'s 200 yields are timing-dependent · `normalisedNote` is static in
one place and an instance member in another · one off-by-one Kotlin citation in
`GlucoseEntryMapperTests`.

**Task 4 — `VitalsViewModel`** · `VitalsModule.preferences` is exported but unread until T6 · the
state builders duplicate structure, which is Kotlin's own shape (kept deliberately).

**Task 5 — BP editor** · `.whitespaces` vs Kotlin's `isBlank()` on a newline · `Double(_:)` does not
trim where `toDoubleOrNull()` does (both inherited → ledger) · the `TODO(M7)` banner in
`VitalsModule.swift` was stale until T7 · two behaviours left unasserted (the entry zone's date, the
note keeping its error) — both Kotlin parity.

**Task 6 — glucose editor** · a third copy of the caption+field+error block and of `noteField`
across the three editors (a feature-private `editorField` is the refactor candidate) · strong `self`
bound before the first suspension in the editors' `init` tasks (house pattern) · `.whitespaces`
again.

**Task 7 — list wiring** · the previews are weight-only · they stayed in `VitalsScreen.swift` ·
**observation for the user**: the three editors draw the system background while the list draws
`colorScheme.background` — pre-existing since iOS-M2, and `m7-manual-qa.md` §4.4 asks for the
decision.

**Task 8 — Home strings** · `androidsDeadKeysAreAbsent`'s third assertion is self-referential
(`27 + 2 == 29`) · the report wrongly calls `today_vitals_bp` the first two-placeholder key
(Medications and Appointments already inline two) · `home_take_dose` is grouped with the doses
block rather than in XML order.

**Task 9 — Home data** · the fakes are split between their own files and the test file's tail.

**Task 10 — `HomeViewModel`** · same fake-placement split.

**Task 11 — `HomeScreen`** · `guard let module else { return }` never retries · the appointments
row's `.frame(maxWidth:alignment:)` was an unlisted divergence at review time (now inside
`D-M7-q`'s neighbourhood).

**Task 12 — app wiring** · the root's `doseActions` / `vitalsQuickEntry` properties now have no
`App/` consumer.

### Android follow-ups opened by this milestone

`salus-android/` is code-read-only for the whole of iOS-M7 — the only write is the parity-ledger
docs commit — so these are recorded here and in `docs/parity-ledger.md` as unnumbered `A?` rows for
the user to number into spec §11. **§11 has never been extended past `A13`; `A14`-`A33` are proposed
numbering and the nine iOS-M6 rows are still unnumbered. Re-check §11 before writing any of these
in.**

- **`SaveBloodPressureEntryUseCase` and `SaveGlucoseEntryUseCase` accept NaN** — the twin of `A11`
  for weight. `x < MIN || x > MAX` is false for NaN, and so is `systolic <= diastolic`, so Android
  stores a NaN reading. iOS rejects it (`D-M7-b`).
- **`home_title` and `home_settings` are dead keys, and `HomeScreen.kt:18-22` holds three dead
  imports** (`Icons.Outlined.Settings`, `IconButton`, `Icon`) — the leftovers of the settings gear
  Android's M9 removed. Delete them or restore the gear.
- **`today_doses_empty` is one edit away from a banned stem.** "Bugün için planlı doz yok." carries
  `planlı`, not the banned `planlan`, so it is legal today — but the string is one keystroke from
  failing the scan on both platforms. Consider rewording it on the Android side first.
- **Home's re-subscribe semantics differ by construction.** Android re-captures `today` /
  `nowMinute` / `nowMs` after `WhileSubscribed(5_000)`'s grace; iOS on every appearance
  (`D-M7-e`). Decide which is the contract — a dashboard that shows yesterday's date after a long
  background is the failure mode on Android.
- **The sparkline has no accessibility text on either platform.** Compose gives it no
  `contentDescription`; iOS hides it explicitly (`D-M7-h`). If the trend is meant to be information
  rather than decoration, both platforms owe it a label.
- **`DAYS_PER_WEEK` is declared twice on Android** — `CycleViewModel.kt:212` and
  `CycleScreen.kt:542`. iOS now has one `SalusModel.LocalDate.daysPerWeek` with three readers.
- **Editor label visibility is equivalent by different means.** Material's `label` floats and stays
  when the field is filled; SwiftUI's placeholder vanishes, so iOS added a persistent caption
  (`D-M7-l`). Recorded so the parity question is not re-asked — and so that an Android field that
  ever moves to a placeholder-only style inherits the same defect knowingly.
- **`formatValue` / `formatNumber` locale quirks are ported verbatim** (plan ruling 6): the glucose
  editor formats on `Locale.US` while its list formats on the view locale, and Home's `formatNumber`
  is `Locale.ROOT` while `formatMinutes` is the view locale. Two of the four are almost certainly
  accidents on Android. Decide, and both platforms change together.
- **The iOS-only M7 tables have no Android twin**: `VitalsPreferencesImpl` 4, the ten new
  `VitalsRepositoryImpl` cases, `TodayRepositoryImpl` 11, `AiUsageSummaryAvailability` 3,
  `HomeFormatting` 5, `HomeStrings` 7, `SalusSparkline` 9, the sub-1 axis row, and `SalusCommon`'s
  12 combinator cases.

### Done criterion for iOS-M7

**Blood pressure, glucose with mg/dL↔mmol/L, the two-series BP chart, sparklines, and the Home
aggregate card.**

| Half | State |
| --- | --- |
| Automated | **Met.** 49 of 49 Kotlin vitals cases (M7 closed 34 of them) and 9 of 9 Home cases, ported by name, plus the iOS-only tables above; `scripts/ci.sh` green end to end — 24/24 packages, **895 tests**, both lint gates and all four custom-rule checks, `** BUILD SUCCEEDED **`. |
| The chore backlog M6 carried here | **Met.** `no_calendar_outside_clock` ships with a fixture that asserts an exact hit count and five carve-out silences; the three (four) inline pills are migrated; `throwingStream(over:)` is hoisted; the sub-1-base axis row is pinned. |
| Banned claims | **Met.** No BP or glucose "normal range" hint exists; `vitals_invalid_glucose` and `today_doses_empty` are unchanged; the repo-wide scan is green over sources, comments and every catalog. |
| Manual, executed | **Partly, on a simulator.** Task 7: both editors, the two-series chart, the unit toggle and the mmol/L axis, eleven screenshots. Task 12: the cold-launch dashboard and a live dose row appearing from `FeatureMedications`, two screenshots. |
| Manual, **still owed on a simulator** | `scripts/m7-manual-qa.md` — the "Al" write and the intake log it produces (§3.6-§3.7), the card-body-vs-pill split, the appointment and cycle cards with data, the sparkline in every state (§3.14-§3.16), the cycle push from Home (§4), the delete/undo arms, the migrated pills in both themes (§3.19), and §6 TR/EN + Dynamic Type. |
| Manual, **still owed on a device** | **Nothing new in M7.** `scripts/m6-manual-qa.md` §5 (the cycle notification) and `scripts/m5-manual-qa.md` §5 remain the outstanding device passes. |

### Still owed, and by whom

- **`scripts/m7-manual-qa.md`, by the user** — the whole of it except the steps listed as observed.
- **The `--ff-only` merge and the push**, held for the user as in iOS-M3 through iOS-M6. The Android
  parity-ledger commit is local too, by ruling 16.
- **The Android follow-ups above**, numbered by the user into `docs/ios-v1-plan.md` §11 — the nine
  unnumbered iOS-M6 rows are still waiting there as well.
- **Two decisions the reviews deferred to the user**: the editors' system background vs the list's
  `colorScheme.background` (§4.4), and whether the maps pill's new 48-pt height is the look you want
  (§3.19).
