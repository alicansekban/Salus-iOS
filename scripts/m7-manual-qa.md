# iOS-M7 manual QA — blood pressure, glucose, and the Home dashboard

iOS-M7's acceptance is *blood pressure and glucose with mg/dL↔mmol/L, the two-series BP chart,
sparklines, and the Home aggregate card*. The automated half is mapped case-by-case in the
execution record of `docs/plans/2026-08-29-ios-m7-vitals-home.md` — 49 of 49 contracted Kotlin
vitals cases and 9 of 9 Home cases, 24/24 packages, 895 tests. This document is the other half:
everything that needs a tap, a real clock, and two features writing into one screen.

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code. What *was* observed while M7 was built is listed at the bottom,
honestly and by step number — everything else says **NOT RUN**.

Run it before merging a change to `Packages/Features/FeatureVitals`, to
`Packages/Features/FeatureHome`, to `Packages/SalusUI/Sources/SalusUI/component/SalusSparkline.swift`
or `…/SalusPillButton.swift`, or to the shell files the milestone touched —
`App/RootView.swift`, `App/AppCompositionRoot.swift`, `App/AppCompositionRoot+Modules.swift`.

Every step has an expected result and a checkbox. **§5 is the device section, and M7 adds nothing
to it** — but `scripts/m6-manual-qa.md` §5 has still never been run, and it is the one that proves a
notification fires.

**Language.** The app has no language switch of its own; it follows the device (spec §6.4 — Turkish
is the default *and* the fallback). The steps below quote the Turkish strings, which is what a
default simulator shows. §6 switches to English.

**Two things to know before you start, both of which cost a run if you learn them late:**

1. **Give the medication a dose time *later than the current clock time*.** Home draws the "Al" pill
   only for a `pending` dose. A dose whose time has passed renders the chip **"Kaçırıldı"** and no
   button — this is exactly where Task 12's smoke stalled, and it is not a defect.
2. **The first medication save raises an AlarmKit permission sheet.** Allow it. It is the M5 alarm
   authorization, not something M7 added, and it interrupts the save flow once per install.

---

## 0. Build, install, boot

```sh
cd salus-ios
./scripts/build-app.sh            # Debug, generic/platform=iOS Simulator

UDID=$(xcrun simctl list devices available | sed -n 's/.*iPhone 17 Pro (\([-0-9A-F]*\)).*/\1/p' | head -1)
APP="$(xcodebuild -project Salus.xcodeproj -scheme Salus \
        -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2; exit}')/Salus.app"

xcrun simctl boot "$UDID"; open -a Simulator
xcrun simctl uninstall "$UDID" com.alicansekban.salus   # start from an empty database
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.alicansekban.salus
```

Two shell helpers every later section uses:

```sh
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
DB="$DATA/Library/Application Support/salus.db"
```

- [ ] **0.1** The app launches on the **Home** tab and the tab bar has five tabs (home, medications,
  vitals, appointments, more).
- [ ] **0.2** Home draws the dashboard, **not** a `ProgressView` and not the old placeholder. A
  spinner that never resolves means `homeModule` did not reach `HomeRoute` — a composition-root
  regression, not a Home one.

---

## 1. The blood pressure editor and the two-series chart

- [ ] **1.1** **Ölçümler** tab → segmented control → **Tansiyon**.
  *Expected:* the empty state reads **"Henüz ölçüm yok. İlk tansiyon kaydını ekle."** and the **FAB
  is present** (`Ölçüm ekle`). The FAB used to be hidden for BP and glucose — divergence `D-M2-d`,
  closed by M7. A missing FAB here is a regression to M2.
