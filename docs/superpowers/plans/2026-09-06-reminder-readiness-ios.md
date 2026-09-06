# Reminder readiness steering — iOS implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.
> Compact plan: contracts and behaviour, not full code. Executors read the spec + the Android
> plan (`salus-android/docs/superpowers/plans/2026-09-06-reminder-readiness-android.md`) first.

**Goal:** Same steering as Android: post-save dialog in the medication editor when reminders are
BROKEN, a Home card for any problem. No Reminder Health change on iOS.

**Architecture:** Pure `ReminderReadiness` in `SalusReminder` `api` (async, mirrors the async
`ReminderEnvironment`); consumers are `MedicationEditorViewModel` and `HomeViewModel`. Navigation
to `ReminderHealthKey` stays a `RootView` callback.

**Tech stack:** Swift 6, SwiftUI, Swift Testing, SPM packages.

**Spec:** `docs/superpowers/specs/2026-09-06-reminder-readiness-steering-design.md` (pointer) →
Android spec.

**Branch:** `feature/reminder-readiness` from `main`. `swift test` per package + an
`xcodebuild` build of the app before ff-merge.

## Global constraints

- No UIKit in `SalusReminder` `api`; the package builds on the macOS test host.
- Strings in each feature's `Localizable.xcstrings` (TR source + EN), through the feature's
  `*Strings` enum; extend the parity tests.
- Shared components: `SalusCard`, `SalusIconBadge`, `SalusConfirmDialog` twins from `SalusUI`.
- Route/Screen split, `pendingEffects` + `consumeEffects()` effect shape.

---

### Task 1: `ReminderReadiness`

**Files**
- Create `Packages/SalusReminder/Sources/SalusReminder/api/ReminderReadiness.swift`
- Test `Packages/SalusReminder/Tests/SalusReminderTests/ReminderReadinessTests.swift`
  (fake env in `Fakes.swift` already exists — extend if it lacks setters)

**Produces**
```swift
public enum ReminderReadiness: Sendable, Equatable { case ok, degraded, broken }
public enum ReminderProblem: Sendable, Equatable, CaseIterable {
    case notificationsOff, alarmKitDenied, backgroundRefreshOff
    public var isHard: Bool   // first two true
}
public struct ReminderReadinessReport: Sendable, Equatable {
    public let readiness: ReminderReadiness
    public let problems: [ReminderProblem]      // CaseIterable order
    public var hardProblems: [ReminderProblem]
    public static let ok: ReminderReadinessReport
}
public extension ReminderEnvironment {
    func readiness(alarmKitSupported: Bool) async -> ReminderReadinessReport
}
```
`alarmKitDenied` only when `alarmKitSupported && !(await alarmKitAuthorized())`.

**Tests:** healthy → `.ok`; notifications denied → broken; AlarmKit denied + supported → broken;
AlarmKit denied + unsupported → ok; refresh off → degraded with one problem; hard + soft → broken, both.

- [ ] Tests → fail; implement → pass; `swift test --package-path Packages/SalusReminder`
- [ ] Commit `feat(reminder): readiness classification`

### Task 2: Shared problem copy

**Files**
- `SalusUI` does not depend on `SalusReminder`, so the copy lives in `SalusReminder` itself
  (Android twin: `:core:reminder` resources). Add `Packages/SalusReminder/Sources/SalusReminder/Resources/Localizable.xcstrings`
  (+ `resources: [.process("Resources")]` in `Package.swift`) and `ReminderStrings.swift` following
  the `SalusUIStrings` shape (`Bundle.module`, no UIKit): `reminderProblemNotificationsOff`,
  `reminderProblemAlarmKitDenied`, `reminderProblemBackgroundRefreshOff` (copy the wording from
  `SettingsStrings.reminderHealth*Problem`), `reminderFix` ("Düzelt"/"Fix"), `reminderNotNow`
  ("Şimdi değil"/"Not now").
- Create `Packages/SalusReminder/Sources/SalusReminder/api/ReminderProblemText.swift`:
  `public extension ReminderProblem { var reason: String }`.
- Add a strings parity test in `SalusReminderTests` (TR and EN keys equal), the shape the other
  packages use.

- [ ] Strings + mapping + test; `swift test --package-path Packages/SalusReminder`
- [ ] Commit `feat(ui): shared reminder problem copy`

### Task 3: Medication editor post-save dialog

**Files**
- Modify `.../FeatureMedications/ui/editor/MedicationEditorUiState.swift`:
  `var reminderWarning: [ReminderProblem]?`; events `.reminderWarningFixClicked`,
  `.reminderWarningDismissed`; `enum MedicationEditorEffect: Equatable { case openReminderHealth }`.
