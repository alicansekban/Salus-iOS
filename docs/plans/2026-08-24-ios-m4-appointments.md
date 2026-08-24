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
- `AppointmentsUiState { isLoading = true; upcoming: [AppointmentDaySection]; past: [AppointmentListItem]; isPastExpanded = false; todayEpochDay = 0; var hasNothing }`, `AppointmentListItem { id, title, doctorName?, location?, startsAt: LocalDateTime }`, `AppointmentDaySection { epochDay: Int; items }`, `AppointmentsEvent.togglePastSection`, `offsetLabel(_ minutes: Int) -> String` (60 → hour, 1440 → day, else week — Kotlin's `offsetLabelRes`).
- `AppointmentsViewModel(repository:pendingDeletes:clock:)` — `now = clock.now()` at start, merges `observeUpcoming(from: now)`, `observePast(before: now)` and `pendingDeletes.pendingIds` (`withObservationTracking` re-registration, `VitalsViewModel` pattern); pending ids filtered from both lists; upcoming grouped by `startsAt.date.epochDay` preserving repo order; `todayEpochDay = clock.todayEpochDay()`.
- Screen (`AppointmentsRoute` public + `AppointmentsScreen` internal): `SalusScreenHeader(title:)`, `ProgressView` while loading, `SalusEmptyState(systemImage: "calendar", title: empty, accent: .appointments, actionLabel: add, onAction:)` when `hasNothing`, else `ScrollView` + `LazyVStack(pinnedViews: .sectionHeaders)`: `appointments_no_upcoming` line when upcoming is empty; per day a pinned header (`Bugün`/`Yarın`/`"EEEE, d MMMM"`), `SalusCard(onTap:)` rows: time `"HH:mm"` in the appointments accent, 64 pt wide; title; `person` / `mappin.and.ellipse` detail rows when present. Past block: `appointments_past_header(count)` + show/hide `Button`, rows only when expanded. `SalusFab("plus")` bottom-trailing, 16 pt; bottom content padding 88. Row tap → `navigator.navigate(AppointmentDetailKey(id:))`; FAB/empty action → `AppointmentEditorKey(id: nil)`.

- [ ] Port the 4-case VM table by name; `#Preview` for empty/loaded/expanded. `swift test` green, app builds (tab still placeholder until Task 10). Commit.

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

**Acceptance (milestone from spec §10, iOS-M4):** *CRUD, multiple reminder offsets, EventKit "add to calendar".* Evidence table: one automated pointer per Android test table (7 files / 38 names verified against the files), plus the manual script's tick marks.

**Android follow-ups to hand over (start numbering after the last taken `A` in §11 — re-check, M2 and M3 both found their assumed numbers used):** (i) notification tap should deep-link to the appointment detail (iOS does); (ii) unify the calendar payload — detail sends `notes`, editor sends `doctor + notes`; (iii) `appointments_upcoming_header`, `appointments_ok`, `appointments_cancel` are dead string keys; (iv) the iOS-only `LocalDateTime` ISO/`instant(in:)` cases and the DAO partition/cascade cases have no Android twin (same shape as A8/M3's note).

- [ ] `scripts/ci.sh` green end to end + Release build; ledger updated; memory note for the next session (M5 prerequisites: M3a device list + `scripts/m3-manual-qa.md` before M5, per the M3 record).

---

## Self-review notes (written at planning time)

- **Spec coverage:** CRUD (T2/T4/T7/T8/T9), multiple reminder offsets end to end (T4 storage, T5 occurrences, T9 chips, T10 registration), EventKit add-to-calendar (T8/T9), §8 "rows open a detail" (T7), §6.1 "appointment reminder stays a standard notification" (T5 — no `presentation` override), banned-claims scan (T3), template compliance (T3/T7–T9), the M3 prerequisite (T0), the two lifts the previous milestones scheduled for "the second consumer" (T1/T6).
- **Parallelism:** T1 ∥ T2 ∥ T3 ∥ T6 after T0; T4 after T1+T2+T3; T5 after T4; T7 after T3–T6; T8 then T9; T10 after T9; T11 last.
- **Type consistency checked:** `LocalDateTime(date:minuteOfDay:)`, `.instant(in:)`, `.isoLocalString`; `AppointmentsRepository` method names identical in T4/T5/T7–T9; module closure names in T7/T8/T9; key names `AppointmentDetailKey(id:)`/`AppointmentEditorKey(id:)` in T7/T8/T9/T10.
- **Not in scope:** Home's "upcoming appointment" card (M7), the `nav_appointments` tab label (M8 hub strings), appointment status editing (Android has none — status only ever changes by migration/backup), Critical Alerts/alarms for appointments (rejected by the M11 decision).
