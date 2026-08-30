# iOS-M8 manual QA — settings, onboarding, app lock and the secure screen

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code. Every step below says **NOT RUN** until someone runs it.

Each section is written by the task that shipped the behaviour it checks, so the file grows a
section at a time and the numbering follows the plan rather than the reading order.

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
  *If the simulator instead shows a black or empty app window as soon as the toggle goes on* —
  i.e. the app itself is broken, not the screenshot — that is the known simulator artefact the Task
  10 brief anticipated: the fix is to wrap `SecureScreenMask.apply()`/`remove()` in
  `#if !targetEnvironment(simulator)`. Report it rather than working around it.

- [ ] **2.5 The mask is reversible.** Turn **Güvenli ekran** back off, then take another screenshot.
  *Expected — device:* the screenshot shows the app normally again. *Expected — simulator and
  device:* the app keeps drawing and keeps responding to taps through both flips — scroll the list
  and open an editor after each one. *Why this row exists:* the mask re-parents the app's root layer
  under the text field's content layer and `setEnabled(false)` puts it back; a one-way door would
  leave the app permanently masked or, worse, permanently blank.

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
`scripts/lint.sh` (0 violations in 491 files) and wrote this section from the code. Every §2 row
above is **NOT RUN**. §2.4 and §2.6 in particular have never been observed on any hardware, and
they are the two rows that carry the feature's actual promise.
