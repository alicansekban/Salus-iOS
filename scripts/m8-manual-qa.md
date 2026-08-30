# iOS-M8 manual QA — settings, onboarding, app lock and the secure screen

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code. Every step below says **NOT RUN** until someone runs it.

Each section is written by the task that shipped the behaviour it checks, so the file grows a
section at a time and the numbering follows the plan rather than the reading order.

**Language.** The steps quote the Turkish strings, which is what a default simulator shows
(spec §6.4 — Turkish is the default *and* the fallback).

---

## §1. Onboarding (Task 8)

Written by Task 8 (`Packages/Features/FeatureOnboarding/Sources/FeatureOnboarding/ui/
OnboardingScreen.swift`, `OnboardingHeader.swift`, `OnboardingHero.swift`,
`OnboardingStepContent.swift`, plus `OnboardingModule.swift`). The automated half is
`OnboardingUiStateTests` + `OnboardingViewModelTests` (T2/T7): the step machine, the gates and the
three writes `finish()` performs. What no test can reach is the eight step bodies, the header, the
two hero clusters and the keyboard behaviour — those are visual and run only on a device or
simulator.

**Before you start — the gate is mounted since Task 11.** Task 8 shipped the screens and the module;
**Task 11** hung the overlay above `RootView` (ruling 3: onboarding outermost, app lock beneath), so
the rows below are reachable. The wiring around them — that a fresh install opens the flow at all,
that finishing it lands on Home, and that a relaunch does not repeat it — is **§7**, and §1 assumes
it: if you cannot reach the Welcome step, run §7.1 first and stop there.

**How to get back to a first launch.** The gate is `onboarding_completed` in `UserDefaults`
(Android-verbatim key). Delete the app from the simulator and reinstall — that clears the defaults
*and* the database, which is what makes §1.9's "the profile row was empty before" checkable. Do not
try to reset by editing defaults by hand; the weight row in §1.9 needs an empty vitals history too.

**The order under test** is `OnboardingStep.allCases`: Welcome → Ad → Cinsiyet → Doğum tarihi →
Boy → Kilo → Sağlık notları → Bildirimler. Welcome carries no header, so the counter runs **1/7 …
7/7** over the seven asking steps, never 1/8.

### The flow renders and walks

