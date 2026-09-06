# iOS-M14 manual QA — the M12 UI refresh mirror

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code. Every row below says **NOT RUN** until someone runs it.

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

## What was executed when this section was written (iOS-M14 Task 6)

**Nothing.** Task 6 ran `scripts/test-packages.sh FeatureSettings` (1/1 package passed, 67 tests in
8 suites), `scripts/build-app.sh` (**BUILD SUCCEEDED**) and `scripts/lint.sh` (0 violations in
639 files). Every §1, §2 and §3 row above is **NOT RUN**; the hero band, the badges, the vitals
tiles, the appointment date tiles and the profile band/segmented selector have never been drawn on
any hardware. The `#Preview`s in `HomeScreen.swift`, `AppointmentsScreen.swift` and
`ProfileScreen.swift` ship for the user's own inspection; no agent has rendered them either.
