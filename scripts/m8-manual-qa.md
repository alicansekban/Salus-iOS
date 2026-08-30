# iOS-M8 manual QA — settings, onboarding, app lock and the secure screen

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code. Every step below says **NOT RUN** until someone runs it.

Each section is written by the task that shipped the behaviour it checks, so the file grows a
section at a time and the numbering follows the plan rather than the reading order.

**Language.** The steps quote the Turkish strings, which is what a default simulator shows
(spec §6.4 — Turkish is the default *and* the fallback).

---

## §2. The secure screen (Task 10)

Three mechanisms, one setting, and only one of them is behind the setting's switch — that is
spec §6.2 / global-constraints ruling 2, and it is what these rows separate:

| # | mechanism | behind the toggle? |
|---|-----------|--------------------|
| a | app-switcher blur | **no** — always on |
| b | screenshot mask (`isSecureTextEntry` layer) | yes |
| c | screen-capture hide (`UIScreen.isCaptured`) | yes |

The code that decides is `PrivacyOverlay.State.resolve(scenePhase:isCaptured:maskingEnabled:)` in
`App/PrivacyOverlay.swift`. Its table, which §2.1–§2.7 walk row by row:

    scenePhase   isCaptured   maskingEnabled   result
    .active      false        any              .hidden
    .active      true         false            .hidden
    .active      true         true             .captured
    .inactive    any          any              .switcher
    .background  any          any              .switcher

**Wording, and it is checked as well as implemented (spec §6.2).** Nothing in this feature blocks
or prevents anything: it *hides* content. `settings_secure_screen_desc` says "hides screenshots and
the recents preview" and that is the whole promise. A photograph of the screen still works. If any
step below tempts you to write "blocked" in the result column, write "hidden" instead — and if the
app's own copy ever says "blocks", that is the finding.

**Where the toggle is:** More tab → **Gizlilik** → **Güvenli ekran** (`settings_secure_screen`).
The switch is Task 6's; these rows only flip it.

### 2.1 The switcher blur is on with the toggle OFF

- [ ] **2.1** Fresh install, toggle **off** (the default — `UserSettings.secureScreenEnabled` is
  `false`, `Settings.kt:21`). Open the **Ölçümler** tab so real numbers are on screen, then swipe up
  slowly to the app switcher.
  *Expected — simulator:* the Salus card shows a **heavy blur with the app name "Salus" and a heart
  badge on it**. No blood pressure value, no chart line, no list row is legible through it.
  *Expected — device:* identical. Hold the card on screen for a few seconds; it must not resolve
  into the underlying screen after a moment.
  *Why this row exists:* this is the always-on half. A blur that only appears with the toggle on is
  the bug ruling 2 is written against.

- [ ] **2.2** Still toggle **off**: press Home (or swipe up fully) to background the app, then
  reopen it.
  *Expected — simulator and device:* the curtain lifts immediately on return — the app is back on
  the exact tab and scroll position it left, with **no blur left behind**. A curtain that stays up
  after `.active` means the phase observation is stuck, and the app looks frozen.

- [ ] **2.3 Control Centre / a system sheet does not tear the curtain.** With the toggle **off**,
  pull Control Centre down halfway over the Ölçümler tab and let it go.
  *Expected — simulator and device:* while the shade is down the app behind it is blurred
  (`scenePhase` is `.inactive` there, which `resolve` treats as `.switcher`); when it closes the
  blur goes. A brief blur flash here is correct, not a defect.

### 2.4–2.5 The screenshot mask (toggle ON)

