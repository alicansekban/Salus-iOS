# iOS-M3 — Reminder Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Executor subagents run on **Opus** (user preference). Compact plan: contracts and behaviour, not source code — the named Kotlin files are the spec. Read `CLAUDE.md`, `docs/ios-feature-template.md`, and the M2 plan's execution record first. Independent tasks may run in parallel implementers (own worktree + side branch, rebased before review). Branch: `m3-reminder-engine`.

**Goal:** The reminder engine as a new `SalusReminder` package: the ported `ReminderWindowSynchronizer` over a 7-day/60-notification rolling window, `UNUserNotificationCenter`-backed scheduling with baked content and actionable categories, the AlarmKit/time-sensitive `ALARM` routing, `BGAppRefreshTask` + foreground reconcile + timezone-change refill, and a Reminder Health screen in `FeatureSettings` — with the Android synchronizer tests ported and green.

**Architecture:** `SalusReminder` is the twin of Android `:core:reminder`. Pure contracts (`ReminderHandler`, `ReminderScheduler`, `ReminderEnvironment`) + the engine (`ReminderWindowSynchronizer`, `NotificationGateway`) with **injected window constants**. The central platform divergence: Android builds notification content lazily when the alarm fires (`HandleFiredAlarmUseCase`); iOS has no code running at fire time, so **content is baked at scheduling time** — the synchronizer asks the handler for content during `sync()` and hands it to the gateway. `UNUserNotificationCenter` is both scheduler and presenter, so Android's `:core:notifications`/`ReminderNotificationPresenter` have no iOS twin. Handlers stay empty until M4/M5/M6 — everything is proven with fakes; M3a's alarm payload is validated by iOS-M5 on device.

**Tech Stack:** Swift 6 / SwiftUI, GRDB (existing `SalusDatabase`), UserNotifications, BackgroundTasks, AlarmKit (`#available(iOS 26)`), swift-testing (match whatever M1/M2 tests use).

**Spec:** `salus-android/docs/ios-v1-plan.md` — §6.1 (window), the 2026-08-23 AlarmKit note (presentation contract), the iOS-M3 milestone entry, §7 contracts. Kotlin sources named per task are the behavioural spec. **Do not modify anything under `salus-android/`** — its working tree has local commits the user owns.

## Global Constraints

- **§6.1 decision (Alican, 2026-08-23): iOS window = 7 days / 60 occurrences, 4 slots reserved for snoozes.** Constants are injected (`ReminderWindowConfig`), never hardcoded — ported tests inject Android's 48 h/30 to stay byte-comparable with the Kotlin tests; production injects 7 d/60; iOS-only tests cover the 60 cap.
- Presentation contract is **handler-owned**: `ReminderNotificationContent.presentation` (`NOTIFICATION` default / `ALARM`). The presenting layer never guesses from `ReminderType`. Critical Alerts are **not** used.
- Date/time semantics from §7: `minuteOfDay` 0–1439, `epochDay`, `epochMs + tz_id`. Handlers own DST conversion; the engine only compares `Date` instants from `SalusClock`.
- Domain purity: `SalusReminder` contracts + engine import no SwiftUI/UIKit; only the gateway file imports UserNotifications/AlarmKit. SwiftLint rules apply.
- Strings: TR source + EN in `Localizable.xcstrings`, typed accessors, `BannedHealthClaims` scan passes (no "adherence"/"compliance" wording anywhere).
- Lowercase UUID ids (`UUIDIdGenerator`), ledger ids match Android's shape.
- Every task: `swift test` (touched packages) + `xcodebuild build` green before commit. SwiftFormat/SwiftLint clean.

---

### Task 1: Delete `ReminderType.SNOOZE` (dead code, both-sides decision — iOS side)

**Files:**
- Modify: `Packages/SalusModel/Sources/SalusModel/Reminder.swift` (remove `case snooze = "SNOOZE"`)
- Modify: `Packages/SalusModel/Tests/SalusModelTests/*` (any raw-value round-trip tests that enumerate cases)

