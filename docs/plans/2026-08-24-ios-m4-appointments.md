# iOS-M4 — Appointments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Executor subagents run on **Opus** (user preference). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md`, `docs/ios-feature-template.md` (MANDATORY rules, follow to the letter) and the M2/M3 plans' execution records first. Independent tasks may run in parallel implementers (own worktree + side branch `m4-appointments-tN`, rebased onto `m4-appointments` before review). Branch: `m4-appointments`.

**Goal:** `FeatureAppointments` — the third feature package: appointment CRUD (list / detail / editor), multiple reminder offsets driven through the M3 engine by a real `AppointmentReminderHandler`, and "add to calendar" through EventKitUI — with the seven Android test tables (38 cases) ported by name and green.

**Architecture:** Twin of Android `:feature:appointments`. Persistence is already there (M1: `AppointmentRecord`, `AppointmentReminderRecord`, migrations, indices) — M4 adds `AppointmentDao` in `SalusDatabase`, then the feature package exactly as the template lays it out: `domain/{model,repository,usecase}`, `data/`, `ui/{list,detail,editor,calendar}`, `navigation/`, `AppointmentsStrings`, `AppointmentsModule`. The reminder handler is the first real `ReminderHandler` the M3 registry hosts: it turns every `SCHEDULED` future appointment × enabled offset into a `ReminderOccurrence` (key `"<id>|<offset>"`) and bakes `NOTIFICATION`-presentation content. Two shared pieces are lifted out of `FeatureVitals` because a second feature now needs them: `LocalDateTime` (→ `SalusModel`) and the epoch-day date field (→ `SalusUI`, joined by a time field and the chips this feature needs).

**Tech Stack:** Swift 6 / SwiftUI, GRDB (`SalusDatabase`), `SalusReminder` (M3 engine), EventKit + EventKitUI (`EKEventEditViewController`, iOS only), swift-testing.

**Spec:** `salus-android/docs/ios-v1-plan.md` — §4 (module structure), §6.1 (window: appointment reminders are plain notifications), §7 (contracts, banned claims), §8 (screen backlog: `AppointmentsScreen`, `AppointmentDetailScreen`, `AppointmentEditorScreen`; list rows open a detail, never an editor), iOS-M4 milestone entry. Kotlin sources named per task are the behavioural spec. Research brief with every Android rule transcribed: this plan's "Android reference" blocks. **Do not modify anything under `salus-android/`** — Android follow-ups are recorded in Task 11 for the user to carry over.

## Global Constraints

- **Decisions (Alican, 2026-08-24):** (1) "Add to calendar" = **`EKEventEditViewController`** prefilled, user confirms — not a silent `EKEvent` write. (2) A tapped appointment notification **pushes `AppointmentDetailKey(id)`** after switching to the Appointments tab (iOS-only behaviour; Android opens the launcher only — follow-up A-next). (3) Reminder-offset multi-select = a new **`SalusFilterChip`** in `SalusUI` (Material `FilterChip` twin, Material metrics; `design-tokens.md` has no chip spec — record that). (4) The detail screen's **"Doktora söylenecekler" (profile `healthNotes`) is ported now** through `ProfileRepository.observeProfile()`.
- **Recorded iOS divergences (write them into the execution record, not silently):** (a) "Haritalarda aç" is always shown when `location` is non-blank — Apple Maps always resolves; (b) the undo snackbar auto-dismisses at `PendingDeleteController.undoWindowMillis` (M2 ruling, Android A10 still open); (c) `EditorDateField` and `LocalDateTime` move out of `FeatureVitals` (their own comments demand it); (d) the calendar payload difference between detail (`description = notes`) and editor (`description = doctor + "\n" + notes`) is ported **verbatim** and opened as an Android follow-up; (e) `EKEventEditViewController` replaces `ACTION_INSERT` — no calendar chooser step, the system sheet has its own.
- Wall-clock semantics (§7): `starts_at_local` is an ISO-8601 local date-time **without offset, without seconds when zero** (`2026-08-24T14:30`, Kotlin `LocalDateTime.toString()`), `tz_id` beside it, `starts_at_epoch_ms` is a **derived cache** re-computed on save. Instants are always re-derived with the *current* clock zone — `SalusClock.instant(of:minuteOfDay:)`'s Calendar carve-out is the only place a `Calendar` is built.
- Offsets: `Int` **minutes before start**, presets exactly `[60, 1440, 10080]`, multi-select, no custom offset, `filter { $0 >= 0 }.distinct().sorted()` on save, reminder rows fully replaced on every save with deterministic ids `"<appointmentId>:<offset>"` and `enabled = true`.
- Domain purity: `domain/` and `data/` import no SwiftUI/UIKit/EventKit; only `ui/calendar/` imports EventKit/EventKitUI, inside `#if canImport(EventKitUI)` so `swift test` on the macOS host still compiles the package.
- Strings: **46 Android keys verbatim** (`feature/appointments/src/main/res/values{,-en}/strings.xml`, table in the research brief / Task 3), TR source + EN, placeholders `%1$s`→`%1$@`, `%1$d`→`%1$lld`; typed `AppointmentsStrings` over `Bundle.module`; `BannedHealthClaims` scan passes. Shared `SalusUIStrings.undo/.cancel/.delete` for the confirm dialog and undo.
- Every task: `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` green before commit; SwiftFormat/SwiftLint clean; `scripts/clean.sh` after adding a file to a path dependency. Ported test names = Kotlin backticked names, case for case.
- Executors report: test names verified against files, every divergence from the Kotlin twin listed, nothing "fixed while passing" outside the task's files.

---

### Task 0: Branch + the M3 prerequisite (`.public` → `.private` on error interpolations)

**Files:**
- Modify: `App/AppCompositionRoot.swift:270,401` (error/reason), `Packages/SalusReminder/Sources/SalusReminder/platform/BackgroundRefreshScheduler.swift:242`, `Packages/SalusReminder/Sources/SalusReminder/engine/ReminderWindowSynchronizer.swift:101,148`

**Why:** M3 execution record: "`privacy: .public` on the error interpolation … a §12 surface that widens once M4-M6 handlers land; prefer `.private`". Real handlers arrive in Task 5, so this goes first. Identifiers (task id, type raw value, profile id, db name) **stay** `.public`.

- [ ] `git checkout -b m4-appointments` from `main` (`5396254`).
- [ ] Flip exactly the five `String(describing: error)` / `reason` interpolations to `privacy: .private`. `grep -rn 'privacy: .public'` afterwards lists only identifier sites.
- [ ] `swift test` for `SalusReminder`, app builds. Commit `fix(log): keep error text private in reminder and boot logs`.

### Task 1: `LocalDateTime` moves to `SalusModel`

**Files:**
- Create: `Packages/SalusModel/Sources/SalusModel/LocalDateTime.swift` (moved from `Packages/Features/FeatureVitals/Sources/FeatureVitals/ui/VitalsLocalDateTime.swift`, which is deleted)
- Modify: `FeatureVitals/ui/list/{VitalsUiState,VitalsScreen,VitalsViewModel}.swift` (rename), `FeatureSettings/ui/reminderhealth/ReminderHealthLastSync.swift` (comment only), `Packages/SalusCommon/Sources/SalusCommon/SalusClock.swift` (see below)
- Test: `Packages/SalusModel/Tests/SalusModelTests/LocalDateTimeTests.swift` (move any existing `VitalsLocalDateTime` cases; add the ones listed)

**Interfaces (produces):**
- `public struct LocalDateTime: Equatable, Hashable, Sendable { public let date: LocalDate; public let minuteOfDay: Int }` — same body as today.
- `public extension Date { func wallClock(in zone: TimeZone) -> LocalDateTime }` (now `public`, floored division kept).
- `public extension LocalDateTime { func formatted(pattern: String, locale: Locale = .current) -> String; var isoLocalString: String; init?(isoLocalString: String) }` — ISO twin of Kotlin `LocalDateTime.toString()/parse`: writes `yyyy-MM-dd'T'HH:mm`, parses with or without `:ss`, no offset, no `Calendar` (pure integer arithmetic over `LocalDate(year:month:day:)`).
- `public extension LocalDate { func formatted(pattern:locale:) -> String }` (unchanged).
- `SalusClock.instant(of:minuteOfDay:)` stays where it is; add `public extension LocalDateTime { func instant(in zone: TimeZone) -> Date }` in **`SalusCommon`** (it needs the Calendar carve-out; `SalusClock.instant(of:minuteOfDay:)` becomes a one-line forward to it so there is still exactly one `Calendar` site). Kotlin twin: `LocalDateTime.toInstant(TimeZone)`.

- [ ] Move file, make it public, rename usages, `swift test` green in `SalusModel`, `SalusCommon`, `FeatureVitals`, `FeatureSettings`.
- [ ] TDD the additions: ISO round trip (`14:30` ↔ `"…T14:30"`, `"…T14:30:00"` parses, `"…T14:30+03:00"` rejected), `instant(in:)` across the Europe/Istanbul DST-less zone and a `America/New_York` spring-forward day (compare with `SalusClock.instant(of:minuteOfDay:)`), pre-1970 `wallClock`.
- [ ] Commit `refactor(model): lift LocalDateTime out of FeatureVitals for its second consumer`.