- [ ] **2.4** Turn **Güvenli ekran** on. Go to **Ölçümler** with at least one saved measurement on
  screen. Take a screenshot (device: side + volume-up; simulator: ⌘S, or
  `xcrun simctl io booted screenshot /tmp/shot.png`).
  *Expected — device:* the screenshot thumbnail and the saved file show the app area **black /
  blank**; the status bar may still render. Open it in Photos to confirm — the thumbnail alone is
  not evidence.
  *Expected — simulator:* **likely NOT masked, and that is not a failure of this row.** A simulator
  "screenshot" is a host-side capture of a window, not an iOS render-server capture, so the
  `isSecureTextEntry` exclusion has nothing to act on. Record what you see and treat **§2.4 as a
  device-only pass**.
  *If the app itself breaks the moment the toggle goes on* — a black or empty window, or (see §2.5)
  content that jumps out of place — that is the artefact the Task 10 brief anticipated: the fix is to
  wrap `SecureScreenMask.apply()`/`remove()` in `#if !targetEnvironment(simulator)`. Report it rather
  than working around it.

- [ ] **2.5 The mask is reversible, and it does not move the app.** With the toggle **on**, before
  turning it back off, look hard at the screen: **the content is not displaced or offset** — no
  shift down or to the right, nothing running off the edge, no strip of blank where the layout used
  to start, and a tap still lands on the control it is under (tap a tab, then a list row). Then turn
  **Güvenli ekran** off and take another screenshot.
  *Expected — device:* the screenshot shows the app normally again. *Expected — simulator and
  device:* the app draws in exactly the same place with the toggle on as with it off, and keeps
  responding to taps through both flips — scroll the list and open an editor after each one. With
  **VoiceOver on** and the toggle on, swiping through the screen still reaches the app's own
  controls and never announces a "secure text field": the masking field is full-screen, so if it
  were an accessibility element it would swallow the whole screen.
  *Why this row exists:* the mask re-parents the app's root layer under the text field's content
  layer, and re-parenting changes whose coordinate space that layer's position is read in. Get the
  field's geometry wrong and the app renders offset by half the screen **while hit-testing stays
  where it was**, so taps fire the wrong control — a failure that looks like a layout bug and is
  not. The other half of the row is the one-way-door check: `setEnabled(false)` must put the layer
  back.

### 2.6–2.7 The capture hide (AirPlay / recording)

- [ ] **2.6** Toggle **on**. Start a screen recording (device: Control Centre → Record; or mirror to
  an Apple TV / QuickTime "Movie Recording" with the iPhone as camera source).
  *Expected — device:* the app **hides behind the curtain while the capture is running** — the same
  blur + name, live, with the app in the foreground — and the curtain lifts the moment the recording
  or mirroring stops. The recorded file shows the curtain, not the data.
  *Expected — simulator:* there is no `UIScreen.isCaptured` to raise on a simulator; **NOT
  APPLICABLE**, record it as such.

- [ ] **2.7 Mirroring is not hidden when the user did not ask for it.** Toggle **off**, then start
  the same recording/mirror.
  *Expected — device:* the app draws normally and the recording shows it. This is the deliberate
  gate in `resolve` — `.captured` requires `maskingEnabled` — so that plugging into a TV does not
  silently blank the app for someone who never turned the setting on.

### 2.8 The curtain is above everything

- [ ] **2.8** Toggle **off** (so only the always-on blur is in play). Push a detail screen (a
  measurement row → detail, where the tab bar is hidden), then background the app and look at the
  switcher. Repeat with a sheet or a dialog open, and — once Task 11 lands — with the **app-lock**
  screen and the **onboarding** flow showing.
  *Expected — simulator and device:* the blur covers the whole window every time, edge to edge,
  including the status-bar and home-indicator strips. Nothing shows around it, and no gate screen
  draws over it. *Why this row exists:* `RootView` applies `.secureScreen(maskingEnabled:)` outside
  the `TabView` and every `NavigationStack`, and inside `.salusTheme(_:)` only. A later overlay
  added *after* that line would sit on top of the curtain, which is exactly the ordering bug this
  step catches.

- [ ] **2.9 The curtain follows the theme.** Set **Koyu** (dark) in the theme dialog, then
  background the app.
  *Expected — simulator and device:* the blur and the app name are the dark palette's, not a light
  card in a dark system. A light curtain over a dark app means `.secureScreen` was applied outside
  `.salusTheme`, which is the mistake the comment on that line names.

