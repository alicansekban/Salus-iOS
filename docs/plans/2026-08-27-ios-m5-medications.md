# iOS-M5 — Medications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. Executor subagents run on **Opus** (user preference). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md`, `docs/ios-feature-template.md` (MANDATORY rules, follow to the letter) and the M3/M4 plans' execution records first. Independent tasks may run in parallel implementers (own worktree + side branch `m5-medications-tN`, rebased onto `m5-medications` before review). Branch: `m5-medications`.

**Goal:** `FeatureMedications` — the fourth feature package: medication CRUD with the schedule builder (list / detail / editor), `DoseOccurrenceGenerator` (8-case table), the per-medication reminder toggle (schema v4), a real `MedicationReminderHandler` whose doses present as **alarms** with Taken/Snooze actions that write intake logs from the background, stock chips, and the **recorded-dose share** on the list card — with the eight Android test files (53 cases) ported by name and green, and the M3a acceptance clause finally exercised (a dose rings as a full-screen AlarmKit alarm on iOS 26.1+, as a time-sensitive notification below, while an appointment stays a plain notification).

**Architecture:** Twin of Android `:feature:medications`. Persistence is mostly there (M1: three records, tables, indices); M5 adds GRDB migration `v4` (`medications.reminders_enabled`), `MedicationDao` in `SalusDatabase`, then the feature package exactly as the template lays it out: `domain/{model,repository,usecase}`, `data/`, `reminder/`, `ui/{list,detail,editor}`, `navigation/`, `MedicationsStrings`, `MedicationsModule`. The handler is the first with a non-empty `actions` array and the first with `presentation = .alarm`; `SalusReminder` grows the missing half of the alarm surface (stop + secondary buttons backed by `AppIntents`, a request-code action dispatcher). `AppCompositionRoot.init` is restructured first because it sits at the 60-line limit.

**Tech Stack:** Swift 6 / SwiftUI, GRDB (`SalusDatabase`), `SalusReminder` (M3 engine), AlarmKit + AppIntents (`LiveActivityIntent`, iOS 26.1+, app target), UserNotifications, swift-testing.

**Spec:** `salus-android/docs/ios-v1-plan.md` — §4 (module structure), §6.1 (window; doses are alarms — 2026-08-23 note), §7 (contracts; **banned claims**: `adher`, `complian`, `uyum`, `planlan`… — the ratio is "kaydedilen doz / recorded doses"), §8 (screens: `MedicationsScreen`, `MedicationDetailScreen`, `MedicationEditorScreen`; list rows open a detail), §11 A9 (reminders toggle = schema v4), iOS-M5 + iOS-M3a milestone entries. Kotlin sources named per task are the behavioural spec. Research inventory (scratchpad, 1 823 lines) was transcribed into this plan's "Android reference" blocks. **Do not modify anything under `salus-android/`** — Android follow-ups are recorded in Task 14 for the user to number and carry over.

## Global Constraints