- [ ] **1.2** Tap the FAB.
  *Expected:* **"Yeni tansiyon kaydı"** pushes, and **the tab bar is gone** (the shell's rule; §4
  checks it across the milestone's other pushed screens).
- [ ] **1.3 The captions are persistent, not floating placeholders.** Look at the three number
  fields before typing anything, then type into them.
  *Expected:* **"Büyük tansiyon"**, **"Küçük tansiyon"** and **"Nabız (isteğe bağlı)"** stay visible
  **above** their fields once filled. *Why this step exists:* SwiftUI's `TextField` placeholder
  disappears the moment a value is typed, and two adjacent mmHg fields with no labels are
  indistinguishable. The caption is an iOS divergence (`D-M7-l`) added by the Task 5 review, and no
  test can see it.
- [ ] **1.4** Enter systolic **120**, diastolic **80**, pulse **70**, and save (**Kaydet**).
  *Expected:* the editor pops. The list header reads **"Son ölçüm: 120/80 mmHg"**, the row's
  headline is **"120/80 mmHg"** and its supporting line **"Nabız: 70 bpm"**.
- [ ] **1.5 The error outline.** Open the FAB again, enter systolic **80**, diastolic **120**, save.
  *Expected:* nothing is saved, the message **"Büyük tansiyon küçük tansiyondan yüksek olmalı."**
  appears once, and **both** number fields are outlined in the error colour. *Why this step exists:*
  the message is a single shared `Text`, so the red outline is the only per-field signal of which
  two fields the error means (`D-M7-m`). Type one digit into either field: the outline and the
  message clear together.
- [ ] **1.6** Still in the editor, enter systolic **300**.
  *Expected:* **"Büyük tansiyon için 60 ile 250 mmHg arasında bir değer gir."** and only the
  systolic field outlined. Repeat for diastolic **10** (**"…30 ile 150 mmHg…"**) and pulse **500**
  (**"…20 ile 250 bpm…"**). There is **no** "normal range" hint anywhere on this screen and there
  must never be one (spec §7).
- [ ] **1.7 Same-day entries do not draw a chart.** Save a second entry today (135/88, pulse 72).
  *Expected:* two rows, **no chart**. Two measurements on one day collapse to one chart point and
  the chart needs two *distinct* days. This is Kotlin-identical (`VitalsStateBuilders.swift`
  ports `chartOrNull`'s `minChartPoints = 2`) and it is the one thing in this section that reads
  like a bug and is not.
- [ ] **1.8 The two-series chart.** Save a third entry (118/76, pulse 68) dated **yesterday** via the
  date field.
  *Expected:* a chart appears with **two lines** — systolic in the vitals accent, diastolic in the
  theme's tertiary colour — over the two-day x range, with whole-number y labels (0 / 50 / 100).
  The chart is 220 pt tall and VoiceOver reads it as the header text.
- [ ] **1.9** Tap a row → the editor preloads that entry's values and its measured time; change the
  pulse and save; the row updates in place (no second row).
- [ ] **1.10** In the editor of an existing entry, tap **Sil** → confirm **"Kayıt silinsin mi?"** /
  **"Bu ölçüm kalıcı olarak kaldırılır."**
  *Expected:* the editor pops immediately and the undo snackbar **"Kayıt silindi"** appears; the row
  is gone. Tapping **Geri al** brings it back. The write is deferred, so the database still holds
  the row until the window closes:
  ```sh
  sqlite3 "$DB" "select id, type, value_primary, value_secondary, unit from vitals_measurements
                 where type='BLOOD_PRESSURE' order by measured_at_epoch_ms desc;"
  ```

**Acceptance for §1:** the FAB reaches the BP editor, the captions survive typing, both validation
messages and the per-field outline behave, same-day entries collapse to one point, and two distinct
days draw two series.

---

## 2. The glucose editor and the unit toggle

- [ ] **2.1** Segmented control → **Kan şekeri**.
  *Expected:* empty state **"Henüz ölçüm yok. İlk kan şekeri kaydını ekle."**, FAB present.
- [ ] **2.2** FAB → **"Yeni kan şekeri kaydı"** pushes, tab bar gone. The unit selector shows
  **mg/dL** (selected) and **mmol/L**; the value field's caption reads **"Kan şekeri"** and its
  suffix **mg/dL**.
  *Expected (a11y):* VoiceOver on the unit selector announces the **segment values**, not "Kan
  şekeri" — the selector deliberately has no label, matching Kotlin (fixed in Task 7).
- [ ] **2.3 The toggle converts what is typed.** Type **100** with mg/dL selected, then tap
  **mmol/L**.
  *Expected:* the field becomes **5,6** (`%.1f`, comma in Turkish), the suffix flips to `mmol/L`,
  and nothing is saved yet.
- [ ] **2.4** Pick a context chip — the four are **Açlık / Tokluk / Yatmadan önce / Rastgele**.
  *Expected:* they **wrap onto a second line** rather than truncating (`ChipFlowLayout`, `D-M7-n`);
  tapping the selected chip again deselects it.
- [ ] **2.5** Save.
  *Expected:* the row reads **"5,6 mmol/L"** and the header **"Son ölçüm: 5,6 mmol/L"**, while
  storage stays canonical mg/dL:
  ```sh
  sqlite3 "$DB" "select value_primary, unit from vitals_measurements where type='GLUCOSE';"
  #                                                                        expected: 100.0 | mg/dL
  ```
- [ ] **2.6** Save a second entry (7,4 mmol/L) dated **yesterday**.
  *Expected:* the chart's y-axis labels are **0,0 / 2,0 / 4,0 / 6,0** — the `%.1f` decimal axis that
  the sub-1-base axis row (Task 2) exists for. A whole-number axis here means the mmol/L branch was
  lost.
- [ ] **2.7** Invalid value: type **900** in mg/dL and save.
  *Expected:* **"20 ile 600 mg/dL (1,1 ile 33,3 mmol/L) arasında bir değer gir."**, nothing saved.
- [ ] **2.8 The unit is app-wide and persists.** Kill and relaunch the app.
  ```sh
  xcrun simctl terminate "$UDID" com.alicansekban.salus
  xcrun simctl launch "$UDID" com.alicansekban.salus
  plutil -p "$DATA/Library/Preferences/com.alicansekban.salus.plist" | grep glucose_unit
  ```
  *Expected:* the key is `glucose_unit` with value `MMOL_L` (Android-verbatim), the vitals list
  still renders mmol/L rows and the `%.1f` axis, and a newly opened editor starts on **mmol/L**.
- [ ] **2.9 …and Home follows it.** Go to the **Home** tab.
  *Expected:* the **Ölçümler** card's glucose line reads **"Kan şekeri: 5,6 mmol/L"**. Switch the
  unit back to mg/dL in a glucose editor, return to Home, and the same line reads **"Kan şekeri:
  100 mg/dL"**. One preference, three readers (editor, list, Home).

**Acceptance for §2:** the toggle converts rather than reinterprets, storage stays mg/dL, and the
chosen unit survives a relaunch and is honoured by the vitals list and the Home card alike.

---

## 3. The Home dashboard

Home reads four DAOs directly and writes doses through `DoseActions`; it depends on no feature
module. Every step here is really a question about whether two features meet on one screen.

### The header band

- [ ] **3.1** On Home, look at the top of the screen.
  *Expected:* a tinted band (`primaryContainer`) carrying today's **full date** — e.g. **"30 Ağustos
  2026 Pazar"** — above the greeting (**Günaydın / İyi günler / İyi akşamlar / İyi geceler**,
  by the hour). The band is **full-bleed horizontally** (the tint runs to both screen edges; the
  padding is inside it) and **starts below the status bar** — it is the first child of a
  `ScrollView`, so it does not tint the safe area. That is the intended look; record a screenshot
  if you disagree with it rather than changing the code first.
- [ ] **3.2** Scroll the dashboard down and back.
  *Expected:* the band scrolls away with the content (it is not pinned) and there is no navigation
  title above it.

### Doses, and the "Al" write

- [ ] **3.3** With no medications, the **"Bugünün dozları"** card reads **"Bugün için planlı doz
  yok."**
- [ ] **3.4** **Medications tab → add a medication** ("Parol", Tablet, **Her gün**), and set its dose
  time to **a few minutes after the current simulator clock time** (see the warning at the top —
  a time in the past gives you a `Kaçırıldı` chip and no button). **Allow the AlarmKit permission
  sheet** the first save raises.
- [ ] **3.5** Return to **Home**, without relaunching.
  *Expected:* the doses card now shows the row **"HH:MM · Parol"** with the pill **"Al"** beside it.
  No relaunch is needed — the card is a live query. If the row only appears after a relaunch, the
  observation was not re-subscribed.
- [ ] **3.6 The "Al" pill is a sibling of the card, not a child of its tap target.** Tap the row's
  **body** (not the pill).
  *Expected:* the app switches to the **Medications** tab. Go back to Home and tap **"Al"** itself.
  *Expected:* the pill's own action runs — the status flips to **"İçildi"** and the tab does **not**
  switch. *Why this step exists:* a pill nested inside a card's own `Button` label is swallowed by
  the card; M7 made both the dose and the appointment pill card siblings (`D-M7-p`), and only a real
  tap can tell the two arrangements apart.
- [ ] **3.7 The tap wrote an intake log.** Medications tab → the medication's detail.
  *Expected:* today's dose is listed as taken there too, and the row exists in the database:
  ```sh
  sqlite3 "$DB" "select medication_id, status, datetime(taken_at_epoch_ms/1000,'unixepoch')
                 from medication_intake_logs order by taken_at_epoch_ms desc limit 5;"
  ```
  *Expected:* one `TAKEN` row for the dose you tapped. This is the whole point of the Home →
  `DoseActions` binding: the dashboard writes into `FeatureMedications`' own store.
- [ ] **3.8** Wait for a dose whose time has passed (or add one at a past time).
  *Expected:* it renders the chip **"Kaçırıldı"** and **no** "Al" pill. The four chips are
  **İçildi / Ertelendi / Bekliyor / Kaçırıldı**.

### Appointments

- [ ] **3.9** Appointments tab → add an appointment for **tomorrow**. Back to Home.
  *Expected:* **"Yaklaşan randevular"** lists it with its title, doctor/location line and the start
  formatted as an abbreviated date + short time **in the appointment's own time zone**. With none,
  the card reads **"Yaklaşan randevu yok."**
- [ ] **3.10** Tap the appointment row's body → the app switches to the **Appointments** tab.

### Cycle

- [ ] **3.11** More → **Regl Takibi** → **Regl başladı** (start a period today). Back to Home.
  *Expected:* the **"Döngü"** card reads **"Döngünün 1. günü"** and, on a second line,
  **"Dönem devam ediyor"** in the cycle accent. With no period recorded it reads **"Henüz dönem
  kaydı yok."**
- [ ] **3.12 The progress track.** Look at the bar under the cycle text.
  *Expected:* a **platform `ProgressView`** — the system's own track, with the bar tinted in the
  cycle accent. There is no hand-drawn capsule behind it any more: the plan's divergence (i) was
  amended during Task 11's review to the platform track, matching `MedicationCard`. Check it in
  **both light and dark** appearance; the system track is a translucent grey and must stay legible
  on the card fill in each.

### Vitals card and the sparkline

- [ ] **3.13** With entries from §1 and §2 present, the **"Ölçümler"** card lists up to three lines:
  **"Kilo: … kg"**, **"Tansiyon: 120/80 mmHg"**, **"Kan şekeri: … mg/dL"** (or mmol/L, per §2.9).
  With nothing recorded it reads **"Henüz ölçüm yok."**
- [ ] **3.14 The sparkline needs two weights on different days.** Vitals tab → **Kilo** → add two
  weight entries **dated on different days** (e.g. 82,5 today and 83,0 yesterday). Back to Home.
  *Expected:* a small trend line (96×32 pt, 2-pt round stroke, vitals accent) appears beside the
  weight line. With one weight — or two on the same day — there is **no** sparkline at all.
- [ ] **3.15** Add a third weight equal to the other two (a flat series).
  *Expected:* the line is drawn **along the bottom** of its box, not through the middle. That is
  Kotlin's own arithmetic (`SalusSparkline.kt`'s `span` fallback only avoids a divide-by-zero), and
  the plan's "centre" wording was wrong — Task 2 corrected it against the Kotlin.