---

## What was executed when this section was written (iOS-M8 Task 10)

**Nothing.** Task 10 ran `scripts/build-app.sh` (BUILD SUCCEEDED, zero new warnings) and
`scripts/lint.sh` (0 violations) and wrote this section from the code. Every §2 row above is **NOT
RUN**. §2.4 and §2.6 in particular have never been observed on any hardware, and they are the two
rows that carry the feature's actual promise; §2.5's displacement check was added in review round 1,
after a reviewer derived the offset from CALayer's coordinate-space rules — also unobserved.
---

## §3. The app lock (Task 9)

Written by Task 9 (`Packages/SalusCommon/Sources/SalusCommon/AppLockManager.swift`,
`App/Lock/AppLockScreen.swift`, `App/Lock/LockPrompting.swift`). The gate itself is mounted by the
shell task, so **run this section only once the shell draws the lock overlay** — before that the
manager exists but nothing shows it.

The automated half is `AppLockManagerTests` (8 cases): the gate's whole state machine, including
both sides of the 30 s boundary and the boundary itself, runs on a fake clock. What no test can
reach is the part that belongs to iOS: whether a *real* background stay of a *real* 31 seconds
re-locks, and whether the system's own authentication sheet appears and unlocks.

**Before you start.** Step 3.1 is the one to run *without* an enrolled biometric; every step after
it needs one. So run 3.1 first, then enrol a face — **Features → Face ID → Enrolled** — and carry on
from 3.2.

### When the device has no screen lock

- [ ] **3.1 No biometric and no passcode disables the toggle and swaps its subtitle.** On a
  simulator with **no** Face ID enrolment and **no** device passcode (**Features → Face ID →
  Enrolled** *off*, and no passcode under **Settings → Face ID & Passcode**), open the More tab →
  **Güvenlik** section.
  *Expected:* the **"Uygulama kilidi"** row is **greyed out and cannot be tapped**, and its subtitle
  is **"Bu cihazda ekran kilidi tanımlı değil"** — not the usual **"30 sn arka planda kaldıktan
  sonra biyometri veya cihaz kilidi iste"**. Tapping it does nothing.
  *Why this step exists:* `appLockAvailable = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication)`
  is the twin of Android's `BiometricManager.canAuthenticate(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)`
  (`MoreScreen.kt:94-98`), and the subtitle swap plus the disabled toggle are
  `MoreScreen.kt:263-270`. Enabling a lock that cannot then be opened is the one way to brick the
  app, which is why the row is disabled rather than merely failing at the prompt.
  *Ownership note:* the row and its subtitle belong to the More hub (T6, `FeatureSettings`); this
  step is here because the **availability rule** is the lock's, and nothing else in the milestone
  hand-checks it. If §4 grows a duplicate, delete this one rather than keeping both.

### Turning the lock on

- [ ] **3.2 Enabling app lock re-authenticates first.** More tab → **Güvenlik** section → tap the
  **"Uygulama kilidi"** toggle on.
  *Expected:* the system authentication sheet appears **before** the toggle moves, titled
  **"Uygulama kilidini etkinleştir"**. Approve it (**Features → Face ID → Matching Face**).
  *Expected:* the toggle is now on. *Why this step exists:* the confirmation is what stops someone
  holding an unlocked phone from locking its owner out (M8 ruling 4).
- [ ] **3.3 A refused confirmation leaves the setting alone.** Turn the toggle off, then on again
  and **cancel** the sheet (or **Features → Face ID → Non-matching Face**).
  *Expected:* the toggle springs back to off and nothing is written. Kill and relaunch the app —
  it is still off.
- [ ] **3.4 Disabling needs no confirmation.** With the lock on, tap the toggle off.
  *Expected:* it goes off immediately, with no sheet. Android does the same, deliberately: a
  confirmation to *remove* a protection you are already past protects nobody.

### The 30 s background grace — both sides of the boundary