### Task 2: `AppointmentDao` in `SalusDatabase`

**Files:**
- Create: `Packages/SalusDatabase/Sources/SalusDatabase/AppointmentDao.swift`
- Test: `Packages/SalusDatabase/Tests/SalusDatabaseTests/AppointmentDaoTests.swift`

**Kotlin source:** `core/database/.../dao/AppointmentDao.kt` (13 members), `.../entity/AppointmentEntity.kt`. Records and tables exist (`Records/AppointmentRecord.swift`, `Records/AppointmentReminderRecord.swift`, `Migrations.swift:29-49`). Follow `VitalsDao.swift` exactly (`public struct … : Sendable`, `init(database:)`, `conflatedStream` helper, Room SQL verbatim in doc comments with `AppointmentDao.kt:line` citations).

**Interfaces (produces):** `public struct AppointmentDao: Sendable` with
`upsert(_: AppointmentRecord)`, `upsertReminders(_: [AppointmentReminderRecord])`, `upsertWithReminders(_:reminders:)` (**one write transaction**: upsert → `deleteRemindersFor` → upsertReminders), `getById(_:) -> AppointmentRecord?`, `observeById(_:) -> AsyncThrowingStream<AppointmentRecord?, any Error>`, `observeRemindersFor(appointmentId:) -> AsyncThrowingStream<[AppointmentReminderRecord], any Error>`, `observeUpcoming(profileId:fromEpochMs: Int64)` (`starts_at_epoch_ms >= ? AND status = 'SCHEDULED' ORDER BY starts_at_epoch_ms ASC`), `observePast(profileId:beforeEpochMs:)` (`starts_at_epoch_ms < ? OR status != 'SCHEDULED' ORDER BY … DESC`), `getRemindersFor(appointmentId:)`, `deleteRemindersFor(appointmentId:)`, `deleteById(_:)`, `getScheduled(profileId:)` (no order), `getRemindersForAppointments(ids: [String])`, `observeRemindersForProfile(profileId:)` (INNER JOIN `appointments`). Status strings are `AppointmentStatus.rawValue` (`SCHEDULED`/`COMPLETED`/`CANCELLED`).

- [ ] TDD against `SalusDatabase.inMemory(clock:)`: upsertWithReminders replaces rows atomically; upcoming/past partition + ordering (incl. a `COMPLETED` future appointment landing in *past*); `deleteById` cascades reminder rows (FK on); `observeRemindersForProfile` excludes another profile's rows; `getRemindersForAppointments([])` returns empty without a malformed `IN ()`.
- [ ] `swift test` green in `SalusDatabase`. Commit.

### Task 3: Package setup + strings catalog (`AppointmentsStrings`)