- **Decisions (Alican, 2026-08-27):** (1) The list-card ratio is **renamed and re-based**: `recordedDosePercent` / `RecordedDoseRatio`, string key `medications_recorded_doses`, **denominator = recorded logs** in the 7-day window (`takenLogs / loggedLogs`, nearest whole percent — the `SummaryModels.kt:87-89` rule), not Android's generated-occurrence denominator; two Android follow-ups (name, denominator). (2) The AlarmKit alarm surface gets **real buttons via `AppIntents`** so a dose can be answered on iOS 26.1+ without opening the app. (3) A tapped dose notification/alarm **lands on the Medications tab root** (no detail push; `entityId` is a scheduleId) — Android parity, unlike M4's appointment detail push.
- **Decision (4) (Alican, 2026-08-27, read before Task 8):** AlarmKit's `Alert` has exactly two buttons — a mandatory stop button and one optional secondary. Stop = **"Kapat"** = `ReminderActionIds.dismiss` (handler no-op, then sync). Secondary = **the handler's first action** (`taken`, "Aldım", `secondaryButtonBehavior: .custom`). Stop must never be mapped to `taken` — an unattended stop would forge an intake record. Snooze is reachable only on the notification path and is a recorded divergence. No `alarmUpdates` observer: every way of ending an alert runs an intent, so the intents are the reaction hook.
- **Recorded iOS divergences (write into the execution record, not silently):** (a) ratio name + denominator (decision 1); (b) `medications_recorded_doses` replaces `medications_adherence` with new TR/EN copy — the only banned hit in 86×2 strings; (c) alarm surface = Kapat + Aldım, no Ertele, no body text (Android's `AlarmScreen` shows title+text and three buttons); (d) `saveMedication` runs in **one write transaction** (Android: three writes); (e) mapper enum fallback (`OTHER`/`DAILY`/`PENDING`) is **ported**, unlike M4 divergence (n) — it is a tested Kotlin behaviour; (f) `latestOfBoth` is duplicated into the feature (template-sanctioned), list VM follows `AppointmentsViewModel`'s shape (two streams + `pendingIds` via observation tracking + `confirmingId` as plain state); (g) mapper test names say `record` (M4 (m)); (h) `editor_back`/`editor_confirm`/`editor_cancel` are dead on iOS for structural reasons — ported for key-set parity; (i) dose tap → tab root (decision 3); (j) list card uses disjoint tap targets (no nested button — M4 (p)); (k) `MedicationDetailKey(id:)` / `MedicationEditorKey(id:)` — M4 spelling, Kotlin says `medicationId`; (l) `salus_alarm.caf` stays the placeholder; (m) `SalusStatus` tints come from `design-tokens.md` success/warning entries; (n) `AS_NEEDED` keeps its silent `timeOfDayMinutes = 0` schedule row, **no** ad-hoc logging UI is invented; (o) stock = two warning chips only, no notification/refill; (p) dismiss reaching `onAction` is a no-op (Kotlin `when` has no `else`).
- Local-time semantics: schedules store `(epochDay, minuteOfDay)`; every handler sync re-derives instants with `clock.timeZone()` **at call time** through `LocalDateTime.instant(in:)` (the only `Calendar` carve-out). Half-open trim `[from, until)` after whole-day generation.
- Occurrence identity: `ReminderRef(type: .medicationDose, entityId: scheduleId, occurrenceKey: DoseOccurrenceKey.encode(epochDay, minuteOfDay))`, key = `"\(epochDay)|\(minuteOfDay)"`. Request codes = the M3 Java-hash twin, unchanged.
- Domain purity: `domain/`, `data/`, `reminder/` import no SwiftUI/UIKit/UserNotifications/AlarmKit. AppIntents live in the **app target** (`App/Reminder/`), never in a package.
- Strings: **86 Android keys** (`feature/medications/src/main/res/values{,-en}/strings.xml`), 85 verbatim + `medications_recorded_doses`; TR source + EN; `%1$s`→`%1$@`, `%1$d`→`%1$lld`, `%%`→`%%`; typed `MedicationsStrings` over `Bundle.module`; `BannedHealthClaims` source + catalog scans stay green (repo-wide). Shared `SalusUIStrings.undo/.cancel/.delete`.
- Every task: `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` green before commit; SwiftFormat/SwiftLint clean (file 500, type 300, function 60, params 6 — split screens into section files as M4 did); `scripts/clean.sh` after adding a file to a path dependency; `project.yml` + regenerated `pbxproj` in the same commit. Ported test names = Kotlin backticked names, case for case; the four renamed names are listed in Task 10.
- Executors report: test names verified against files, every divergence from the Kotlin twin listed, nothing "fixed while passing" outside the task's files.

**Dependency graph:** T0 → {T1 → T2, T3 → T4, T8, T9} in parallel → T5 (needs T2+T4), T6 (needs T4), T7 (needs T4+T6) → T10 (needs T5+T6+T9) → T11 ∥ T12 → T13 (needs T7, T8, T11, T12) → T14.

---

### Task 0: Branch + `AppCompositionRoot.init` restructure (pure refactor)

**Files:** Modify `App/AppCompositionRoot.swift` (`init()` at :146, currently at the 60-line limit).

- [x] `git checkout -b m5-medications` from `main` (`43f53a4`).
- [x] Split `init()` into private static builders by concern — `makeInfrastructure(...)` (database, clock, id generator, profile), `makeFeatureModules(...)` (vitals, appointments, settings, later medications), `makeReminderGraph` (exists) — such that adding a module in Task 13 costs ≤ 5 lines in `init`. No behaviour change, no new types visible outside the file, `debugHandlers` untouched.
- [x] `scripts/build-app.sh` + `scripts/test-packages.sh` (all) green. Commit `refactor(app): split AppCompositionRoot.init into concern-sized builders`.

### Task 1: Schema v4 — `medications.reminders_enabled`

**Files:** Modify `Packages/SalusDatabase/Sources/SalusDatabase/Migrations.swift` (register `"v4"`), `Records/MedicationRecord.swift`, `Tests/SalusDatabaseTests/SampleRecords.swift`, `RoomSchemaParityTests.swift` (bump to 4), `MigrationTests.swift`. Create `Tests/SalusDatabaseTests/Resources/RoomSchemas/4.json` (copied byte-for-byte from `salus-android/core/database/schemas/com.alicansekban.salus.core.database.SalusDatabase/4.json`, identityHash `8635b2225d3d662cda9dfafecdd50e17`).

**Android reference:** `core/database/.../migration/Migrations.kt` `MIGRATION_3_4` = `ALTER TABLE medications ADD COLUMN reminders_enabled INTEGER NOT NULL DEFAULT 1`; `MedicationEntity.kt` field `remindersEnabled: Boolean = true`; `MigrationTest.kt` case `3 to 4 adds reminders_enabled and existing medications keep ringing` (a v3 row reads back `reminders_enabled = 1`).

**Produces:** `MedicationRecord.remindersEnabled: Bool` (CodingKey `reminders_enabled`, init parameter after `isActive`, default `true`).

- [x] Port the migration test by name (v3 database with one medication → migrate → column exists, value 1); parity test now checks versions 1…4 and the v4 `createSql` character for character.
- [x] Add the migration, the field, the fixture; `scripts/test-packages.sh SalusDatabase` green. Commit `feat(db): migration v4 adds medications.reminders_enabled (Android 3→4 parity)`.

### Task 2: `MedicationDao` in `SalusDatabase`

**Files:** Create `Packages/SalusDatabase/Sources/SalusDatabase/MedicationDao.swift`, `Tests/SalusDatabaseTests/MedicationDaoTests.swift`. Template: `AppointmentDao.swift` (struct over `DatabaseWriter`, Room SQL verbatim in doc comments with `MedicationDao.kt:line` citations, streams via `conflatedStream`).

**Android reference:** `core/database/.../dao/MedicationDao.kt` — 22 members, SQL in the inventory §4.1; load-bearing comments: insert is **ABORT** ("the unique (schedule, date, minutes) index is the idempotency key — a duplicate occurrence must surface as a constraint error"), `deactivateSchedulesExcept` ("deactivate instead of delete: the FK cascade would erase intake history"). `#19/#20` have no `ORDER BY`. `DaoSmokeTest.kt` case `duplicate intake log occurrence violates unique index`.

**Produces (`public struct MedicationDao: Sendable`, `init(database:)`):** `upsert(_: MedicationRecord)`, `upsertSchedules(_: [MedicationScheduleRecord])`, `getById(_:) -> MedicationRecord?`, `observeActive(profileId:) -> AsyncThrowingStream<[MedicationRecord], any Error>` (ORDER BY name), `observeById(_:) -> …<MedicationRecord?>`, `observeActiveSchedulesFor(medicationId:)`, `getActiveSchedulesFor(medicationId:)`, `getAllActiveSchedules(profileId:)` (the JOIN), `observeAllActiveSchedules(profileId:)`, `insertIntakeLog(_:)` (throws `DatabaseError` on the unique index), `updateIntakeLog(_:)`, `getIntakeLogById(_:)`, `observeIntakeLogsForDay(profileId:epochDay:)`, `getIntakeLogForOccurrence(scheduleId:epochDay:minutes:)`, `deleteById(_:)`, `getActive(profileId:)`, `getScheduleById(_:)`, `deactivateSchedulesExcept(medicationId:keepIds:)`, `observeIntakeLogsBetween(profileId:fromEpochDay:toEpochDay:)`, `getIntakeLogsBetween(…)`, `decrementStock(id:amount: Double)` (`MAX(0, …)`, `stock_count IS NOT NULL`), `setRemindersEnabled(id:enabled:updatedAtEpochMs:)`. **iOS-only:** `saveWithSchedules(_ medication: MedicationRecord, schedules: [MedicationScheduleRecord])` = upsert + upsertSchedules + deactivateSchedulesExcept(keepIds: schedules.map(\.id)) in **one** `database.write` (divergence (d)).

- [x] Tests: the Kotlin smoke case by name; iOS-only: each observe stream emits on write; JOIN excludes inactive medications and inactive schedules; `decrementStock` floors at 0 and no-ops on NULL; `deactivateSchedulesExcept` keeps history rows; `saveWithSchedules` is atomic (a failing schedule insert leaves no medication row); cascade delete removes schedules and logs.
- [x] `scripts/test-packages.sh SalusDatabase` green. Commit `feat(db): MedicationDao ported query-for-query from Room`.

### Task 3: Package setup + strings catalog (`MedicationsStrings`)

**Files:** Modify `Packages/Features/FeatureMedications/Package.swift` (`defaultLocalization: "tr"`, `resources: [.process("Resources")]`), `project.yml` (add `FeatureMedications` under `packages:` and the app target's products) + `xcodegen generate` (same commit). Create `Sources/FeatureMedications/Resources/Localizable.xcstrings`, `Sources/FeatureMedications/MedicationsStrings.swift`, `Tests/FeatureMedicationsTests/MedicationsStringsTests.swift`. Delete the placeholder `FeatureMedications.swift` / its test.

**Android reference:** 86 keys in `feature/medications/src/main/res/values{,-en}/strings.xml`, grouped: list 7 · editor 29 · forms 8 · recurrence 5 · weekdays 7 · notification 5 · detail 13 · intake status 4 · delete/undo 4 · reminder toggle 4. Format keys (10): `medications_low_stock`, `editor_start_date`, `editor_end_date`, `notification_dose_title`, `notification_dose_text` (two `%@`), `notification_dose_text_plain`, `medication_detail_dose_value`, `medication_delete_title` (`%1$@`); `recurrence_every_n_days` (`%1$lld`); **`medications_recorded_doses`** replaces `medications_adherence` (`Son 7 gün %%%1$d`) with TR `Son 7 gün kaydedilen doz %%%1$lld` / EN `Recorded doses, last 7 days: %1$lld%%`. Template: `AppointmentsStringsTests.swift` (exact key count, tr+en parity, format keys render, banned scan).

- [x] Tests first (count 86, parity, 10 format keys render the Android sentence, banned scan); typed accessors; `scripts/test-packages.sh FeatureMedications` + `scripts/build-app.sh` green. Commit `feat(medications): package setup and the 86-key strings catalog`.

### Task 4: Domain — models, generator, key codec, ratio, repository contract, formatting

**Files:** Create under `Sources/FeatureMedications/`: `domain/model/MedicationModels.swift`, `domain/DoseOccurrenceGenerator.swift`, `domain/DoseOccurrenceKey.swift`, `domain/RecordedDoseRatio.swift`, `domain/repository/MedicationRepository.swift`, `ui/MedicationFormatting.swift` (`formatAmount` — the **single** copy of the trim-".0" rule; `formatTime` `"%02d:%02d"`; `scheduleSummary(schedules:strings:locale:) -> String`). Tests: `DoseOccurrenceGeneratorTests.swift` (8, by name), `DoseOccurrenceKeyTests.swift` (iOS-only: encode/decode round trip, malformed → nil), `RecordedDoseRatioTests.swift` (iOS-only, 4 cases), `MedicationFormattingTests.swift` (amount trim, summary rules).

**Android reference:** `domain/model/MedicationModels.kt` (5 types, only default `remindersEnabled = true`, `isLowOnStock = stockCount <= stockThreshold` both non-nil); `domain/DoseOccurrenceGenerator.kt` (inverted range → empty; skip inactive medication; `medFrom = max(from, start)`, `medTo = end.map{min(to,$0)} ?? to`; skip `medFrom > medTo`; skip inactive schedule; inclusive day loop with `RecurrenceRule.occursOn`; stable sort by `(epochDay, minuteOfDay, scheduleId)`); `domain/DoseOccurrenceKey.kt`; `ui/MedicationFormatting.kt` (`scheduleSummary`: empty → `medications_no_schedule`; first is `AS_NEEDED` → `recurrence_as_needed`; else `"<label> · <times sorted, ", ">"`, `INTERVAL_DAYS` label uses `intervalDays ?? 1`); `MedicationRepository.kt` (14 members, doc comments ported). `AdherenceCalculator.kt` is **not** ported — replaced per decision (1).

**Produces:** `public struct Medication` (12 fields, `var isLowOnStock: Bool`), `MedicationSchedule` (9), `MedicationWithSchedules`, `DoseOccurrence` (Hashable), `IntakeLog` (10 fields, `Int64?` epoch ms); `enum DoseOccurrenceGenerator { static func occurrencesFor(medications:fromEpochDay:toEpochDay:) -> [DoseOccurrence]; static func occursOn(schedule:epochDay:) -> Bool }`; `enum DoseOccurrenceKey { static func encode(epochDay:minuteOfDay:) -> String; static func decode(_:) -> (epochDay: Int, minuteOfDay: Int)? }`; `enum RecordedDoseRatio { static func perMedication(logs: [IntakeLog], fromEpochDay:toEpochDay:) -> [String: Double] }` — per medication `taken / recorded` over logs whose `epochDay` is in the inclusive range; medications with zero recorded logs **absent**; `protocol MedicationRepository: Sendable` with the 14 members (`AsyncThrowingStream<_, any Error>` for the three observe streams, `async throws` elsewhere; `saveMedication(_:schedules:)`, `getLog(scheduleId:epochDay:minuteOfDay:)`, `upsertLog(_:)`, `decrementStock(medicationId:amount:)`, `setRemindersEnabled(medicationId:enabled:)`).

- [x] Tests first, then implementation; `scripts/test-packages.sh FeatureMedications` green. Commit `feat(medications): domain models, DoseOccurrenceGenerator (8 cases), key codec, recorded-dose ratio`.

### Task 5: Data — mapper, repository, `latestOfBoth`

**Files:** Create `data/MedicationMapper.swift`, `data/MedicationsRepositoryImpl.swift`, `data/LatestOfBoth.swift` (copy of FeatureAppointments' with its tests). Tests: `MedicationMapperTests.swift` (4, by name, `entity`→`record`), `MedicationsRepositoryImplTests.swift` (iOS-only, over a real in-memory `SalusDatabase`), `LatestOfBothTests.swift`.

**Android reference:** `data/MedicationMappers.kt` — enums stored as raw names, unknown → `OTHER`/`DAILY`/`PENDING` (tested: `unknown enum strings fall back to safe defaults`); `data/MedicationRepositoryImpl.kt` — `observeActiveMedications` = combine(`observeActive`, `observeAllActiveSchedules`) grouped by `medicationId`, DAO order preserved; `observeMedication` = combine(`observeById`, `observeActiveSchedulesFor`) → nil when gone; `saveMedication` reads `existing`, keeps `colorToken ?? "primary"`, `createdAt ?? now`, `updatedAt = now`, **`remindersEnabled = existing?.remindersEnabled ?? medication.remindersEnabled`** ("the toggle has one write path"); `upsertLog` reuses the stored row id for the `(schedule, day, minutes)` triple; `deleteMedication` = `deleteById` (cascade). Profile id = `SalusDatabase.DEFAULT_PROFILE_ID` twin as AppointmentsRepositoryImpl does.

**Produces:** `struct MedicationsRepositoryImpl: MedicationRepository { init(dao: MedicationDao, clock: any SalusClock, profileId: String) }` using `dao.saveWithSchedules` (divergence (d)).

- [x] Tests first; green; commit `feat(medications): mapper and GRDB-backed repository`.

### Task 6: Use cases — save, delete, mark taken, snooze

**Files:** Create `domain/usecase/SaveMedicationUseCase.swift`, `DeleteMedicationUseCase.swift`, `MarkDoseTakenUseCase.swift`, `SnoozeDoseUseCase.swift`; tests `SaveMedicationUseCaseTests.swift` (6), `IntakeActionUseCasesTests.swift` (6); `Tests/.../FakeMedicationRepository.swift`, `TestData.swift` (port `Fakes.kt`/`TestData.kt` shapes), a `FakeReminderScheduler` counting `requestSync()`.

**Android reference:** `SaveMedicationUseCase.kt` — order: blank name → `emptyName`; `end < start` → `endBeforeStart`; no active schedule → `noDoseTimes`; per active schedule first offender: `INTERVAL_DAYS` with `(intervalDays ?? 0) < 1` → `invalidInterval`, `DAYS_OF_WEEK` with mask 0 → `noDaysSelected`; save with **trimmed** name; `requestSync()`; `.success`. `MarkDoseTakenUseCase.kt` — `getLog` → if `.taken` return (idempotent); `getSchedule` nil → return silently; seed/copy log with `status = .taken`, `takenAtEpochMs = clock.nowEpochMilliseconds()`, `snoozedUntilEpochMs = nil`, `doseAmount = schedule.doseAmount` on seed, `id = idGenerator.newId()` on seed; `upsertLog`; `decrementStock(medicationId, log.doseAmount)`. `SnoozeDoseUseCase.kt` — `SNOOZE_DURATION = 10 min`; early return on `.taken` **or** `.skipped`; `status = .pending`, `snoozedUntilEpochMs = now + 600_000`; `upsertLog`; `requestSync()`. `DeleteMedicationUseCase.kt` — delete then `requestSync()`.

**Produces:** `SaveMedicationUseCase(repository:reminderScheduler:)` with `enum Result: Equatable { success, emptyName, noDoseTimes, invalidInterval, noDaysSelected, endBeforeStart }` and `callAsFunction(_:schedules:) async throws -> Result`; `DeleteMedicationUseCase(repository:reminderScheduler:).callAsFunction(id:)`; `struct MarkDoseTakenUseCase: DoseActions { init(repository:clock:idGenerator:) }` (the `SalusModel.DoseActions` conformance — Home consumes it in M7); `SnoozeDoseUseCase(repository:clock:idGenerator:reminderScheduler:)` with `static let snoozeDuration: TimeInterval = 600`, `callAsFunction(scheduleId:epochDay:minuteOfDay:)`.

- [x] Tests first (12 by name); green; commit `feat(medications): save/delete/taken/snooze use cases`.

### Task 7: `MedicationReminderHandler` + notification texts

**Files:** Create `reminder/MedicationNotificationTexts.swift` (protocol), `reminder/LocalizedMedicationNotificationTexts.swift` (`Bundle.module`), `reminder/MedicationReminderHandler.swift`; tests `MedicationReminderHandlerTests.swift` (9 by name + iOS-only: `dismiss is a no-op and leaves the log untouched`, `the first action is taken and the second is snooze`).

**Android reference:** `reminder/MedicationReminderHandler.kt` — `occurrencesBetween`: zone at call time; `fromDay/untilDay` = local dates of the instants; `getAllActiveMedications().filter(\.remindersEnabled)`; generator over `[fromDay, untilDay]`; `getLogsBetween` keyed by triple; drop `.taken`/`.skipped`; `trigger = log?.snoozedUntilEpochMs.map(Date.init(epochMilliseconds:)) ?? LocalDateTime(date: LocalDate(epochDay:), minuteOfDay:).instant(in: zone)`; keep `from <= trigger < until`; emit `(entityId: scheduleId, occurrenceKey, triggerAt)`. `notificationContent`: nil on decode failure / missing schedule / missing medication / `!isActive || !remindersEnabled` / log `.taken`/`.skipped`; `strength = [strengthValue.map(formatAmount), strengthUnit].compactMap.joined(" ")`; title `notification_dose_title(name)`; text `notification_dose_text_plain(amount)` when strength blank else `notification_dose_text(amount, strength)`; **`actions = [taken, snooze]` in that order** (the alarm surface shows the first); `presentation = .alarm` (doc comment ported verbatim). `onAction`: decode → `taken` → `markDoseTaken`, `snooze` → `snoozeDose`, else no-op. Template: `AppointmentReminderHandler.swift`.

**Produces:** `public struct MedicationReminderHandler: ReminderHandler { public static let actionTaken = "taken", actionSnooze = "snooze"; init(repository:markDoseTaken:snoozeDose:clock:texts:) }`, `type = .medicationDose`.

- [x] Tests first; green; commit `feat(medications): MedicationReminderHandler presents doses as alarms with taken/snooze`.

### Task 8: `SalusReminder` — the answerable alarm surface + action dispatcher

**Files:** Modify `Packages/SalusReminder/Sources/SalusReminder/platform/AlarmKitScheduling.swift` (header comment: the deferral is now paid), `platform/ReminderNotificationDelegate.swift` (delegate action path routes through the dispatcher; its tests stay green unchanged), `Package.swift` (`defaultLocalization: "tr"`, resources). Create `engine/ReminderActionDispatcher.swift`, `api/AlarmActionIntentProvider.swift`, `Resources/Localizable.xcstrings` (one key `alarm_dismiss`: TR `Kapat`, EN `Dismiss` — the twin of the label Android's `AlarmService.kt:87` appends), `ReminderStrings.swift`; tests `ReminderActionDispatcherTests.swift`, `ReminderStringsTests.swift`, a `UserNotificationGatewayRoutingTests` case proving a `.alarm` content with two actions registers both `UNNotificationAction`s (background options) on the fallback path.

**Android reference:** `AlarmScreen.kt:153` / `AlarmService.kt:87` (handler actions + DISMISS); `HandleReminderActionUseCase.kt` (`getByRequestCode` → `handler.onAction` → dismiss → `synchronizer.sync()`); `ReminderActionReceiver.kt` (works app-closed).

**Produces:**
- `public protocol AlarmActionIntentProvider: Sendable` (`#if canImport(AppIntents)`): `func stopIntent(requestCode: Int32) -> any LiveActivityIntent`, `func actionIntent(requestCode: Int32, actionId: String) -> any LiveActivityIntent`.
- `SystemAlarmKitScheduler.init(intents: any AlarmActionIntentProvider, dismissLabel: String)`; `schedule` builds `AlarmButton(text: dismissLabel, textColor: .white, systemImageName: "xmark")` as stop, `content.actions.first` → `AlarmButton(text: label, …, "checkmark")` as secondary with `secondaryButtonBehavior: .custom`, `AlarmManager.AlarmConfiguration.alarm(schedule: .fixed(triggerAt), attributes:, stopIntent:, secondaryIntent:, sound: .named(ReminderAlarmSound.fileName))`. Gate stays `@available(iOS 26.1, *)` unless the SDK accepts 26.0 with a stop button supplied — verify and record.
- `public struct ReminderActionDispatcher: Sendable { init(alarmDao: ReminderAlarmDao, registry: ReminderHandlerRegistry, synchronizer: any ReminderWindowSyncing); func perform(requestCode: Int32, actionId: String) async; func perform(ref: ReminderRef, actionId: String) async }` — ledger lookup (`getByRequestCode`, unknown code → sync only), handler `onAction` with errors swallowed and logged `.private`, **always** `synchronizer.sync()` afterwards.

- [x] Tests first (dispatcher: known code calls handler then syncs; unknown code syncs only; handler throw still syncs; dismiss reaches the handler as `ReminderActionIds.dismiss`); `scripts/test-packages.sh SalusReminder` + build green. Commit `feat(reminder): AlarmKit stop/secondary buttons via AppIntents provider and a request-code action dispatcher`.

### Task 9: `SalusUI` additions — status tints, icon badge, chip flow, chip icon

**Files:** Modify `Packages/SalusUI/Sources/SalusUI/component/SalusStatusChip.swift`; create `component/SalusStatus.swift`, `component/SalusIconBadge.swift`, `component/ChipFlowLayout.swift` (moved out of `FeatureAppointments/ui/detail/AppointmentDetailScreen.swift`, which now imports it); tests for the new views' models (`SalusStatusTests`: each status maps to a token; `ChipFlowLayoutTests` if the M4 private one had any).

**Android reference:** `core/ui/.../SalusStatusChip.kt` (`enum class SalusStatus { Success, Warning, Error, Neutral }`, `SalusStatusChip(text, status, icon)`), `SalusIconBadge.kt` (77 LOC: rounded square, accent-tinted 16 % fill, SF-symbol foreground). Tints: `salus-android/docs/design/design-tokens.md` success/warning entries (record the exact token names).

**Produces:** `public enum SalusStatus: Sendable { case success, warning, error, neutral }`; `SalusStatusChip(label:status:systemImage: String? = nil)` **added beside** the existing `(label:accent:)` init (M4 callers untouched); `SalusIconBadge(systemImage:accent:)`; `public struct ChipFlowLayout: Layout`.

- [x] `scripts/test-packages.sh SalusUI FeatureAppointments` + build green. Commit `feat(ui): SalusStatus tints, SalusIconBadge, shared ChipFlowLayout`.

### Task 10: Navigation, module factory, list screen

**Files:** Create `navigation/MedicationsNavigation.swift`, `MedicationsModule.swift`, `ui/list/MedicationsUiState.swift`, `ui/list/MedicationsViewModel.swift`, `ui/list/MedicationsScreen.swift` (+ `MedicationCard.swift` if the 500-line limit demands); tests `MedicationsViewModelTests.swift` (6), `FakeNavigator.swift`, `TestDeletes.swift`/`WaitUntil.swift` copies as M4.

**Android reference:** `ui/list/*.kt` — `MedicationsUiState(isLoading = true, medications = [], pendingDelete: Medication? = nil)`; `MedicationListItem(medication, schedules, recordedDosePercent: Int?)` (doc: taken/recorded over the last 7 days, 0…100; nil when nothing recorded yet); events `deleteRequested(id)`, `deleteDismissed`, `deleteConfirmed`; VM combines `observeActiveMedications` + `observeLogsBetween(today-6, today)` (`recordedDoseWindowDays = 7`), filters `pendingIds`, percent = `Int((ratio * 100).rounded())`; `undoableDelete(id, medication_deleted) { deleteMedication(id) }`. Screen: `SalusScreenHeader(medications_title)`, `SalusEmptyState(systemImage: "pills", …, actionLabel: medications_add)`, `SalusFab("plus")` → editor(nil), card = `SalusIconBadge(form symbol)` · name + `"<strength> <unit>"` · right column `medications_recorded_doses` label over `ProgressView(value:)` 72 pt · trash (disjoint target) · `scheduleSummary` · `SalusStatusChip(medication_reminders_off, .neutral, "bell.slash")` when silenced · `SalusStatusChip(medications_low_stock(formatAmount(stock)), .warning)` when low; confirm dialog `medication_delete_title(name)` / `medication_delete_message`. Form symbols: injection → `"syringe"`, syrup/drop → `"drop"`, else `"pills"`. **Renamed tests (decision 1):** `state carries medications with the recorded-dose share over the last seven days`, `medication without any recorded dose yet has nil share`; the other four by name.

**Produces:** `MedicationsKey`, `MedicationDetailKey(id:)`, `MedicationEditorKey(id: String?)`, `View.medicationsDestinations()`; `public struct MedicationsModule { repository, navigator, reminderHandler: any ReminderHandler, makeMarkDoseTakenUseCase: () -> MarkDoseTakenUseCase, makeMedicationsViewModel: @MainActor () -> MedicationsViewModel, makeMedicationDetailViewModel: @MainActor (String) -> MedicationDetailViewModel, makeMedicationEditorViewModel: @MainActor (String?) -> MedicationEditorViewModel }`; `public func makeMedicationsModule(medicationDao:reminderScheduler:clock:idGenerator:pendingDeletes:snackbar:navigator:) -> MedicationsModule`; `@Entry var medicationsModule: MedicationsModule?`; `MedicationsViewModel(repository:pendingDeletes:deleteMedication:undoableDelete:clock:)`.

- [x] Tests first; build green; commit `feat(medications): navigation, module factory, list screen`.

### Task 11: Detail screen + reminders toggle

**Files:** Create `ui/detail/MedicationDetailUiState.swift`, `MedicationDetailViewModel.swift`, `MedicationDetailScreen.swift`, `MedicationDetailSections.swift`; tests `MedicationDetailViewModelTests.swift` (8, by name).

**Android reference:** `ui/detail/*.kt` — state `(isLoading = true, medication: Medication?, schedules, history: [IntakeHistoryItem], showDeleteConfirm)`, `showSupply = medication?.stockCount != nil`; `IntakeHistoryItem(epochDay, minuteOfDay, status, doseAmount)`, `historyWindowDays = 30`, filtered to this medication, newest first `(epochDay desc, minuteOfDay desc)`; events `deleteClicked`, `deleteDismissed`, `deleteConfirmed` (close → undoable delete → `navigator.pop()`), `remindersToggled(Bool)` (**written immediately**: `setRemindersEnabled` then `requestSync()`); nil medication → `medication_detail_missing`. Sections in order: Header (badge, name, strength, silenced chip) · RemindersCard (`Toggle`, on/off descriptions) · Details (`medication_detail_when` = summary, `medication_detail_dose` = `medication_detail_dose_value(formatAmount)`, optional instructions) · Supply (only when `showSupply`; low-stock chip) · History (empty text; rows end in `SalusStatusChip(intake_status_*, status tint: taken→success, skipped→neutral, missed→error, pending→warning)`) · Actions (edit `.borderedProminent`, delete `.bordered`, capsule, full width). No dose-logging or stock-adjust affordance exists on Android — do not add one.

**Produces:** `MedicationDetailViewModel(medicationId:repository:deleteMedication:navigator:undoableDelete:reminderScheduler:clock:)`.

- [x] Tests first; build green; commit `feat(medications): detail screen with the per-medication reminder toggle`.

### Task 12: Editor screen — the schedule builder

**Files:** Create `ui/editor/MedicationEditorUiState.swift`, `MedicationEditorViewModel.swift`, `MedicationEditorScreen.swift`, `MedicationEditorSections.swift`, `DoseTimesSection.swift`; tests `MedicationEditorViewModelTests.swift` (6, by name).

**Android reference:** `ui/editor/*.kt` — 17-field state with defaults (`form = .tablet`, `recurrence = .daily`, `intervalDaysInput = "2"`, `doseTimes = []`, …); `DoseTimeUi(existingScheduleId: String?, minuteOfDay: Int, amountInput: String)`; `EditorError` 5 cases ↔ `editor_error_*`; 20 events; create-mode init `startDateEpochDay = today`, one `DoseTimeUi(nil, 480, "1")` (`defaultDoseMinutes = 480`); edit-mode `getMedication` nil → `pop()`, recurrence/mask/interval from `schedules.first`, dose rows sorted by minute with `formatAmount`; error cleared by `nameChanged`, `startDateSelected`, `endDateSelected`, `recurrenceSelected`, `dayOfWeekToggled`, `intervalDaysChanged`, `doseTimeAdded`, `doseTimeRemoved` **only**; `doseTimeAdded` appends then sorts (no dedupe); `save()`: `id = medicationId ?? newId()`, decimals parse `replacingOccurrences(",", ".")`, blank → nil, `isActive = true`, `remindersEnabled` left `true` (repository preserves); `buildSchedules`: `AS_NEEDED` → one row `(first ?? DoseTimeUi(nil, 0, "1"))` with `timeOfDayMinutes = 0`, else every row; `anchorDateEpochDay = startDateEpochDay`; `intervalDays = Int(intervalDaysInput)`; `doseAmount = parsed ?? 1.0`; `.success → pop()` else set error. Body order (12 items) in the inventory §7.3: error banner · name · `FormSelector` (`ChipFlowLayout` of 8 `SalusFilterChip`s) · strength value+unit row · instructions · stock count+threshold row · start `SalusDateField` + optional end (`editor_no_end_date`, clear button) · `editor_schedule_section` text · recurrence chips (4) · `DAYS_OF_WEEK` → 7 day chips / `INTERVAL_DAYS` → interval field · `if recurrence != .asNeeded` `DoseTimesSection` (`SalusTimeField` + `editor_dose_amount` + remove, add row) · spacer. Toolbar: `editor_title_new`/`_edit`, trash only when `!isNew`, save. No unsaved-changes guard.

**Produces:** `MedicationEditorViewModel(medicationId:repository:saveMedication:deleteMedication:clock:idGenerator:navigator:undoableDelete:)`.

- [x] Tests first; build green; commit `feat(medications): editor with the schedule builder`.

### Task 13: App wiring — composition root, tab, handler, intents, deep link

**Files:** Modify `App/AppCompositionRoot.swift` (module via the Task 0 builders; handlers `+ [appointmentsModule.reminderHandler, medicationsModule.reminderHandler]`; `var doseActions: any DoseActions { medicationsModule.makeMarkDoseTakenUseCase() }` beside `vitalsQuickEntry`; `SystemAlarmKitScheduler(intents: AppAlarmIntents(), dismissLabel: ReminderStrings.alarmDismiss)`; build the `ReminderActionDispatcher` and bind it into `AlarmActionBridge`; update the `:329-331` comment), `App/RootView.swift` (medications tab stack hosts `MedicationsScreen` + `medicationsDestinations()`; `openTappedReminder` `case .medicationDose:` → `switchTopLevel(.medications)` only, and guard the M4 appointment arm against pushing a detail already on top), `App/RootTab.swift` (symbol stays `"pills"`). Create `App/Reminder/DoseAlarmIntents.swift` (`ReminderAlarmStopIntent`, `ReminderAlarmActionIntent: LiveActivityIntent` with `@Parameter requestCode: Int` (+ `actionId: String`), `openAppWhenRun = false`, `perform()` awaits `AlarmActionBridge.shared.perform(requestCode:actionId:)`), `App/Reminder/AlarmActionBridge.swift` (actor; `bind(_ dispatcher:)`; calls made before binding **wait** for the bind — the app is launched to run the intent, so `SalusApp.init` binds before `perform` can be starved), `App/Reminder/AppAlarmIntents.swift` (`AlarmActionIntentProvider`). Debug: `DebugReminderHandler` unchanged.

- [x] `scripts/ci.sh` green end to end; simulator smoke: create a medication with a dose 2 minutes ahead → time-sensitive notification with **Aldım / Ertele** → tap Aldım with the app killed → `medication_intake_logs` row `TAKEN`, stock decremented, ledger row resolved, window refilled. Commit `feat(app): wire FeatureMedications, the medication handler and the AlarmKit intents`.

### Task 14: Acceptance sweep + execution record + manual QA script

- [x] `scripts/ci.sh` at the branch tip (record the test total; expected ≈ 545 + M5's ~110).
- [x] Write `scripts/m5-manual-qa.md`: §1 simulator CRUD round trip + undo both directions; §2 editor validation (5 errors) + `AS_NEEDED`; §3 reminder toggle silences the ledger; §4 fallback notification actions with the app killed (Aldım → TAKEN + stock; Ertele → `snoozed_until` + re-ring in 10 min); §5 **device, iOS 26.1+**: a dose rings as a full-screen AlarmKit alarm with **Kapat / Aldım**, Aldım writes the log with the app killed, Kapat leaves it pending, an appointment reminder stays a plain notification; §6 older simulator (no AlarmKit): time-sensitive path; §7 TR/EN + Dynamic Type on the chip rows.
- [x] Append the execution record to this plan (commits per task, review rounds, rulings, deferred findings, divergences (a)–(p) with evidence) and the **Android follow-ups** for the user to number after A16: (1) `:feature:medications` banned-claims violations (6 sites, 1 key×2, 4 test names); (2) list-card denominator vs `HealthPeriodStats.takenPercent`; (3) missing tests: `AdherenceCalculator`, `RecurrenceRule`, `DoseOccurrenceKey`, medications strings scan; (4) `ReminderType.SNOOZE` still on Android; (5) `IntakeStatus.SKIPPED/MISSED` have no writer; (6) three copies of the trim-".0" rule; (7) `saveMedication` not transactional; (8) `observeIntakeLogsBetween` unordered; (9) card nests an `IconButton` in a clickable card; (10) iOS-only test tables with no Android twin (A8-shaped).
- [x] Update the memory note for the next session; leave the `--ff-only` merge and push to the user after the device pass.

## Self-review notes (written at planning time)

- Spec coverage: schedule builder (T12), generator 8-case table (T4), actionable notifications from the background (T7+T8+T13), stock (T4/T10/T11/T12 chips + decrement), recorded-dose ratio without banned wording (T4/T10, decision 1), M3a acceptance (T14 §5/§6), A9 toggle (T1/T11). Home's today card, `TodayDoseAssembler`, trends ratio are out of scope by the milestone table.
- Type consistency: `MedicationDetailKey(id:)`, `MedicationEditorKey(id:)`, `MarkDoseTakenUseCase: DoseActions`, `ReminderActionDispatcher.perform(requestCode:actionId:)`, `AlarmActionIntentProvider` are spelled identically in T6/T7/T8/T10/T13.
- Risks: AlarmKit `AlarmConfiguration.alarm(...)` parameter labels must be verified against the Xcode 26.4 SDK in T8 (the plan's spelling comes from the M3 code + Apple's docs); `LiveActivityIntent.perform` running before `SalusApp.init` finishes is the reason the bridge waits instead of dropping.

## Execution record (2026-08-28)

Executed subagent-driven on branch `m5-medications` off `main` at `43f53a4`: one Opus implementer
per task, an independent Opus reviewer per task, a scoped re-review after a fix round. Parallelism
was the default rather than the exception — the pre-flight scan (in the ledger) cleared the whole
first wave (T1 → T2, T3 → T4, T8, T9), then T5 ∥ T6 and T11 ∥ T12, each in its own worktree on
`m5-medications-tN`, rebased onto the branch before review. **Thirteen of the fourteen tasks passed
review first time.** Only Task 12 took a fix round, and it was a lint fix (a 62-line function body
against a 60-line limit) that the *rebase* created, not a review finding. Task 0 was returned once as
`NEEDS_CONTEXT` before it started committing — a repo-policy question the implementer was right not
to answer alone (ruling 2). Eighteen commits carry the plan and Tasks 0-13 (`3ac8acc..f31a1c1`);
Task 14 adds this record and `scripts/m5-manual-qa.md`.

One session was lost to a usage limit, mid-flight: the Task 11 implementer died just after RED (its
tests written and uncommitted in the worktree) and Task 12's state was unknown at the time. Both were
re-dispatched after the reset and both finished from where they were. That is not a fix round and it
is not counted as one.

Nothing was added to the plan during execution. Two of its statements turned out to be wrong and were
overruled by rulings rather than followed: the repository's member count (ruling 4) and the history
chip's tint mapping (ruling 6). Both are recorded below.

### `scripts/ci.sh`, run end to end at the branch tip

```
# 1/5  toolchain    ==> Toolchain matches README.md.        (Xcode 26.4.1 / 17E202, SwiftLint 0.65.0, SwiftFormat 0.62.1)
# 2/5  lint         0/361 files require formatting, 13 files skipped.
                    Done linting! Found 0 violations, 0 serious in 361 files.
# 3/5  custom rules PASS  no_ui_framework_in_domain fired on Packages/SalusModel/…/LintFixtureDoNotCommit.swift
                    PASS  no_ui_framework_in_domain stayed quiet on Packages/SalusUI/…/LintFixtureDoNotCommit.swift
                    PASS  no_charts_in_features fired on Packages/Features/FeatureVitals/…/LintFixtureDoNotCommit.swift
                    PASS  no_charts_in_features stayed quiet on Packages/SalusUI/…/LintFixtureDoNotCommit.swift
                    ==> every custom rule fired in scope and stayed quiet outside it.
# 4/5  test         ==> summary: 24/24 packages passed          (675 tests)
# 5/5  build        ** BUILD SUCCEEDED **
==> CI pipeline passed.
```

**675 tests across 24 packages**, up from iOS-M4's 545. Where the 130 new ones live:

| Package | Now | Was | New cases |
| --- | --- | --- | --- |
| `FeatureMedications` | 89 | 1 (the placeholder smoke test, deleted in T3) | the whole feature: 8 generator + 4 mapper + 13 use-case + 11 handler + 6 list VM + 8 detail VM + 6 editor VM + 11 repository + 6 strings (86 parameterised) + 6 formatting + 4 ratio + 3 key codec + 3 `latestOfBoth` |
| `SalusDatabase` | 75 | 51 | `MedicationDaoTests` 17, `MedicationIntakeLogDaoTests` 5, plus the v4 migration case and the v4 parity/DDL cases |
| `SalusReminder` | 110 | 97 | `ReminderActionDispatcherTests` 7, `ReminderStringsTests` 5, and one added routing case |
| `SalusUI` | 64 | 59 | `SalusStatusTests` 5 |

The baselines are iOS-M4's record; only the totals were re-measured here. `FeatureMedications`
existed at `43f53a4` as a one-test placeholder package, which is why 89 new cases move the total by
88.

The Release build the acceptance asks for is green too, and silent:
`xcodebuild -project Salus.xcodeproj -scheme Salus -destination 'generic/platform=iOS Simulator'
-configuration Release build` → `** BUILD SUCCEEDED **`, **0 warnings**.

### Acceptance evidence

iOS-M5's criterion is *medication CRUD with the schedule builder, the per-medication reminder toggle
(schema v4), and a dose that presents as an **alarm** whose actions write an intake log from the
background* — plus the iOS-M3a clause: a dose rings as a full-screen AlarmKit alarm on iOS 26, as a
time-sensitive notification below it, while an appointment reminder stays a plain notification.

The plan's evidence contract was **eight Android test files, 53 cases**, ported by name. All 53 are
present and green, and the denominator held this time — unlike iOS-M4, no Kotlin file turned out to
carry cases the plan had not counted. Two further Kotlin cases outside those eight were ported as
well (the DAO smoke test's unique-index case and the 3→4 migration case), for **55 Kotlin cases in
total**. Every name below was read out of the Swift file it lives in.

| Kotlin table | iOS twin | Cases | Pointer |
| --- | --- | --- | --- |
| `domain/DoseOccurrenceGeneratorTest.kt` | `DoseOccurrenceGeneratorTests.swift` | 8 of 8 | The schedule builder's whole contract, in Kotlin order: **`DAILY produces one occurrence per day per schedule`**, **`DAYS_OF_WEEK respects the Monday-based bitmask`**, **`INTERVAL_DAYS counts from the anchor date`**, **`AS_NEEDED never generates occurrences`** (divergence (n)), **`nothing before the anchor or medication start date`**, **`medication end date cuts off occurrences`**, **`inactive medication or schedule generates nothing`**, **`output is sorted by day then minute`** |
| `data/MedicationMappersTest.kt` | `MedicationMapperTests.swift` | 4 of 4 | **`unknown enum strings fall back to safe defaults`** — the one place M5 keeps a fallback where M4's mapper throws, because Kotlin tests it (divergence (e)); the three round-trip cases carry divergence (g)'s `entity` → `record` rename |
| `domain/usecase/SaveMedicationUseCaseTest.kt` | `SaveMedicationUseCaseTests.swift` | 6 of 6 (+1 iOS-only) | The five editor errors as a contract, not a screen: **`blank name is rejected`**, **`no active dose times is rejected`**, **`interval below one is rejected`**, **`days-of-week without any day is rejected`**, **`end date before start date is rejected`**, over **`valid medication saves and requests a reminder sync`**. The seventh, **`the saved name is trimmed`**, has no Kotlin twin and is in the brief's own contract |
| `domain/usecase/IntakeActionUseCasesTest.kt` | `IntakeActionUseCasesTests.swift` | 6 of 6 | The *actions write a log from the background* half at its source: **`taken creates a TAKEN log and decrements stock by the dose amount`**, **`taken is idempotent - no double stock decrement`**, **`snooze stores snoozed_until ten minutes ahead and requests a sync`**, **`snooze after taken is a no-op`**, **`taken after snooze clears the snooze and marks taken`**, **`unknown schedule is ignored`** |
| `reminder/MedicationReminderHandlerTest.kt` | `MedicationReminderHandlerTests.swift` | 9 of 9 (+2 iOS-only) | The alarm clause: **`a dose is presented as an alarm, not a notification`** and **`a snoozed dose is still presented as an alarm`** — `presentation == .alarm`, which is what routes the occurrence to AlarmKit. The A9 toggle: **`a silenced medication contributes no occurrences while its sibling still does`** and **`a re-enabled medication rings again`**. Plus **`snoozed dose is re-emitted with the snooze instant as trigger`** (same occurrence key, new trigger), **`taken doses are not emitted again`**, **`notification content includes name and both actions`**, **`notification content is null for a deleted medication or taken dose`**, **`emits dose occurrences with local-time triggers in the current zone`**. The two iOS-only cases are **`dismiss is a no-op and leaves the log untouched`** (divergence (p)) and **`the first action is taken and the second is snooze`** — the ordering decision 4 depends on |
| `ui/list/MedicationsViewModelTest.kt` | `MedicationsViewModelTests.swift` | 6 of 6 | **`state carries medications with the recorded-dose share over the last seven days`** and **`medication without any recorded dose yet has nil share`** — the two renamed names (decision 1; the Kotlin names are not repeated here because they carry a banned stem). The CRUD-from-the-list flow: **`delete request asks for confirmation and dismissing it deletes nothing`**, **`confirmed delete hides the row at once and writes when the undo window closes`**, **`undo within the window brings the row back without a write`**, **`empty repository yields empty non-loading state`** |
| `ui/detail/MedicationDetailViewModelTest.kt` | `MedicationDetailViewModelTests.swift` | 8 of 8 | The toggle's own case, **`toggling reminders writes immediately and requests a sync`** — schema v4's reason to exist, spec §11 A9. Plus **`state carries the medication, its schedules and supply visibility`**, **`supply is hidden when stock tracking is off`**, **`history holds only this medication's logs, newest first`**, **`delete asks before it does anything`**, **`confirming defers the write, closes the screen and offers undo`**, **`undo cancels the deletion the popped screen started`**, **`a medication that no longer exists leaves the screen with nothing to show`** |
| `ui/editor/MedicationEditorViewModelTest.kt` | `MedicationEditorViewModelTests.swift` | 6 of 6 | The schedule builder from the editor: **`new medication starts with today and one default dose time`**, **`existing medication loads fields and schedule rows`**, **`save with valid input persists and closes`**, **`save with blank name surfaces the error and does not close`**, **`days-of-week without a selected day surfaces the error`**, **`delete confirms first, then defers the write and closes`** |
| `core/database/DaoSmokeTest.kt` | `MedicationDaoTests.swift` | 1 | **`duplicate intake log occurrence violates unique index`** — the idempotency key that makes "taken twice" impossible at the storage layer, not only at the use case |
| `core/database/MigrationTest.kt` | `MigrationTests.swift` | 1 | **`3 to 4 adds reminders_enabled and existing medications keep ringing`** — a v3 row reads back with the column set to 1 |

**53 of 53 across the eight contracted files, 55 Kotlin cases in all.** Nothing in them is unported.

The iOS-only rows, which have no Kotlin twin and are Android follow-up 10 below:

| Criterion | Evidence | Where |
| --- | --- | --- |
| **CRUD — the storage half** | `observeActive` orders by name and skips inactive rows and other profiles; `observeById` emits the row, its update and `nil` after delete; **`deleteById` cascades to schedules *and* their intake logs**; `setRemindersEnabled` writes the flag *and* `updated_at` and leaves `name` alone; `decrementStock` floors at 0 and no-ops on a NULL stock; `deactivateSchedulesExcept` keeps the intake row of the schedule it deactivated (history survives) and handles an **empty** `keepIds`; `saveWithSchedules` replaces the active set and is **atomic** — an FK-violating schedule leaves no medication row (divergence (d)) | `MedicationDaoTests` (17 cases, `SalusDatabase`) |
| **CRUD — the log half** | day-query ordering + re-emission; the range queries inclusive at both bounds with another profile excluded, asserted as **sets** because the SQL promises no order; occurrence lookup; `updateIntakeLog`; `getIntakeLogById` nil | `MedicationIntakeLogDaoTests` (5 cases) |
| **Schema v4** | **`the v4 DDL is the v3 DDL plus exactly one column`** — 4.json held beside 3.json character for character, `medications` differing by exactly `` `reminders_enabled` INTEGER NOT NULL DEFAULT 1, ``; the parity suite now runs `arguments: [1, 2, 3, 4]`; `SampleRecords.medication` sets `remindersEnabled: false` deliberately, so a record that forgot to write the column could not pass by matching `DEFAULT 1` | `RoomSchemaParityTests`, `MigrationTests` |
| **The repository over a real database** | 11 cases on `SalusDatabase.inMemory` with the real `MedicationDao`: the save's single transaction, the schedule-set replacement, the observe streams settling after a write | `MedicationsRepositoryImplTests` |
| **The recorded-dose share** | fraction per medication · **zero recorded doses ⇒ absent, never 0 %** · window bounds inclusive · a non-taken status counts in the denominator only. Decision 1's denominator, pinned | `RecordedDoseRatioTests` (4 cases) |
| **The occurrence key** | encode shape, round trip, malformed → `nil`; `decode` passes `omittingEmptySubsequences: false` so `"20514\|"` is rejected by the count check rather than by accident | `DoseOccurrenceKeyTests` (3 cases) |
| **Formatting** | amount trim including the **past-`Int.max` guard** (divergence: `Int(exactly:)`), time padding, empty list, as-needed short-circuit, label+times composition, interval fallback to 1 | `MedicationFormattingTests` (6 cases) |
| **Two streams, one state** | **`nothing is emitted until both sides have a value`**, **`a slow transform never overwrites a fresher pair`**, **`a failure on either side fails the combined stream`** — `latestOfBoth`, duplicated per divergence (f) and re-tested here rather than trusted | `LatestOfBothTests` (3 cases) |
| **The action dispatcher** | a known request code calls the handler and **then** syncs; an **unknown** code syncs anyway (divergence: Kotlin returns early); a throwing handler **still** syncs; the alarm's stop button reaches the handler as `ReminderActionIds.dismiss` | `ReminderActionDispatcherTests` (7 cases, `SalusReminder`) |
| **The alarm surface's copy** | `alarm_dismiss` exists in both languages, is the string the stop button is built from, and names nothing banned | `ReminderStringsTests` (5 cases) |
| **Status tints** | success ⇒ `extendedColors.success`, warning ⇒ `extendedColors.warning`, error ⇒ `colorScheme.error`, neutral ⇒ `colorScheme.onSurfaceVariant`, and the four are four distinct colours in **both** themes — each asserted against the theme's own token property, never a hex literal | `SalusStatusTests` (5 cases, `SalusUI`) |
| **Strings** | 86 keys, TR source + EN, an `@Test(arguments:)` table of all 86 in both languages, every accessor asking for a carried key, the ten format keys rendering the Android sentence in both languages plus a specifier check on **both** languages of every format key, and `BannedHealthClaims` repo-wide. End-to-end, past what `swift test` can see: the built `Salus.app` carries `FeatureMedications_FeatureMedications.bundle` with `tr.lproj`/`en.lproj`, and `plutil -extract medications_recorded_doses` returns the two sentences | `MedicationsStringsTests` (6 cases, 86 parameterised) |

**Manual, and what it does and does not prove.** Task 13 ran a real simulator smoke with `CGEvent`
taps against the Simulator window — not a code-path shortcut: the app launches with the Medications
tab wired, the empty state renders, and **İlaç ekle** pushes the editor, which proves
`medicationsDestinations()` resolves a pushed `MedicationEditorKey` *and* that
`.environment(\.medicationsModule, …)` applied to the stack reaches a pushed destination. It did
**not** run the notification-action smoke and did not claim to. Everything the dose path still owes
is written down as `scripts/m5-manual-qa.md` §4 (the fallback notification actions with the app
killed) and §5 (the device pass), and §5 is the iOS-M3a clause that has been owed since iOS-M3.

### Commits and review rounds per task

SHAs are the ones on `m5-medications` after rebase, not the side-branch ones the reports quote.

| Task | Commits | Review |
| --- | --- | --- |
| — the plan itself | 2 — `3ac8acc`, `2608e7d` (decision 4) | — |
| 0 — `AppCompositionRoot.init` restructure | 1 — `f4033f8` | Clean first time (one `NEEDS_CONTEXT` before committing — ruling 2) |
| 9 — `SalusUI` status tints, icon badge, chip flow | 1 — `6f4ae83` | Clean first time (ruling 3) |
| 1 — schema v4, `medications.reminders_enabled` | 1 — `6647cc5` | Clean first time |
| 3 — package setup + the 86-key catalog | 1 — `68d37a3` | Clean first time |
| 8 — the answerable alarm surface + action dispatcher | 2 — `647f0b2`, `6d4e3e3` (Kotlin line citations) | Clean first time (implementer reported `DONE_WITH_CONCERNS`; the concerns became Task 13's wiring list) |
| 2 — `MedicationDao` | 1 — `8ccf898` | Clean first time |
| 4 — domain models, generator, key codec, ratio | 1 — `5d65e49` | Clean first time (ruling 4) |
| 6 — save / delete / taken / snooze use cases | 1 — `ee7a393` | Clean first time |
| 5 — mapper, repository, `latestOfBoth` | 1 — `509f0c0` | Clean first time (ruling 1) |
| 7 — `MedicationReminderHandler` + texts | 1 — `eb0e75e` | Clean first time |
| 10 — navigation, module factory, list screen | 1 — `5749309` | Clean first time (rulings 5, 8) |
| 11 — detail screen + the reminders toggle | 1 — `0d6192a` | Clean first time (rulings 6, 7) |
| 12 — editor screen, the schedule builder | 2 — `6d61d23`, lint fix `68d7f88` | Clean first time; the fix round is the post-rebase `function_body_length` failure, re-reviewed and ADDRESSED |
| 13 — app wiring, tab, handler, intents, deep link | 1 — `f31a1c1` | Clean first time |
| 14 — this record and `scripts/m5-manual-qa.md` | 1 | — |

Integration was continuous rather than batched: every task was rebased onto `m5-medications` and
fast-forward merged as its review closed, so the branch was green at each of the fifteen points
above rather than at two or three checkpoints. Task 12's rebase was the only one with conflicts —
three, all adjacent additions to `MedicationsModule.swift`, `MedicationsNavigation.swift` and the
shared `MedicationFormLabel.swift`, resolved by the controller and then caught by lint, which is
what the fix round is.

### Decisions and recorded divergences

The four decisions are the user's, taken on 2026-08-27 before dispatch (decision 4 in a second
sitting, and it is why `2608e7d` exists as its own commit). (a)-(p) were written into the plan before
execution; everything after them was recorded as it happened.

**Decisions (Alican, 2026-08-27)**

1. **The list-card ratio is renamed *and* re-based.** `recordedDosePercent` / `RecordedDoseRatio`,
   string key `medications_recorded_doses`, and the denominator is the **recorded logs** in the
   seven-day window (`takenLogs / loggedLogs`, nearest whole percent — the `SummaryModels.kt:87-89`
   rule), not Android's generated-occurrence denominator. Two Android follow-ups fall out of it
   (the name, and the denominator), numbered 1 and 2 below.
2. **The AlarmKit alarm surface gets real buttons via `AppIntents`**, so a dose can be answered on
   iOS 26 without opening the app.
3. **A tapped dose notification or alarm lands on the Medications tab root** — no detail push,
   because a dose's `entityId` is a *schedule* id. Android parity, and deliberately unlike iOS-M4's
   appointment-detail push.
4. **The alarm's two buttons are stop = "Kapat" = `ReminderActionIds.dismiss` and secondary = the
   handler's first action** (`taken`, `secondaryButtonBehavior: .custom`). `AlarmPresentation.Alert`
   has exactly two, so this is a choice about which two. **Stop must never be mapped to `taken`** —
   an unattended stop would forge an intake record. Snooze is therefore reachable only on the
   notification path, and that is divergence (c). No `alarmUpdates` observer: every way of ending an
   alert runs an intent, so the intents are the reaction hook.

**Recorded divergences from Android — the plan's list, with what execution made of each**

- **(a) The ratio is `RecordedDoseRatio` / `recordedDosePercent`, over a recorded-logs denominator**
  (decision 1). Visible in three places: the field name, the call (which needs neither the medication
  list nor `nowMinuteOfDay`, so Kotlin's two extra arguments have no twin), and the two renamed test
  names. **A medication with no logs is absent from the ratio and draws no bar — never 0 %.** The
  Kotlin case that seeds 4 TAKEN against 7 generated occurrences and asserts 57 is reached here by
  seeding all 7 days: 4 recorded taken, 3 recorded skipped. Same assertion, same arithmetic, over
  the base this port computes.
- **(b) `medications_recorded_doses` replaces the Android key**, with new TR/EN copy — tr
  *"Son 7 gün kaydedilen doz %%%1$lld"*, en *"Recorded doses, last 7 days: %1$lld%%"*. It is the only
  banned hit across 86 keys × 2 languages. The reason is written twice, where each reader meets it:
  the header of `MedicationsStrings.swift` and the row comment in the test table. **Neither file
  spells the Android key out**, because `assertSourcesNameNothingBanned` reads comments too and a
  comment must not reintroduce the vocabulary a string was cleaned of. Android owes the mirror edit
  (follow-up 1).
- **(c) The alarm surface is Kapat + İçtim, with no Ertele and no body text.** Android's
  `AlarmScreen` shows a title, a body and every action. `AlarmPresentation.Alert` has a `title` and
  no body slot, so `content.text` ("1 × 100 mg al") does not reach it; and it has exactly two
  buttons, so `snooze` is unreachable from the alarm surface — it survives on the notification
  fallback, and after the alarm is stopped the occurrence stays unresolved, which is the point.
  Recorded in `schedule`'s doc comment.
- **(d) `saveMedication` runs in one write transaction** where Android issues three separate writes.
  Semantics otherwise identical, including the *replace* of the active schedule set. Pinned by
  `saveWithSchedules` **atomicity**: an FK-violating schedule leaves no medication row.
- **(e) The mapper's enum fallbacks (`OTHER` / `DAILY` / `PENDING`) are ported**, unlike iOS-M4's
  divergence (n) where the appointment mapper throws. The difference is not a preference: this is a
  *tested* Kotlin behaviour (`unknown enum strings fall back to safe defaults`), and iOS-M4's was
  implicit. The Swift case additionally asserts the `MedicationForm` and `IntakeStatus` arms, which
  Kotlin does not, because the same `?? default` is written three times and one of them could rot
  alone.
- **(f) `latestOfBoth` is duplicated into the feature** rather than promoted (ruling 1), and the list
  VM follows `AppointmentsViewModel`'s shape: two streams, `pendingIds` via observation tracking, and
  `confirmingId`/`pendingDeleteId` as plain state — nothing outside the class observes it, so it is
  not a `combine` arm.
- **(g) Mapper test names say `record` where Kotlin says `entity`** — the types genuinely are
  `…Record` on iOS. iOS-M4's divergence (m) is the precedent.
- **(h) `editor_back` / `editor_confirm` / `editor_cancel` are dead on iOS for structural reasons**
  and were ported for key-set parity: the back arrow is the navigation stack's own, and the two
  dialogs those labels belong to are the pickers `SalusDateField` / `SalusTimeField` replace. **They
  are live on Android** — this is a fact about the port, not an Android finding, and no use was
  invented for them.
- **(i) A tapped dose lands on the tab root** (decision 3).
- **(j) The list card uses disjoint tap targets.** The card is a non-interactive `SalusCard`; "open"
  is a tap gesture with button semantics restored by hand, and the trash is its **sibling**, because
  `SalusCard(onTap:)` is a `Button` and a nested one would never receive the tap. `VitalsRow` (M2)
  and `AppointmentCard` (M4, divergence (p)) settled this shape. **One measured difference inside
  it:** the trash is `.top`-aligned where Kotlin's is `CenterVertically`.
- **(k) `MedicationDetailKey(id:)` / `MedicationEditorKey(id:)`** — iOS-M4's spelling; Kotlin says
  `medicationId`.
- **(l) `salus_alarm.caf` is still the generated placeholder** from
  `scripts/generate-alarm-sound.sh`. A designed ≤ 30 s sound is owed before release; carried from
  iOS-M3.
- **(m) `SalusStatus`'s tints come from `design-tokens.md`** — success and warning from
  `extendedColors`, error from `colorScheme.error` (there is no extended token for it, and the
  comment records why), neutral from `colorScheme.onSurfaceVariant` so the accent-less chip's tint
  cannot diverge from the named one.
- **(n) `AS_NEEDED` keeps its silent `timeOfDayMinutes = 0` schedule row** and **no ad-hoc logging
  UI was invented**. The generator emits nothing for it, which is the ported case
  `AS_NEEDED never generates occurrences`, and `scripts/m5-manual-qa.md` §2.7-2.8 checks the row is
  there and the ledger is empty.
- **(o) Stock is two warning chips and nothing else** — "Hatırlatıcılar kapalı" and
  "Stok azaldı: N kaldı". No low-stock notification, no refill flow.
- **(p) `dismiss` reaching `onAction` is a no-op**, because Kotlin's `when` has no `else`. Pinned by
  the iOS-only case `dismiss is a no-op and leaves the log untouched`: no log written, no sync
  requested by the handler, and the occurrence still emitted afterwards.

**Further divergences, recorded during execution**

Grouped by where they were found. Each is at its call site in the source as well as here.

*Storage (T1, T2)*

- **`updateIntakeLog` throws on a missing row.** Room's `@Update` silently updates nothing; GRDB's
  update-by-primary-key throws `RecordError.recordNotFound`. This follows the brief's "GRDB update by
  primary key" and diverges in the safe direction. Noted on the member.
- **`deactivateSchedulesExcept` drops the `NOT IN` clause when `keepIds` is empty.** Behaviour
  matches Room; the clause is dropped for clarity, not because SQLite would reject it (the
  pre-existing comment on `AppointmentDao` claiming it would is wrong — deferred finding, T2).
- **The two `…Between` queries carry no `ORDER BY`**, faithfully. Called out in the file header, in
  both members' doc comments, and in the tests, which assert **sets** rather than sequences — so it
  reads as a ported fact rather than an omission. Android follow-up 8.

*Domain (T4, T6, T7)*

- **`MedicationRepository` has 13 members, not the plan's 14** (ruling 4).
- **`formatAmount` guards the `Int` conversion with `Int(exactly:)`.** Kotlin's `Double.toInt()`
  saturates at `Int.MAX_VALUE`; Swift's `Int(_: Double)` **traps**, and a decimal keypad can produce
  twenty digits. Realistic doses are byte-identical to Kotlin; the difference shows only for values
  Android renders as `2147483647`. Pinned by a test case.
- **`scheduleSummary`'s `strings:` parameter is a value type, `ScheduleSummaryStrings`** — five
  labels, `Sendable`, `internal`, no behaviour, with `static var localized` (a computed var, so a
  locale change is picked up) built from the `MedicationsStrings` accessors. It is what lets the
  composition rule be asserted at all: `swift test` copies a `.xcstrings` verbatim instead of
  compiling it, so a live lookup would answer with the key.
- **`MedicationForm.icon()` / `.labelRes()` are not in `MedicationFormatting.swift`.** Both are UI
  mappings, and keeping them out is what lets that file import Foundation alone and stay callable
  from the reminder handler's background actor. They live in `ui/MedicationFormIcon.swift` and
  `ui/MedicationFormLabel.swift`.
- **All five domain models are `Hashable`** (the Kotlin `data class` shape), not only
  `DoseOccurrence` as the plan asked.
- **The generator's comparator is total** — `(epochDay, minuteOfDay, scheduleId)`. Kotlin's
  `sortedWith(compareBy(...))` is stable and Swift's `sorted(by:)` is not, and that triple is the
  idempotency key.
- **`DoseOccurrenceGenerator` sorts with `scheduleId` as a third key where Kotlin's stable sort
  preserves insertion order for day+minute ties.** Both platforms are deterministic and both agree
  on the *set* of occurrences; only the order *within* a tie can differ, and only for two schedules
  of the same medication at the same minute. Documented in-file, at the comparator.
- **`DoseOccurrenceKey.decode` passes `omittingEmptySubsequences: false`.** Swift's `split` drops
  empty parts, which would read `"20514|"` as one part and reject it for the wrong reason.
- **The use cases' `Result` is `Equatable, Sendable`** where the plan spelled only `Equatable`. A
  public Swift enum gets no implicit `Sendable`, so a caller hopping isolation would not compile;
  Kotlin's `data object`s are trivially shareable. Same fact, spelled for Swift 6.
- **`snoozeDuration` is a `TimeInterval` of seconds** (Kotlin: `10.minutes`). The test pins both the
  constant (`== 600`) and the written column (`nowEpochMs + 600_000`) with literals, so "ten minutes"
  is an assertion rather than a restatement of the constant under test.
- **`SnoozeDoseUseCase`'s init order is the plan's**, not Kotlin's, and
  `DeleteMedicationUseCase`'s parameter is `id:` (Kotlin: `medicationId`), matching the rest of the
  tree.
- **`observeLogsBetween` / `getLogsBetween` filter with two comparisons, not a `ClosedRange`** — an
  inverted window traps in Swift where Kotlin's range is simply empty, and a fake that crashed on a
  reversed window would hide the caller's bug rather than show it.
- **Three `fileprivate` `with…` / `markedTaken` / `snoozed` extensions** stand in for Kotlin's
  `data class copy(...)`, one per file, each naming the exact `copy` it ports
  (`Appointment.with(...)` is the precedent).
- **`LocalizedMedicationNotificationTexts` is `public`**, so the composition root can construct it,
  exactly as its appointments twin is.
- **Kotlin's file-private `Double.formatTrimmed()` is not ported**; `formatAmount(_:)` is the single
  copy of that rule by construction, used for both the dose amount and the strength.
- **Kotlin's `Triple` becomes a private `LogKey: Hashable`** — Swift tuples are not `Hashable`, and
  a named type also stops the three fields being read in the wrong order.
- **Type spellings:** `MedicationsRepositoryImpl` (plural) vs Kotlin's `MedicationRepositoryImpl`,
  and `MedicationMapper.swift` (singular) vs `MedicationMappers.kt`. Both are the plan's names.

*The alarm surface (T8, T13)*

- **The `@available` gate is `iOS 26.0`, not the plan's `26.1`.** Verified against Xcode 26.4.1 /
  `iPhoneOS26.4.sdk`: the whole alarm surface exists from 26.0. What changes at 26.1 is that the stop
  button's *copy* becomes the system's own, with no parameter for it — so decision 4's "Stop =
  Kapat" is literally true only on 26.0, while its **semantics** hold on both: stop runs
  `stopIntent`, the engine reads it as `ReminderActionIds.dismiss`, and stop is never `taken`. The
  leftover label property is documented as unused above 26.0.
- **An unknown request code still triggers a sync**, where Kotlin returns early. Same reasoning the
  notification delegate already used for a swallowed handler error: the refill is a property of the
  *event*, not of the occurrence still being known. Stated in the dispatcher's header and pinned by a
  test.
- **`ReminderActionDispatcher.init` takes `ReminderAlarmDao?`, not `ReminderAlarmDao`** — deliberate
  and tested, so the dispatcher can exist before the ledger does.
- **`AlarmActionIntentProvider` carries platform-unavailability attributes** the plan did not name.
  Required, not decorative.
- **`static let openAppWhenRun` / `static let title` on the intents, not `static var`.** Forced by
  Swift 6 strict concurrency; both are get-only protocol requirements, so a `let` witnesses them.
- **`isDiscoverable = false`** on both intents — they are reaction hooks, not Shortcuts actions.
- **`App/Reminder/AlarmActionBridge.swift` is the one sanctioned `static let shared` in the tree.**
  CLAUDE.md's composition-root rule says a type takes its dependencies in `init`; an `AppIntent`
  cannot, because the system instantiates it through the protocol's own `init()`, in a process iOS
  may have launched for nothing but that one intent — there is no call site to inject the graph
  through. The bridge is a rendezvous point rather than a service locator: the only thing that ever
  passes through it is the `ReminderActionDispatcher` the composition root built and bound, and the
  bridge only forwards to it. Named as a carve-out in CLAUDE.md by the final-review fix wave below.
- **`ReminderAlarmDao` is hoisted to a `let` inside `makeReminderGraph`**, not to a property on
  `AppCompositionRoot` as the brief said. Nothing outside that function reads it; the *dispatcher* is
  what the root needs, and it is a stored `let`. A root property with no consumer would be dead
  weight.
- **The duplicate-push guard is a memo, not a read.** `NavigationPath` exposes a count and nothing
  else, so "is this key on top?" cannot be asked of it. `RootView` remembers what the last reminder
  tap pushed (id + the depth the push left behind) and skips a push that would repeat it; any
  `.navigate` command landing on that stack clears the memo, and a pop needs no line because it moves
  the depth the memo is matched against. A `TabBackStacks` "top key" API would be cleaner, but that
  is `Packages/` and was out of Task 13's scope.

*UI (T9, T10, T11, T12)*

- **`SalusIconBadge` is a circle filled with the opaque `accent.container` token**, not the plan's
  prose "rounded square, 16 %-opacity fill with a corner radius" (ruling 3). `SalusShapes.pill` over
  a square frame is the token spelling of `CircleShape`, so no radius literal was introduced.
- **`ProgressView(value:)` has no `trackColor`.** Kotlin's
  `LinearProgressIndicator(color = accent.accent, trackColor = accent.container)` becomes
  `.tint(accent.accent)` over the platform's own dimmed track. The 72 pt width the plan pins is
  identical.
- **The history chips follow Kotlin's `IntakeStatus.chipStatus()`** — `TAKEN → success`,
  `MISSED → warning`, `SKIPPED`/`PENDING → neutral` — not the plan's prose, which said
  missed → error and pending → warning (ruling 6). The `chipStatus` doc comment says so out loud so
  nobody "fixes" it back.
- **The detail's two actions keep `.buttonBorderShape(.capsule)`** (ruling 7): Android's
  `SalusPillButton` *is* a pill. iOS-M4's `AppointmentDetailScreen` did not carry it; the
  final-review fix wave below added it there — to the action block and to `OpenMapsButton`, which is
  a `SalusPillButton` on Android too (`AppointmentDetailScreen.kt:237`) — so both detail screens now
  draw the same shape.
- **`sortSwitchCases` reorders `MedicationForm.systemImage`'s arms** alphabetically (`.drop`,
  `.syrup` before `.injection`). The arms and their answers are Kotlin's; only the source order moved,
  and the lint rule is why.
- **Screen sections are `internal View` structs in a second file**, not `private @Composable`
  functions in one. Swift has no per-file privacy for a view used from another file, and the 500-line
  limit asks for the split. A header-plus-card section wraps in `VStack(spacing: md)` so the drawn
  spacing does not depend on how SwiftUI flattens a tuple body.
- **`Toggle` is labelled then hidden** (`Toggle(remindersTitle, isOn:).labelsHidden()`) rather than
  `Toggle("")`, so VoiceOver announces a *named* switch where Compose's `Switch` inherits the row's
  semantics.
- **`onEvent(_:)`, not the plan's `send(_:)`** — every ViewModel in the tree spells it `onEvent`.
- **`getMedication` failure pops the editor**, and `save()` has a `catch` arm that leaves it open
  with the form intact. Kotlin's repository cannot throw; the iOS protocol declares `async throws`,
  and a failed read leaves nothing to edit — the same exit as a missing id, rather than a blank form
  the user could save over a row they never saw.
- **`isLoading` draws a spinner** where Kotlin draws a progress bar over an empty body — the spinner
  is what `MedicationsScreen` already draws for the same moment.
- **There is no per-field error tint.** Kotlin tints the name field, the interval field and the
  end-date text *and* draws the banner; SwiftUI's `TextField` has no `isError`, so the banner is the
  single error surface.
- **The date row.** `SalusDateField` is the button and its picker in one view, so Kotlin's button
  *text* ("From …" / "Until …") becomes the field's title, hidden with `.labelsHidden()` and still
  read by VoiceOver. `editor_no_end_date` keeps its exact job as the end field's placeholder, and the
  clear button is Kotlin's. Dates render through `LocalDate.formatted(pattern:locale:)` with
  `"d MMM yyyy"` — never a `Calendar` — standing in for Kotlin's `FormatStyle.MEDIUM`.
- **The add-time row is the wheel plus an explicit add button.** `SalusTimeField` reports every turn
  of the wheel, which is right for "set this row's time" and wrong for "append a row" — it would add
  one row per intermediate minute. The wheel writes to the section's own `@State` and the button
  emits `doseTimeAdded`. Two taps on both platforms, one row per confirmation; Kotlin's `-1 = add
  new` sentinel has no twin for the same reason.
- **Index-carrying editor events guard their range.** Kotlin's `mapIndexed` / `filterIndexed` no-op
  on a stale index; a Swift subscript would trap, so the guard is the translation of that "nothing".
- **`cyclomatic_complexity` is waived on `MedicationEditorViewModel.onEvent(_:)`** with a
  `disable`/`enable` pair and a written reason: 20 Kotlin arms port to 20 Swift arms, and splitting
  them would invent a dispatch layer Android does not have. Same waiver style as
  `MedicationsModule.swift`'s `function_parameter_count`. **No lint rule was relaxed repo-wide, and
  no `file_length` was disabled** — Task 0's ruling set that precedent.
- **`MedicationForm.label` is a shared file, `ui/MedicationFormLabel.swift`**, because the detail
  header and the editor's form picker both need it. Task 11 and Task 12 wrote it independently on
  concurrent branches; the integrator kept one copy.

*Test-shape substitutions, uniform across the milestone*

Turbine's `state.test { skipItems(1); awaitItem() }` → `await waitUntil { … }` then reading the
published state; `MainDispatcherRule` → `@MainActor` on the suite; `advanceUntilIdle()` closing the
undo window → `TestDeletes.closeUndoWindow()`; `IdGenerator { "gen-${nextId++}" }` → a lock-guarded
`SequentialIdGenerator` (a `FixedIdGenerator` would hand the medication and its schedule the same
id); Kotlin's `assertEquals(…, xs.single())` → `try #require(xs.first)` **plus** an explicit
`count == 1`, so "exactly one" stays an assertion rather than a crash. One assertion is *added*
rather than ported, iOS-M4's divergence (b) again: Kotlin asserts `deletes.snackbar.shown.size == 1`
because Android's undo snackbar is indefinite, while the iOS controller publishes only the snackbar
that is *up*, so "exactly one" is spelled as one being up and nothing coming up behind it.

Anything else that differs from `:feature:medications` is a bug, not a port decision.

### Rulings made during execution (decided on the user's behalf — read these)

In ledger order. Each says what it costs if it turns out to be wrong.

1. **`latestOfBoth` is duplicated into `FeatureMedications`, not promoted** (pre-flight). Features
   may not depend on each other, and the template sanctions the duplicate (the `CancellationBox` /
   `FakeNavigator` / `WaitUntil` precedent, iOS-M4 divergence (l)). A reviewer flagging it as
   plan-mandated duplication is answered by this ruling, not by a fix. *Cost if wrong:* one later
   promotion refactor across two features.
2. **Task 0 splits the file rather than relaxing the lint rule.** The restructure pushed
   `AppCompositionRoot.swift` past `file_length` 500, and the implementer stopped rather than pick
   between them. The reminder assembly moved to `App/AppCompositionRoot+Reminder.swift` (an
   extension, so the members become app-internal with no new public API);
   `ignore_comment_only_lines` was **rejected**, because it weakens a repo-wide gate for one file.
   *Cost if wrong:* one extra file to navigate.
3. **`SalusIconBadge` is ported from the Kotlin, not from the plan's prose** (Task 9). The plan
   described a rounded square with a 16 %-opacity fill and asked for its corner radius;
   `SalusIconBadge.kt` is a `CircleShape` filled with the opaque `accent.container`, and the 16 %
   alpha belongs to `SalusStatusChip`. CLAUDE.md's port-fidelity rule makes the Kotlin the spec.
   *Cost if wrong:* none — visual parity either way.
4. **The plan's "14 members" for `MedicationRepository` was a counting error** (Task 4).
   `MedicationRepository.kt` declares **13**, and `MedicationRepositoryImpl.kt` has 13 `override`s.
   Thirteen were ported; there is no fourteenth. *Cost if wrong:* none — the count was checkable and
   was checked.
5. **`MedicationsModule` ships incrementally across T10/T11/T12** (Task 10 dispatch). The plan listed
   detail and editor ViewModel factory closures whose types arrive in T11/T12, so T10 shipped the
   module without them and registered placeholder destinations marked with the replacing task.
   *Cost if wrong:* two small edits to `MedicationsModule.swift` instead of one. (This is iOS-M4's
   ruling 7 applied again, and it worked the same way.)
6. **The history chip tints follow Kotlin's `IntakeStatus.chipStatus()`, not the plan's prose**
   (Task 11). The plan said "taken→success, skipped→neutral, missed→error, pending→warning";
   `MedicationDetailScreen.kt:368-372` says `TAKEN → Success`, `MISSED → Warning`,
   `SKIPPED, PENDING → Neutral`, and the task's own instruction was "port that mapping exactly".
   **The plan sentence is the thing that was wrong.** *Cost if wrong:* none.
7. **The detail's action buttons keep `.buttonBorderShape(.capsule)`** (Task 11), because Android's
   `SalusPillButton` is a pill and the plan's mapping table says so. iOS-M4's
   `AppointmentDetailScreen` lacks it, which is now a deferred parity fix rather than a reason to
   drop the modifier here. *Cost if wrong:* one modifier line.
8. **`CancellationBox`'s third byte-identical copy is accepted inside M5 and promoted afterwards**
   (Task 10 review). Hoisting it — with `latestOfBoth` and `mapped`, which are in the same position —
   into `SalusCommon` is a milestone-level decision, and doing it mid-milestone would have touched
   three features under review. It is a post-M5 chore. *Cost if wrong:* one more copy in iOS-M6.
9. **Task 14 does the record and the script only; the `--ff-only` merge and the push are held for
   the user**, exactly as iOS-M3's ruling 6 and iOS-M4's ruling 8. *Why:* merging publishes a shared
   branch, and the acceptance criterion's alarm half still needs a device and a human finger.
   *Cost if wrong:* one extra user command.

### Deferred findings, verbatim from the ledger, grouped by task

None of these blocks iOS-M6. Task 14 deliberately fixed none of them.

**Task 0 — `AppCompositionRoot.init` restructure**
- `makeInfrastructure`'s memberwise-init evaluation order moves three side-effect-free constructors
  (`PendingDeleteController`, `Navigator`, `SnackbarController`) after the two data sources. Inert
  today; a future init-time `UserDefaults` read in one of them would make the reorder matter.
- `ReminderGraph` and `makeReminderGraph` are app-target-**internal** (the memberwise init is
  exposed) rather than file-private. That is ruling 2's accepted cost.

**Task 9 — `SalusUI` additions**
- Kotlin line citations in `SalusIconBadge.swift` / `SalusStatusChip.swift` are off by ~5 lines (the
  values themselves are correct).
- An empty `systemImage: ""` is not guarded, on either the chip or the badge.
- `SalusStatus.tint(in:)` is `public` although only the tests and the chip need it.
- `ChipFlowLayout` proposes `.unspecified` to its children, so an over-wide chip can still overflow
  — pre-existing, and now **→ `scripts/m5-manual-qa.md` §7.5/§7.7**.

**Task 1 — schema v4**
- The parity pragma comparison omits `defaultValue`; the new column is covered behaviourally, but
  only for `reminders_enabled`.
- `v4Statement` has no derived-from-Room pin of its own.
- Note carried into Task 2 and honoured there: Android's entity has **no** Kotlin default
  (`@ColumnInfo(defaultValue = "1")` only), so the mapper must pass `remindersEnabled` explicitly.

**Task 3 — strings**
- The `formatted` helper's doc comment is split into `//` + `///`
  (`MedicationsStrings.swift:335-341`).
- Three same-text delete keys (`delete` / `editorDelete` / `detailDelete`) need a call-site note.
  Resolved per screen during T10-T12 — `SalusUIStrings.delete` for the list's dialog, `editorDelete`
  for the editor toolbar, `detailDelete` for the detail action — but the note itself was never
  written into the file.

**Task 2 — `MedicationDao`**
- `MedicationDaoTests.swift:208` asserts order on an unordered query; it should compare sets.
- JOIN-stream re-emission is tested on a *schedules* write only, not on a *medications* write.
- `updateIntakeLog` throws on a missing row where Room's `@Update` no-ops (recorded above as a
  divergence beside (d)).
- `MedicationFixtures.intakeLog` derives `medicationId` from `profileId`.
- Pre-existing, found in passing: `AppointmentDao.getRemindersForAppointments`'s doc comment repeats
  the false claim that SQLite rejects `NOT IN ()`.

**Task 4 — domain**
- The `formatAmount` divergence comment understates the 32-vs-64-bit threshold (Kotlin's `Int`
  saturates at 2³¹; `DoseOccurrenceKey.decode` also accepts values above 2³¹).
- `ScheduleSummaryStrings.localized`'s mapping is untested.
- The inverted-range guard is untested.
- `RecordedDoseRatioTests` compares `Double`s exactly.

**Task 6 — use cases**
- `SnoozeDoseUseCase.swift:53` computes `Int64(duration) * 1000`, truncating before scaling.
- The trim set differs from Kotlin for U+001C-U+001F.
- Test-file Kotlin citations point one line past the closing braces.
- **`FakeMedicationRepository.mutate` fires observers while holding the lock, and `onTermination`
  takes the same non-recursive `NSLock` — a latent deadlock** once ViewModel tests iterate streams.
  Carried into the Task 10 dispatch; it did not fire, and it is still latent.
- `TestData`'s fixed-id doc comment overpromises.

**Task 8 — the alarm surface**
- `ReminderActionDispatcher.init(alarmDao:)` is widened to optional (deliberate and tested).
- `title` shadowing at `AlarmKitScheduling.swift:239`.
- The `AlarmScreen.kt` citation is off by 4 lines.

**Task 5 — data**
- An unused `import Foundation` in `MedicationsRepositoryImpl.swift`.
- **`mapped` is a third copy of the stream-rebuild helper** — a promotion candidate to `SalusCommon`
  alongside `latestOfBoth` (ruling 8).
- One test name covers both `getLogsBetween` and `observeLogsBetween`.
- The medication round trip only ever sees `isActive: true`.

**Task 7 — the reminder handler**
- The decode-failure branch and the `!isActive`-alone nil branch are untested (Kotlin does not test
  them either).
- `#require(first)` is ordered before the count expectation in two tests.

**Task 10 — list screen**
- `MedicationsNavigation.swift:60`'s comment miscounts the Kotlin entries (3, not 2).
- The trash is `.top`-aligned where Kotlin is `CenterVertically` (recorded with divergence (j)).
- A redundant nested accessibility combine at `MedicationCard.swift:138`.
- **The undo tests' "no write" assertions are not drained** — they need `await Task.yield()`, the
  same precedent as `AppointmentsViewModelTests:182`. This is **milestone-wide**, not Task 10's
  alone.
- `state` is reassigned unconditionally, with no `Equatable` guard (the house pattern).
- `FakeNavigator` was unused until T11/T12 landed.
- **`CancellationBox` is a third byte-identical copy** (ruling 8).
- `FakeMedicationRepository`'s publish-under-lock hazard is still latent here too.

**Task 11 — detail screen**
- `ForEach(history, id: \.self)` can collide for two schedules at the same time, status and dose —
  use the enumerated offset.
- A confirm tap also fires a redundant `deleteDismissed`.
- A third spelling of `isBlank` in the package.
- The loading branch drops Kotlin's `padding(xl)`.
- Pre-existing: the `MedicationsModule.kt:39` reference is off by one.

**Task 12 — editor screen**
- `doseTimeRemoved` skips `error = nil` on a stale index where Kotlin clears it (unreachable from the
  UI).
- `decimal(_:)` rejects Java's `1d` / `1f` suffixes (unreachable via `.decimalPad`).
- After the lint fix round: `MedicationsModule.swift`'s header still narrates all three ViewModel
  factories as inline closures, which is stale.

**Task 13 — app wiring**
- The `RootView` guard's doc comment overstates its coverage — a user-navigated detail is not
  de-duplicated.
- `Int32(requestCode)` is a **trapping** conversion in the intents; `truncatingIfNeeded` is the
  right spelling.
- The `AlarmActionBridge` continuation is not cancellation-aware.
- `AppAlarmIntents()` is referenced outside a `canImport` guard.
- **The intent's `perform()` awaits a full window refill inside the AppIntents execution budget.**
  If a device pass records the dose but does not refill the window, this is the first suspect —
  **→ `scripts/m5-manual-qa.md` §5.3**.
- `isDiscoverable = false` was kept.

### Android follow-ups opened by this milestone

`salus-android/` is read-only for the whole of iOS-M5 — nothing under it was touched — so these are
recorded here and written into `docs/ios-v1-plan.md` §11 by the user. **iOS-M4 opened seven that have
not been written in yet**; if those land as A14-A20 these start after them. Re-check before writing:
M2, M3 and M4 all found their assumed numbers already taken.

1. **`:feature:medications` has banned-claims violations — six sites.** One string key used in two
   places, and four test names. The iOS side renamed the key to `medications_recorded_doses` with
   new copy (divergence (b)) and renamed the two test names it ported (divergence (a)); Android owes
   the mirror rename in the XML, in the Kotlin that reads it, and in the Kotlin test names.
2. **The list card's denominator disagrees with `HealthPeriodStats.takenPercent`.** Android divides
   taken logs by *generated occurrences*; `SummaryModels.kt:87-89` divides by *recorded logs*, and
   iOS ported the latter (decision 1). One rule, two implementations, on the same platform. Pick one.
3. **Four missing Android test tables**: the seven-day ratio calculator — the class whose name is
   itself follow-up 1, so it is not written out here, and whose iOS replacement is
   `RecordedDoseRatio` — plus `RecurrenceRule`, `DoseOccurrenceKey`, and a strings/banned-claims
   scan for `:feature:medications`, which is *why* the stems in follow-up 1 survived there.
4. **`ReminderType.SNOOZE` still exists on Android.** iOS has no twin: snooze is an *action* on a
   dose occurrence, not a reminder type. Dead enum case, or an unported concept — decide which.
5. **`IntakeStatus.SKIPPED` and `IntakeStatus.MISSED` have no writer.** Nothing on either platform
   ever writes them; they are rendered by the detail history and counted in the ratio's denominator.
   Either give them a writer or delete them — and note that deleting `MISSED` is what makes the
   "recorded doses" wording exactly true rather than merely careful.
6. **Three copies of the trim-".0" rule.** iOS has exactly one (`formatAmount`, and Kotlin's
   file-private `Double.formatTrimmed()` was deliberately not ported a second time). Android has
   three.
7. **`saveMedication` is not transactional on Android** — three separate writes where iOS does one
   (divergence (d)). A failure between them leaves a medication with a half-replaced schedule set.
8. **`observeIntakeLogsBetween` is unordered.** Faithfully ported as unordered, with the iOS tests
   asserting sets to say so out loud. Add an `ORDER BY` on both platforms together, or document that
   callers must sort.
9. **The medication card nests an `IconButton` inside a clickable card.** iOS cannot do this at all
   (a nested `Button` never receives the tap), so the trash is a sibling with disjoint tap targets
   (divergence (j)). Android's nesting works but is the accessibility shape iOS-M4 already moved
   away from for appointments.
10. **The iOS-only test tables have no Android twin**, in the shape A8 tracks the M2 vitals tables:
    `MedicationDao`'s 17 cases (cascade, `deactivateSchedulesExcept` history survival, empty
    `keepIds`, `decrementStock` flooring and NULL no-op, JOIN filtering, `saveWithSchedules`
    atomicity); the intake-log DAO's 5; the v4 DDL diff and the round-trip-with-`false` case;
    `RecordedDoseRatio`'s 4; `DoseOccurrenceKey`'s 3; `MedicationFormatting`'s 6; `latestOfBoth`'s 3;
    `ReminderActionDispatcher`'s 7; `SalusStatus`'s 5; the handler's `dismiss is a no-op` and
    `the first action is taken and the second is snooze`; and `the saved name is trimmed`.

### Done criterion for iOS-M5

**Medication CRUD with the schedule builder, the per-medication reminder toggle, and a dose that
presents as an alarm whose actions write an intake log from the background — plus the iOS-M3a clause.**

| Half | State |
| --- | --- |
| Automated | **Met.** 53 of 53 contracted Kotlin cases ported by name across the eight tables (55 including the DAO smoke and migration cases), plus the iOS-only rows above; `scripts/ci.sh` green end to end — 24/24 packages, **675 tests**, lint and custom-rule gates clean, `** BUILD SUCCEEDED **` — and the Release build green with **0 warnings**. |
| Manual, executed | **Partly met, by Task 13 on a simulator** and written up in `scripts/m5-manual-qa.md`: the app launches with the Medications tab wired, the empty state renders, and **İlaç ekle** pushes the editor, through real `CGEvent` taps. That proves the navigation graph and the environment reach a pushed destination. It does **not** touch a dose. |
| Manual, **still owed on a simulator** | `scripts/m5-manual-qa.md` **§1-§3** (the CRUD round trip with undo in both directions, the five editor errors and `AS_NEEDED`, the reminder toggle silencing the ledger) and **§4** (the fallback notification actions with the app killed — İçtim → `TAKEN` + stock, 10 dk ertele → `snoozed_until` + a re-ring ten minutes later). §4's two action presses need a finger; everything around them is scripted. |
| Manual, **still owed on a device** | `scripts/m5-manual-qa.md` **§5** — the alarm half of the criterion and the iOS-M3a clause: a dose rings full-screen with the stop button and **İçtim**, İçtim writes the log with the app killed, stop leaves the dose pending, an appointment reminder stays a plain notification. **Never run.** This is why the `--ff-only` merge is held for the user (ruling 9). |

The automated half is complete and the wiring is proven. **The alarm itself has never rung on real
hardware** — that is the honest state of the criterion, and §5 is the whole of what is left to say
otherwise.

### Still owed, and by whom

- **The device pass** — `scripts/m5-manual-qa.md` §5, eight steps, one iPhone on iOS 26. It carries
  the iOS-M3a checklist with it: the authorization prompt, a real AlarmKit schedule and cancel, the
  `.caf` sound on the alarm path, the refusal-degrades leg, and the reboot survival. One person, one
  phone, one evening.
- **The rest of the manual script** — §1-§3 (simulator, scripted, cheap), §4 (two action presses),
  §6 (an older simulator, no AlarmKit), §7 (TR/EN and Dynamic Type on the chip rows). None of §1-§3,
  §6 or §7 is load-bearing for the criterion; §4 is.
- **The `--ff-only` merge and the push** (ruling 9), after the device pass.
- **A designed `salus_alarm.caf`** — still the generated placeholder (divergence (l)), carried from
  iOS-M3 and now overdue, because M5 is the milestone that actually plays it.
- **`CancellationBox`, `latestOfBoth` and `mapped` promoted to `SalusCommon`** — a post-M5 chore
  (ruling 8). Three byte-identical copies each across `FeatureAppointments` and `FeatureMedications`,
  sanctioned by the template only for as long as nobody has spent an hour on the core package.
- **The milestone-wide `await Task.yield()` in the undo tests.** The "no write" assertions in the
  list, detail and editor suites are not drained before they are read. They pass today because the
  write is deferred by a real timer, not because the assertion waited for anything.
- **The Android follow-ups above**, numbered by the user into `docs/ios-v1-plan.md` §11 after
  iOS-M4's seven.

### Final-review fix wave

One commit on top of `bc0dbbd` — `fix(m5): final-review wave — row identity, pill parity, intent
conversions, 26.1 comments`, the branch tip — carrying the six findings of the final whole-branch
review and nothing else. (1)
`MedicationHistorySection` keyed its rows `id: \.self`, and two schedules sharing a minute make two
recorded doses two *equal* `IntakeHistoryItem`s — one SwiftUI id for two rows; it keys by position
now, and `MedicationDetailViewModelTests` gained the reachability case that pins the ViewModel
publishing two equal items. (2) iOS-M4's `AppointmentDetailScreen` gained
`.buttonBorderShape(.capsule)` on the action block and on `OpenMapsButton` — both are
`SalusPillButton`s on Android (`AppointmentDetailScreen.kt:237`, `:299-317`) — so the two detail
screens finally draw the same shape. (3) `DoseAlarmIntents` converts the request code with
`Int32(truncatingIfNeeded:)`: a trap inside a lock-screen intent is a crash, and the value
round-trips from an `Int32` the app scheduled. (4) `App/Reminder/AlarmActionBridge.swift` is now
recorded as the one sanctioned `static let shared`, in CLAUDE.md's composition-root rule and in the
alarm-surface divergence list above. (5) The "26.1" comments left behind when the AlarmKit gate moved
to 26.0 were rewritten to the current fact — `SystemAlarmKitScheduler` is `@available(iOS 26.0, *)`,
and 26.1 only decides whether the stop button is the system's or the app's "Kapat" — across the six
sites the review named plus the rest of the tree's now-false mentions (`FeatureSettings`, the
`SalusReminder` tests, the iOS-M3 plan and its manual-QA script). Comments and docs only. (6) The
domain divergence list above gained the `DoseOccurrenceGenerator` tie-break line.

`scripts/lint.sh`, `scripts/test-packages.sh FeatureMedications FeatureAppointments SalusReminder
SalusTesting` (4/4, 292 tests) and `scripts/build-app.sh` are green on the wave.

### Post-QA fix (2026-08-28)

One commit after the final-review wave: the medication editor's `ScrollView` gained
`salusDismissesKeyboardOnTap()` (new in `SalusUI/component/`) plus
`.scrollDismissesKeyboard(.interactively)`, so a tap or a drag closes a keyboard the manual pass
found no way out of — an **iOS-only divergence**, because every numeric field here is
`.decimalPad` / `.numberPad`, neither pad draws a return key, and Compose's number IMEs still
carry the `ImeAction.Next` / `ImeAction.Done` its fields declare, so `MedicationEditorScreen.kt`
needs no such affordance and has none. The appointments and vitals editors are candidates for the
same modifier and did not get it — a deferred consistency item.

A second commit: the AlarmKit alert's tint is the **medications feature accent** rather than
`Color.accentColor`, which the app has no asset for and which therefore drew the system blue —
`SystemAlarmKitScheduler.init` now takes the colour and the composition root resolves it once
(`SalusTheme.resolve(systemIsDark: false).extendedColors.medications.accent`), the parity being
Android's `AlarmScreen.kt:143-150`. The light palette is frozen on purpose (the system draws the
alert from an attribute set at sync time); the premium palette is not an input — feature accents
are premium-independent on both platforms (spec §4.5), so iOS-M9 changes nothing here.