- Modify `MedicationEditorViewModel.swift`: init gains `environment: any ReminderEnvironment,
  alarmKitSupported: Bool`; `pendingEffects`/`consumeEffects()` (the `MoreViewModel` shape);
  on save `.success`: `if remindersEnabled, await environment.readiness(alarmKitSupported:).readiness == .broken { reminderWarning = report.hardProblems } else { navigator.pop() }`;
  Fix → `navigator.pop()` then append `.openReminderHealth`; Dismiss → `navigator.pop()`.
  `remindersEnabled` is not an editor field on either platform: the rule is
  `state.recurrence != .asNeeded` (an as-needed medication schedules no alarm), stated in a comment
  and covered by a test.
- Modify `MedicationEditorScreen.swift` Route: `onOpenReminderHealth: @escaping () -> Void`;
  consume effects after each event; `SalusConfirmDialog` with
  `MedicationsStrings.medicationSavedRemindersBlockedTitle`, message `warning.first!.reason`,
  confirm `ReminderStrings.reminderFix`, dismiss `ReminderStrings.reminderNotNow`.
- `App/RootView.swift`: editor entry passes `onOpenReminderHealth: { root.navigator.navigate(ReminderHealthKey()) }`
  after the pop (the pop is the ViewModel's; the callback only pushes).
- `App/AppCompositionRoot*.swift`: pass `reminderEnvironment` and the existing
  `alarmKitSupported` decision into the editor factory.
- Strings (FeatureMedications xcstrings): `medicationSavedRemindersBlockedTitle` TR "Kaydedildi,
  ama alarmlar çalışmayabilir" / EN "Saved, but alarms may not fire".
- Tests `MedicationEditorViewModelTests.swift`: same five cases as Android.

- [ ] Tests → fail; implement → pass; `swift test --package-path Packages/Features/FeatureMedications`
- [ ] Commit `feat(medications): warn after save when reminders cannot fire`

### Task 4: Home readiness card

**Files**
- Modify `.../FeatureHome/ui/HomeUiState.swift`: `var reminderReadiness: ReminderReadinessReport?`;
  event `.appeared`.
- Modify `HomeViewModel.swift`: init gains `environment: any ReminderEnvironment, alarmKitSupported: Bool`;
  `.appeared` → `Task { await refreshReminderReadiness() }` storing the report when `!= .ok`, else nil.
  Expose `func sceneDidBecomeActive()` that sends `.appeared` so the shell can call it.
- Modify `HomeScreen.swift`: `HomeRoute` gains `onOpenReminderHealth`; `.task { viewModel.onEvent(.appeared) }`
  on appear; new `HomeReminderReadinessCard.swift` (`SalusCard` + `SalusIconBadge(systemName:
  "bell.slash", accent: .medications)`, title by level, subtitle `problems.first!.reason`, chevron)
  rendered right after `HomeHeader`.
- `App/SalusApp.swift` `.active` arm: after the app-lock call, forward to the Home ViewModel's
  `sceneDidBecomeActive()` through the composition root (one line; do not add a second
  `scenePhase` reader).
- `App/RootView.swift`: `HomeRoute(..., onOpenReminderHealth: { root.navigator.navigate(ReminderHealthKey()) })`.
- Strings (FeatureHome xcstrings): `homeRemindersBrokenTitle` TR "Alarmlar çalışmayacak" / EN
  "Alarms will not fire"; `homeRemindersDegradedTitle` TR "Alarmlar gecikebilir" / EN "Alarms may be late".
- Tests `HomeViewModelTests.swift`: ok → nil; broken/degraded → report; healthy again → nil.

- [ ] Tests → fail; implement → pass; `swift test --package-path Packages/Features/FeatureHome`
- [ ] Commit `feat(home): reminder readiness card`

### Task 5: Integration, QA, ledger

- [ ] `xcodebuild -scheme Salus -destination 'generic/platform=iOS Simulator' build` clean;
  all touched packages' `swift test` green.
- [ ] `docs/qa/reminder-readiness-manual-qa.md`: deny notifications → save medication → dialog →
  Fix → Reminder Health; Background App Refresh off → Home DEGRADED card; re-enable → card gone
  on foreground.
- [ ] Parity ledger entry (`salus-android/docs/parity-ledger.md`): iOS has no Restricted
  battery twin; readiness is async; copy lives in SalusReminder resources.
- [ ] `git rebase main`, `git merge --ff-only`, push.