- [ ] **3.16 The sparkline is invisible to VoiceOver** (`D-M7-h`). Swipe through the vitals card with
  VoiceOver on.
  *Expected:* the weight line is spoken with its value and the sparkline is skipped — it carries no
  information the text does not.
- [ ] **3.17** Tap the vitals card's body → the app switches to the **Ölçümler** tab.
- [ ] **3.18 There is no AI summary card and no section header for one** (ruling 1). If one is on
  screen, something from iOS-M10 landed early.

### Migrated pills, both themes

- [ ] **3.19** The last inline pills became `SalusPillButton` in M7. Look at each in **light and
  dark**, and confirm nothing lost its shape or its 48-pt touch target:
  - **Appointment detail — four pills**, including the **maps pill**, whose drawn height *grows* to
    the 48-pt floor (it used to size itself to its label). That change is deliberate and visible.
  - **Medication detail — two pills.**
  - **The empty-state action pill** (any empty list).
  *Expected:* filled/tonal fills match their neighbours, labels do not truncate mid-word, disabled
  pills stay legible.

**Acceptance for §3:** the four cards render live data from four different features, "Al" writes an
intake log that `FeatureMedications` shows, the card body and its pill do different things, the
sparkline appears only with two distinct days, and the migrated pills look right in both themes.