- [ ] **3.5 Under 30 s in the background does not lock.** With the lock on and the app unlocked,
  press **Home** (⇧⌘H), count **ten seconds**, and reopen Salus.
  *Expected:* the app comes back exactly where it was. **No lock screen, no authentication sheet.**
  *Why this step exists:* answering a message or copying a code out of another app must not cost an
  unlock — the grace is what makes the lock livable.
- [ ] **3.6 Over 30 s in the background locks.** Press **Home** again, wait **at least 35 seconds**
  by a real clock, and reopen Salus.
  *Expected:* the lock screen covers everything: a large lock badge, the title **"Salus kilitli"**
  and a **"Kilidi aç"** pill. The authentication sheet appears **on its own**, without you tapping
  anything.
  *Boundary note:* the code re-locks on *strictly more* than 30 000 ms, so 30 s exactly is still the
  same session. Do not try to test the boundary by hand — `AppLockManagerTests` pins it to the
  millisecond; what this step proves is only that the scenePhase transitions reach the manager at
  all.
- [ ] **3.7 A cold start is locked.** With the lock on, kill the app from the app switcher and
  relaunch it.
  *Expected:* the lock screen again, and the prompt again — a fresh process has no unlock behind it.
- [ ] **3.8 The tab bar and any pushed screen survive the lock.** Before step 3.6, push a detail
  screen (Medications → a medication). Then background for 35 s, return, and unlock.
  *Expected:* you land back on **that detail screen**, not on a tab root. The gate is an overlay
  above the navigation stacks, never a destination, so nothing is popped by it.

### The prompt, and what a refusal does

- [ ] **3.9 Face ID unlocks.** On the lock screen, approve the sheet (**Features → Face ID →
  Matching Face**).
  *Expected:* the gate disappears and the app is usable. Backgrounding for under 30 s from here does
  not bring it back (re-run 3.5 to confirm the unlock stuck for the session).
- [ ] **3.10 Cancelling leaves the gate up, and the button is the retry.** Background for 35 s,
  return, and **cancel** the sheet.
  *Expected:* the sheet goes away and the lock screen is still there — no error message, no toast,
  nothing moves. Tap **"Kilidi aç"**.
  *Expected:* the sheet comes back. This is Android verbatim: only the success callback is
  implemented, so a failure is silence and the button is the only retry.
- [ ] **3.11 A non-matching face does not unlock.** Repeat 3.10 with **Features → Face ID →
  Non-matching Face** until iOS offers the passcode.
  *Expected:* the gate stays up through every failure, and iOS eventually offers **"Parola Kullan"**.
- [ ] **3.12 The passcode is a real fallback.** Take that passcode option and enter the device
  passcode (set one under **Settings → Face ID & Passcode** if the simulator has none).
  *Expected:* the gate opens. *Why this step exists:* the policy is
  `.deviceOwnerAuthentication`, the twin of Android's `BIOMETRIC_WEAK or DEVICE_CREDENTIAL` — a
  phone whose face fails must still be openable by its owner. If this ever asks *only* for a face,
  the policy has been narrowed to `.deviceOwnerAuthenticationWithBiometrics` and that is a bug.
- [ ] **3.13 Disabling the setting while the gate is up removes it instantly.** This one needs two
  hands: it cannot be reached from behind the lock, so use a build where you can toggle the setting
  from another device or re-check it in code review instead. *(No simulator route — recorded as
  covered by `AppLockManagerTests.disablingTheSettingWhileLockedUnlocksImmediately` and not
  reproducible by hand.)*

### The Face ID usage description

