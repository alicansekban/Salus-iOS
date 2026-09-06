# iOS-M14 manual QA — the M12 UI refresh mirror

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code — the file is written by the agents, run by the user. Every row
below says **NOT RUN** until someone runs it.

Each section is written by the task that shipped the behaviour it checks, so the file grows a
section at a time and the numbering follows the plan rather than the reading order.

**Language.** The steps quote the Turkish strings, which is what a default simulator shows
(spec §6.4 — Turkish is the default *and* the fallback).

This milestone mirrors Android's M12 UI refresh (`56ccb9b`): a gradient hero header with a
personalised greeting, an avatar and a dose-progress ring on Home; feature-accented card badges;
vitals stat tiles. The automated half is `FeatureHomeTests` (47 tests) plus
`SalusDesignSystemTests`/`SalusUITests` for the tokens and shared components. What no test reaches
is the visual layout — hero gradient direction, ring placement, badge alignment at large type.

---

## §0. Setup (preamble)

Read this before §1 or §6, or any row that asks for a "fresh install" or seeded data. It is the
setup the other sections assume and is written once here so they do not each repeat it.

**A fresh install seeds a profile name and today's doses through onboarding.** Deleting the app
clears `onboarding_completed` (the gate) and the database (§0 of `m8-manual-qa.md` is the full
reset procedure); on the next launch, walking onboarding sets a profile name and sex. The dose-today
rows need at least one dose scheduled for today; enter one through the Medications tab (`+` FAB).

**The health-data seeder.** Several vitals rows in this milestone need a richer history than a
fresh install gives (a weight trend with ≥2 points for the sparkline, blood pressure and glucose
readings). That data comes from the existing seed script instead of hand-entry:

```sh
scripts/dev/seed-health-data.sh [days]        # booted simulator, default 30 days
```

It is the iOS wrapper over the shared Android seeder
(`../salus-android/scripts/dev/seed_health_data.py` — `SEED_SCRIPT=<path>` to override) and fills
the Salus database directly on the booted simulator or a paired iPhone. Development builds only:
it reads the app container and rewrites `Library/Application Support/salus.db`, keeping a
timestamped `.bak`. If a row below says "seed health data", run this first, then re-open the
screen.

**Every row below was written by the task that shipped the behaviour; none of them has been run.**
Per the banner, the simulator and device passes are the user's. Nothing here has ever been drawn
on any hardware.

---

## §1. Home hero header + card badges + vitals tiles (Task 4)

Written by Task 4 (`Packages/Features/FeatureHome/Sources/FeatureHome/ui/HomeHeader.swift`,
`HomeScreen.swift`, `HomeDosesCard.swift`, `HomeAppointmentsCard.swift`, `HomeCycleCard.swift`,
`HomeVitalsCard.swift`). Android's hero band with the personalised greeting is `HomeScreen.kt:159-235`;
the accented badges and vitals rows are the same file's cards (`:251-509`).

**Setup.** A fresh install seeds a profile name and today's doses through onboarding (§0 of
`m8-manual-qa.md`); the rows below tell you what to check on Home afterwards. The dose ring needs
at least one dose scheduled today (`HomeViewModel` feeds `doseProgress` from the today overview).

### The hero band

- [ ] **1.1 Hero renders in light and dark.** Open Home. In light mode the band under the date is
  the hero gradient `#2C6B4F` (top) → `#3E7D5F` (bottom); switch the app to **Koyu** (More › Görünüm ›
  Tema) and it is `#1E4A36` → `#275B43`. The band reaches edge to edge horizontally — the padding is
  *inside* the gradient, no background strip shows around it.
  *Why this step exists:* the gradient is `theme.extendedColors.hero.vertical` and the band's padding
  order is what keeps the tint full-width; a reordered padding would leave the theme's surface
  visible around the edges.
- [ ] **1.2 The greeting personalises once a name exists, and falls back to the plain word.** With a
  seeded profile name (e.g. **Ayşe**), Home reads **"İyi günler, Ayşe"** (or the matching word for
  the time of day) in `headlineMedium`, white, above the full date in `bodyLarge` white-90%. A
  profile with no name yet draws the plain **"İyi günler"** with no comma and no name. English shows
  the same split ("Good afternoon, Ayşe" vs "Good afternoon").
  *Why this step exists:* the port's `greetingText` picks the `%1$@` arm when `profileName != nil`
  and the `*_plain` arm otherwise (`HomeScreen.kt:221-235`).
