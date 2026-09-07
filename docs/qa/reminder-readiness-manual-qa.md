# Reminder readiness steering — manual QA (iOS)

Spec pointer: `docs/superpowers/specs/2026-09-06-reminder-readiness-steering-design.md`
(the design itself lives with the Android reference).
Branch: `feature/reminder-readiness`. The twin sheet is
`salus-android/docs/qa/reminder-readiness-manual-qa.md`; the sections below are its sections, in
its order, with the iOS deviations called out where they change what you should see.

Automated coverage: `ReminderReadinessTests`, `ReminderProblemTextTests`, `ReminderStringsTests`,
`MedicationEditorViewModelTests`, `HomeReadinessTests`, `HomeViewModelTests`, `HomeStringsTests`,
`MedicationsStringsTests`. Green before this sheet is run: `scripts/lint.sh`,
`scripts/lint-custom-rules.sh`, `scripts/test-packages.sh` (24/24), and
`xcodebuild -scheme Salus -destination 'generic/platform=iOS Simulator' build`.

**Why this sheet exists at all.** Two things in this feature cannot be proven by `swift test`.
A `.xcstrings` is compiled only by Xcode's build system, so under `swift test` every one of these
strings resolves to its key — the copy below is only ever *seen* on a device or simulator. And
the three device answers (`UNUserNotificationCenter`, AlarmKit, `UIApplication
.backgroundRefreshStatus`) come from the OS, which no unit test can set.

## Device

**A real device, at least for §3 and §4.** The iOS Simulator does not offer Settings → General →
Background App Refresh at all, and its AlarmKit authorization cannot be denied through the
Settings UI, so the two soft problems have no simulator route. What the simulator *does* cover:
§1, §2 and §4 (notification authorization is a real toggle there), plus the whole navigation
walk. Run §1/§2/§4 on the simulator if that is what you have; run §3 on hardware.

iOS 26 or newer for anything naming AlarmKit — below it the app never asks, by design
(`ReminderReadiness.readiness(alarmKitSupported:)`), and a device with no AlarmKit must read
healthy. If the device is below iOS 26, tick §3.2 as "n/a — no AlarmKit" rather than as a pass.

Each step names what to see; tick or note the deviation.

## 1. Post-save dialog (hard failure)

Only `notificationsOff` is hard on iOS, so notifications are the only setting that raises this
dialog (Android additionally raises it for denied exact alarms and a Restricted battery).

1. Settings → Salus → Notifications → **Allow Notifications** off.
2. Open Salus → İlaçlar (Medications) → **+** → name "QA A", keep the default daily 08:00 dose →
   Kaydet (Save).
3. Expect a dialog **"Kaydedildi, ama alarmlar çalışmayabilir"** / *"Saved, but alarms may not
   fire"* with **"Bildirimler kapalı — hatırlatıcılar gösterilemez."** underneath, and the buttons
   **"Düzelt"** / **"Şimdi değil"**. The medication is already saved — the dialog reports, it does
   not ask.
4. Tap **Düzelt** → **Hatırlatıcı sağlığı** (Reminder health) opens, with the Bildirimler row
   showing the problem. Press **Back** → the **medications list**, "QA A" in it. **Not the
   editor** — the editor is popped before the push, so Back cannot land back on a form that has
   already been saved.
5. Confirm the tab bar is **hidden** on Reminder health (it is a pushed screen) and back on the
   list.
6. Repeat step 2 with "QA B" and tap **Şimdi değil** → the list, no further navigation.

## 2. No dialog for soft failures or as-needed medications

1. Turn notifications back on. Settings → General → Background App Refresh → **Salus off**
   (device only; skip to step 3 on the simulator).
2. Medications → + → "QA C" → Save → **no dialog**, the editor closes. Background refresh is soft
   on iOS: the window is still refilled every time the app is opened.
3. Turn notifications off again. Medications → + → "QA D" → recurrence **"Gerektiğinde"**
   (as needed) → Save → **no dialog**, the editor closes. A medication with no schedule has no
   reminder to fail.
4. Turn notifications back on, and Background App Refresh back on.

## 3. Home card — soft problems (DEGRADED)

**Device only.** iOS has no Restricted-battery twin, so the two soft problems below are what
stands in for Android's §3.

1. Settings → General → Background App Refresh → **Salus off**. Return to Salus without killing
   it → **Ana Sayfa** (Home): a card **"Alarmlar gecikebilir"** / *"Alarms may be late"* sits
   directly under the header and **above "Bugünkü dozlar"**, reading *"Arka plan yenilemesi
   kapalı — hatırlatıcı listesi yalnızca uygulamayı açtığınızda tazelenir."*
   - The card appears **without a relaunch**: the foreground return reaches the dashboard through
     `AppForegroundSignal`, which re-reads the device. If it only appears after a relaunch, that
     is a finding.
2. iOS 26+: Settings → Salus → **Alarms** (AlarmKit) → deny. Return to Salus → the card still
   reads **"Alarmlar gecikebilir"** with *"İlaç alarmları ekranı kaplayamıyor…"*.
   **This is the ruled iOS deviation**: the spec calls a denied AlarmKit a hard problem, and on
   iOS it is soft — the dose still posts as a time-sensitive notification with the alarm sound, so
   the reminder reaches the user, it just does not take over the lock screen. A **"Alarmlar
   çalışmayacak"** card here would be the finding.