---

## 4. Pushed screens hide the tab bar

The rule is the shell's (`App/RootView.swift`), not a feature's. M7 adds four pushed destinations to
check.

- [ ] **4.1** Home → tap the **cycle card's body**.
  *Expected:* the cycle calendar **pushes onto the Home stack** (it does not switch tabs) and the
  **tab bar is hidden**.
- [ ] **4.2** Tap back.
  *Expected:* Home returns **with the tab bar**, and the dashboard is still showing today's data.
- [ ] **4.3** The three M7 editors, each pushed from the vitals list: **weight**, **tansiyon**,
  **kan şekeri**.
  *Expected:* no tab bar on any of them; the bar returns on back. If one still shows the bar, the
  modifier is on the wrong view — and note that a feature must never write
  `.toolbar(…, for: .tabBar)` itself (`no_tab_bar_toolbar_in_features` would have failed CI).
- [ ] **4.4 An observation the reviews deferred to you, not a defect.** The three editors draw the
  **system grouped background** (they are `Form`s) while the vitals list draws
  `colorScheme.background`. It has been that way since iOS-M2 and it is visible when you push from
  the list into an editor. Decide whether the editors should adopt the theme background; either
  answer is fine, but it should be a decision rather than a leftover.

---

## 5. The device pass

**M7 adds nothing here.** Blood pressure, glucose and the dashboard involve no notification, no
alarm, no biometric and no entitlement — every M7 behaviour is reachable on a simulator, and §1–§4
are the whole of what M7 asks for.