- [ ] **1.3 The avatar sits at the trailing edge of the hero, top-aligned.** A 72 pt circle filled
  with the hero gradient shows the user's initials in white; on a profile with no name it shows the
  person glyph instead. It is aligned to the top of the row, beside the greeting/date column, and is
  not read by VoiceOver.
- [ ] **1.4 The dose ring and caption appear when today's doses exist.** With at least one dose
  scheduled, a 64 pt progress ring sits leading-aligned below the greeting/date area with the
  fraction `taken/total` inside it in white, and the caption in `bodySmall` white-90% to its right,
  on the same baseline. Exercise the two edges: a day where **none** of today's doses is taken yet
  draws the ring **empty** (no filled arc, "0/…" label, caption like "Bugünün ilerlemesi 0/3"); a day
  with three of five taken draws the arc ~60% full with "3/5" and "Bugünün ilerlemesi 3/5" (English:
  "Today's progress 3/5").
  *Why this step exists:* the ring is drawn only when `doseProgress != nil` (`HomeScreen.kt:203-217`);
  a day with no doses must show no ring at all, and both the empty and partial arcs come from the same
  clamped `progress`.

### The five card badges

- [ ] **1.5 Every card leads with its accent badge.** Down the Home column, each card opens with a
  tinted circle at its leading edge: **doses** — pills glyph in the medications colour; **appointments**
  — calendar glyph in the appointments colour; **cycle** — heart glyph in the cycle colour; **vitals**
  — ECG heart-wave glyph in the vitals colour; **AI summary** — sparkles glyph in the trends colour.
  The icons read at a glance and the container fill is the feature's `container`, the glyph its
  `accent`.
- [ ] **1.6 An empty doses/summary badge is still aligned.** A card with no rows (the "Bugün için
  planlı doz yok." empty line, the AI summary with no free credit) still draws its badge at the same
  inset as its populated siblings — the badge does not collapse when the content is a single line.

### The vitals stat tiles

- [ ] **1.7 Each reading is a badge + value row, and the sparkline survives.** With weight, blood
  pressure and glucose recorded, Home's vitals card shows three rows, each a vitals-colour badge then
  a `titleMedium` value — **"Kilo: 72.5 kg"** with the weight sparkline at its trailing edge,
  **"Tansiyon: 120/80 mmHg"**, and **"Kan şekeri: 95 mg/dL"** — separated by `xs` gaps. The weight
  value and sparkline share one baseline.
- [ ] **1.8 Partial and missing vitals behave.** With weight only, only the weight row draws (and its
  sparkline only draws once the trend has ≥2 points). Delete all vitals and the card collapses to the
  one **"Bugün için kayıt yok"** empty line with no badge. The glucose line converts **mg/dL** to
  **mmol/L** when the user's unit is mmol/L — the conversion logic is untouched from before this
  milestone.

### Type and accessibility

- [ ] **1.9 The hero survives %200 Dynamic Type.** Settings › Accessibility › Display & Text Size ›
  Larger Text to the largest (AX5), Home in Turkish.
  *Expected:* the greeting and date **wrap** rather than truncate with an ellipsis; the avatar stays
  a fixed 72 pt roundel (it is decorative, sized by the component, not by text scale) and does not
  overlap the wrapped greeting; the ring label and caption wrap without clipping; the name-then-caption
  spacing reads cleanly at the largest size.

---

## §2. Appointments date tiles (Task 5)

Written by Task 5 (`Packages/Features/FeatureAppointments/Sources/FeatureAppointments/ui/list/
AppointmentsScreen.swift`). Android's card change is `AppointmentsScreen.kt:241-286` (the
`SalusDateTile` leading column, the time moved into the content column as `labelLarge` in the
accent's accent, and the `Spacer(SalusSpacing.md)` between tile and content — the final-review gap
fix `0ea0d35`).