**Kotlin source:** the 2026-08-23 note in `ios-v1-plan.md` — a snooze re-emits the same `MEDICATION_DOSE` occurrence with a later trigger, so `SNOOZE` is structurally dead.

**Interfaces:** Produces the final `ReminderType` vocabulary consumed by every later task: `medicationDose`, `appointment`, `cycle` (whatever remains in the file — do not invent new cases).

- [ ] Remove the case; fix compilation and enumeration tests. Grep the whole repo for `snooze`/`SNOOZE` raw-value usage (none should exist outside this enum yet).
- [ ] `swift test` green in `SalusModel`. Commit.

### Task 2: `ReminderAlarmDao` in SalusDatabase

**Files:**
- Create: `Packages/SalusDatabase/Sources/SalusDatabase/ReminderAlarmDao.swift`
- Test: `Packages/SalusDatabase/Tests/SalusDatabaseTests/ReminderAlarmDaoTests.swift`

**Kotlin source:** `salus-android/core/database/.../dao/ReminderAlarmDao.kt`, `.../entity/ReminderAlarmEntity.kt`. The GRDB table `reminder_alarms` and `ReminderAlarmRecord` already exist (M1 schema parity) — this task only adds the DAO.

**Interfaces (produces):**
- `struct ReminderAlarmDao: Sendable` over `DatabaseWriter`, mirroring the Kotlin DAO query-for-query (port every `@Query`/`@Upsert` by name: upsert, fetch scheduled, fetch by request code, state transitions, delete). Follow `VitalsDao.swift`'s style exactly.
- State strings are the Android `state` column vocabulary (read them from the Kotlin sources; do not invent).

- [ ] TDD: port the DAO behaviours against an in-memory GRDB database (upsert-is-idempotent, unique `request_code` index conflict, scheduled-only fetch, state transition).
- [ ] Implement. `swift test` green in `SalusDatabase`. Commit.

### Task 3: `SalusReminder` package — contracts + registry

**Files:**
- Create: `Packages/SalusReminder/Package.swift` (deps: `SalusModel`, `SalusCommon`, `SalusDatabase`; test dep: `SalusTesting`)
- Create: `Packages/SalusReminder/Sources/SalusReminder/api/ReminderContracts.swift`
- Create: `Packages/SalusReminder/Sources/SalusReminder/engine/ReminderHandlerRegistry.swift`
- Test: `Packages/SalusReminder/Tests/SalusReminderTests/ReminderContractsTests.swift`