- [ ] **5.1** `scripts/m6-manual-qa.md` **§5 has still never been run** — the cycle reminder firing
  at its configured time and its tap opening the calendar. It is the oldest unrun section in the
  repo, and it is unaffected by M7.
- [ ] **5.2** `scripts/m5-manual-qa.md` §5 (medication alarms on a device) is likewise still owed.
  Note that §3.4 above makes AlarmKit ask for permission on the simulator — that prompt is *not*
  evidence for either device section.

---

## 6. TR / EN and Dynamic Type

- [ ] **6.1** Switch the device to English and relaunch.
  *Expected:* the dashboard reads **Today's doses / Upcoming appointments / Cycle / Measurements**,
  the greeting is **Good morning / Good afternoon / Good evening / Good night**, the dose chips are
  **Taken / Snoozed / Pending / Missed**, and the vitals editors read **Systolic / Diastolic /
  Pulse (optional)** and **Blood sugar**. The glucose axis switches to a decimal point.
- [ ] **6.2** Set a language that is **neither** Turkish nor English (French, say) and relaunch.
  *Expected:* **Turkish**, not English — Turkish is the fallback as well as the default (spec §6.4).
- [ ] **6.3** Raise Dynamic Type to the largest non-accessibility size.
  *Expected:* the greeting band, the four cards, the dose row's pill, the context chips and the two
  editors' captions grow and wrap without clipping; the sparkline keeps its fixed 96×32 box; the
  pills stay at least 48 pt.

---

## 7. Inspection commands

```sh
UDID=<from section 0>
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
DB="$DATA/Library/Application Support/salus.db"

# Everything the vitals list and the Home card read.
sqlite3 "$DB" "select type, value_primary, value_secondary, value_tertiary, unit,
                      measurement_context, note,
                      datetime(measured_at_epoch_ms/1000,'unixepoch') as measured_utc
               from vitals_measurements order by measured_at_epoch_ms desc;"

# What the "Al" tap wrote.
sqlite3 "$DB" "select medication_id, schedule_id, status,
                      datetime(taken_at_epoch_ms/1000,'unixepoch')
               from medication_intake_logs order by taken_at_epoch_ms desc;"

# The dashboard's other three sources.
sqlite3 "$DB" "select id, name, is_active from medications;"
sqlite3 "$DB" "select id, title, datetime(starts_at_epoch_ms/1000,'unixepoch'), time_zone_id
               from appointments order by starts_at_epoch_ms;"
sqlite3 "$DB" "select id, start_date, end_date from cycle_periods order by start_date desc;"

# The app-wide unit (Android-verbatim key and value: MG_DL / MMOL_L).
plutil -p "$DATA/Library/Preferences/com.alicansekban.salus.plist" | grep glucose_unit

# Today's epoch day, which every date column above is measured in.
sqlite3 "$DB" "select cast((julianday('now','localtime') - 2440587.5) as int);"

# The app's own log. --info --debug is required: `log show` hides both levels by default.
xcrun simctl spawn "$UDID" log show --last 10m --info --debug \
    --predicate 'subsystem == "com.alicansekban.salus"' --style compact

# Teardown.
xcrun simctl uninstall "$UDID" com.alicansekban.salus
xcrun simctl shutdown "$UDID"
```