**Setup.** Seed at least one upcoming appointment (the agenda's "upcoming" window) so a card draws
with a date tile. The rows below tell you what to check on the Appointments tab afterwards.

- [ ] **2.1 The card leads with a calendar date tile.** Each appointment card opens with a 56×60
  rounded tile filled with the appointments accent's `container`, showing the **day of month** in
  `headlineMedium` above the **short month** in `labelMedium`, both in the accent's `accent` colour.
  The month reads as the Turkish abbreviation (e.g. **Ağu** for August, **Eyl** for September) in
  Turkish, and the English abbreviation in English — the tile follows the in-app language pick, not
  the device's.
  *Why this step exists:* the tile is `SalusDateTile(dayOfMonth:monthShort:accent:)` fed from
  `item.startsAt.date.day` and the `"MMM"` formatter (`AppointmentsScreen.kt:260-264`); the month
  must track the picked locale like every other date on the screen.
- [ ] **2.2 The time sits above the title, in the accent.** The appointment time (e.g. **10:00**)
  is drawn in `labelLarge` in the appointments accent's `accent` colour, directly above the title in
  `titleMedium` — no longer in a fixed-width leading column.
  *Why this step exists:* the time moved from the old `timeColumnWidth` column into the content
  column (`AppointmentsScreen.kt:267-271`); a regression would put it back on the left or lose the
  accent colour.
- [ ] **2.3 A `md` gap separates the tile from the text.** Between the date tile and the time/title
  column there is a `SalusSpacing.md` (12 pt) gap — the Android final-review fix mirrored
  (`AppointmentsScreen.kt:265`). The doctor and location rows and the trash button are unchanged.
- [ ] **2.4 The tile renders in light and dark.** Switch the app to **Koyu** (More › Görünüm › Tema)
  and the tile's `container` fill and `accent` text follow the dark palette; the day and month stay
  legible on the tinted fill in both modes.

---

## §3. Profile gradient band + segmented sex selector (Task 6)

Written by Task 6 (`Packages/Features/FeatureSettings/Sources/FeatureSettings/ui/profile/
ProfileScreen.swift`). Android's change is `ProfileScreen.kt:109-185` (the identity band and the
`SingleChoiceSegmentedButtonRow` replacing the three `SalusOptionRow`s).

**Setup.** Open the Profile editor (More › Profil). The rows below tell you what to check.

- [ ] **3.1 The band renders in light and dark.** A hero-gradient band (green, `hero.top` → `hero.bottom`)
  sits directly under the nav bar, above the scrollable form, and stays put while the form scrolls.
  Switch the app to **Koyu** (More › Görünüm › Tema) and the band follows the dark hero stops; the
  white name and sex label stay legible on both.
  *Why this step exists:* the band is `theme.extendedColors.hero.vertical` (`ProfileScreen.kt:110-115`);
  a regression would drop the gradient or let the band scroll away.
- [ ] **3.2 A blank name shows the placeholder.** With the name field empty (or whitespace-only), the
  band shows the **profile name placeholder** string in `titleLarge` white and the avatar draws the
  person icon — no initials.
  *Why this step exists:* `state.name.takeIf { it.isNotBlank() } ?: placeholder` (`ProfileScreen.kt:118-123`);
  a regression would show a stray empty line or initials for a blank name.
- [ ] **3.3 The name live-updates while typing.** Type in the name field and the band's `titleLarge`
  text and the avatar's initials update on every keystroke, without leaving the field.
  *Why this step exists:* the band reads `state.name` directly (`ProfileScreen.kt:118-123`); a
  regression would freeze the band until save.
- [ ] **3.4 The segmented picker fires the same event.** The three sex options render as a single
  segmented control (text labels only, no icons). Tapping **Erkek** (male) from a female/other
  profile opens the same sex-change confirm dialog the old rows did; confirming writes the new sex,
  cancelling restores the stored one. Tapping the already-selected segment does nothing.
  *Why this step exists:* the picker fires `.sexSelected(option)` exactly as the `SalusOptionRow`s
  did (`ProfileScreen.kt:161-177`); a regression would bypass the confirm flow or write the wrong sex.
- [ ] **3.5 The band and picker hold up at 200% Dynamic Type.** Set the device text size to the
  largest setting; the band's name/sex text and the segmented control remain legible and the band
  grows to fit without clipping.
  *Why this step exists:* the band uses `titleLarge`/`bodyMedium` and the picker uses the system
  segmented control; a regression would clip the name or crowd the segments.

---

## §4. Medications header count chip + dose time chips (Task 7)