3. Tap the card → **Hatırlatıcı sağlığı**, pushed onto the **Home** stack (not More's). The row
   for the problem shows its text; the other rows read their OK line. Press **Back** → **Home**,
   the card still there.
4. Turn Background App Refresh back on (and grant AlarmKit) → return to Salus → **Home: no
   card**, without relaunching. Reminder health: *"Her şey yolunda görünüyor — hatırlatıcılar
   zamanında gelecektir."*

## 4. Notifications off → Home (BROKEN)

1. Turn notifications off → return to Salus → Home card **"Alarmlar çalışmayacak"** / *"Alarms
   will not fire"* with the notifications reason.
2. With **both** notifications off and Background App Refresh off, the card still reads
   **"Alarmlar çalışmayacak"**: the hard problem wins the title and is the reason shown, because
   `problems` is worst-first and the card draws `problems.first`.
3. Turn notifications on → return → **card gone on the foreground return**, no relaunch.

## 5. Belt and braces

1. Switch the device to **English** and walk §1 step 3 and §3 step 1 again — every string above
   has an EN peer and none of them may render as a raw key (`home_reminders_broken_title` on
   screen means the catalog lookup missed).
2. Leave the app on Home with a card showing and background it for a minute, then return: the
   card is re-read, not re-animated from a stale value.

## Result

| Section | Pass | Notes |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | (device only) |
| 4 | | |
| 5 | | |

---

# Proposed parity-ledger rows

These belong in `salus-android/docs/parity-ledger.md`. They are recorded here rather than written
there because this branch does not touch the Android repo; copy them across when the two branches
are merged.

| # | Android | iOS | Why |
|---|---|---|---|
| 1 | `ReminderProblem.BATTERY_RESTRICTED` (hard) and `BATTERY_OPTIMIZED` (soft) | **no twin** | iOS has no per-app battery-restriction state a process can read, and nothing the user could be sent to fix. The iOS problem set is `notificationsOff`, `alarmKitDenied`, `backgroundRefreshOff`. |
| 2 | `ReminderProblem.FULL_SCREEN_DENIED` (soft), `EXACT_ALARMS_DENIED` (hard) | `alarmKitDenied`, **soft** | The iOS twin of the full-screen intent is AlarmKit, and denying it leaves the dose posting time-sensitive with the alarm sound — the reminder still reaches the user. **This is a deviation from the shared spec**, which called a denied AlarmKit hard; ruled in Task 1 and recorded in the pointer spec. iOS has no exact-alarm permission at all. |
| 3 | `ReminderProblem.BACKGROUND_RESTRICTED` | `backgroundRefreshOff` (`reminder_problem_background_refresh_off`) | **iOS-only key.** `UIApplication.backgroundRefreshStatus` is the closest reading, and the copy names the iOS setting by its Settings-app name ("Arka plan yenilemesi" / "Background App Refresh"). Soft on both sides. |
| 4 | `ReminderEnvironment.readiness()` is blocking | `readiness(alarmKitSupported:) **async**` | `UNUserNotificationCenter.notificationSettings` only answers through a callback, so the whole classification is `async`. Consequence for the ViewModels: Kotlin makes readiness the fourth `combine` source, iOS runs an unstructured `Task` per arrival and carries the last answer forward in `publish(...)` — with a generation guard, because two arrivals can be in flight at once. |
| 5 | `readiness()` takes no parameter | `readiness(alarmKitSupported:)` | AlarmKit exists only from iOS 26. The **caller** decides availability so the classification stays pure and never reports a denial the user cannot act on; below iOS 26 `alarmKitAuthorized()` is not asked at all (`HomeReadinessTests.alarmKitIsNotAskedAboutOnASystemThatHasNone`). |
| 6 | Problem copy lives in `:core:reminder` `strings.xml` | `Packages/SalusReminder/Sources/SalusReminder/Resources/Localizable.xcstrings` | Same module position. Reached through `ReminderStrings` / `ReminderProblemText`, never a bare `String(localized:)`, so the editor dialog and the Home card cannot drift apart. |
| 7 | Home refresh: `LifecycleResumeEffect` | `HomeEvent.appeared`, sent by `HomeRoute`'s `.task` **and** by `AppForegroundSignal` | SwiftUI does not re-run a `.task` for a foreground return, and the shell keeps exactly one `scenePhase` reader (`SalusApp.swift`). The signal — which arrived with the in-app review prompt and is shared with it — is the fan-out, and it holds a locked arrival back until `AppLockManager.didUnlock`. The pointer spec's "hooks into the single `scenePhase` site" is satisfied through that signal rather than by a second call in the `.active` arm. |
| 8 | n/a | `ReminderEnvironmentGraph` | iOS-only assembly type: the composition root builds the environment and the AlarmKit answer **once** and hands the same pair to Reminder Health, the medication editor and Home, so no two surfaces can disagree about the device. |
| 9 | n/a | `App/RootNavigationStack.swift` | iOS-only file, extracted from `RootView.swift` when the Home and Medications stacks both had to register `.settingsDestinations()` — SwiftUI resolves `navigationDestination(for:)` per stack, so `ReminderHealthKey` has to be declared on every stack that can push it. No Android twin: Compose's `NavHost` is one graph. |