- [ ] **1.1 The eight steps render in order.** Fresh install, launch.
  *Expected:* the **Welcome cover** first — a large rounded shield cluster, **"Salus'a Hoş
  Geldiniz"** centred under it, the body paragraph under that, and a full-width **"Başla"** pill
  with a forward arrow at its trailing edge. **No header**: no back button, no progress bar, no
  counter, and no skip button. Tap **Başla** and walk forward with **Devam Et**, checking each
  step in turn:
  1. **Ad** — "Adınız Nedir?" over a pill text field placeholdered **"Örn: Ayşe"**;
  2. **Cinsiyet** — badge, left-aligned heading, three option rows **Kadın / Erkek / Diğer**;
  3. **Doğum tarihi** — "Doğum Tarihiniz" over the date field showing **"Tarih seçin"**;
  4. **Boy** — decimal field, suffix **cm**, placeholder **"Örn: 170"**;
  5. **Kilo** — decimal field, suffix **kg**, placeholder **"Örn: 70"**;
  6. **Sağlık notları** — a 240 pt note area with the green **"Yalnızca bu cihazda"** lock chip
     pinned to its bottom-right, and a shield privacy card under it. Two cosmetics to judge here,
     both known and neither blocking: (a) the placeholder **"Örn: …"** may sit ~8 pt above where
     the first typed character lands, so watch for a small jump on the first keystroke
     (`UITextView`'s `textContainerInset.top`, uncancelled); (b) tap **mid-paragraph** in a note
     you have already typed a few lines of — the caret must move **without the keyboard dropping
     and bouncing back** (the screen's `salusDismissesKeyboardOnTap` sees every tap, and this is
     the app's first multi-line editor under it). Record either as a finding if it is worse than
     described;
  7. **Bildirimler** — the bell/heart hero cluster, the body paragraph, one benefit card
     (**"Zamanında Hatırlatma"** over "Asla bir dozu kaçırmayın."), and the primary button now
     reading **"İzin Ver"** with a **tick** rather than an arrow.
  Finally, compare the header's **back chevron** against the back button on a pushed screen (More ›
  Profil): the onboarding one is hand-drawn at a 24 pt SF Symbol where Material's 24 dp is a
  bounding box, so it may read **larger** than every other back button in the app. Cosmetic —
  record the size, do not block on it.
  *Why this step exists:* the order and the two hero steps are `OnboardingStep.kt` + Kotlin's
  `OnboardingStepContent.kt:64-188` verbatim; a step in the wrong place is the port's most likely
  regression.
- [ ] **1.2 The header counts 1/7 … 7/7 and the bar only ever grows.** On each step after Welcome,
  read the header.
  *Expected:* section title centred — **Kişisel Bilgiler** on the five personal steps
  (Ad, Cinsiyet, Doğum tarihi, Boy, Kilo), **Sağlık Notları** on the notes step,
  **Gizlilik Tercihleri** on the notifications step — over a short 128 pt bar, with a filled circle
  at the trailing edge reading **1/7**, **2/7**, … **7/7**. The bar grows monotonically across the
  whole flow and **never resets** when the section title changes.
- [ ] **1.3 Back walks in-flow and the first step is a no-op.** From **Kilo**, tap the header's
  back chevron three times.
  *Expected:* Boy → Doğum tarihi → Cinsiyet, each with the counter and bar going down. Keep tapping
  back to **Ad**, then tap back once more.
  *Expected:* the **Welcome cover** returns (`stepIndex` 1 → 0). On Welcome there is no header and
  therefore no back button at all — and **the flow cannot be escaped**: there is no swipe-from-edge
  and no system back that leaves it (ruling 8, `OnboardingScreen.swift`'s `BackHandler` note).
  Try the edge swipe on Welcome and on Ad and record that nothing happens.
- [ ] **1.3b The gate is opaque before it has anything to show.** Cold-start the app from a fresh
  install and watch the **very first frame** (record the screen and step through it if the eye
  cannot catch it).
  *Expected:* the app goes launch screen → **solid background** → Welcome cover. At no point does
  the **Home tab** (tab bar, cards) appear behind or through the gate, not even for one frame.
  *Why this step exists:* `OnboardingRoute` builds its ViewModel in `.task`, which runs *after* the
  first render pass, so the loading branch has to paint the same opaque background the screen does
  (review I-1). A flash of the live app behind the gate is the regression.
- [ ] **1.4 Values survive a walk back and forward.** Type **Ayşe** on Ad, pick **Kadın**, set a
  birth date, type **170** on Boy. Walk back to Ad and forward again.
  *Expected:* every answer is still there — the name field still reads Ayşe, Kadın is still the
  selected row, the date still shows, Boy still reads 170.

### The gates

- [ ] **1.5 Cinsiyet is the one hard gate.** Arrive on **Cinsiyet** with nothing picked.
  *Expected:* **Devam Et** is visibly **disabled** (dimmed) and does nothing when tapped, and there
  is **no skip button** on this step — it is the only asking step that is not skippable
  (`isSkippable`, ruling 8). Tap **Kadın**: the row fills with the cycle accent, the button enables,
  and Devam Et advances.
- [ ] **1.6 A present-but-unusable measurement blocks Devam Et; empty does not.** On **Boy**, type
  **12**.
  *Expected:* the field turns to its error style and the supporting text reads **"50 ile 250 cm
  arasında bir değer girin."**; **Devam Et** is disabled. Clear the field to empty.
  *Expected:* the error goes away and **Devam Et** enables again — an unanswered step is allowed
  through, only a wrong answer is not. Repeat on **Kilo** with **5** and the message **"20 ile 400
  kg arasında bir değer girin."**
- [ ] **1.7 A Turkish decimal comma is a valid weight.** On **Kilo**, type **72,4** on the Turkish
  keyboard (the decimal key types a comma).
  *Expected:* **no error**, **Devam Et** enabled. *Why this step exists:* `MeasurementInput`
  normalises comma→dot (divergence (h)); Kotlin's `toDoubleOrNull` accepts no comma, so this is the
  one input where the two platforms take different characters for the same number. Record the
  numeric value that reaches the weight chart in §1.9 — it must be **72,4 kg**, not 724 and not 72.

### Skip clears the step

- [ ] **1.8 Şimdilik Atla clears the step's own answer and advances.** For each of **Ad**, **Doğum
  tarihi**, **Boy**, **Kilo**, **Sağlık notları** in turn: type/pick an answer, tap **Şimdilik
  Atla**, then walk **back** to that step.
  *Expected:* the step is **empty again** — the name field blank, the date field back to "Tarih
  seçin", the measurement fields blank, the note area back to its placeholder. Skip **clears**, it
  does not merely pass by (ruling 8). Also confirm the skip button reads **"Daha Sonra"** on the
  notifications step and **"Şimdilik Atla"** everywhere else, and that it is absent on Welcome and
  on Cinsiyet.

### Finishing writes three things, in order

- [ ] **1.9 Bitir writes the profile, then the weight, then the flag.** Walk the flow answering
  **Ad = Ayşe**, **Cinsiyet = Kadın**, a birth date, **Boy = 170**, **Kilo = 72,4**, a note. On the
  last step the primary button reads **"İzin Ver"** (notifications) — tap it, answer the system
  permission sheet either way (see §1.10), and the flow closes.
  *Expected, in the app:*
  a. the gate disappears and the **Home tab** is showing — no onboarding on any later launch,
     including after a force-quit;
  b. **Daha Fazla › Profil** shows **Ayşe**, the sex **Kadın**, the birth date and **170** cm, and
     the note text in the notes field;
  c. **Ölçümler › Kilo** has **exactly one** entry, **72,4 kg**, timestamped now — the weight is a
     measurement, not a profile field (ruling 7), so it lands in the vitals history and the chart
     starts from it.
  *Why the order matters:* the profile is written first and the flag last, so a crash midway
  replays the flow rather than stranding a half-filled profile behind a closed gate. There is **no
  error UI** on this step by design (ruling H-4): if a write fails the button simply re-enables and
  the step stays open.
- [ ] **1.10 Denial is not a dead end.** Reinstall and walk to **Bildirimler**. Tap **İzin Ver** and
  **Reddet** on the system sheet.
  *Expected:* the flow finishes anyway — exactly as if you had allowed (divergence (e)). Reinstall
  once more and this time tap **Daha Sonra** instead.
  *Expected:* the flow finishes and **no system permission sheet is ever shown** — the skip button
  advances without asking. In both cases **Daha Fazla › Hatırlatıcılar** is where the permission can
  be fixed later, and it should report notifications as not authorised.

### Type sizes and locales

- [ ] **1.11 Turkish at AX5 does not clip.** Settings › Accessibility › Display & Text Size › Larger
  Text, slider to the **largest** (AX5). Walk all eight steps in Turkish.
  *Expected:* every heading and body paragraph **wraps** rather than truncating with an ellipsis;
  the header's section title and the **1/7** counter stay legible and do not overlap the back
  button; the primary pill's label wraps or the pill grows rather than the text being cut; the
  longest strings in the flow — `onboarding_sex_body`, `onboarding_notes_privacy_body` and
  `onboarding_notifications_body` — are readable end to end by scrolling. Short steps stay
  **vertically centred**; long ones simply scroll (that is the one layout trick in
  `OnboardingScreen.swift`'s `steps`).
- [ ] **1.12 English is a full peer.** Switch the device (or the app, via Daha Fazla › Dil, which
  applies on next launch — divergence (a)) to English, reinstall, walk the flow.
  *Expected:* every string above appears in English — "Welcome to Salus", "Continue", "Skip For
  Now", "Allow", "Later", "Finish", "Step 2 of 7" for the bar's VoiceOver label — and nothing shows
  a raw key such as `onboarding_next`. *Why this step exists:* a `.xcstrings` is compiled only by
  Xcode, so `swift test` cannot see a missing translation at all.

### Accessibility

- [ ] **1.13 VoiceOver reads the position once, not twice.** Turn VoiceOver on and swipe through the
  header of any asking step.
  *Expected:* the progress bar announces **"Adım 2 / 7"**; the counter circle beside it is **not**
  focusable and announces nothing — the same fact twice in a row is the thing being avoided (the M7
  sparkline precedent). The two hero clusters (Welcome, Bildirimler) are likewise skipped entirely.
  Focus the header's **back button**: it announces **"Geri"** (`onboarding_back`), and in English
  **"Back"**. *Why this row says so explicitly:* this is the only back button in the app that draws
  itself — every other one belongs to the shell's `NavigationStack`, which is why the rest of the
  port carries no back label at all (divergence (d)). Controller ruling H-8 restored the key for
  this button; an unlabelled chevron here is the regression to look for.

## What was executed when this section was written (iOS-M8 Task 8)

**Nothing.** Task 8 ran `scripts/test-packages.sh FeatureOnboarding SalusUI` (2/2 packages passed),
`scripts/build-app.sh` (BUILD SUCCEEDED — the first build that compiles `FeatureOnboarding` against
the iOS SDK at all, since this task links it in `project.yml`) and `scripts/lint.sh` (0 violations).
Every §1 row above is **NOT RUN**, and until Task 11 mounts the overlay above `RootView` none of
them is even reachable — the eight step bodies, the two hero clusters and the header have never
been drawn on any hardware. The eight `#Preview`s in `OnboardingScreen.swift`, one per step, ship
for the user's own inspection; no agent has rendered them either.

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
`App/Lock/AppLockScreen.swift`, `App/Lock/LockPrompting.swift`), and **runnable since Task 11**,
which mounted the gate (`App/RootView.swift`, `App/RootGates.swift`, `App/Lock/AppLockGate.swift`)
and forwarded the scene transitions that drive it (`App/SalusApp.swift`). Task 11 also added
**3.16–3.18** at the end of this section — the three checks that belong to the wiring rather than to
the manager.

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

### The shell's half of the gate (Task 11)

These three are about the *wiring*, not the state machine: everything above assumes the gate is
drawn at the right moment, and these are the moments where "right" is not obvious.

- [ ] **3.16 With the lock OFF, a cold start shows no gate and asks for nothing.** Make sure the
  **Uygulama kilidi** toggle is **off**, kill the app from the app switcher, and relaunch it —
  watching the *first half second* closely, ideally two or three times in a row.
  *Expected:* the launch screen hands straight over to Home. **No lock badge, no "Salus kilitli",
  and above all no Face ID sheet — not even for one frame.**
  *Why this step exists:* `AppLockManager.isLocked` starts **`true`** on purpose (its divergence 3 —
  an unread setting must not draw the app's contents), so between launch and the first
  `userSettings` emission the manager honestly says "locked" for a setting nobody has read. Two
  things stop that becoming a visible gate: `hasReadSetting`, which `RootGates.resolve` requires
  before it will draw the lock, and the splash-hold, which draws nothing at all until
  `onboarding_completed` answers. If either is dropped, this step is what shows it — and it shows
  it as a Face ID prompt fired at a user who never enabled the lock, because `AppLockScreen`
  prompts on appearance.
- [ ] **3.17 With the lock ON, the gate arrives without the app flashing behind it.** Turn the lock
  on (§3.2), kill the app, and relaunch — again watching the first half second.
  *Expected:* a blank frame, then the lock screen. **The tab bar and Home never appear**, not
  even for a frame, and no screen contents are visible behind the lock badge.
  *Not a bug:* the blank frame is `SplashHoldCover`, which paints the app's own `background` token,
  while `UILaunchScreen` before it is empty and therefore paints the *system* background. Where the
  two colours differ you may see one frame of colour step between them. Report a **flash of app
  content**, not a flash of a slightly different grey.
  *Why this step exists:* this is ruling 3's splash-hold from the other side. The lock is an overlay
  over a `TabView` that is mounted and laid out underneath it (exactly as Android composes
  `SalusApp()` under its splash), so "the gate covers everything" is a claim about z-order and
  opacity that only the eye can check.
- [ ] **3.18 On a reinstall, onboarding sits ON TOP of the lock.** This is the one state where both
  gates are up at once, and it is reachable on a **device** only (see 3.15): with the lock **on**,
  delete the app and reinstall it. The Keychain keeps `app_lock_enabled`; the reinstall clears
  `onboarding_completed`.
  *Expected:* the **onboarding Welcome step** is what you see — not the lock screen. A Face ID sheet
  may appear over it (the lock gate is drawn underneath and prompts on appearance); dismissing or
  approving it leaves onboarding exactly where it was, and the flow is walkable from there. Finish
  the flow: at the end you land on the **lock screen**, and only after unlocking, on Home.
  *Why this step exists:* the order is Android's, verbatim — "Onboarding sits outermost — a first
  launch has nothing to lock" (`MainActivity.kt:96-98`, ruling 3). If the lock is on top instead,
  the two `if`s in `RootView`'s `ZStack` have been swapped.

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
  *Expected:* a sheet lists **Sistem dili** / **Türkçe** / **English** plus **İptal**, with the
  current language drawn selected, and a footnote line under the options reading
  **"Değişiklik, uygulamayı yeniden açtığınızda uygulanır."** (the option labels are the catalog's
  own — `language_english` is "English" in **both** locales and `language_system` is "Sistem dili";
  corrected here by Task 12, which added the footnote). Tap **Türkçe**.
  *Expected:* the dialog closes and the row's subtitle becomes **Türkçe**. **The running app's
  strings do not flip until the next launch** (ruling 6 / divergence (a) — the `AppleLanguages`
  override is read at launch time). Kill and relaunch to see the change — §5 is that half.

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

## §5. Language (Task 12)

Written by Task 12. The files, under
`Packages/Features/FeatureSettings/Sources/FeatureSettings/`:
`data/UserDefaultsAppLocaleController.swift` and `domain/AppLocaleController.swift` (both T3),
`ui/more/MoreSelectionDialog.swift` + `ui/more/MoreScreen.swift` (the footnote T12 added); plus
`project.yml`'s `options.developmentLanguage: tr` + `settings.base.DEVELOPMENT_LANGUAGE: tr`, and
`App/RootTab.swift` + `App/RootView.swift` for §5.10. §4.9 checks the
*dialog*; this section checks the *pipeline*: what the picked language does to the app after it
restarts, and what it does to a user who never opens the dialog at all.

The automated half is `UserDefaultsAppLocaleControllerTests` (the three `AppleLanguages` writes and
the four `current()` readings) and the ten `…StringsTests` suites (`tr` is the source language, every
key carries both locales). None of them can prove what the **system** does with the key at launch,
because `UserDefaults` is only half the mechanism — `UIApplication` reads it while the process starts
and picks the bundle's localization from it. That half has no test on any platform, so every row
below is the only check it gets.

**The mechanism, so a failure can be read.** `apply(_:)` writes `AppleLanguages` into the app's own
`UserDefaults`: `["tr"]` for Türkçe, `["en"]` for English, and it **removes** the key for Sistem
dili. iOS reads that key at process start only, which is why nothing changes until a relaunch
(ruling 6, **recorded divergence (a)** — Android's appcompat recreates the activity instead). With no
key, the device's own language order applies, resolved against the bundle's `tr` and `en` `.lproj`s
and falling back to `tr` (`developmentRegion`) for anything else — spec §6.4.

**How to relaunch properly.** Swipe the app out of the app switcher, or stop and re-run from Xcode.
Backgrounding is **not** enough: the process survives, and so does the language it launched with.

**Before you start.** Note the device's own language (Settings → General → Language & Region);
several rows below change it and the last one restores it.

### The pick survives, and lands, on the next launch

- [ ] **5.1 Türkçe → relaunch → Turkish.** On a device whose own language is **English** and with
  no override set, the app starts in English — so open **More → Language** (not "Dil"; the row is
  still English at this point), tap **Türkçe**, then kill and relaunch the app.
  *Expected:* the whole app is Turkish — More's header is **"Diğer"** and the section labels are
  **"Takip"** / **"Görünüm"** / **"Güvenlik"**, with the **Dil** row's subtitle **Türkçe**.
  Settings → Salus (the iOS Settings page) now offers a **Preferred Language** row reading
  **Türkçe**. *Why this row exists:* it is the only proof that the key the controller writes is the
  key `UIApplication` reads. If the app comes back English, the write landed in the wrong defaults
  suite or the bundle has no `tr.lproj`.
- [ ] **5.2 English → relaunch → English.** From 5.1, open More → **Dil**, tap **English**, kill and
  relaunch.
  *Expected:* the whole app is English — **"More"**, **"Tracking"** / **"Appearance"** /
  **"Security"**, and the language row reads **Language / English**. The onboarding and lock copy is
  English too if you can reach it (§1, §3): every package catalog carries `en`, so the override is
  bundle-wide, not settings-only.
- [ ] **5.3 Sistem dili → relaunch → the device's language.** From 5.2, open the dialog and tap
  **System language**, kill and relaunch.
  *Expected:* the app comes back in the **device's** language rather than the one last picked —
  English on an English device. Re-open the dialog: **System language** is the selected row. *Why
  this row exists:* `system` is a **removal**, not a third stored value; if the app stays on the
  previous pick, the key was overwritten instead of removed and `current()` will keep answering the
  stale language forever.
- [ ] **5.4 A relaunch is required, and only a relaunch.** With the app in Turkish, open the dialog
  and tap **English**, then **background** the app (home gesture) and come back.
  *Expected:* the app is **still Turkish**; only the row's subtitle says **English**. Now kill and
  relaunch — it is English. *Why this row exists:* this is divergence (a) itself. The footnote in the
  dialog (§4.9) is the app's only warning, and this row is what proves the warning is honest rather
  than a hedge.

### The user who never opens the dialog

- [ ] **5.5 A system-language user is untouched.** Delete the app and reinstall it (a fresh install
  has no `AppleLanguages` key). Walk far enough into onboarding to read some copy, then — **without
  ever opening the language dialog** — change the device language (Settings → General → Language &
  Region) to the other one of Turkish/English and relaunch Salus.
  *Expected:* the app follows the device, both times, and Settings → Salus shows **no** Preferred
  Language row until the dialog has been used at least once. *Why this row exists:* the override must
  be opt-in — writing `["tr"]` at first launch would pin every user to Turkish and make the device
  setting dead.

### The Turkish fallback (spec §6.4)

- [ ] **5.6 A third system language falls back to Turkish, not English.** With **no** override set
  (5.5's state — reinstall if unsure), set the device language to one the app does not ship,
  **Deutsch** or **Français**, and relaunch Salus.
  *Expected:* the app is **Turkish** — every screen, every package: More, onboarding, the lock, the
  notification copy. *Why this row exists:* Xcode's default development region is `en`, while the
  Android app falls back to `values/`, which is Turkish. `project.yml` says `tr` twice
  (`options.developmentLanguage` for the project's `developmentRegion`, `DEVELOPMENT_LANGUAGE` for
  `CFBundleDevelopmentRegion`) precisely so both platforms answer the same for this user. **If this
  screen comes back English, one of those two lines was lost** — that is the whole failure mode, and
  it is invisible on a TR or EN device.
- [ ] **5.7 …and an override still wins over the fallback.** From 5.6 (device in Deutsch, app in
  Turkish), open More → **Dil** → **English**, kill and relaunch.
  *Expected:* the app is English.
- [ ] **5.8 The Info.plist purpose strings follow the same override.** With the app in English (5.2
  or 5.7), reach the Face ID prompt (§3.2 — turn the app lock on) and, on iOS 26+, the AlarmKit
  permission (§3 / M5).
  *Expected:* the system sheets show the **English** sentences from `App/en.lproj/InfoPlist.strings`,
  not the Turkish ones from `Info.plist`. Switch to Türkçe, relaunch and repeat: the Turkish
  sentences. *Why this row exists:* each purpose string lives in three places (the plist base value
  and the two `.lproj` peers) and only a real prompt shows which one the system picked.
- [ ] **5.9 Restore the device language.** Set Settings → General → Language & Region back to what
  you noted before 5.1, and set the app back to **Sistem dili**.

### The tab bar

- [ ] **5.10 The five tab labels are Turkish in Turkish.** In Turkish (5.1), look at the tab bar.
  *Expected:* **Ana Sayfa / İlaçlar / Ölçümler / Randevular / Daha Fazla**, left to right in that
  order, each under the icon it had before. Switch to English (5.2), relaunch, and look again:
  **Home / Medications / Vitals / Appointments / More**. *Why this row exists:* until iOS-M8 T12
  these were five hardcoded English words (`RootTab.placeholderLabel`, the M0 placeholder), so a
  Turkish app had an English tab bar — the most visible §6.4 violation there was. Controller ruling
  H-10 ported Android's five `nav_*` keys (`app/src/main/res/values{,-en}/strings.xml:5-10`,
  verbatim) and the app catalog went 3 → 8 keys. This row is what proves the labels now follow the
  override like everything else.
- [ ] **5.11 The labels still fit at the largest Dynamic Type size.** With the app in Turkish, set
  Settings → Accessibility → Display & Text Size → Larger Text to the largest non-accessibility
  size.
  *Expected:* the five labels truncate the way iOS truncates any tab title — no overlap, no icon
  pushed out of place. **Daha Fazla** and **Randevular** are the long ones and are what to watch;
  Turkish is longer than English on four of the five, which is exactly why this is checked here and
  not left to §6 (Task 14's Dynamic Type pass, which covers the screens rather than the shell).

---

## What was executed when this section was written (iOS-M8 Task 12)

**Nothing.** Task 12 added the dialog footnote (`language_relaunch_note`, the settings catalog's
88th key), verified that the launch-time wiring was already complete (T3's controller, T6's dialog
and `project.yml`'s two `tr` lines — nothing was missing in `SalusApp.swift`, exactly as the brief
predicted), and ran `scripts/test-packages.sh` (all 24 packages), `scripts/build-app.sh` and
`scripts/lint.sh`. Every §5 row above is **NOT RUN**: no simulator, no device, no language has ever
been switched on any hardware. §5.6 has never been observed and is the row most likely to surprise —
it is the only one that exercises the fallback the spec argues about, and the only one no TR or EN
device can fail.

**Fix round 1 (controller ruling H-10) localized the tab bar and ran nothing on hardware.** §5.10
was a *record-the-gap* row and is now a real check, and §5.11 (Dynamic Type on the Turkish labels)
is new beside it. The round ported Android's five `nav_*` keys into the app catalog (3 → 8),
replaced `RootTab.placeholderLabel` with `RootTab.label` resolving through `AppStrings`, and ran
`scripts/test-packages.sh SalusTesting` (32 tests, 5 suites), `scripts/build-app.sh` (BUILD
SUCCEEDED) and `scripts/lint.sh` (0 violations in 527 files). The compiled bundle was read to
confirm the five keys are present in both `tr.lproj` and `en.lproj` with the Android values —
file inspection of the build product, not a simulator run.

---

## §7. The shell wiring (Task 11)

Written by Task 11 (`App/RootView.swift`, `App/RootGates.swift`, `App/Lock/AppLockGate.swift`,
`App/SalusApp.swift`, `App/AppCompositionRoot.swift`, `App/AppCompositionRoot+Modules.swift`). This
section is about the seams: the More tab is a *mounted* hub rather than a placeholder, the two gates
are *overlays over the `TabView`* rather than destinations, and the tab bar hides on a push. What
each screen draws once it is on screen belongs to §1 (onboarding), §3 (the lock) and §4 (the hub) —
those rows are not repeated here.

The automated half is nothing: the app target has no test bundle (`project.yml`'s
`scheme.testTargets: []`, the M8 "no app test target" decision), so the only mechanical guard on
this task is that it compiles. `RootGates.resolve` is pure and total and can be read on its own, but
it has no runner. Everything below is therefore the *only* check these seams get.

**Before you start.** Several rows need a fresh install (delete the app to clear
`onboarding_completed`). On a **device** a delete does **not** clear `app_lock_enabled` — it lives
in the Keychain (§3.15) — so turn the lock off before deleting unless the row says otherwise.

### The first launch

- [ ] **7.1 A fresh install opens onboarding, and never Home first.** Delete Salus, reinstall, and
  launch it — watching the first half second.
  *Expected:* a blank frame, then the onboarding **Welcome** step. **The tab bar and Home never
  appear**, not for a frame. (The blank frame is the app's background token, not the system launch
  background — see the "not a bug" note on §3.17 if the two colours step.) *Why this step exists:* `onboardingCompleted` is `Bool?` and starts
  `nil`; while it is nil the shell draws `SplashHoldCover` over everything (ruling 3, divergence
  (f) — iOS has no `installSplashScreen`, so this is the hold). A default of `false` here would
  flash onboarding on every launch; a default of `true` would flash Home on the first one.
- [ ] **7.2 Walking the flow to the end lands on Home, with no gate left behind.** From 7.1, walk
  all eight steps (the §1 rows describe each one) and finish.
  *Expected:* the onboarding overlay disappears and you are on the **Home tab**, with the tab bar
  visible and Home's own content drawn — not on a blank frame, not on the More tab, and not on a
  second copy of onboarding. *Why this step exists:* the flow closes itself by writing
  `onboarding_completed` (T8 — the Route has no callback and hands nothing back out), and the
  shell's `userSettings` loop is the only thing that notices. If the overlay stays up, that loop is
  not reading the flag; if the app is blank, the hold is being re-entered.
- [ ] **7.3 Killing and relaunching does not repeat onboarding.** From 7.2, kill Salus from the app
  switcher and relaunch.
  *Expected:* straight to Home. No Welcome step, no flash of one.
- [ ] **7.4 Onboarding cannot be escaped by the edge swipe or by backgrounding.** Re-do 7.1 to get
  the flow back, advance to step 2 or later, then (a) swipe from the left edge of the screen, and
  (b) press **Home**, wait five seconds, and return.
  *Expected:* in both cases the flow is still up, on the same step. *Why this step exists:* ruling 8
  — the gate is an overlay with no navigation container, so there is nothing to swipe back *to*;
  this row proves nobody has since wrapped it in a `NavigationStack` or a `.sheet`.

### The More tab is the hub

- [ ] **7.5 The More tab's root is the hub, not a placeholder.** Tap the **More** tab.
  *Expected:* the settings hub — the header, the 13 rows and the version footer described in §4.
  There is no "placeholder" text and no empty screen. *Why this step exists:* `PlaceholderScreen`
  was deleted in T6 and the tab now mounts `MoreRoute`; this row is what proves the shell mounts it
  rather than something else.
- [ ] **7.6 Every row the hub pushes renders, and the shell's back button returns.** From the hub,
  push **Profil**, come back; **Hakkında**, come back; **Hatırlatıcılar**, come back; **Regl
  Takibi** (on a non-male profile), come back.
  *Expected:* all four open a real screen and all four return to the hub. *Why this step exists:*
  three of them (`ProfileKey`, `AboutKey`, `ReminderHealthKey`) are registered by
  `settingsDestinations()` and the fourth (`CycleKey`) by `cycleDestinations()` — both applied to
  the More stack. A key with no registered destination pushes *nothing*, silently, which looks
  exactly like a dead row.
- [ ] **7.7 The two unbuilt rows are no-ops and say so by doing nothing.** Tap **Doktor raporu**,
  then **Trendler**.
  *Expected:* nothing happens, twice. The shell callbacks are TODO stubs until M10/M11 (this is
  §4.6 from the shell's side; run one or the other, not both).

### The tab bar belongs to the shell

- [ ] **7.8 The tab bar hides on every push and comes back on every pop.** In each of the five tabs
  in turn, push the deepest screen you can reach — Home → a card that pushes (**Regl Takibi**),
  Medications → a medication → its editor, Vitals → the weight editor, Appointments → an
  appointment → its editor, More → **Profil**.
  *Expected:* the tab bar is **gone** on every pushed screen, and the screen uses the full height
  down to the home indicator. Going back brings it straight back, with the system's own slide
  animation.
  *Why this step exists:* `.toolbar(backStacks.isAtRoot(tab) ? .visible : .hidden, for: .tabBar)` is
  written once, on the stack, by the shell — the twin of Android's `showBottomBar`
  (`SalusApp.kt:133-136`). A feature that writes its own `.toolbar(…, for: .tabBar)` is a lint
  error (`no_tab_bar_toolbar_in_features`), so a bar that stays visible on a push means the shell's
  own line moved or the tab's root grew a wrapper.
- [ ] **7.9 A gate covers the tab bar too.** With the lock on (§3.2), background for 35 s and
  return.
  *Expected:* the lock screen covers the **whole window including the tab-bar band** — no tab
  icons peeking out at the bottom, and tapping where a tab icon used to be switches nothing.
  Repeat with onboarding (7.1): the Welcome step covers the same band.
  *Why this step exists:* the gates are siblings of the `TabView` inside `RootView`'s `ZStack`, not
  overlays inside a tab, so they are laid out against the window rather than the tab's content
  region. The snackbar host is the deliberate opposite (it sits *inside* the tab so it lands above
  the bar); if a gate ever starts behaving like the snackbar, this row is what catches it.

### The gates do not disturb what is behind them

- [ ] **7.10 A pushed screen survives the lock.** Push More → **Profil**, background for 35 s,
  return, unlock.
  *Expected:* you are back on **Profil**, not on the More root and not on Home. (§3.8 is the same
  check from the lock's side, on the Medications stack; running either is enough.) *Why this step
  exists:* "Overlays, not destinations: the back stack and pending notification deep links stay
  intact behind the gates" (`MainActivity.kt:96-98`).
- [ ] **7.11 The cycle-calendar memo still holds behind the gates — reminder then reminder.** Needs
  a cycle reminder you can fire twice: set the cycle reminder to a near time (More → **Regl
  Takibi** → the reminder settings), let it fire, and tap the notification. You land on **Home**
  with the calendar pushed. Now, **without popping it**, pull the notification centre down and tap
  the *same* notification again.
  *Expected:* nothing is pushed the second time — you are still on **one** calendar, and one back
  tap returns you to Home. *Why this step exists:* `pushCycleCalendar` memoizes the stack depth its
  push left (`D-M7-ab`), and T11's gates sit above the `TabView` and outside every
  `NavigationStack`, so they neither push nor pop and the memo still means what it meant. If a
  second tap stacks a second calendar you have to dismiss twice, a gate has started touching the
  back stack.
- [ ] **7.12 …and card then reminder.** Pop back to Home, open the calendar from the **Regl Takibi**
  card, and then tap the cycle notification while it is open.
  *Expected:* again exactly one calendar. *Why this step exists:* the card's push seeds the memo
  through `observeNavigationCommands` rather than clearing it, which is the case that would
  otherwise let the following reminder tap open a second calendar.
- [ ] **7.13 The secure-screen curtain is drawn over the gates, not under them.** With the lock on,
  background for 35 s and return so the lock screen is up, then — without unlocking — press **Home**
  and open the app switcher.
  *Expected:* the Salus card in the switcher is **blurred**, exactly as §2.1 describes for the app
  itself. Repeat with onboarding up.
  *Why this step exists:* `.secureScreen(…)` is applied *outside* the `ZStack` that holds the gates
  (§2.8), so the curtain covers them too. If a gate shows through the blur, the modifier order in
  `RootView.body` has been changed.

### The scene transitions reach the graph

- [ ] **7.14 Backgrounding still commits an open undo window.** Delete a medication so the undo
  snackbar appears, and — while it is still showing — press **Home**. Wait five seconds, return.
  *Expected:* the snackbar is gone and the medication is **deleted**; the undo did not survive the
  backgrounding. *Why this step exists:* the app lock's two calls were added to the same
  `onChange(of: scenePhase)` switch that already drove `reminderDidBecomeActive()` and
  `commitPendingDeletes()`, and this row is what proves the older two still fire from the arms the
  new ones were added to.
- [ ] **7.15 Returning to the foreground still refills the reminder window.** With at least one
  future appointment reminder, background the app, return, and open More → **Hatırlatıcılar**.
  *Expected:* Reminder Health's "last sync" line shows a time from the last few seconds. *Why this
  step exists:* same reason as 7.14, for the `.active` arm.

---

## What was executed when this section was written (iOS-M8 Task 11)

**Nothing.** Task 11 ran `scripts/build-app.sh` (BUILD SUCCEEDED), `scripts/lint.sh` (0 violations)
and `scripts/test-packages.sh SalusTesting SalusCommon` (2/2 packages passed). No simulator was
booted, no preview was rendered, and no screenshot was taken — every row in §7, and the three rows
Task 11 added to §3 (3.16–3.18), is **NOT RUN**.

Two rows in this section cannot be run on a simulator at all and are flagged where they appear:
§3.18 (both gates at once) needs a device, because it depends on the Keychain surviving a delete.