- [ ] **3.14 The purpose string is the app's, in the device's language.** On a **Turkish** device,
  trigger the first prompt after a fresh install.
  *Expected:* iOS's own Face ID permission alert quotes **"Uygulama kilidini açmak için Salus'un
  Face ID iznine ihtiyacı var."** Switch the device to English, delete and reinstall, and repeat.
  *Expected:* **"Salus needs Face ID access to unlock the app."**
  *Why this step exists:* a missing `NSFaceIDUsageDescription` does not warn — it **terminates the
  app** on the first evaluation. If the app dies instead of prompting, the key did not reach
  `App/Info.plist`.
  ```sh
  plutil -extract NSFaceIDUsageDescription raw \
    "$(xcrun simctl get_app_container booted com.alicansekban.salus)/Info.plist"
  ```
  *Expected:* the Turkish sentence above.

### Device-only

- [ ] **3.15 On a real device, the lock survives a reinstall of nothing else.** The flag lives in
  the Keychain (`KeychainAppLockFlagStore`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), not
  in `UserDefaults`, so deleting the app's data must not clear it. With the lock on, delete the app
  and reinstall it.
  *Expected:* the lock is **still on** and the first launch is gated. *This step needs a device:*
  the Keychain entitlement is not granted under `swift test`, and this is the only check that the
  store works at all.

---

## §4. The More hub (Task 6)

Written by Task 6 (`Packages/Features/FeatureSettings/Sources/FeatureSettings/ui/more/
MoreScreen.swift`, `MoreScreenComponents.swift`, `MoreSelectionDialog.swift`;
`Packages/SalusUI/Sources/SalusUI/component/SalusListItemChevron.swift`,
`SalusSectionHeader.swift`). The automated half is `MoreViewModelTests` (20 cases, T4) plus
`MoreEffectQueueTests` (2 cases, fix round 1): the five event gates and the buffered effects. What
no test can reach is the row layout and the three dialogs — those are visual and run only on a
device or simulator.

The hub is the More tab's root: `SalusScreenHeader` (no back button — the tab has no parent), then a
scroll column of 13 rows split across five sections by four `SalusSectionHeader` labels, with a
version footer at the bottom. The draw order is `MoreScreen.kt:180-313` verbatim.

**Before you start.** The rows that push the doctor report (M10) and trends (M11) are no-ops today —
the callbacks are TODO stubs in `RootView.swift`. Run those two rows and record the no-op; the
screens they open arrive with their milestones. Cycle is shown only for non-male profiles
(`state.showCycle`); a male profile hides the row and its section label.

### The rows render in the §1 order

- [ ] **4.1 All 13 rows render in order.** Open the More tab on a profile whose sex is **not male**
  (so the Cycle row shows).
  *Expected:* top to bottom — **Profil** (person), **Premium** (crown), **Doktor raporu** (doc),
  **Trendler** (chart), then the **Takip** section with **Regl Takibi** (drop), then **Görünüm**
  with **Tema** / **Renk teması** / **Dil**, then **Güvenlik** with **Uygulama kilidi** (lock) and
  **Güvenli ekran** (camera), then **Bildirimler** with **Bildirimler** (bell) and **Hatırlatıcılar**
  (alarm), then **Uygulama** with **Hakkında** (info), then the version footer
  **"Sürüm x.y.z"**. *Why this step exists:* the order is `MoreScreen.kt:180-313` verbatim — a row
  out of order is the port's most likely regression.