**Kotlin source:** `core/reminder/.../api/ReminderContracts.kt` (port doc comments too — they carry the DST responsibility rule), `engine/ReminderHandlerRegistry.kt`, plus the `presentation` field from the 2026-08-23 note (Android's M11 added it; port the field even though the checked-out Kotlin file may predate it).

**Interfaces (produces):**
- `struct ReminderRef: Hashable, Sendable { let type: ReminderType; let entityId: String; let occurrenceKey: String }`
- `struct ReminderOccurrence: Equatable, Sendable { let entityId: String; let occurrenceKey: String; let triggerAt: Date }`
- `struct ReminderAction: Equatable, Sendable { let id: String; let label: String }`
- `enum ReminderPresentation: String, Sendable { case notification = "NOTIFICATION"; case alarm = "ALARM" }`
- `struct ReminderNotificationContent: Equatable, Sendable { let title: String; let text: String; var actions: [ReminderAction] = []; var presentation: ReminderPresentation = .notification }`
- `protocol ReminderHandler: Sendable { var type: ReminderType { get }; func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence]; func notificationContent(for ref: ReminderRef) async throws -> ReminderNotificationContent?; func onAction(ref: ReminderRef, actionId: String) async throws }` — `onAction` gets a default empty implementation, mirroring Kotlin.
- `protocol ReminderScheduler: Sendable { func requestSync() }`
- `protocol ReminderEnvironment: Sendable` — the iOS re-reading of Android's device-state view: `func notificationsAuthorized() async -> Bool`, `func alarmKitAuthorized() async -> Bool` (always `false` below iOS 26), `func backgroundRefreshAvailable() -> Bool`.
- `struct ReminderHandlerRegistry: Sendable { let all: [any ReminderHandler] }` (value at composition root, Koin `getAll()` twin).

- [ ] TDD: raw-value pins for `ReminderPresentation`, default-`presentation` pin, `ReminderRef` hashability.
- [ ] Implement. `swift test` green. Commit.

### Task 4: `ReminderWindowSynchronizer` port (the heart)

**Files:**
- Create: `Packages/SalusReminder/Sources/SalusReminder/engine/ReminderWindowConfig.swift`
- Create: `Packages/SalusReminder/Sources/SalusReminder/engine/NotificationGateway.swift` (protocol only)
- Create: `Packages/SalusReminder/Sources/SalusReminder/engine/ReminderWindowSynchronizer.swift`
- Test: `Packages/SalusReminder/Tests/SalusReminderTests/{ReminderWindowSynchronizerTests,Fakes}.swift`

**Kotlin source:** `core/reminder/.../engine/ReminderWindowSynchronizer.kt` + `ReminderWindowSynchronizerTest.kt` + `Fakes.kt` — port the algorithm and **every test by name**. `AlarmGateway.kt` for the gateway shape.

**Interfaces (produces):**
- `struct ReminderWindowConfig: Sendable { let window: TimeInterval; let maxOccurrences: Int; static let ios = Self(window: 7*24*3600, maxOccurrences: 60); static let androidParity = Self(window: 48*3600, maxOccurrences: 30) }`
- `protocol NotificationGateway: Sendable { func schedule(requestCode: Int32, triggerAt: Date, content: ReminderNotificationContent, ref: ReminderRef) async throws; func cancel(requestCodes: [Int32]) async; func pendingRequestCodes() async -> Set<Int32> }` — the iOS twin of `AlarmGateway`, widened to carry baked content (see Architecture).
- `final class ReminderWindowSynchronizer: Sendable`, `init(dao:gateway:handlerRegistry:environment:clock:idGenerator:config:)`, `func sync() async`.

**Behaviour (the iOS deltas from the Kotlin file — everything else ports 1:1):**
1. Desired set = handlers' `occurrencesBetween(now, now+window)`, filtered to `[now, windowEnd)`, sorted by trigger, capped at `maxOccurrences` — identical to Kotlin.
2. `request_code` derivation: port the **exact** Kotlin hash from `ReminderWindowSynchronizer.kt` (Kotlin/Java string-hash semantics reimplemented in Swift). Pin test with 2–3 concrete values computed from the Kotlin side so both platforms cancel the same identifiers forever.
3. **Content baking:** for each desired occurrence the synchronizer calls `handler.notificationContent(for:)` *at sync time*; `nil` ⇒ not scheduled (and any existing row/notification for it is cancelled). Every sync re-`schedule`s all desired occurrences — `UNNotificationRequest` with a stable identifier is add-or-replace, so re-baking keeps content fresh (medication renamed ⇒ next sync fixes the text) while staying idempotent by identity: the idempotency test asserts the ledger row set and pending-identifier set are unchanged after a second `sync()`.
4. **Past-due `SCHEDULED` rows** (no fire-time receiver exists on iOS): mark `FIRED` when `environment.notificationsAuthorized()` is true (the OS presented it — delivered-then-dismissed is indistinguishable and assumed delivered), else `MISSED`; then cancel + prune exactly where the Kotlin stale-branch does.
5. Reconcile against reality, not just the ledger: rows whose identifier is missing from `pendingRequestCodes()` (force-quit does **not** clear pending notifications, but OS eviction/user "clear all delivery" edge cases exist) are re-scheduled.

- [ ] TDD first: port `ReminderWindowSynchronizerTest` cases by name, running with `.androidParity` config + `FixedSalusClock` (`advanceTo`, `moveToZone` across a DST boundary). Add iOS-only cases: 60-cap with 70 desired occurrences keeps the earliest 60; second `sync()` is a no-op by identity; past-due row → `FIRED`/`MISSED` per authorization; missing-pending re-schedule; nil-content cancellation; **cold-period test:** advance the clock 5 days without sync, then one `sync()` materializes the next full 7-day window.
- [ ] Implement. `swift test` green. Commit.

### Task 5: `UserNotificationGateway` + AlarmKit routing

**Files:**
- Create: `Packages/SalusReminder/Sources/SalusReminder/platform/{UserNotificationCenting,UserNotificationGateway,AlarmKitScheduling}.swift`
- Create: `Packages/SalusReminder/Sources/SalusReminder/platform/ReminderUserInfo.swift`
- Test: `Packages/SalusReminder/Tests/SalusReminderTests/UserNotificationGatewayTests.swift`
- Modify: `project.yml` — `NSAlarmKitUsageDescription`, notification sound resource
- Create: `App/Resources/salus_alarm.caf` (placeholder ≤30 s generated via `afconvert` in `scripts/`; replaced by a designed sound before release — note it in the execution record)

**Kotlin source:** `engine/AndroidAlarmGateway.kt` (shape + doc discipline), `engine/ReminderNotificationPresenter.kt` (`ReminderIntentExtras` twin, action wiring). Spec: the 2026-08-23 AlarmKit note.

**Interfaces (produces):**
- `protocol UserNotificationCenting: Sendable` — the thin seam over `UNUserNotificationCenter` (`add`, `removePendingNotificationRequests`, `pendingNotificationRequests`, `notificationSettings`, `setNotificationCategories`, `requestAuthorization`) + `struct SystemUserNotificationCenter` and a test fake.
- `final class UserNotificationGateway: NotificationGateway` — identifier = `String(requestCode)`; `userInfo` keys `ReminderUserInfo.type/entityId/occurrenceKey` (twin of `ReminderIntentExtras`); actions → `UNNotificationCategory` per `ReminderType` with the handler-provided action ids; calendar trigger from `triggerAt` in the current time zone, `repeats: false`.
- **Presentation routing:** `content.presentation == .alarm` → `#available(iOS 26)`: schedule through `AlarmKitScheduling` (protocol seam over AlarmKit's manager; alarms do **not** consume the 64 budget); below 26 → `UNNotificationRequest` with `interruptionLevel = .timeSensitive` + `UNNotificationSound(named: "salus_alarm.caf")`. `.notification` → plain request, default sound. Cancellation must route to the same backend that scheduled it (ledger's request code is enough — AlarmKit ids derive from it).
- `pendingRequestCodes()` unions UN-pending ids and (iOS 26+) AlarmKit-scheduled ids.

- [ ] TDD with the fake center: identifier/userInfo/category pins, time-sensitive + custom-sound pin for `.alarm` fallback path, plain path pin, cancel-removes-pending, budget invariant (gateway never holds > 64 pending UN requests — assert after scheduling 70; the synchronizer's cap makes this unreachable, the gateway `assertionFailure`s as a tripwire).
- [ ] AlarmKit adapter compiles behind `#available(iOS 26)`; unit-test only the routing decision via the seam (real AlarmKit behaviour is M3a → validated on-device in iOS-M5).
- [ ] `swift test` green; app builds. Commit.

### Task 6: Notification delegate — actions, foreground presentation, deep-link contract

**Files:**
- Create: `Packages/SalusReminder/Sources/SalusReminder/platform/ReminderNotificationDelegate.swift`
- Test: `Packages/SalusReminder/Tests/SalusReminderTests/ReminderNotificationDelegateTests.swift`

**Kotlin source:** `receiver/ReminderActionReceiver.kt` + `engine/HandleReminderActionUseCase.kt` (delegation order), `HandleFiredAlarmUseCase.kt` (post-event refill).

**Interfaces (produces):**
- `final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate` over `(handlerRegistry, synchronizer, onOpen: @Sendable (ReminderRef) -> Void)`.
- `didReceive response`: parse `ReminderRef` from `userInfo`; action id ≠ default/dismiss → `handler.onAction(ref:actionId:)` then `synchronizer.sync()` (the "refill after every notification action" §6.1 trigger — this is the brief background window); default tap → `onOpen(ref)` (M3: routes to the matching tab root; the real detail-screen push arrives with M4/M5 navigation keys).
- `willPresent` → `[.banner, .sound, .list]` — mirrors Android's "notification still posts while UI is open; Room/GRDB observation updates the screens".

- [ ] TDD with fakes: action dispatch order (handler before sync), unknown-ref no-crash, default-tap routes, willPresent options pin.
- [ ] `swift test` green. Commit.

### Task 7: Sync triggers — BGAppRefreshTask, foreground reconcile, time-change; composition root wiring

**Files:**
- Create: `Packages/SalusReminder/Sources/SalusReminder/platform/{BackgroundRefreshScheduler,SystemReminderEnvironment}.swift`
- Modify: `App/AppCompositionRoot.swift`, `App/SalusApp.swift`, `project.yml` (`BGTaskSchedulerPermittedIdentifiers` = `com.alicansekban.salus.reminder.refresh`, background mode `fetch`)
- Test: `Packages/SalusReminder/Tests/SalusReminderTests/BackgroundRefreshSchedulerTests.swift`

**Kotlin source:** `work/{WorkManagerReminderScheduler,RescheduleAllRemindersWorker}.kt` (unique-work semantics, retry cap), `di/ReminderModule.kt` (graph shape), `AndroidReminderEnvironment.kt`.

**Interfaces (produces):**
- `final class BackgroundRefreshScheduler: ReminderScheduler` — `requestSync()` debounces into a single in-flight `Task` running `synchronizer.sync()` (the `enqueueUniqueWork(REPLACE)` twin — iOS features run in-process, so "unique background work" collapses to a coalesced task); after every sync it re-submits the `BGAppRefreshTask` request (`earliestBeginDate` ≈ 12 h, the periodic-refill twin).
- App wiring in `SalusApp`/composition root: register the BG task at launch (task body: `sync()` then `setTaskCompleted`); `scenePhase == .active` → `requestSync()` (foreground reconcile); observe `NSNotification.Name.NSSystemTimeZoneDidChange` and `UIApplication.significantTimeChangeNotification` → `requestSync()` (the TIMEZONE_CHANGED/TIME_SET receiver twins; BOOT/PACKAGE_REPLACED have no iOS meaning — pending notifications survive reboot).
- Composition root builds: `ReminderAlarmDao`, `ReminderHandlerRegistry(all: [])`, gateway, synchronizer (`.ios` config), delegate (set as `UNUserNotificationCenter.current().delegate`), scheduler — exposed as `ReminderScheduler` for M4/M5/M6 features. `SystemReminderEnvironment` implements the Task 3 protocol.
- Persist `lastSyncCompletedAt` (epochMs) through the existing preferences data source after each successful sync — Reminder Health's honesty signal.

- [ ] TDD: coalescing (two `requestSync()` → one sync), post-sync BG resubmission via a seam, lastSync persistence.
- [ ] Manual: app builds, launches, registers the BG task without console errors; `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:...]` smoke noted in the execution record.
- [ ] `swift test` green; commit.

### Task 8: Reminder Health screen (`FeatureSettings`)

**Files:**
- Create: `Packages/Features/FeatureSettings/Sources/FeatureSettings/{ui/reminderhealth/{ReminderHealthUiState,ReminderHealthViewModel,ReminderHealthScreen}.swift,navigation/SettingsNavigation.swift,SettingsStrings.swift,SettingsModule.swift,Resources/Localizable.xcstrings}`
- Modify: `App/RootView.swift` (More tab hosts the Settings destinations; PlaceholderScreen gains the row until M8 builds the hub)
- Test: `Packages/Features/FeatureSettings/Tests/FeatureSettingsTests/ReminderHealthViewModelTests.swift`

**Kotlin source:** `feature/settings/.../reminderhealth/*` (UiState/Event/Effect names, card layout, `LifecycleResumeEffect` re-check). Follow `docs/ios-feature-template.md` to the letter — this is the template's second consumer.

**Interfaces (produces):**
- `ReminderHealthUiState { isLoading, notificationsEnabled, alarmKitAuthorized (row only on iOS 26+), backgroundRefreshAvailable, lastSyncAt: Date?, allHealthy }`; Events `Refresh/FixNotifications/FixBackgroundRefresh/RequestAlarmKit`; Effects open `UIApplication.openNotificationSettingsURLString` / `openSettingsURLString`.
- Android's exact-alarm and battery-optimization cards have no iOS twin — replaced by the AlarmKit row and the Background App Refresh row. The "app hasn't run since …" line renders from `lastSyncAt` (the §"risk table" honesty requirement).
- Re-check on `scenePhase`/`willEnterForeground` (the `LifecycleResumeEffect` twin) — permissions change in Settings outside our process.

- [ ] TDD: ViewModel state derivation from a fake `ReminderEnvironment` + fixed clock (healthy/unhealthy permutations, lastSync formatting), strings test (TR+EN, banned-claims scan).
- [ ] Implement screen with design tokens (`SalusDesignSystem`), wire route from More tab. `swift test` green; app builds and the screen renders both states. Commit.

### Task 9: Acceptance sweep + execution record

**Files:**
- Modify: this plan (execution record section), `docs/ios-feature-template.md` (only if Task 8 exposed template gaps — record them, don't silently diverge)
- Create: `scripts/m3-manual-qa.md` — the self-serve manual test script (user preference: repeated manual steps become a script/doc)

**Acceptance (milestone ✅ from the spec):** *Reminders survive force-quit, timezone change, DST boundary, notification-permission revocation, and a 5-day cold period.*

- [ ] Automated evidence, one pointer per criterion: force-quit → pending-notifications-survive + missing-pending re-schedule test (T4); timezone/DST → ported `moveToZone` tests (T4); permission revocation → `MISSED` marking + Reminder Health surfacing (T4/T8); cold period → the 5-day cold-period test (T4). List test names in the execution record.
- [ ] `scripts/m3-manual-qa.md`: simulator walkthrough — schedule a fake handler occurrence (debug-only fake handler behind `#if DEBUG` in the composition root), force-quit, verify delivery; change simulator timezone, relaunch, verify reconcile; revoke notifications, open Reminder Health, verify the red card + fix deep link; BG task simulation command.
- [ ] Full `swift test` across all packages + release-config `xcodebuild build`. SwiftLint/SwiftFormat clean. Update the progress ledger the way M1/M2 did. Commit.

---

## Self-review notes (written at planning time)

- **Spec coverage:** §6.1 window (T4/T7), actionable notifications (T5/T6), BGAppRefreshTask (T7), foreground reconcile (T7), Reminder Health (T8), AlarmKit routing + `presentation` contract (T3/T5), SNOOZE deletion follow-up (T1), acceptance criteria (T4/T9), M3a deferral to M5 explicitly noted (T5).
- **Known open item carried forward, not blocking:** the custom alarm sound is a generated placeholder; a designed ≤30 s asset is owed before release (tracked in T5 + execution record).
- **Not in scope:** real handlers (M4/M5/M6), deep-link pushes to detail screens (needs those features' navigation keys), Critical Alerts (deliberately rejected in the spec).