### Troubleshooting

| Symptom | Most likely cause | What to do |
| --- | --- | --- |
| The dose row shows **Kaçırıldı** and no **Al** pill | the dose time is in the past — Home draws the pill only for `pending` | edit the medication's time to a few minutes ahead, or add a second schedule later today (§3.4) |
| The medication save is interrupted by a permission sheet | AlarmKit authorization, once per install (iOS-M5) | Allow, then continue; it does not reappear |
| No chart under the BP or glucose list | both entries are on the **same day** — they collapse to one chart point | date one entry a day earlier (§1.7, §1.8) |
| No sparkline on the Home vitals card | fewer than two weight entries **on different days** | add a second weight dated yesterday (§3.14) |
| Home is a spinner that never resolves | `homeModule` did not reach `HomeRoute` — composition-root wiring | check `App/AppCompositionRoot+Modules.swift`; not a Home bug |
| A new medication does not appear on Home until relaunch | the dashboard did not re-subscribe on appearance | `HomeRoute`'s `.task` → `restartObservation()` (`D-M7-e`) |
| Tapping **Al** switches tabs instead of taking the dose | the pill is nested inside the card's own tap target again | it must be a **sibling** of `SalusCard(onTap:)` (`D-M7-p`) |
| Turkish decimals show a dot, or the axis shows whole numbers in mmol/L | the view locale was replaced by a fixed one, or the sub-1-base axis row regressed | §2.6; `ChartAxisScale`'s sub-1 base row (Task 2) |
| The simulator stops accepting taps after a text field has had focus | a known limitation of driving the Simulator through the accessibility API | tap with the mouse, or restart the Simulator window |

---

## What was executed when this document was written (iOS-M7 Task 13)

**Nothing in it.** Task 13 ran `scripts/ci.sh` end to end (5/5 green — 24/24 packages, **895 tests**,
both lint gates and all four custom rules, `** BUILD SUCCEEDED **`) and wrote this script from the
code, the string catalogs and the evidence in the Task 2, 5, 6, 7, 11 and 12 reports. The simulator
and device passes are the user's, by the 2026-08-30 decision.

**What Task 7 observed**, with eleven screenshots
(`.superpowers/sdd/2026-08-29-ios-m7-vitals-home/task-7-shots/`, git-ignored), driven through the
macOS accessibility API on an iPhone 17 Pro / iOS 26.0:

- **§1.1, §1.2** — BP tab, empty state, FAB present, editor pushed with the tab bar gone.
- **§1.4** — 120/80/70 saved; header and row text as quoted above.
- **§1.7** — the same-day collapse (two rows, no chart).
- **§1.8** — the two-series chart across two days, with its whole-number axis.
- **§2.1, §2.2, §2.3** — glucose tab and FAB, editor pushed with the tab bar gone, the unit toggle
  converting 100 mg/dL to 5,6 mmol/L.
- **§2.5, §2.6** — the mmol/L rows and the `%.1f` (0,0 / 2,0 / 4,0 / 6,0) axis.

**What Task 12 observed**, with two screenshots (`…/task-12-shots/`):

- **§0.1, §0.2, §3.1, §3.3** — cold launch onto the real dashboard: the greeting band ("30 Ağustos
  2026 Pazar" / "İyi günler") and all four cards with their empty lines.
- **§3.5, §3.8** — a medication added in `FeatureMedications` appearing on Home **with no relaunch**,
  as a `Kaçırıldı` row (its 08:00 dose was already past).

**Everything else in this document is NOT RUN**, and in particular: the "Al" tap and the intake log
it writes (§3.6, §3.7), the card-body vs pill distinction, the cycle and appointment cards with real
data, the sparkline in any form, the cycle push from Home (§4.1), the editors' delete/undo arms, the
migrated pills in either theme (§3.19), and all of §6. Task 12's run stalled at exactly §3.4 —
the wheel time picker could not be driven through the accessibility API — which is why the warning
at the top of this file exists.

## What was executed on a device

*(Nothing, and M7 asks for nothing. See §5: `scripts/m6-manual-qa.md` §5 is still the outstanding
device pass.)*