- [ ] **4.1b The four section labels line up with the card edges.** On the same screen, sight down
  the left edge: **Takip**, **Görünüm**, **Güvenlik**, **Bildirimler** and **Uygulama** must start
  at the same x as the cards below them, not a step further right.
  *Expected:* one 16 pt screen inset, applied once by the scroll column — the label carries
  `SalusSectionHeaderDefaults.topOnly`, the twin of Kotlin's
  `contentPadding = PaddingValues(top = SalusSpacing.sm)` (`MoreScreen.kt:363-366`). *Why this step
  exists:* fix round 1 — the labels used to be inset twice (column `lg` + the header's own `lg`).
- [ ] **4.2 The Cycle row and its section are hidden on a male profile.** Switch the profile's sex
  to male (Profile editor), **confirm the sex-change dialog**, return to More.
  *Expected:* no **Takip** section, no **Regl Takibi** row; everything else stays. Now verify the
  sex was actually **stored**: kill and relaunch the app, open **Profil**, and the sex still reads
  male (T5's carry-in check — confirming the dialog must write the sex that was confirmed, not the
  one that was showing). Re-switch to female/other/unspecced, confirm, and the row + section come
  back.

### Pushes

- [ ] **4.3 Profile row pushes the editor and save pops back.** Tap **Profil**.
  *Expected:* the profile editor opens (`.navigationTitle` "Profil", the shell's back button).
  Change the name, tap **Kaydet**, and the editor pops back to More, which now shows the new name
  as the row's subtitle. *Why this step exists:* the push is `navigator.navigate(ProfileKey())`
  and the pop is `ProfileViewModel`'s `navigator.pop()` on save — both go through the shell's one
  `Navigator`, never `backStacks.push` directly.
- [ ] **4.4 About row pushes the About screen.** Tap **Hakkında**.
  *Expected:* the About screen opens with `.navigationTitle` "Hakkında" and the shell's back button
  (no in-screen back button — divergence (d)). The body shows **"Salus"** (headlineMedium, primary),
  the description, and one privacy card. Tap the shell's back button and it pops back to More.
- [ ] **4.5 Reminders row pushes Reminder Health.** Tap **Hatırlatıcılar**.
  *Expected:* the Reminder Health screen opens (the M3 screen). Back returns to More.
- [ ] **4.6 Doctor report and Trends rows are no-ops (M10/M11).** Tap **Doktor raporu**, then
  **Trendler**.
  *Expected:* nothing happens — the rows are tappable but the shell callbacks are TODO stubs until
  `FeatureAIHealth` (M10) and `FeatureTrends` (M11) land. Record the no-op; do not file a bug.
  *Ownership note:* the premium gate that decides whether the report row opens the screen or the
  paywall lives in `MoreViewModel` and is tested there; the row itself is ungated here, by design.
  *Fix-round note:* the effect collector is now `.onChange(of: viewModel.pendingEffects)`, so an
  effect fired minutes after the tab first appeared is still delivered. Nothing observable proves
  that at M8 — every effect-producing branch is behind an entitlement that only M9 can grant — so
  the guarantee is pinned by `MoreEffectQueueTests` instead, and this row becomes a real check when
  M10/M11 fill the callbacks in.

### The three selection dialogs

Each dialog is a **sheet** (fix round 1 — divergence 7), not an action sheet: a title, one
`SalusOptionRow` per option with a radio indicator on the trailing edge, and a tonal **İptal** pill
at the bottom. Every row in one dialog carries the same icon as the More row that opened it; the
indicator is what tells the options apart, exactly as Kotlin's `RadioButton(selected = …)` does.

- [ ] **4.7 Theme dialog opens on row tap, shows the stored pick, and applies the new one.** Tap
  **Tema**.
  *Expected:* a sheet titled **"Tema"** lists **Sistem** / **Açık** / **Koyu** plus an **İptal**
  pill, and **the currently stored mode is drawn selected** (filled radio dot, tinted container).
  Tap **Koyu**.
  *Expected:* the dialog closes, the row's subtitle becomes **Koyu**, and the app's palette flips
  to dark immediately (the theme is resolved in `RootView` from `userSettings.themeMode`). Re-open
  — **Koyu** is now the selected row — and tap **İptal**; nothing changes. Swiping the sheet down
  is the same as **İptal**.
- [ ] **4.8 Color theme dialog shows the full list, the stored pick, and writes only when
  entitled.** Tap **Renk teması**.
  *Expected:* a sheet lists **Klasik** / **Okyanus** / **Gün batımı** / **Orman** plus **İptal**,
  with the **stored** palette drawn selected. *On a free user (the M8 default):* tapping any
  palette closes the dialog and fires the paywall no-op (ruling 5 — `NoOpPaywallRequester` logs the
  source and does nothing visible); the row's subtitle stays **Klasik** (the effective theme
  collapses to Classic for a free user, div. 6) while the dialog keeps showing the stored pick as
  selected. *Why this step exists:* the entitlement gate is in `MoreViewModel`, not the screen — a
  free user may open the picker and tap; nothing is written, and the selection they can see is the
  one that survives a lapse.
- [ ] **4.9 Language dialog shows the current language and applies.** Tap **Dil**.
  *Expected:* a sheet lists **Sistem** / **Türkçe** / **İngilizce** plus **İptal**, with the current
  language drawn selected. Tap **Türkçe**.
  *Expected:* the dialog closes and the row's subtitle becomes **Türkçe**. **The running app's
  strings do not flip until the next launch** (ruling 6 / divergence (a) — the `AppleLanguages`
  override is read at launch time). Kill and relaunch to see the change.

### The app-lock toggle (ruling 4)

- [ ] **4.10 Enabling app lock re-authenticates first.** With Face ID enrolled (Features → Face ID
  → Enrolled) and a device passcode set, tap the **Uygulama kilidi** toggle on.
  *Expected:* the system authentication sheet appears **before** the toggle moves, titled
  **"Uygulama kilidini etkinleştir"**. Approve it (Features → Face ID → Matching Face).
  *Expected:* the toggle is now on. *Why this step exists:* the confirmation is the shell-owned
  `appLockPrompt` closure `MoreRoute` calls (ruling 4 / divergence 2 — the shell owns the
  `LAContext`, the same one `AppLockScreen` reaches through `makeLockPrompt()`). §3.2 is the same
  gate from the lock's side; this row is the setting's side.
- [ ] **4.11 A refused confirmation leaves the toggle off.** Turn the toggle off, then on and
  **cancel** the sheet (or Non-matching Face).
  *Expected:* the toggle springs back to off and nothing is written. Kill and relaunch — still off.
- [ ] **4.12 No biometric and no passcode disables the row.** On a simulator with **no** Face ID
  enrolment and **no** passcode, open More → **Güvenlik**.
  *Expected:* the **Uygulama kilidi** row is **greyed out**, its subtitle is
  **"Bu cihazda ekran kilidi tanımlı değil"**, and tapping it does nothing. (This is §3.1's
  availability check from the More side; run one or the other, not both.)

### The notification row

- [ ] **4.13 The notification row opens the system Settings page.** Tap **Bildirimler**.
  *Expected:* iOS's Settings page for Salus opens (the app's own Settings, not a
  notification-only page — divergence 3, `UIApplication.openSettingsURLString`). Return to Salus;
  the row did not push anything, so More is still where you left it. *Why this step exists:* iOS
  exposes no narrower destination than the app's own Settings; the row is a deep-link, not an
  in-app screen.

---

## What was executed when this section was written (iOS-M8 Task 6)

**Nothing.** Task 6 ran `scripts/build-app.sh` (BUILD SUCCEEDED), `scripts/test-packages.sh`
(24/24 packages passed, including the 20 `MoreViewModelTests` cases from T4 and the
`AppStringCatalogTests` update that drops the two `more_cycle*` keys), and `scripts/lint.sh`
(0 violations). Every §4 row above is **NOT RUN**; the row layout and the three dialogs have never
been observed on any hardware. §4.6 (doctor report / trends no-ops) and §4.8 (free-user color
theme gate) in particular depend on the M9 paywall and the M10/M11 screens that do not exist yet.

**Fix round 1 (review of Task 6) changed three §4-visible things and ran nothing.** The dialogs are
now sheets that draw the stored selection (4.7–4.9 rewritten), the section labels are inset once
rather than twice (4.1b added), and 4.2 carries T5's stored-sex check. The round ran
`scripts/test-packages.sh FeatureSettings SalusUI` (2/2 passed, 68 + 89 tests),
`scripts/build-app.sh` (BUILD SUCCEEDED) and `scripts/lint.sh` (0 violations in 520 files) —
no simulator, no device, no preview render.
---