Written by Task 7 (`Packages/Features/FeatureMedications/Sources/FeatureMedications/ui/list/
MedicationsScreen.swift`, `MedicationCard.swift`, `MedicationFormatting.swift`). Android's change is
`MedicationsScreen.kt:99-113` (the header's `trailing` `medications_count` chip) and `:226-269`
(the card's recurrence label + dose-time pills in a `FlowRow`), from `52498f2` + `a9f8e23` +
`0ea0d35`.

**Setup.** Seed two or three active medications (More › İlaçlar › the `+` FAB). The rows below tell
you what to check on the Medications tab afterwards.

- [ ] **4.1 The header chip counts the medications, localised incl. count=1.** With three
  medications, the header's trailing slot shows a neutral pill reading **"3 ilaç"** (Turkish) /
  **"3 medications"** (English). Delete to exactly one medication and it reads **"1 ilaç"** /
  **"1 medication"** — the singular grammar, not the plural key. With zero medications the chip is
  gone entirely (the empty state owns the screen).
  *Why this step exists:* iOS carries the count as two keys (`medications_count` /
  `medications_count_one`, divergence (e)) because `.xcstrings` has no plural groups; the accessor
  picks by `count == 1`. A regression would show the key, or read "1 medications".
- [ ] **4.2 The card draws the recurrence label, then the dose times as pills.** A daily medication
  with two dose times draws **"Her gün"** in `bodyMedium`, then two pill chips **"09:00"** and
  **"21:00"** — `labelLarge`, medications accent text on the medications `container` fill, fully
  rounded (`CircleShape`). The times are distinct and sorted: two schedules on the same clock time
  draw **one** pill.
  *Why this step exists:* `doseTimes` does `.distinct().sorted()` (`MedicationFormatting.kt:76-81`);
  a regression would draw a duplicate pill or an unsorted row.
- [ ] **4.3 The pills wrap with ChipFlowLayout.** Add enough dose times (a days-of-week medication
  with many slots) that the pills can't fit one row on a small phone; they **wrap** to a second line
  with `xs` (4 pt) spacing between them and between rows — never clip or overflow the card. This is
  the behaviour `FlowRow` exists for and `ChipFlowLayout` is its twin.
- [ ] **4.4 An as-needed medication draws the label only.** A medication whose plan is "Gerektiğinde"
  ("As needed") draws **"Gerektiğinde"** and **no** pills — `doseTimes` is empty for AS_NEEDED. A
  medication with empty schedules draws **"Plan yok"** and no pills.
  *Why this step exists:* `doseTimes` returns `[]` for both (`MedicationFormatting.kt:76-81`), so the
  chip `FlowRow` is skipped; a regression would draw a stray "08:00" pill on an as-needed card.
- [ ] **4.5 The recurrence label is kept (not the old flat summary).** The card no longer renders the
  combined "Her gün · 08:00, 21:00" sentence — the label and the pills are separate rows. The detail
  screen **still** renders the combined `scheduleSummary` sentence for "Ne zaman"; nothing there
  changed.
  *Why this step exists:* `scheduleSummary` is kept for the detail screen's caller
  (`MedicationDetailSections.swift:163`); a regression on the card or the detail screen would drop
  the recurrence wording from one of the two.

## §5. Cycle calendar push + cycle-card gating (Task 8)

Written by Task 8 (verification-only, divergence (f)): the cycle calendar is a pushed destination
inside a `NavigationStack`, so it gets the system back button and the tab bar hides (`RootView.swift`
`tabStack(for:)` — the `isAtRoot` toolbar rule, the twin of Android's `showBottomBar`,
`SalusApp.kt:133-136`). Android's M12 cycle-screen back-button fix has no iOS code twin; these rows
verify the equivalent behaviour already exists. The cycle card is gated by `cycleForProfile`
(`TodayModels.kt:10-11`), which returns nil for a male or missing profile.

**Setup.** A female profile (More › Profil › the sex selector) for rows 5.1–5.2 and 5.4; a male
profile for row 5.3.

- [ ] **5.1 Cycle calendar from More: system back button + hidden tab bar.** Open More › Tracking +
  Cycle. The calendar renders with the **system back button** in the top-left; tapping it returns to
  More. While the calendar is on screen the **tab bar is hidden** (the `isAtRoot` rule — a pushed
  destination gets the full height). *Why this step exists:* the M12 Android fix added a back button
  to the cycle screen; iOS gets it from `NavigationStack` for free, and `CycleScreen.swift` writes no
  `navigationBarBackButtonHidden` or custom toolbar that would suppress it.
- [ ] **5.2 Cycle calendar from Home's cycle card: same two checks.** On Home, tap the cycle card
  (female profile). The calendar shows the **system back button** and the **tab bar is hidden**;
  tapping back returns to Home. *Why this step exists:* Home's card pushes `CycleKey` onto Home's own
  stack (`RootView.swift` `onOpenCycle`), so the same pushed-destination behaviour must hold from
  this entry point too.
- [ ] **5.3 Male profile: no cycle card on Home, no cycle row on More.** With a male profile, Home
  draws **no** cycle card and More draws **no** "Tracking + Cycle" row. *Why this step exists:* both
  gates are the same rule — `cycleForProfile` returns nil for `sex == .male`
  (`TodayModels.kt:10-11`), and More's `showCycle` is `profile != nil && profile?.sex != .male`
  (`MoreViewModel.kt:64-65`).
- [ ] **5.4 Female profile: cycle card visible on Home with correct data.** With a female profile,
  Home draws the cycle card showing the current cycle day, the progress bar and the period status.
  *Why this step exists:* `cycleForProfile` passes the snapshot through for a female profile, so the
  card must appear with real data, not the empty state.

---

## What was executed when this section was written (iOS-M14 Task 6)

**Nothing.** Task 6 ran `scripts/test-packages.sh FeatureSettings` (1/1 package passed, 67 tests in
8 suites), `scripts/build-app.sh` (**BUILD SUCCEEDED**) and `scripts/lint.sh` (0 violations in
639 files). Every §1, §2 and §3 row above is **NOT RUN**; the hero band, the badges, the vitals
tiles, the appointment date tiles and the profile band/segmented selector have never been drawn on
any hardware. The `#Preview`s in `HomeScreen.swift`, `AppointmentsScreen.swift` and
`ProfileScreen.swift` ship for the user's own inspection; no agent has rendered them either.

## What was executed when this section was written (iOS-M14 Task 7)

**Nothing.** Task 7 ran `scripts/test-packages.sh FeatureMedications` (1/1 package passed, 89 tests
in 13 suites), `scripts/build-app.sh` (**BUILD SUCCEEDED**) and `scripts/lint.sh` (0 violations in
639 files). Every §4 row above is **NOT RUN**; the header chip, the dose-time pills and the
`ChipFlowLayout` wrapping have never been drawn on any hardware. The `#Preview`s in
`MedicationsScreen.swift` and `MedicationCard.swift` ship for the user's own inspection; no agent
has rendered them either.

---

## §6. Sweep — light/dark + 200% Dynamic Type across the five touched screens (Task 9)

Written by Task 9 to close the milestone: §1–§5 each checked *one* screen in isolation (and §1.9,
§3.5 already took a first pass at one screen at AX5); this section walks the **five** screens the
M12 mirror touched — Home, Appointments, Profile, Medications, Cycle — as a pair with the new
tokens applied everywhere, so a token or a shared component (the avatar, the progress ring, the
date tile, `ChipFlowLayout`, the segmented picker) that reads fine alone is read again where the
others sit beside it.

**Before you start.** Do this after §1–§5 (they exercise the mechanics; this is the polish pass).
You need a profile name and sex and today's doses (§0), upcoming appointments (§2's setup),
two or three active medications (§4's setup), and a female profile for the Cycle rows (§5's
setup). Switch **Görünüm › Tema** between **Açık** and **Koyu** and the device's Larger Text to
the **largest** (AX5) as each row asks.

### The five screens as a whole

- [ ] **6.1 Home at light/dark and AX5.** Walk Home's hero, the five card badges (§1.1, §1.5) and
  the vitals stat tiles (§1.7) in **Açık**, then **Koyu**, then at the largest Dynamic Type size.
  *Expected:* the hero gradient's two stops resolve to the palette the mode asks for; the badge
  `container` fills and `accent` glyphs track their feature colour in both modes; at AX5 the
  greeting, date, ring caption and every card row **wrap** — no fixed-height card clips a wrapped
  line, and the avatar (72 pt) keeps from overlapping the wrapped greeting.
  *Why this step exists:* the gradient and the five `SalusIconBadge`s come from the same extended
  colours; a token that only differs in dark (`hero.bottom`, a container fill) shows up here and
  nowhere in the per-screen rows.

- [ ] **6.2 Appointments list at light/dark and AX5.** Walk the date tiles (§2.1) with the time
  above the title (§2.2) in both themes, then at the largest size. *Expected:* the tile's
  `container` fill and the `accent` day/month follow the mode; at AX5 the day-of-month and month
  stay inside the fixed 56×60 tile **unchanged in size** (they are scaled by the component, not
  the text size), while the time and title rows wrap on their own line without clipping.
  *Why this step exists:* the tile is a fixed-size `RoundedRectangle` — unlike the ring it is a
  hard box, so AX5 must be watched for the day/month overflowing or the tile colliding with a
  wrapped title.

- [ ] **6.3 Profile band and segmented picker at light/dark and AX5.** Walk the profile band (§3.1)
  and the segmented sex selector (§3.4) in both themes, then at the largest size. *Expected:* the
  band follows the hero stops in each mode; at AX5 the band's `titleLarge` name and the segmented
  labels stay legible and the band grows to fit (§3.5 re-states the single-screen half — this is
  the read with a surrounding screen).
  *Why this step exists:* the band is the same `hero.vertical` the Home hero uses, so a stop that
  reads fine at 72 pt under the nav bar is re-checked here in the profile context where the
  scrolling `Form` sits directly beneath it.

- [ ] **6.4 Medications header chip and dose-time pills at light/dark and AX5.** Walk the count
  chip (§4.1) and the wrapping pills (§4.3) in both themes, then at the largest size. *Expected:*
  the neutral chip and the medications-accent pills resolve per theme; at AX5 the pills still wrap
  with `ChipFlowLayout` (an extra wrapped line is fine) and never clip, and the count chip's
  `labelLarge` text fits.
  *Why this step exists:* the pills are `labelLarge` text on a `container` fill — at AX5 the text
  grows and the pill is expected to grow with it, which is exactly the case where a hand-set height
  would clip first.

- [ ] **6.5 Cycle calendar at light/dark and AX5.** Walk the cycle calendar (a female profile, §5.4)
  and its day cells in both themes, then at the largest size. *Expected:* the calendar and the day
  grid resolve per theme; at AX5 the day cells and the legend stay readable and nothing truncates.
  *Why this step exists:* the M12 cycle work was two *code* fixes (male gating, system back button)
  with no layout change, so this is the AX5/theme read the cycle screen otherwise never gets in this
  milestone — the M8 a11y pass (§6.2.6) covered it at M8 scale, not after a theme refresh.

- [ ] **6.6 The five screens together still navigate.** From Home in **Koyu** at AX5, push the cycle
  calendar from the cycle card (§5.2) and confirm the system back button and hidden tab bar still
  hold at the large text size; return and switch to **Açık**, push Appointments → an appointment and
  Profile from More, confirming each pushed screen draws its new element and pops back.
  *Why this step exists:* the M12 change touched five screens plus the shared components; a theme or
  text-size pass that works screen-by-screen can still break at the seams (a band that stops
  scrolling, a tile that overlaps a pushed header).

### Store screenshots

- [ ] **6.7 Take fresh App Store screenshot set.** After the light/dark pass above (they are the
  new look), capture the App Store screenshot set for the touched screens — Home (hero + cards), the
  Appointments list, the Profile editor, the Medications list, and the Cycle calendar — in **Açık**
  at the default text size. Replace the store listing's old captures, and re-capture the dark-mode
  set the listing carries if it is a paired Açık/Koyu pair.
  *Why this step exists:* the visual change since the last store capture is this milestone; the
  store listing must match what a reviewer installs. This row is a **reminder** — the actual capture
  and upload is the user's, exactly as the banner says.

---

## What was executed when this section was written (iOS-M14 Task 9)

**Nothing.** Task 9 ran `scripts/ci.sh` (all five: toolchain, lint, custom rules, all 24 packages,
and the iOS build — all green) and wrote this §6 and the §0 preamble. Every row in this file — §0
through §6 — is **NOT RUN**: no simulator was booted, no screen was rendered, and no store screenshot
has been taken. The user runs the manual QA and takes the App Store screenshots.