**Files:**
- Modify: `Packages/Features/FeatureAppointments/Package.swift` (add `defaultLocalization: "tr"`, `resources: [.process("Resources")]` on the main target), `project.yml` (add `FeatureAppointments` under `packages:` and to the app target's package products, beside `FeatureVitals`), then `xcodegen generate` — pbxproj and yml in the **same commit**
- Create: `Sources/FeatureAppointments/Resources/Localizable.xcstrings`, `Sources/FeatureAppointments/AppointmentsStrings.swift`
- Test: `Tests/FeatureAppointmentsTests/AppointmentsStringsTests.swift`

**Android reference:** the 46-key table (TR | EN) in the research brief, reproduced from `feature/appointments/src/main/res/values{,-en}/strings.xml` — keys `appointments_title … appointment_deleted`. Port **all 46** including the three Android never reads (`appointments_upcoming_header`, `appointments_ok`, `appointments_cancel`) — key-set parity is the drift detector. Format keys: `appointments_past_header` (`Geçmiş (%1$lld)`), `appointments_notification_title` (`Randevu: %1$@`), `appointment_detail_time` (`Saat %1$@ · %2$lld dakika`), `appointment_delete_title` (`%1$@ silinsin mi?`).

**Interfaces (produces):** `public enum AppointmentsStrings` — one `static var` per key in `VitalsStrings.swift`'s pattern (private `Key` enum, `localized(_:)`), plus `static func pastHeader(count: Int)`, `notificationTitle(_:)`, `detailTime(time:durationMinutes:)`, `deleteTitle(_:)` using `String(format:locale:)`.

- [ ] Write the catalog (tr source + en, every key both languages), the accessors, and the strings suite mirroring `VitalsStringsTests`: exact key set (46), source language + every key localized, `@Test(arguments:)` TR/EN verbatim table, every accessor asks for a carried key, the four format keys render the Android sentence, `BannedHealthClaims.assertCatalogsNameNothingBanned`.
- [ ] `scripts/clean.sh`; `swift test` green; app builds with the package linked. Commit.

### Task 4: Domain + data — model, repository, mapper, use case

**Files:**
- Create: `Sources/FeatureAppointments/domain/model/Appointment.swift`, `domain/repository/AppointmentsRepository.swift`, `domain/usecase/SaveAppointmentUseCase.swift`, `data/AppointmentMapper.swift`, `data/AppointmentsRepositoryImpl.swift`
- Test: `Tests/FeatureAppointmentsTests/{AppointmentMapperTests,AppointmentsRepositoryImplTests,SaveAppointmentUseCaseTests,FakeAppointmentsRepository}.swift`

**Kotlin source:** `feature/appointments/.../domain/model/Appointment.kt`, `domain/repository/AppointmentsRepository.kt`, `data/{AppointmentMapper,AppointmentsRepositoryImpl}.kt`, `domain/usecase/SaveAppointmentUseCase.kt`. Depends on Task 1 (`LocalDateTime`) and Task 2 (DAO).

**Interfaces (produces):**
- `public struct Appointment: Equatable, Hashable, Sendable { id, title, doctorName: String?, specialty: String?, location: String?, notes: String?, startsAt: LocalDateTime, timeZone: TimeZone, durationMinutes: Int, status: AppointmentStatus, reminderOffsetsMinutes: [Int] }`, `static let defaultDurationMinutes = 60`.
- `public protocol AppointmentsRepository: Sendable { observeUpcoming(from: Date) -> AsyncThrowingStream<[Appointment], any Error>; observePast(before: Date) -> …; getAppointment(id:) async throws -> Appointment?; observeAppointment(id:) -> AsyncThrowingStream<Appointment?, any Error> (emits nil when gone); getScheduledAppointments() async throws -> [Appointment]; saveAppointment(_:) async throws; deleteAppointment(id:) async throws }`.
- Mapper (internal, pure): `AppointmentRecord.toDomain(reminders:)` — `LocalDateTime(isoLocalString:)`, `TimeZone(identifier:)` (unknown id → throw `IllegalTimeZoneError`, the Vitals precedent), `AppointmentStatus(rawValue:)`, offsets = `reminders.filter(\.enabled).map(\.offsetMinutes).sorted()`; `Appointment.toRecord(profileId:createdAtEpochMs:updatedAtEpochMs:)` — `startsAtLocal = startsAt.isoLocalString`, `startsAtEpochMs = startsAt.instant(in: timeZone).epochMilliseconds`, `status = rawValue`; `Appointment.toReminderRecords()` — id `"\(id):\(offset)"`, `enabled = true`.
- `AppointmentsRepositoryImpl(appointmentDao:profileId: String = SalusDatabase.defaultProfileId, reminderScheduler: any ReminderScheduler, clock: any SalusClock)` — `observeUpcoming/Past`: merge the DAO's appointment stream with `observeRemindersForProfile` (latest-of-both, group by `appointmentId`) exactly as Kotlin's `combine`; `observeAppointment`: `observeById` × `observeRemindersFor`; `getScheduledAppointments`: early-return on empty, one batched reminder fetch; `saveAppointment`: `now = clock.nowEpochMilliseconds()`, `createdAt = existing?.createdAtEpochMs ?? now`, `upsertWithReminders`, then **`reminderScheduler.requestSync()`**; `deleteAppointment`: `deleteById` then `requestSync()`.
- `SaveAppointmentUseCase(repository:idGenerator:clock:)`, `callAsFunction(existingId: String?, title: String, doctorName: String?, location: String?, notes: String?, dateEpochDay: Int?, minuteOfDay: Int?, reminderOffsetsMinutes: [Int]) async throws -> Result`; `enum Result: Equatable, Sendable { saved(Appointment), missingTitle, missingDateTime }`. Rules verbatim from the Kotlin block: trimmed empty title → `.missingTitle` (checked first); nil date or minute → `.missingDateTime`; `""`-after-trim optionals → nil; `specialty`, `durationMinutes` (default 60), `status` (default `.scheduled`) carried from the existing row, never from input; `timeZone = clock.timeZone()`; offsets `filter >= 0 → distinct → sorted`.

- [ ] Port the three Kotlin test tables by name (mapper 4 · repository 4 with a `RecordingReminderScheduler` and the **real** `AppointmentDao` over `SalusDatabase.inMemory` — the template's RepositoryImpl standard · use case 4 with `FakeAppointmentsRepository`, zone default `Europe/Istanbul`).
- [ ] `swift test` green. Commit.

### Task 5: `AppointmentReminderHandler` + notification texts

**Files:**
- Create: `Sources/FeatureAppointments/reminder/{AppointmentReminderHandler,AppointmentNotificationTexts,LocalizedAppointmentNotificationTexts}.swift`
- Test: `Tests/FeatureAppointmentsTests/AppointmentReminderHandlerTests.swift`

**Kotlin source:** `reminder/{AppointmentReminderHandler,AndroidAppointmentNotificationTexts}.kt`. Depends on Task 4. Consumes `SalusReminder.ReminderHandler` (`type`, `occurrencesBetween(from:until:)`, `notificationContent(for:)`, default `onAction`), `ReminderOccurrence(entityId:occurrenceKey:triggerAt:)`, `ReminderNotificationContent(title:text:)` (actions empty, presentation `.notification` by default — appointments are never alarms, §6.1/M11 decision).

**Interfaces (produces):**
- `public protocol AppointmentNotificationTexts: Sendable { func title(appointmentTitle: String) -> String; func body(startsAt: LocalDateTime, doctorName: String?, location: String?) -> String }`; `LocalizedAppointmentNotificationTexts` = `AppointmentsStrings.notificationTitle` + `startsAt.formatted(pattern: "d MMM yyyy, HH:mm")` followed by the non-blank of `[doctorName, location]` joined with `" · "`.
- `public struct AppointmentReminderHandler: ReminderHandler` `(repository:clock:texts:)`, `type = .appointment`; `occurrencesBetween`: for each `getScheduledAppointments()` entry, `start = startsAt.instant(in: clock.timeZone())` (the **current** zone, not the stored one — Kotlin does the same), skip the whole appointment when `start < from`, else one occurrence per offset with `triggerAt = start − offset·60 s` when `from <= triggerAt < until`; `occurrenceKey = "\(id)|\(offset)"` (**pipe**, unlike the reminder-row id's colon); `notificationContent`: nil when the appointment is gone, `status != .scheduled`, or `start < clock.now()`.

- [ ] Port the 8-case table by name (type · each offset with stable keys · outside-window excluded · past produce none · deterministic across calls · nil for deleted · nil for past/non-scheduled · uses feature texts).
- [ ] `swift test` green. Commit.

### Task 6: `SalusUI` additions — chips, section header, date/time fields

**Files:**
- Create: `Packages/SalusUI/Sources/SalusUI/component/{SalusFilterChip,SalusStatusChip,SalusSectionHeader,SalusDateField,SalusTimeField}.swift`
- Modify: `FeatureVitals/ui/editor/EditorDateField.swift` → **deleted**; `WeightEditorScreen.swift` uses `SalusDateField`; `EditorMeasuredAtTests` untouched (pure)
- Test: `Packages/SalusUI/Tests/SalusUITests/SalusTimeFieldTests.swift` (binding arithmetic only — views are `#Preview` build)

**Android reference:** Material `FilterChip` (`AppointmentEditorScreen.kt` reminder row), `SalusStatusChip(label, SalusStatus.Neutral)`, `SalusSectionHeader` and `SalusPillButton` in `core/designsystem`. **`SalusPillButton` gets no component**: map it to `Button` + `.buttonStyle(.borderedProminent)` (filled) / `.bordered` (tonal) + `.buttonBorderShape(.capsule)` + `.frame(maxWidth: .infinity)`, and add that line to the template's mapping table in Task 11. Independent of Tasks 1–5 → parallel implementer.

**Interfaces (produces):**
- `SalusFilterChip(label: String, isSelected: Bool, action: () -> Void)` — capsule, 32 pt tall, selected = accent-tinted fill + checkmark, unselected = outlined, `accessibilityAddTraits(.isButton)`, `.isSelected` when on.
- `SalusStatusChip(label: String, accent: FeatureAccent? = nil)` — non-interactive twin for status/offset labels.
- `SalusSectionHeader(title: String)` — `titleSmall`, secondary color, `SalusSpacing.sm` top padding.
- `SalusDateField(title: String, epochDay: Int?, placeholder: String, onChange: (Int) -> Void)` — `EditorDateField` moved verbatim (GMT-bound `DatePicker(displayedComponents: .date)` through `epochDay × 86 400`), plus a nil state that shows `placeholder` until the first pick.
- `SalusTimeField(title: String, minuteOfDay: Int?, placeholder: String, onChange: (Int) -> Void)` — the same trick with `.hourAndMinute`: `Date(timeIntervalSince1970: minuteOfDay × 60)` in `.gmt`, returns `Int(interval / 60) % 1440`.

- [ ] TDD the time-field binding (0 ↔ 00:00, 1439 ↔ 23:59, nil shows placeholder), build previews, migrate Vitals, `swift test` green in `SalusUI` + `FeatureVitals`, app builds. Commit.

### Task 7: Navigation, module factory, list screen

**Files:**
- Create: `Sources/FeatureAppointments/navigation/AppointmentsNavigation.swift`, `AppointmentsModule.swift`, `ui/list/{AppointmentsUiState,AppointmentsViewModel,AppointmentsScreen}.swift`, `ui/CancellationBox.swift` (copy of the Vitals helper — the template allows this one duplicate)
- Test: `Tests/FeatureAppointmentsTests/{AppointmentsViewModelTests,FakeNavigator,TestDeletes,WaitUntil}.swift` (fakes copied from `FeatureVitalsTests`)

**Kotlin source:** `navigation/AppointmentsNavigation.kt`, `di/AppointmentsModule.kt`, `ui/list/*`, `ui/AppointmentFormatting.kt`. Depends on Tasks 3–6.

**Interfaces (produces):**
- Keys: `public struct AppointmentsKey: Hashable, Sendable`, `AppointmentDetailKey(id: String)`, `AppointmentEditorKey(id: String?)`; `public extension View { func appointmentsDestinations() -> some View }` registering detail + editor routes (`VitalsNavigation.swift` pattern; no callbacks — the feature has no cross-feature moves).
- `@MainActor public struct AppointmentsModule { repository: any AppointmentsRepository; navigator: Navigator; reminderHandler: any ReminderHandler; makeSaveAppointmentUseCase: @MainActor () -> SaveAppointmentUseCase; makeAppointmentsViewModel: @MainActor () -> AppointmentsViewModel; makeAppointmentDetailViewModel: @MainActor (String) -> AppointmentDetailViewModel; makeAppointmentEditorViewModel: @MainActor (String?) -> AppointmentEditorViewModel }`; `@MainActor public func makeAppointmentsModule(appointmentDao:profileRepository:reminderScheduler:clock:idGenerator:pendingDeletes:snackbar:navigator:) -> AppointmentsModule`; `EnvironmentValues.appointmentsModule: AppointmentsModule?`. This task ships the struct with `repository`, `navigator`, `reminderHandler`, `makeSaveAppointmentUseCase` and `makeAppointmentsViewModel` only; Tasks 8 and 9 each **add** their own `make…ViewModel` member and its factory line (no placeholder members, no `fatalError`).
- `AppointmentsUiState { isLoading = true; upcoming: [AppointmentDaySection]; past: [AppointmentListItem]; isPastExpanded = false; todayEpochDay = 0; var hasNothing }`, `AppointmentListItem { id, title, doctorName?, location?, startsAt: LocalDateTime }`, `AppointmentDaySection { epochDay: Int; items }`, `AppointmentsEvent.togglePastSection` (**Task 12 added `pendingDelete` plus `deleteRequested`/`deleteDismissed`/`deleteConfirmed`** — this line under-specified the state against `AppointmentsUiState.kt`), `offsetLabel(_ minutes: Int) -> String` (60 → hour, 1440 → day, else week — Kotlin's `offsetLabelRes`).
- `AppointmentsViewModel(repository:pendingDeletes:clock:)` (**Task 12 inserted `undoableDelete:` before `clock:`, Kotlin's order**) — `now = clock.now()` at start, merges `observeUpcoming(from: now)`, `observePast(before: now)` and `pendingDeletes.pendingIds` (`withObservationTracking` re-registration, `VitalsViewModel` pattern); pending ids filtered from both lists; upcoming grouped by `startsAt.date.epochDay` preserving repo order; `todayEpochDay = clock.todayEpochDay()`.
- Screen (`AppointmentsRoute` public + `AppointmentsScreen` internal): `SalusScreenHeader(title:)`, `ProgressView` while loading, `SalusEmptyState(systemImage: "calendar", title: empty, accent: .appointments, actionLabel: add, onAction:)` when `hasNothing`, else `ScrollView` + `LazyVStack(pinnedViews: .sectionHeaders)`: `appointments_no_upcoming` line when upcoming is empty; per day a pinned header (`Bugün`/`Yarın`/`"EEEE, d MMMM"`), `SalusCard` rows (**Task 12: not `SalusCard(onTap:)` — the row gained a trash `Button`, so it follows `VitalsRow`'s disjoint-targets shape**): time `"HH:mm"` in the appointments accent, 64 pt wide; title; `person` / `mappin.and.ellipse` detail rows when present; trailing trash button. Past block: `appointments_past_header(count)` + show/hide `Button`, rows only when expanded. `SalusFab("plus")` bottom-trailing, 16 pt; bottom content padding 88. Row tap → `navigator.navigate(AppointmentDetailKey(id:))`; FAB/empty action → `AppointmentEditorKey(id: nil)`.

- [ ] Port the 4-case VM table by name; `#Preview` for empty/loaded/expanded. **The Kotlin table holds 7, not 4** — the count here was wrong, and the three delete cases it hid were ported by Task 12. `swift test` green, app builds (tab still placeholder until Task 10). Commit.

### Task 8: Calendar bridge + detail screen

**Files:**
- Create: `ui/calendar/{CalendarEventDraft,CalendarEventEditSheet}.swift`, `ui/detail/{AppointmentDetailUiState,AppointmentDetailViewModel,AppointmentDetailScreen}.swift`
- Modify: `AppointmentsModule.swift` (add `makeAppointmentDetailViewModel`)
- Test: `Tests/FeatureAppointmentsTests/{AppointmentDetailViewModelTests,FakeProfileRepository,CalendarEventDraftTests}.swift`

**Kotlin source:** `ui/detail/*`. Depends on Task 7. Consumes `ProfileRepository.observeProfile() -> AsyncThrowingStream<Profile?, any Error>`, `UndoableDelete.callAsFunction(_:message:commit:)`.

**Interfaces (produces):**
- `struct CalendarEventDraft: Equatable, Sendable { title: String; notes: String?; location: String?; start: Date; end: Date }` — pure, the twin of the intent extras.
- `CalendarEventEditSheet(draft:onDismiss:)` — `UIViewControllerRepresentable` over `EKEventEditViewController` with `eventStore = EKEventStore()`, a prefilled `EKEvent`, `editViewDelegate` finishing on any action. **iOS 17+ needs no calendar authorization to present this controller** (WWDC23 "Discover Calendar and EventKit"); the executor verifies on the simulator that the sheet appears without a prompt, and only if it does not adds `NSCalendarsWriteOnlyAccessUsageDescription` (tr/en `InfoPlist.strings`) + `requestWriteOnlyAccessToEvents()` and records it. Whole file under `#if canImport(EventKitUI)`; the Screen's fallback branch on other platforms is an empty view.
- `AppointmentDetailUiState { isLoading = true; appointment: Appointment?; healthNotes: String?; startEpochMs: Int64 = 0; endEpochMs: Int64 = 0; showDeleteConfirm = false }`; events `deleteClicked/deleteDismissed/deleteConfirmed`.
- `AppointmentDetailViewModel(appointmentId:repository:profileRepository:navigator:undoableDelete:clock:)` — merges `observeAppointment(id:)` × `observeProfile()`; `healthNotes = profile?.healthNotes` non-blank else nil; `start = startsAt.instant(in: clock.timeZone())`, `end = start + durationMinutes·60 s`; `deleteConfirmed` → dialog off, `undoableDelete(id, message: AppointmentsStrings.deleted) { await repository.deleteAppointment(id:) }`, `navigator.pop()`.
- Screen: `.navigationTitle(appointment_detail_title)`; nil → `appointment_detail_missing`; sections in Android order — header card (title `headlineSmall`, `"EEEE, d MMMM yyyy"` in accent, `detailTime(time: "HH:mm", durationMinutes:)`, `doctorName · specialty` with `person`, `SalusStatusChip` only when `status != .scheduled`), **Location** (when non-blank: `SalusSectionHeader`, `mappin` row, "Haritalarda aç" `Button` → `openURL("maps://?q=<percent-encoded>")` — always shown, divergence (a)), **Notes** (hidden when both nil; `appointment_detail_health_notes` label + profile notes), **Reminders** (when offsets non-empty: label + wrapping row of `SalusStatusChip(offsetLabel)`), **Actions** (edit → `AppointmentEditorKey(id:)`; add to calendar, `.bordered`, disabled until `startEpochMs > 0`, presents `CalendarEventEditSheet` with `CalendarEventDraft(title:, notes: appointment.notes, location:, start:, end:)`; delete → `deleteClicked`). Delete dialog via `.salusConfirmDialog` (`deleteTitle(appointment.title)`, `appointment_delete_message`, `SalusUIStrings.delete` destructive / `.cancel`).

- [ ] Port the 7-case VM table by name (undo cases through `TestDeletes.undoLast()`; the "offers undo" case asserts `lastRequest?.actionLabel == SalusUIStrings.undo` and `duration == .milliseconds(5000)` — divergence (b)). `CalendarEventDraftTests`: detail draft carries `notes` only.
- [ ] Manual on simulator: open detail, tap "Takvime ekle", the system sheet appears prefilled; Save lands in the simulator Calendar; Cancel is harmless. Note the authorization outcome in the execution record.
- [ ] `swift test` green, app builds. Commit.

### Task 9: Editor screen

**Files:**
- Create: `ui/editor/{AppointmentEditorUiState,AppointmentEditorViewModel,AppointmentEditorScreen}.swift`
- Modify: `AppointmentsModule.swift` (add `makeAppointmentEditorViewModel`)
- Test: `Tests/FeatureAppointmentsTests/AppointmentEditorViewModelTests.swift`

**Kotlin source:** `ui/editor/*` (`ReminderOffsets` object, state, events, effect). Depends on Tasks 7–8 (calendar draft/sheet). Parallel-safe with Task 8 only if the implementer stubs `CalendarEventDraft` locally — prefer sequential.

**Interfaces (produces):**
- `enum ReminderOffsets { static let oneHour = 60, oneDay = 1440, oneWeek = 10080; static let options = [60, 1440, 10080] }`.
- `AppointmentEditorUiState { isNew = true; titleText = ""; doctorText = ""; locationText = ""; notesText = ""; dateEpochDay: Int?; minuteOfDay: Int?; selectedOffsets: [Int] = []; isSaving = false; showMissingTitle = false; showMissingDateTime = false; showDeleteConfirm = false }`; events `titleChanged/doctorChanged/locationChanged/notesChanged(String)`, `dateSelected(Int)`, `timeSelected(Int)`, `reminderOffsetToggled(Int)`, `saveClicked`, `deleteClicked/deleteDismissed/deleteConfirmed`, `addToCalendarClicked`; `enum AppointmentEditorEffect: Equatable { case addToCalendar(CalendarEventDraft) }` exposed as `private(set) var pendingEffect` + `consumeEffect()` (ReminderHealth pattern — **never** navigation).
- `AppointmentEditorViewModel(appointmentId:repository:saveAppointment:clock:navigator:undoableDelete:)` — create mode: `dateEpochDay = clock.todayEpochDay()`, `selectedOffsets = [1440]`, `minuteOfDay = nil`; edit mode: `getAppointment` preloads every field, `minuteOfDay = startsAt.minuteOfDay`; title/date/time edits clear their flags; toggle add/remove then sort; `saveClicked` → `isSaving`, use case with raw texts → `.saved` pops, errors reset `isSaving` + flag; `deleteConfirmed` only with an id → `undoableDelete` + pop; `addToCalendarClicked` requires date+time → draft with `start = LocalDateTime(date:minuteOfDay:).instant(in: clock.timeZone())`, `end = start + (loaded?.durationMinutes ?? 60)·60 s`, `notes = [doctorText, notesText].trimmed non-empty joined "\n"` (divergence (d)), `location` trimmed-or-nil.
- Screen: `.navigationTitle(new/edit)`, trailing **trash toolbar item only when `!isNew`**; fields in Android order — title (`.roundedBorder`, error text `appointments_missing_title`, `.textInputAutocapitalization(.words)`), doctor (`.textContentType(.name)`), location, `SalusDateField` + `SalusTimeField` side by side with `appointments_missing_datetime` beneath, `SalusFilterChip` row for the three offsets, notes (`axis: .vertical`, `.lineLimit(2...6)`, sentences), "Takvime ekle" `.bordered` **only when `!isNew`** and enabled with date+time, full-width save `.borderedProminent` disabled while saving. Effect consumed in the Route → presents `CalendarEventEditSheet`. No unsaved-changes guard (Android has none).

- [ ] Port the 7-case VM table by name (the calendar case asserts the draft's fields from edited text, doctor+notes joined).
- [ ] `swift test` green, app builds. Commit.

### Task 10: App wiring — composition root, tab, handler registration, deep link

**Files:**
- Modify: `App/AppCompositionRoot.swift` (`let appointmentsModule: AppointmentsModule`; `makeReminderGraph` takes the appointment handler: `ReminderHandlerRegistry(all: debugHandlers(clock:) + [appointmentHandler])` — build order: DAO → module → graph, or pass a `ReminderScheduler` proxy; the handler needs only the repository, the repository needs the scheduler → build `BackgroundRefreshScheduler` first, hand it to `makeAppointmentsModule`, then register `module.reminderHandler` before the synchronizer is constructed), `App/RootView.swift` (`case .appointments:` stack with `AppointmentsRoute().appointmentsDestinations()` and `.environment(\.appointmentsModule, root.appointmentsModule)` on the stack; `openTappedReminder()` pushes `AnyNavKey(AppointmentDetailKey(id: ref.entityId))` when `ref.type == .appointment` after `switchTopLevel` — decision (2)), `App/RootTab.swift` (label stays the placeholder until M8's `nav_*` catalog; note it)
- Test: `Packages/SalusReminder` untouched; wiring is proven by build + the manual script. Add `AppCompositionRootTests` **only if** one already exists.

- [ ] Wire, build Debug + Release configurations (`scripts/build-app.sh`), launch on the simulator: Appointments tab shows the empty state; create → list → detail → edit → delete/undo round trip; a saved appointment with three offsets yields three `UNUserNotificationCenter` pending requests (inspect through the M3 debug path or `log show`) with `userInfo.occurrenceKey == "<id>|<offset>"`; a tapped notification lands on the detail screen — drive it with `xcrun simctl push <udid> com.alicansekban.salus payload.apns` carrying the same `userInfo` keys the gateway writes (`type: "APPOINTMENT"`, `entityId`, `occurrenceKey`); the delegate's `didReceive` path is identical for remote and local requests, so this exercises the router without waiting 61 minutes.
- [ ] Commit `feat(app): host the Appointments tab, register its reminder handler, deep-link its notifications`.

### Task 11: Acceptance sweep + execution record + manual QA script

**Files:**
- Modify: this plan (execution record: divergences (a)–(e) + decisions (1)–(4), deferred findings, Android follow-ups), `docs/ios-feature-template.md` (add: `SalusPillButton` → `Button` styles line; `LocalDateTime` now lives in `SalusModel`; `SalusDateField`/`SalusTimeField`/`SalusFilterChip` in the mapping table; EventKitUI `#if canImport` rule), `salus-android/docs/ios-v1-plan.md` **is not touched** — Android follow-ups are listed here for the user
- Create: `scripts/m4-manual-qa.md` (self-serve manual script: CRUD round trip, offsets → pending requests, notification tap deep link, add-to-calendar sheet, maps link, undo window)

**Acceptance (milestone from spec §10, iOS-M4):** *CRUD, multiple reminder offsets, EventKit "add to calendar".* Evidence table: one automated pointer per Android test table (7 files / 38 names verified against the files — **the real denominator is 41; the three the count missed were ported by Task 12**), plus the manual script's tick marks.

**Android follow-ups to hand over (start numbering after the last taken `A` in §11 — re-check, M2 and M3 both found their assumed numbers used):** (i) notification tap should deep-link to the appointment detail (iOS does); (ii) unify the calendar payload — detail sends `notes`, editor sends `doctor + notes`; (iii) `appointments_upcoming_header`, `appointments_ok`, `appointments_cancel` are dead string keys; (iv) the iOS-only `LocalDateTime` ISO/`instant(in:)` cases and the DAO partition/cascade cases have no Android twin (same shape as A8/M3's note).

- [x] `scripts/ci.sh` green end to end + Release build; ledger updated; memory note for the next session (M5 prerequisites: M3a device list + `scripts/m3-manual-qa.md` before M5, per the M3 record).

---

## Self-review notes (written at planning time)

- **Spec coverage:** CRUD (T2/T4/T7/T8/T9), multiple reminder offsets end to end (T4 storage, T5 occurrences, T9 chips, T10 registration), EventKit add-to-calendar (T8/T9), §8 "rows open a detail" (T7), §6.1 "appointment reminder stays a standard notification" (T5 — no `presentation` override), banned-claims scan (T3), template compliance (T3/T7–T9), the M3 prerequisite (T0), the two lifts the previous milestones scheduled for "the second consumer" (T1/T6).
- **Parallelism:** T1 ∥ T2 ∥ T3 ∥ T6 after T0; T4 after T1+T2+T3; T5 after T4; T7 after T3–T6; T8 then T9; T10 after T9; T11 last.
- **Type consistency checked:** `LocalDateTime(date:minuteOfDay:)`, `.instant(in:)`, `.isoLocalString`; `AppointmentsRepository` method names identical in T4/T5/T7–T9; module closure names in T7/T8/T9; key names `AppointmentDetailKey(id:)`/`AppointmentEditorKey(id:)` in T7/T8/T9/T10.
- **Not in scope:** Home's "upcoming appointment" card (M7), the `nav_appointments` tab label (M8 hub strings), appointment status editing (Android has none — status only ever changes by migration/backup), Critical Alerts/alarms for appointments (rejected by the M11 decision).

---

## Execution record (2026-08-25)

Executed subagent-driven on branch `m4-appointments` off `main` at `5396254`: one Opus implementer
per task, an independent reviewer per task, a scoped re-review after each fix round. Unlike iOS-M3,
work **did** run in parallel — the pre-flight scan (in the ledger) cleared T1 ∥ T2 ∥ T3 ∥ T6, each in
its own worktree on `m4-appointments-tN`, rebased onto the branch before review — and T10 ∥ T10b ran
in parallel once the files were known to be disjoint. **Four** of the twelve tasks passed review
first time (3, 5, 10, 10b); the other **seven** implementation tasks passed after exactly one fix
round each (1, 2, 4, 6, 7, 8, 9). Task 0 was executed by the controller. Twenty commits carry the
plan and Tasks 0-10b (`c05e182..ccd66b6`); Task 11 adds this record, `scripts/m4-manual-qa.md` and
the two owed doc edits.

Two controller sessions were lost to restarts (during Task 9's review and during Task 10's
implementation); both agents resumed from their transcripts and the T10 worktree's uncommitted
wiring survived. Neither is a fix round and neither is counted as one.

Three tasks were added to the plan during execution:

- **Task 10b** — a *pre-existing iOS-M3 crash*, not M4 work. Tapping any notification killed the app:
  `ReminderNotificationDelegate.userNotificationCenter(_:didReceive:)` was spelled `async`, so it
  resumed off the main thread and UIKit's thunk asserted *"Call must be made on main thread"*.
  Reproduced on the branch base, so it predates every M4 commit. It was fixed inside this milestone
  because decision (2) — a tapped appointment notification opens the detail — cannot be true while
  the tap crashes.
- **`ReminderSchedulerRelay`** (inside Task 10) — the composition-root cycle the pre-flight scan
  predicted, resolved as ruling 5 below.
- **Task 12** — the parity fix for divergence (p), which the Task 11 sweep found: the appointments
  list's per-row delete, and the three Kotlin cases the plan's 4-case count had hidden. Added rather
  than deferred, because the alternative was carrying an unrecorded-difference bug into iOS-M5.

### `scripts/ci.sh`, run end to end on the Task 11 worktree

```
# 1/5  toolchain    ==> Toolchain matches README.md.        (Xcode 26.4.1 / 17E202, SwiftLint 0.65.0, SwiftFormat 0.62.1)
# 2/5  lint         0/292 files require formatting, 11 files skipped.
                    Done linting! Found 0 violations, 0 serious in 292 files.
# 3/5  custom rules PASS  no_ui_framework_in_domain fired on Packages/SalusModel/…/LintFixtureDoNotCommit.swift
                    PASS  no_ui_framework_in_domain stayed quiet on Packages/SalusUI/…/LintFixtureDoNotCommit.swift
                    PASS  no_charts_in_features fired on Packages/Features/FeatureVitals/…/LintFixtureDoNotCommit.swift
                    PASS  no_charts_in_features stayed quiet on Packages/SalusUI/…/LintFixtureDoNotCommit.swift
                    ==> every custom rule fired in scope and stayed quiet outside it.
# 4/5  test         ==> summary: 24/24 packages passed          (536 tests)
# 5/5  build        ** BUILD SUCCEEDED **
==> CI pipeline passed.
```

**536 tests across 24 packages**, up from iOS-M3's 430. Where the 106 new ones live:
`FeatureAppointments` 62 (new package), `SalusReminder` 97 (+5: the relay's 3 and the delegate's 2),
`SalusDatabase` 51 (+14, `AppointmentDaoTests`), `SalusModel` 61 (+`LocalDateTimeTests`),
`SalusCommon` 22 (+`LocalDateTimeInstantTests`), `SalusUI` 53 (+ the date/time field bindings).

The Release build the acceptance asks for is green too, and silent:
`xcodebuild … -configuration Release build` → `** BUILD SUCCEEDED **`, **0 warnings**.

### Acceptance evidence

iOS-M4's criterion from spec §10 is *CRUD, multiple reminder offsets, EventKit "add to calendar"*.
The plan's evidence contract was one automated pointer per Android test table — **7 Kotlin files,
38 names**, which the sweep corrected to **41** and Task 12 then closed — plus the manual script's
tick marks. Every name below was read out of the Swift file it
lives in, not copied from a task report.

| Kotlin table | iOS twin | Cases | Pointer |
| --- | --- | --- | --- |
| `data/AppointmentMapperTest.kt` | `AppointmentMapperTests.swift` | 4 ported (+2 iOS-only) | **`toRecord writes ISO local date-time and correct epoch cache`** — `starts_at_local` is `2026-08-24T14:30` with no offset and no zero seconds, and `starts_at_epoch_ms` is the same wall clock resolved in `tz_id`. Its inverse is **`record round trip preserves the domain model`**. Names carry divergence (m) — `toRecord`/`record` for Kotlin's `toEntity`/`entity` |
| `data/AppointmentsRepositoryImplTest.kt` | `AppointmentsRepositoryImplTests.swift` | 4 ported (+3 iOS-only) | **`save persists appointment with reminder rows and requests a sync`** and **`saving again replaces reminder rows and keeps createdAt`** — the whole-replacement contract the offsets depend on, over the **real** `AppointmentDao` on `SalusDatabase.inMemory` |
| `domain/usecase/SaveAppointmentUseCaseTest.kt` | `SaveAppointmentUseCaseTests.swift` | 4 ported | **`new appointment gets generated id and normalized fields`** (offsets `filter { $0 >= 0 }` → distinct → sorted) and **`update preserves id duration status and specialty`** — the three fields no editor can touch |
| `reminder/AppointmentReminderHandlerTest.kt` | `AppointmentReminderHandlerTests.swift` | 8 ported (+3 iOS-only) | **`occurrences apply each offset with stable keys`** — the *multiple reminder offsets* criterion at its source: one `ReminderOccurrence` per enabled offset, key `"<id>\|<offset>"`, stable across calls (**`occurrence computation is deterministic across calls`**) and clipped by the window (**`triggers outside the window are excluded`**) |
| `ui/list/AppointmentsViewModelTest.kt` | `AppointmentsViewModelTests.swift` | 7 of 7 (+1 iOS-only) | **`upcoming sorted soonest first and past collapsed by default`** and **`upcoming is grouped into one section per calendar day`**; the row-delete flow the sweep found unported and Task 12 closed — **`delete request asks for confirmation and dismissing it deletes nothing`**, **`confirmed delete hides the row at once and writes when the undo window closes`**, **`undo within the window brings the row back without a write`** (divergence (p)) |
| `ui/detail/AppointmentDetailViewModelTest.kt` | `AppointmentDetailViewModelTests.swift` | 7 ported | **`calendar bounds come from the wall-clock start and the duration`** — the EventKit criterion's data half; **`confirming defers the write, closes the screen and offers undo`** and **`undo cancels the deletion the popped screen started`** — delete + undo |
| `ui/editor/AppointmentEditorViewModelTest.kt` | `AppointmentEditorViewModelTests.swift` | 7 ported | **`add to calendar emits intent data derived from the edited fields`** — the EventKit criterion from the editor, asserting the draft off *unsaved* text; **`new editor defaults to today with one-day reminder preselected`** pins the `1440` default |

**41 names ported by name.** The plan contracted 38, and the sweep found the denominator was
never 38: the Kotlin list-VM file holds **7** cases, not the 4 the plan's table counted, and the
extra three are its row-delete flow — see divergence (p). Task 12 ported them, so the seven Kotlin
files are now 41 of 41. Nothing in them is unported.

The iOS-only rows, which have no Kotlin twin and are the Android follow-up in item 5 below:

| Criterion | Evidence | Where |
| --- | --- | --- |
| **CRUD — the storage half** | **`upsertWithReminders replaces the reminder rows it finds`**, **`deleting appointment cascades its reminders`** (FK on), **`observeUpcoming lists the scheduled appointments from the instant onward, soonest first`** / **`observePast lists what already started or is no longer scheduled, newest first`** (a `COMPLETED` *future* appointment lands in *past*), **`getRemindersForAppointments answers empty for an empty id list`** (no malformed `IN ()`) | `AppointmentDaoTests` (14 cases, `SalusDatabase`) |
| **CRUD — malformed rows** | **`an unresolvable stored time zone id throws`**, **`a stored value the platform cannot read throws`** — `MalformedAppointmentRecordError`, divergence (n); Kotlin throws implicitly | `AppointmentMapperTests` |
| **Wall-clock fidelity** | **`it writes what kotlinx.datetime's toString() writes`** and **`it reads back everything it writes`**; **`a wall-clock reading names one instant in its zone`**, **`a reading the spring-forward skips resolves forward, as java.time does`**, **`SalusClock.instant(of:minuteOfDay:) forwards to it, in the clock's zone`** | `LocalDateTimeTests` (`SalusModel`), `LocalDateTimeInstantTests` (`SalusCommon`) |
| **Multiple offsets — the stream half** | **`saving while observing settles on the new reminder offsets`**, and the combinator under it: **`nothing is emitted until both sides have a value`**, **`a slow transform never overwrites a fresher pair`**, **`a failure on either side fails the combined stream`** — divergence (i) | `AppointmentsRepositoryImplTests`, `LatestOfBothTests` |
| **Multiple offsets — the list half** | **`pending deletes hide rows in both lists and undo brings them back`** — the `withObservationTracking` re-registration, mutation-verified at review | `AppointmentsViewModelTests` |
| **EventKit — the payload** | **`the detail draft describes the event with the appointment's notes alone`**, **`the editor draft describes the event with the doctor and the notes`** (divergence (d), verbatim from Kotlin), **`the detail draft spans the appointment's duration`** | `CalendarEventDraftTests` |
| **The maps link** | **`the maps link percent-encodes the location it searches for`** and **`the maps link encodes the query separators a clinic name can contain`** — the second one is RED on `.urlQueryAllowed` and is why divergence (a)'s allow-set is unreserved-only | `MapsLinkTests` |
| **Notification copy** | **`body renders the start with the Android pattern in the given locale`**, **`body appends the doctor and the location in order`**, **`body drops blank details`** | `AppointmentReminderHandlerTests` |
| **The date/time components** | **`nothing picked and the picker closed draws the placeholder button`**, **`opening the picker shows the wheel at the seed, and records nothing`**, **`a chosen time binds the field, whether or not the picker was opened`**, **`midnight is a chosen time, not an absent one`** | `SalusTimeFieldTests` (`SalusUI`); `SalusDateFieldTests` alongside |
| **The wiring** | **`a call before binding is dropped rather than buffered`**, **`a call after binding reaches the target`**, **`rebinding replaces the target`** — `ReminderSchedulerRelay`, ruling 5 | `ReminderSchedulerRelayTests` (`SalusReminder`) |
| **The tap that used to crash** | **`the completion handler is called on the main thread, whatever executor the reaction ran on`** and **`a payload that names no occurrence still finishes the response`** — Task 10b | `ReminderNotificationDelegateTests` |
| **Strings** | 46 keys, TR source + EN, the `@Test(arguments:)` verbatim table, every accessor asking for a carried key, the four format keys rendering the Android sentence, and `BannedHealthClaims` repo-wide | `AppointmentsStringsTests` |

### Commits and review rounds per task

SHAs are the ones on `m4-appointments` after rebase, not the side-branch ones the reports quote.

| Task | Commits | Review |
| --- | --- | --- |
| 0 — `.public` → `.private` on error interpolations (M3 prerequisite) | 1 — `c05e182` | Controller-executed |
| — the plan itself | 1 — `1af30c4` | — |
| 1 — `LocalDateTime` → `SalusModel` | 2 — `fd54d09`, fix `e5381f6` | Approved, 1 Important → 1 round |
| 2 — `AppointmentDao` | 2 — `3a86489`, fix `2e2ffa9` | Approved, 1 Important → 1 round |
| 3 — package setup + the 46-key catalog | 1 — `a6bf81d` | Clean first time (one `NEEDS_CONTEXT` before starting — divergence (f)) |
| 4 — domain, data, mapper, use case | 2 — `f1b02dc`, fix `7f3d2dc` | Needs fixes (1 Important) → 1 round |
| 5 — `AppointmentReminderHandler` + texts | 1 — `6791e98` | Clean first time |
| 6 — `SalusUI` chips, section header, date/time fields | 2 — `c36bd45`, fix `c901e00` | Approved, 1 Important → 1 round |
| 7 — navigation, module factory, list screen | 2 — `6643a7c`, fix `44e38c1` | Approved, 1 Important → 1 round |
| 8 — calendar bridge + detail screen | 2 — `5d316ba`, fix `dcf650b` | Needs fixes (1 Important) → 1 round |
| 9 — editor screen | 2 — `e8dd210`, fix `7fb76f4` | Approved with fixes (1 Important) → 1 round |
| 10 — app wiring, tab, handler registration, deep link | 1 — `723fc50` | Clean first time |
| 10b — notification response on the main thread (M3 bug) | 1 — `ccd66b6` | Clean first time |
| 11 — this record, `scripts/m4-manual-qa.md`, the two doc edits | see the branch tip | — |
| 12 — list row delete (divergence (p)) + the three Kotlin cases | see the branch tip | — |

Two integration checks ran mid-flight — after T1/T2/T3/T6 merged (`e5381f6`) and after T4/T5/T7
(`44e38c1`) and T8/T9/T10 (`723fc50`) — each `24/24 packages passed`.

### Decisions and recorded divergences

The four decisions are the user's, taken on 2026-08-24 before dispatch. (a)-(n) were recorded as
they happened; (o) and (p) were added by this sweep.

**Decisions (Alican, 2026-08-24)**

1. **"Add to calendar" is a prefilled `EKEventEditViewController`** the user confirms, not a silent
   write. Verified on a simulator with a probe app during Task 8: with **no** calendar usage
   description in the plist, iOS 17+ shows the sheet and raises **no** permission prompt, because
   the editor is a separate process writing on the user's behalf. No plist change shipped.
2. **A tapped appointment notification switches to the Appointments tab and pushes
   `AppointmentDetailKey(id)`.** iOS-only: Android's notification opens the launcher.
3. **The reminder-offset multi-select is a new `SalusFilterChip` in `SalusUI`**, not a segmented
   picker — the M2 mapping table's "no chip component exists" line is retired with it.
4. **The detail screen ports "Doktora söylenecekler"** (the profile's `healthNotes`) now rather
   than deferring it to the profile milestone.

**Recorded divergences from Android**

- **(a) "Haritalarda aç" is shown whenever `location` is non-blank.** Android asks the package
  manager whether anything answers `geo:`; iOS has no equivalent question a sandboxed app may ask
  (`canOpenURL` needs the scheme declared and answers one scheme at a time) and Maps is not
  removable, so the row is unconditional. The URL is `maps://?q=…` and the encoding is the
  `Uri.encode` twin — `CharacterSet.salusUriEncodeAllowed`, **unreserved characters only**. Review
  caught `.urlQueryAllowed` here: it permits `& + = ? ; / ,`, so "Smith & Sons" would end the query
  value at the ampersand and "A+ Poliklinik" would arrive as "A Poliklinik".
- **(b) The delete snackbar auto-dismisses at `PendingDeleteController.undoWindowMillis`** (5000 ms)
  rather than living to Material's default. Settled in iOS-M2; Android still has the mismatch
  (follow-up A10, still open).
- **(c) Two pieces moved out of `FeatureVitals` for their second consumer.** `LocalDateTime` →
  `SalusModel`, gaining `isoLocalString`, `init?(isoLocalString:)`, a `minuteOfDay` precondition and
  `instant(in:)` (which lives in `SalusCommon/SalusClock.swift`, inside the existing `Calendar`
  carve-out rather than opening a new one). `EditorDateField` → `SalusUI.SalusDateField`, joined by
  `SalusTimeField` — whose `seedMinuteOfDay` is **required** and which commits nothing until the
  wheel actually moves, so a cancelled picker leaves the field empty exactly as the Compose dialog
  does.
- **(d) The calendar payload differs between the two screens, verbatim from Kotlin**: the detail
  sheet's body is `notes`; the editor sheet's is `doctor + "\n" + notes`. Ported as found rather
  than unified, with an Android follow-up to pick one.
- **(e) `EKEventEditViewController` replaces `ACTION_INSERT`.** The system sheet brings its own
  calendar chooser, so nothing on iOS replaces Android's intent picker — and nothing needs to.
- **(f) `appointment_status_scheduled` reads "Planlı" in Turkish, where Android uses the past
  participle.** The Android wording trips the banned stem `planlan`, and the stem list is a settled
  rule (this is why the word itself is not written out here). The key is never
  rendered — the chip is drawn only when `status != .scheduled`, and no screen can set a status —
  so this is a *temporary copy divergence*: Android owes the mirror rename. It is the only banned
  hit across 46 keys × 2 languages.
- **(g) `SalusSectionHeader` is the faithful core/ui port** (`titleLarge` / `onSurface`, optional
  trailing action), and the editor's "Hatırlatıcılar" label is therefore a plain `Text` at
  `titleSmall` / `onSurface` rather than a misuse of it. The plan had asked for the opposite on both
  counts; ruling 3 reversed it.
- **(h) The chips' metrics are Material 3 defaults, not tokens.** `design-tokens.md` has no chip
  entry at all, and the design-system rule forbids inventing values — so the numbers come from the
  same M3 defaults Compose would have applied, and the Android side owes the doc line.
  `SalusStatusChip` takes a `FeatureAccent?` rather than an `AppointmentStatus`: the success /
  warning / error tints are unported because iOS-M4 has no caller for them.
- **(i) `latestOfBoth` is the `combine` twin** (`data/LatestOfBoth.swift`), used by the repository,
  the list VM and the detail VM. The lock is held across **both** the transform and the yield — the
  first version yielded outside it, and review showed a slow transform could then make a stale pair
  the last emission, which Kotlin's `combine` cannot do.
- **(j) The past-section toggle republishes instead of restarting the observation.** `flatMapLatest`
  has no `@Observable` twin; behaviour-equivalent, and the toggle changes only what is rendered.
- **(k) `ReminderSchedulerRelay` breaks a cycle the composition root cannot otherwise resolve** —
  see ruling 5.
- **(l) Five feature-local duplicates, each sanctioned by the template**: `IllegalTimeZoneError`,
  `CancellationBox`, `FakeNavigator`, `TestDeletes`, `WaitUntil`. Features may not depend on each
  other, so the alternative is a core package for five files.
- **(m) Mapper test names say `toRecord` / `record` where Kotlin says `toEntity` / `entity`** — the
  types genuinely are `…Record` on iOS (records live in `SalusDatabase`), and the M2 Vitals
  `null`→`nil` rename is the precedent.
- **(n) `MalformedAppointmentRecordError` is thrown for a corrupt `starts_at_local` or `status`**
  where Kotlin throws implicitly out of `valueOf` / `parse`. A named error is diagnosable; the
  failure mode is identical.
- **(o) The notification-response delegate methods are the explicit completion-handler spellings,
  and the completion is called inside `MainActor.run`.** This is the Task 10b fix and it has **no
  Android twin at all** — the bug is a Swift-concurrency artifact of `UNUserNotificationCenter`'s
  `@objc` thunk, which asserts the main thread while an `async` delegate method may resume anywhere.
  Android's `onReceive` has no equivalent hazard. Recorded here because the file now differs from
  the shape iOS-M3 shipped. (`@MainActor` plus `@preconcurrency UNUserNotificationCenterDelegate`
  also compiles; the explicit hop was chosen as the more legible of the two.)
- **(p) The iOS appointment list had no row delete; Android's does. — CLOSED BY TASK 12, no
  divergence remains.** Found by the Task 11 sweep, not decided during execution.
  `AppointmentsScreen.kt:269-272` puts a trash `IconButton` on every row,
  wired to `AppointmentsEvent.DeleteRequested/DeleteDismissed/DeleteConfirmed`, and
  `AppointmentsViewModelTest.kt` pins that flow in three cases —
  `delete request asks for confirmation and dismissing it deletes nothing`,
  `confirmed delete hides the row at once and writes when the undo window closes`,
  `undo within the window brings the row back without a write`. The plan's Task 7 specified
  `AppointmentsEvent.togglePastSection` as the only event and counted the table at 4, so neither the
  implementer nor the reviewer had anything to compare against. **CRUD is still complete** — delete
  is reachable from the detail screen and from the editor, and the list's *pending-delete hiding*
  works (it is what `pending deletes hide rows in both lists and undo brings them back` covers) —
  so this was a missing affordance and three unported cases, not a broken criterion. Under the port
  rules an unrecorded difference is a bug, so rather than carry it as one, **Task 12 ported it**:
  `AppointmentsUiState.pendingDelete`, the three events, `AppointmentsViewModel(…, undoableDelete:,
  clock:)`, the row's trash `Button` and the list's `salusConfirmDialog`, plus the three Kotlin cases
  by name. Two shape notes, neither a behaviour difference: the row is a plain `SalusCard` with the
  open-gesture and the trash button as **siblings**, because `SalusCard(onTap:)` is a `Button` and a
  nested one would never receive the tap (`VitalsRow` settled this in iOS-M2); and Kotlin's
  `state.pendingDelete?.let { SalusConfirmDialog(…) }` becomes SwiftUI's `Binding<Bool>` alert, whose
  setter reports a system-driven dismissal back as `deleteDismissed`. No ruling is owed.

Anything else that differs from `:feature:appointments` is a bug, not a port decision.

### Rulings made during execution (decided on the user's behalf — read these)

In ledger order. Each says what it costs if it turns out to be wrong.

1. **Turkish "Planlı" now, Android mirrors later** (Task 3). The alternative was exempting the file
   from the banned-claims scan, which weakens a settled rule for a string nothing renders.
   *Cost if wrong:* one string differs between the platforms until Android mirrors it.
2. **`SalusSectionHeader` is the Kotlin component, not the brief's variant** (Task 6). The brief
   described a `titleSmall` group label; core/ui's `SalusSectionHeader.kt` is `titleLarge` with an
   action slot, and the 1:1 component-mirroring rule wins. *Cost if wrong:* none — it had zero
   callers when the ruling was made.
3. **`SalusTimeField` owns "no time chosen yet"** (Task 9). The first version let the editor seed
   09:00 on tap, which *committed* 09:00 the moment the wheel appeared — Kotlin keeps `null` until
   OK. The component gained a required `seedMinuteOfDay` and commits only on a wheel change.
   *Cost if wrong:* a little `SalusUI` churn; M5's medication editor is the next caller.
4. **The maps allow-set is unreserved-only** (Task 8). The dispatch instruction had said
   `.urlQueryAllowed` and was wrong. *Cost if wrong:* none.
5. **`ReminderSchedulerRelay` resolves the composition cycle** (Task 10). The registry is built
   inside `makeReminderGraph` together with the scheduler; the appointment handler needs the
   repository; the repository needs a `ReminderScheduler` — a cycle. The relay is a `Sendable final
   class` with a lock-guarded optional target: composition is relay → module(relay) →
   graph(handlers) → `relay.target = graph.scheduler`. It **drops** rather than buffers a call made
   before binding. *Cost if wrong:* one small indirection type, and a `requestSync` fired in that
   window is lost — covered by the foreground reconcile on the first `scenePhase == .active`.
6. **Task 10b is done inside this milestone rather than deferred** — decision (2) cannot be
   verified while the tap crashes, and the bug was already shipping. *Cost if wrong:* none; the M3
   path was broken either way.
7. **`AppointmentsModule` ships incrementally across T7/T8/T9** — each task *adds* its own
   `make…ViewModel` member rather than T7 shipping placeholders, and `appointmentsDestinations()`
   gains a destination per task (first lander replaces `self`, second chains). *Cost if wrong:* list
   taps push unregistered keys until T8/T9 land, and the tab is not wired until T10 anyway.
8. **Task 11 does the record, the script and the doc edits only; the `--ff-only` merge and the push
   are held for the user**, exactly as iOS-M3's ruling 6. *Why:* merging publishes a shared branch,
   and one acceptance item still needs a human finger. *Cost if wrong:* one extra user command.

### Deferred findings, verbatim from the ledger, grouped by task

None of these blocks iOS-M5. The whole-branch review triages them; Task 11 deliberately fixed none.

**Task 1 — `LocalDateTime` → `SalusModel`**
- `LocalDateTimeInstantTests.swift`'s name is stale: the source it was written against was folded
  into `SalusClock.swift`.
- `Date.epochMilliseconds` flooring is duplicated in `SalusModel`
  (`epochMillisecondsForWallClock`), with an agreement test rather than one implementation.

**Task 2 — `AppointmentDao`**
- No rollback-atomicity test for `upsertWithReminders`.
- Re-emission coverage exists for 1 of the 5 DAO streams.

**Task 3 — strings**
- `AppointmentsStringsTests.swift:7-8` and `:292` still say "verbatim" unqualified, which divergence
  (f) has made untrue for one key.
- `detailTime` builds its sentence with an inline `String(format:)` rather than the shared helper.

**Task 4 — domain and data**
- Two wall-clock-timed tests cost ~2.6 s between them and are CI flake candidates.
- `latestOfBoth`'s ordering invariant lives in prose above the type, not in a name.

**Task 5 — the reminder handler**
- About two thirds of the Kotlin line citations in `reminder/*` are off by 1-3 lines, and the test
  header declares those citations load-bearing.
- No case at `triggerAt == from` or `triggerAt == until` — the window boundaries themselves.
- `title(appointmentTitle:)`'s delegation is unasserted.
- The body renders the date through `Locale.current`, which can disagree with the TR fallback copy
  around it (Android-faithful).

**Task 6 — `SalusUI` additions**
- Chip metrics are un-tokenised (divergence (h)).
- `SalusStatus`'s success / warning / error tints are unported.

**Task 7 — list screen**
- The past-toggle button is `.plain` where Material draws `labelLarge`.
- `offsetLabel`'s default arm carries a TODO.

**Task 8 — calendar bridge and detail**
- `ChipFlowLayout` measures twice and never uses its `Cache` slot.
- `latestOfBoth` lives in `data/`; it is not data-layer-specific.
- `AppointmentDetailScreen.swift` is ~480 lines.
- `IconRow` sets font size 18 inside an 18 pt box.

**Task 9 — editor screen**
- `SalusTimeField`'s placeholder hard-codes `.bordered` (the `OutlinedButton` twin) instead of
  taking a style.
- The chip row is an `HStack` and does not wrap at large Dynamic Type; `ChipFlowLayout`, which
  would, is private to the detail screen. **→ `scripts/m4-manual-qa.md` §8.**
- The `.labelsHidden()` date/time pickers may compress on small devices. **→ §8.**
- `.words` autocapitalisation on the location field; no `ImeAction.Next` twin.

**Task 10 — app wiring**
- A tapped notification pushes the detail even when that detail is already on top (guard it when M5
  touches `openTappedReminder`).
- `ReminderNotificationDelegate.swift:53-55` carried a stale M3 comment (addressed in 10b).
- `AppCompositionRoot.init` is at the 60-line limit; M5 must restructure it.
- The comment at `AppCompositionRoot.swift:174-176` is hard to parse.

**Task 10b — the delegate fix**
- The `nonisolated(unsafe)` local could be a `@Sendable` completion parameter (verified exportable).
- The test fixture has no `.timeLimit` and no explicit once-count.
- `respond(to:)`'s overload naming.
- The unreadable-payload case is duplicated.
- Idea worth a rule: SwiftLint could reject the `async` `UNUserNotificationCenterDelegate` spelling
  outright, since it is a trap rather than a style choice.

### Android follow-ups opened by this milestone

`salus-android/` is read-only for the whole of iOS-M4 — its working tree has local commits the user
owns — so these are recorded here and written into `docs/ios-v1-plan.md` §11 by the user.
**A13 is the last number written into §11 today** (`VitalsViewModel`'s stale window). But iOS-M3's
record opened **three** follow-ups that have not been written in yet, so if those land first as
A14-A16 these start at **A17**. Re-check before writing: M2 and M3 both found their assumed numbers
already taken.

1. **A tapped appointment notification should open the appointment.** iOS switches tab and pushes
   the detail (decision 2); Android opens the launcher.
2. **Unify the calendar payload.** The detail sends `notes`, the editor sends `doctor + "\n" + notes`
   (divergence (d)). Pick one on both platforms.
3. **Mirror the "Planlı" rename** (divergence (f)), and — the bigger half — **`:feature:appointments`
   has no strings/banned-claims test at all**, which is why the stem survived there. Sweep the other
   unscanned modules for banned stems while opening it.
4. **One dead string key: `appointments_upcoming_header`.** Verified across `.kt` and `.xml` — it is
   declared in both `values/` and `values-en/` and referenced nowhere. *Correction to the plan's
   Task 11 note, which also listed `appointments_ok` and `appointments_cancel`: those two are live
   on Android* (`AppointmentEditorScreen.kt:347`, `:352`, `:381`, `:386` — the picker dialogs' own
   buttons), and so is `appointments_back`. All three are dead on **iOS** for structural reasons —
   SwiftUI's date/time sheets supply their own confirm/cancel and the shell owns the back button —
   which is a fact about the port, not an Android finding.
5. **The iOS-only test tables have no Android twin.** In the shape A8 tracks the M2 vitals tables:
   `LocalDateTime`'s ISO and `instant(in:)` tables; `AppointmentDao`'s partition, cascade and
   empty-`IN` cases; the mapper's malformed-record cases; the repository's `createdAt` / replacement
   / `latestOfBoth` ordering cases; the list VM's pending-id re-registration case; the handler's
   three body-rendering cases and the `content.presentation == .notification` assertion inside
   `notificationContent uses feature texts for upcoming appointment`
   (`AppointmentReminderHandlerTests.swift:155` — spec §6.1's "an appointment reminder stays a
   standard notification", which the Kotlin case does not check); `CalendarEventDraft`'s builders;
   `MapsLink`'s encoding.
6. **`design-tokens.md` has no chip specification.** Add the FilterChip / StatusChip values the iOS
   port had to take from Material 3 defaults (divergence (h)), so the next port is not guessing.
7. **`starts_at_epoch_ms` is recomputed on `TIME_SET` / `TIMEZONE_CHANGED` on Android; iOS has no
   twin.** A receiver does it there; here the partition queries read the cached column and it can go
   stale after a zone change. Decide: recompute on `NSSystemTimeZoneDidChange` (the M3 trigger
   already exists and already refills the reminder window) or accept the staleness and say so.

### Done criterion for iOS-M4

**CRUD, multiple reminder offsets, EventKit "add to calendar".**

| Half | State |
| --- | --- |
| Automated | **Met.** 38 Kotlin cases ported by name across the seven tables plus the iOS-only rows above; `scripts/ci.sh` green end to end — 24/24 packages, 536 tests, lint and custom-rule gates clean, `** BUILD SUCCEEDED **` — and the Release build green with 0 warnings. |
| Manual, executed | **Met, by Task 10 on a simulator** and written up in `scripts/m4-manual-qa.md`: the create → list → detail → edit → delete/undo round trip, the undo window in both directions, and the three occurrence keys `<id>\|60` / `<id>\|1440` / `<id>\|10080` in the alarm ledger (including the narrow seven-day band in which all three land inside the window at once). Task 8 measured the EventKitUI sheet appearing prefilled with **no** usage description and **no** permission prompt. Task 10b delivered the notification and saw the banner. |
| Manual, **pending the user's tap** | **One item: §4.2 of `scripts/m4-manual-qa.md` — tapping the notification banner and landing on the appointment's detail screen.** The push, the payload and the delegate path are all verified; the *tap* is not, because the build host has no Accessibility trust and `xcrun simctl` has no tap primitive. The payload recipe is in §4 verbatim. This is decision (2)'s only unproven step, and it is why the `--ff-only` merge is held for the user rather than done here. |

### Still owed, and by whom

- **The tap** — `scripts/m4-manual-qa.md` §4.2. One person, one simulator, one finger.
- **The rest of the manual script** — §5.4 (Save actually landing in the simulator's Calendar app),
  §7 (the maps link with `&` and `+` in the location), §8 (Dynamic Type on the chip row and the
  date/time pair), §10 (the TR/EN pass and the third-language fallback). None of them is load-bearing
  for the acceptance criterion; all of them are cheap.
- **The `--ff-only` merge and the push** (ruling 8).
- **Carried from iOS-M3, still open and still owed before M5 ships the medication handler**: the M3a
  on-device checklist (`scripts/m3-manual-qa.md` §9) and the simulator taps in its sections 2-7, plus
  the designed `salus_alarm.caf` asset.
