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

- [x] Automated evidence, one pointer per criterion — the table in "Acceptance evidence" below, test names verified against the files rather than against the task reports.
- [x] `scripts/m3-manual-qa.md`, driven by `App/DebugReminderHandler.swift` (`#if DEBUG`, and inert without a launch argument even then).
- [x] `scripts/ci.sh` green end to end (24/24 packages, 430 tests, 0 lint/format findings) + a Release-configuration `xcodebuild build`. Ledger updated.

---

## Self-review notes (written at planning time)

- **Spec coverage:** §6.1 window (T4/T7), actionable notifications (T5/T6), BGAppRefreshTask (T7), foreground reconcile (T7), Reminder Health (T8), AlarmKit routing + `presentation` contract (T3/T5), SNOOZE deletion follow-up (T1), acceptance criteria (T4/T9), M3a deferral to M5 explicitly noted (T5).
- **Known open item carried forward, not blocking:** the custom alarm sound is a generated placeholder; a designed ≤30 s asset is owed before release (tracked in T5 + execution record).
- **Not in scope:** real handlers (M4/M5/M6), deep-link pushes to detail screens (needs those features' navigation keys), Critical Alerts (deliberately rejected in the spec).

---

## Done criterion (spec §10, iOS-M3)

✅ *Reminders survive force-quit, timezone change, DST boundary, notification-permission revocation,
and a 5-day cold period* — with the Android `ReminderWindowSynchronizer` table ported by name and
green on iOS, and the Reminder Health screen telling the user, in plain Turkish, whenever the OS has
taken one of those guarantees away.

---

## Execution record (2026-08-24)

Executed subagent-driven on branch `m3-reminder-engine` off `main` at `e0fd5c9`: one Opus
implementer per task, an independent reviewer per task, a scoped re-review after each fix round. No
task ran in parallel with another — the pre-flight scan (in the ledger) found every pair consistent
but the chain strictly ordered, so each task rebased on nothing. **Five** of the eight
implementation tasks passed review first time (1, 2, 3, 6, 8); the other **three** (4, 5, 7) passed
after exactly one fix round each. Fourteen commits carry the plan and Tasks 1-8
(`c24dc94..d9e4f4f`); Task 9 adds this record, the manual-QA script and the two owed items.

One dispatch was lost to a session restart before Task 4 (no commits, no report, clean tree at
`3a940fe`) and was re-dispatched fresh. That is not a fix round and is not counted as one.

`scripts/ci.sh` was green at the end of every task. At Task 9 it is green end to end —
**24/24 packages, 430 tests, `swiftformat --lint` and `swiftlint --strict` clean, every custom rule
proven to fire in scope, `** BUILD SUCCEEDED **`** — and so is the Release-configuration build the
acceptance asks for (`-configuration Release`, 0 warnings).

**The manual half is only partly done, and nothing is claimed about the rest.** What Task 9
executed on a simulator is written at the end of `scripts/m3-manual-qa.md`; the on-device M3a
checklist in its section 9 has not been run at all, and it is the reason the `--ff-only` merge is
held for the user rather than done here.

### Acceptance evidence

One pointer per criterion. Every name below was read out of the test file it lives in, not copied
from a task report.

| Criterion | Evidence | Where |
| --- | --- | --- |
| **Force-quit** | There is no fire-time code on iOS: the request is handed to `UNUserNotificationCenter` at sync time and the OS holds it across process death — which is why the engine bakes content at scheduling time at all (see Architecture). The part that can fail is the ledger drifting from what the OS actually holds, and that is pinned by **`a row the OS no longer holds pending is re-scheduled`** — a `SCHEDULED` row whose identifier is absent from `pendingRequestCodes()` is materialized again rather than assumed live. Its mirror image, **`a pending request with no live row is cancelled when the content goes nil`**, pins the other direction. | `ReminderWindowSynchronizerIOSTests` |
| **Timezone change** | **`DST fall-back - 8am local doses are 25 hours apart in wall-clock time`** — `FixedSalusClock.moveToZone(America/New_York)`, two 08:00 local doses either side of the 2025-11-02 fall-back, asserted 25 real hours apart at the gateway. The refill *trigger* is the composition root's `NSSystemTimeZoneDidChange` / `significantTimeChangeNotification` observers (`AppCompositionRoot.startReminderEngine`), whose funnel is pinned by **`requests made before the pass starts collapse into one sync`** and **`a request made during a pass earns exactly one more pass`**. | `ReminderWindowSynchronizerTests`; `BackgroundRefreshSchedulerTests` |
| **DST boundary** | The same `DST fall-back` case. Honest limitation, raised at review and carried: it exercises the *fixture's* local-time arithmetic, because the engine only ever compares `Date` instants — DST conversion is the handler's responsibility by contract (`ReminderHandler.occurrencesBetween`'s doc comment). The Kotlin twin is weak in exactly the same way, and the port is faithful to it. | `ReminderWindowSynchronizerTests` |
| **Notification-permission revocation** | Engine: **`a past-due row is FIRED when notifications are authorized`** and its parity twin **`stale scheduled alarms in the past are marked MISSED`** — the engine will not record a delivery the OS could not have made. Screen: **`initial state reflects the environment`** (notifications off ⇒ `notificationsEnabled == false`, `allHealthy == false`), **`refresh picks up changes made in system settings`** (revoked outside the process, re-checked on foreground), **`a granted prompt fixes the row without opening Settings`** and **`a declined prompt asks the screen to open Settings`** (the fix deep link). | `ReminderWindowSynchronizerIOSTests`, `ReminderWindowSynchronizerTests`; `ReminderHealthViewModelTests` |
| **5-day cold period** | **`a cold period of five days is refilled by one sync`** — the clock advances five days with no pass, and a single `sync()` materializes the next full 7-day window. Its companions are **`caps materialization at 60 occurrences on the iOS window`** (the §6.1 cap the refill runs into) and **`the two window configurations carry the spec constants`** (7 d/60 for iOS, 48 h/30 for the Android-parity runs). | `ReminderWindowSynchronizerIOSTests` |

Around those five, the suites that make them mean something: the nine Kotlin cases ported by name in
`ReminderWindowSynchronizerTests` (`materializes only occurrences inside the 48h window`,
`caps materialization at 30 occurrences, earliest first`,
`sync is idempotent - second run schedules nothing new`,
`stale scheduled alarms in the past are marked MISSED`,
`occurrences the handler no longer wants are cancelled`,
`changed trigger time reschedules the same occurrence`,
`cancelled row is resurrected with the same id when wanted again`, the DST case, and
`finished rows older than retention are purged`); the hash pin
`request codes are the Kotlin string hash of the occurrence identity`, without which the two
platforms would cancel different identifiers; and
`an occurrence that cannot be materialized does not starve the rest of the pass`, which is ruling 3
below made executable.

The delivery path either side of the engine: `UserNotificationGatewayTests` (identifier, `userInfo`
keys, per-type categories, non-repeating calendar trigger),
`UserNotificationGatewayRoutingTests` (plain vs time-sensitive vs AlarmKit,
`an AlarmKit refusal falls back to the time-sensitive request instead of losing the dose`,
`a rejected notification write leaves the alarm standing`, and the 64-request budget tripwire),
`ReminderNotificationDelegateTests`
(`an action tap reaches the owning handler and then refills the window, in that order`),
`ReminderSyncStateStoreTests`, `SystemReminderEnvironmentTests` and `ReminderHealthLastSyncTests`.
**92 tests in `SalusReminder`, 20 in `FeatureSettings`.**

### Commits and review rounds per task

| Task | Commits | Review |
| --- | --- | --- |
| 1 — delete `ReminderType.SNOOZE` | 1 — `de7827c` | Clean first time |
| 2 — `ReminderAlarmDao` | 1 — `827ada7` | Clean first time |
| 3 — `SalusReminder` contracts + registry | 1 — `3a940fe` | Clean first time |
| 4 — `ReminderWindowSynchronizer` port | 3 — `d822d2c`, fix `116a2c5`, fix `095d1d5` | Needs fixes (2 Important) → 1 round |
| 5 — `UserNotificationGateway` + AlarmKit routing | 3 — `775baad`, `2c2b0fd`, fix `87cb19a` | Needs fixes (2 Important) → 1 round |
| 6 — notification delegate | 1 — `5040d76` | Clean first time |
| 7 — sync triggers + composition root | 2 — `4296114`, fix `7114096` | Approved code, 1 Important open (the BG simulations were skipped) → 1 round of *verification*, not code |
| 8 — Reminder Health screen | 1 — `d9e4f4f` | Clean first time |
| 9 — this record, `scripts/m3-manual-qa.md`, the two owed items | see the branch tip | — |

### Rulings made during execution (decided on the user's behalf — read these)

In ledger order. Each says what it costs if it turns out to be wrong.

1. **`ReminderAlarmDao.upsert` conflicts loudly on a duplicate `request_code`** (Task 2). The upsert
   targets `ON CONFLICT(id)`, so a request-code collision raises `SQLITE_CONSTRAINT_UNIQUE` rather
   than Room's silent no-op or GRDB's silent row-merge. *Why:* a silent merge corrupts another
   alarm's row; a loud failure is diagnosable, and at ≤ 60 live rows in `Int32` space the collision
   odds are negligible. *Cost if wrong:* a real hash collision aborts one sync pass on iOS where
   Android silently drops the row. Carried forward: treat request codes as effectively unique; do
   not build on silent-drop semantics.
2. **`sync()` stays non-throwing, but every occurrence is isolated inside it** (Task 4). The brief
   made the signature non-throwing; review found that one deterministic throw would then starve
   every later occurrence forever, because iOS has no WorkManager to retry the pass. The resolution
   is a `do`/`catch` inside the materialize loop — the iOS twin of WorkManager's retry, not a
   divergence in the signature. *Cost if wrong:* a slight shape difference from Kotlin's
   abort-the-pass loop, accepted because iOS has no external retry.
3. **The AlarmKit adapter's floor is iOS 26.1, not 26.0** (Task 5). SDK-forced: 26.0's
   `AlarmPresentation.Alert` initializer demands app-supplied localized copy that `SalusReminder`
   has no string catalog to host. 26.0 devices take the documented time-sensitive fallback, and the
   routing itself stays version-free — the gateway routes on whether it was handed a scheduler.
   **Superseded in iOS-M5 Task 8:** the floor is now iOS 26.0. `SalusReminder` gained the string
   catalog whose absence forced this, so a 26.0 device rings a real alarm with an app-supplied
   "Kapat"; from 26.1 up iOS draws and localizes the stop button itself.
   *Cost if wrong:* 26.0-only devices miss full-screen alarms until a catalog lands in
   `SalusReminder`; the fallback is the designed degradation, so nothing is lost.
4. **The Time Sensitive Notifications entitlement was added beyond the brief's file list**
   (Task 5). Without it iOS silently downgrades `interruptionLevel = .timeSensitive` to `.active`
   and the whole iOS 17-25 alarm fallback is inert. Recorded as a gap in the brief, not scope creep.
   *Cost if wrong:* none — the capability is auto-approved, which is exactly why the spec chose it
   over Critical Alerts.
5. **OS-driven background launch and expiration are unverifiable without an unlocked device**
   (Task 7). `BGTaskScheduler` submission answers `BGTaskSchedulerErrorCodeUnavailable` on a
   simulator, so `_simulateLaunchForTaskWithIdentifier:` has no pending request to act on; the
   paired iPhone was built for, signed and installed, and refused the launch because the device was
   locked. Instead the registration was found alive in the real framework and its launch handler
   invoked directly, which advanced `reminder_last_sync_epoch_ms` — the body runs. Carried to the
   M3a checklist with exact commands (`scripts/m3-manual-qa.md` §8-9). *Cost if wrong:* a
   submit-level failure would surface only on device; mitigated by the executed handler-body
   evidence and the registration smoke.
6. **Task 9 does the record, the script and the two owed items only; the `--ff-only` merge and the
   push are held for the user.** *Why:* merging publishes a shared branch, and the manual pass is
   part of iOS-M3's done criterion. *Cost if wrong:* one extra user command.

### Recorded divergences from Android, complete list

1. **Notification content is baked at scheduling time.** Android builds it lazily when the alarm
   fires (`HandleFiredAlarmUseCase`); iOS has no code running at fire time, so the synchronizer asks
   the handler for content during `sync()` and hands it to the gateway. Every pass re-bakes, so a
   renamed medication is corrected by the next sync rather than at fire time. This is the plan's
   central divergence, decided up front.
2. **`:core:notifications` and `ReminderNotificationPresenter` have no iOS twin.**
   `UNUserNotificationCenter` is both scheduler and presenter.
3. **`ReminderEnvironment` asks three different questions.** Exact-alarm and battery-optimization
   permissions have no iOS meaning; what replaces them is notification authorization, AlarmKit
   authorization and Background App Refresh. Reminder Health's cards follow.
4. **Unique background work collapses to a coalesced in-process task.** iOS features run in-process,
   so `enqueueUniqueWork(REPLACE)` becomes `BackgroundRefreshScheduler`'s single in-flight `Task`
   plus one queued follow-up pass.
5. **Three of Android's system-event receivers are dropped, not ported.** `BOOT_COMPLETED` and
   `MY_PACKAGE_REPLACED` because iOS holds pending requests across a reboot and an app update, and
   `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` because no iOS permission sits behind it.
6. **Past-due `SCHEDULED` rows are resolved at the next sync, not at fire time** — `FIRED` when
   notifications are authorized, `MISSED` when they are not. Delivered-then-dismissed is
   indistinguishable on iOS, and assuming delivery is the honest reading of an authorized OS.
7. **`ReminderType.SNOOZE` is deleted on iOS and still present on Android** (Task 1). A snooze
   re-emits the same `MEDICATION_DOSE` occurrence with a later trigger, so the case is structurally
   dead. The Android deletion is an owed follow-up, and until it lands the two enums differ by one
   case that nothing writes.
8. **The alarm surface carries no action buttons.** A custom button on an AlarmKit alert needs an
   AppIntents `LiveActivityIntent`, i.e. the fire-time hook this milestone does not have. The
   handler's actions still reach the user on the fallback path as notification actions.
9. **`lastSyncCompletedAt` lives in a `SalusReminder`-owned store**, not in the settings data
   source, so no `SalusReminder → SalusSettings` edge is created that Android does not have. The key
   is iOS-local and pinned as *not* one of the thirteen Android settings keys.
10. **The AlarmKit row reuses Android's `reminder_health_full_screen_*` keys verbatim** rather than
    minting iOS names, because `alarmKitAuthorized` is documented as the replacement for
    `canUseFullScreenAlarms` and the Android copy describes the iOS behaviour accurately.
11. **`UserNotificationGateway.trigger(at:)` uses `UNCalendarNotificationTrigger`**, i.e. wall-clock
    date components resolved in the zone current at bake time, not the absolute instant. A pending
    request therefore drifts to wall-clock semantics across a timezone change while the app is
    closed; Android's `AlarmManager` keeps the absolute instant until its receiver — which runs
    without the app — resyncs it. Both platforms converge at the next sync, and wall-clock is
    arguably the better semantic for medication times anyway. Recorded here because the port rule
    says any unrecorded difference is a bug.

Anything else that differs from `:core:reminder` is a bug, not a port decision.

### Deferred findings, verbatim from the ledger, grouped by task

None of these blocks iOS-M4. The whole-branch review triages them; Task 9 deliberately did not fix
any of them.

**Task 1 — `SNOOZE` deletion**
- `Reminder.swift`'s doc comment "Android's core/model drops it too" reads present-tense; the
  Android deletion is still a follow-up.

**Task 2 — `ReminderAlarmDao`**
- `ReminderAlarmDao.swift:28` + `ReminderAlarmDaoTests.swift:34` cite the unique index as
  `ReminderAlarmEntity.kt:13`; the correct line is 15.
- Whole-row upsert replacement (including a state rewrite on a reused finished row) is not pinned by
  a test of its own — Task 4 drives that path.
- The duplicate-request-code test asserts the throw but not that the surviving row is untouched.
- Pre-existing M1 fixture `SampleRecords.swift:181` uses type `"MEDICATION"`, which is not a
  `ReminderType` member (Android's is `MEDICATION_DOSE`).

**Task 3 — contracts + registry**
- `ReminderNotificationContent`'s defaults are declared twice (stored properties *and* the explicit
  initializer) — drift risk.
- The placeholder-deletion convention claim was taken on faith by the reviewer.

**Task 4 — the synchronizer**
- Both empty `catch` sites (the `sync()` edge and the per-occurrence one) still lack diagnostics.
- A dead `requestCode` parameter in two `ledgerRow` branches; the `ledger()` helper hardcodes
  `med-1`/`med-2`.
- The ported DST test exercises the fixture rather than the engine (faithful to a weak Kotlin twin —
  see the acceptance table).
- Concurrent `sync()` is not serialized in the synchronizer itself. **→ closed by Task 7:** every
  trigger in the app funnels through `BackgroundRefreshScheduler`'s coalescing, the delegate
  included.

**Task 5 — gateway + AlarmKit routing**
- `CategoryRegistry` is process-local while `setNotificationCategories` is app-wide, so a relaunch
  leaves a partial category set until a pass converges.
- The UN identifier space is unnamespaced next to the AlarmKit prefix.
- Minted alarm-id UUIDs are not RFC 4122 variant-conformant (opaque bits, fine today).
- The budget tripwire costs one `pendingNotificationRequests()` per `schedule` — about 120 extra
  seam round trips per 60-occurrence sync. Accepted: the budget covers what the *app* holds, so it
  cannot be tracked locally.
- AlarmKit's `.named` sound with a `.caf` extension is unverifiable off device. **→ on the M3a
  checklist** (`scripts/m3-manual-qa.md` §9).

**Task 6 — the delegate**
- The corrupt-`userInfo` matrix covers a non-string value only for the `type` key.
- No dismiss-without-handler case (functionally the same path).
- The framework delegate methods are one-line forwards that `swift test` cannot exercise.
- `ReminderWindowSyncing` lives in the delegate's file; move it beside the synchronizer if a second
  caller appears.

**Task 7 — triggers + wiring**
- `SalusApp.init`'s side effect is not idempotent if the `App` value is re-created (the weak delegate
  would drop); the file comment contradicts itself on the point.
- `.onChange(scenePhase)` has no `initial: true`, so the cold-launch reconcile relies on a phase
  transition.
- `privacy: .public` on the error interpolation at both log sites — a §12 surface that widens once
  M4-M6 handlers land; prefer `.private`.
- The lastSync stamp is written even after a failed pass, so its semantic is "a pass ran"; say so
  where Task 8 reads it.
- The `systemEventObservers` comment asserts an undocumented `NotificationCenter` auto-unregister.
- `openTappedReminder` does not pop to the tab root although the doc wording says root.
- The coalescing test has a theoretical flake, and the awaited-extra-pass property that §6.1's
  refill relies on has no pin of its own.
- `RootTab.hosting` is untested (the app target has no test host).

**Task 8 — Reminder Health**
- The BG-refresh row depends on undocumented ancestor-first `scenePhase` ordering.
- `reminderEnvironment` / `reminderAuthorization` are write-only on the composition root, and the
  comment at `AppCompositionRoot.swift:86` is inaccurate about who reads them.
- Three identical "Düzelt" buttons with no `accessibilityLabel` (an Android-faithful gap).
- `UiState.timeZone` defaults to `.current`, which can mask a wrong zone.
- `refresh()` is unserialized — last writer wins by completion order.
- `FeatureSettings/Package.swift` still declares `SalusProfile`, `SalusPremium` and `SalusSettings`,
  unused until M8's hub.
- The `full_screen_*` copy runs ahead of the engine; re-verify the wording when M11 wires it.

### Owed items closed by Task 9

1. **The English peer of `NSAlarmKitUsageDescription`** (Task 5's deferral). `App/en.lproj/` and
   `App/tr.lproj/InfoPlist.strings` now carry the sentence, and `project.yml`'s plist value stays
   the base. The pair rather than English alone is the result of a measurement, not caution: with
   `en.lproj` as the only `.lproj` in the bundle, `Bundle.preferredLocalizations` answers `["en"]`
   even for a `tr-TR` preference — a Turkish phone would have read the English sentence, which is
   §6.4 backwards. With both files present it answers `["tr"]` for `tr-TR` and `["en"]` for `en-US`,
   measured against the built `Salus.app`. The base value in `Info.plist` is what a locale that is
   neither still gets. Three places now carry one sentence in two languages; the comment in each
   says so and names the other two.
2. **The `os.Logger` subsystem** (Task 7's "verify at T9"). **Nothing is wrong with it and nothing
   was changed.** All four call sites — `ReminderWindowSynchronizer`, `BackgroundRefreshScheduler`
   (×2) and `AppCompositionRoot` — use `subsystem: "com.alicansekban.salus"`, which is the bundle
   identifier, with categories `reminder`, `boot` and (Task 9's debug handler) `debug`. Task 7's
   smoke saw nothing because `log show` **hides `info` and `debug` level messages unless `--info`
   and `--debug` are passed**, and `debug` additionally needs
   `log config --mode "level:debug" --subsystem …` on a simulator. With both, all three categories
   appear — re-measured on iPhone 17 Pro / iOS 26.4 at Task 9:
   `[com.alicansekban.salus:debug] debug reminder armed …`,
   `[com.alicansekban.salus:boot] database ready, default profile id=default-profile`,
   `[com.alicansekban.salus:reminder] background refresh request refused: … Code=1`. The commands
   are in `scripts/m3-manual-qa.md` §10 with that caveat written next to them, so the next person
   does not spend the same hour.
3. **`scripts/m3-manual-qa.md` and the debug handler behind it.**
   `App/DebugReminderHandler.swift` is one fake `MEDICATION_DOSE` occurrence, entirely inside
   `#if DEBUG`, and inert even in a Debug build unless the app is launched with
   `-SalusDebugReminderLeadMinutes <n>`. Verified absent from the Release binary
   (`strings Salus | grep -c SalusDebugReminderLeadMinutes` → 0 in Release, 2 in Debug). The
   walkthrough was run as far as a terminal can take it: the engine went from the launch argument
   through the handler to a `SCHEDULED` ledger row
   (`debug-medication | 1787578507 | -919929169 | SCHEDULED`) with `reminder_last_sync_epoch_ms`
   stamped. Everything needing a tap or a wait is unrun and is marked as such in the document.

### Still owed, and by whom

- **The M3a on-device checklist** — `scripts/m3-manual-qa.md` §9. Seven items: the AlarmKit
  authorization prompt in both languages, a real AlarmKit schedule and a real cancel, the `.caf`
  sound on the AlarmKit path, the refusal fallback, OS-driven background launch and expiration, and
  a reboot. Needs an unlocked iPhone on iOS 26.0+ (26.1 as written; see divergence 3). Owed before
  iOS-M5 ships the medication handler.
- **The designed alarm sound.** `App/Resources/salus_alarm.caf` is still the placeholder generated
  by `scripts/generate-alarm-sound.sh`; a designed ≤ 30 s asset is owed before release.
- **The simulator taps** — sections 2-7 of the manual QA script.
- **The `--ff-only` merge and the push** (ruling 6).

### Android follow-ups opened by this milestone

`salus-android/` is read-only for the whole of iOS-M3 — its working tree has local commits the user
owns — so these are recorded here and written into `docs/ios-v1-plan.md` §11 by the user. **A13 was
the last number taken** at the time of writing, so they start at **A14**; re-check before writing,
because M2 found its assumed numbers already used.

- **Delete `ReminderType.SNOOZE` on Android too.** iOS removed it in Task 1 (divergence 7); a snooze
  re-emits the same `MEDICATION_DOSE` occurrence with a later trigger, so the case is dead on both
  platforms.
- **The iOS-only test tables have no Android twin.** The ten iOS-delta cases in
  `ReminderWindowSynchronizerIOSTests` — the 60 cap, identity idempotency, `FIRED`/`MISSED` per
  authorization, the missing-pending re-schedule, both nil-content withdrawal directions,
  per-occurrence isolation, the request-code hash pin and the 5-day cold period — describe behaviour
  Android mostly has and does not pin. Worth porting back, the way A8 tracks the M2 vitals tables.
- **`ReminderWindowSynchronizerTest`'s DST case exercises the fixture, not the engine**, on both
  platforms. Whichever side fixes it first should fix it for both.
