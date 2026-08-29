# iOS-M6 manual QA — the cycle calendar, the day log, and the one notification

iOS-M6's acceptance is *calendar + prediction overlay, symptom logging, `CyclePredictor` (port the
11-case table); predictions are never persisted; the disclaimer is mandatory*. The automated half is
mapped case-by-case in the execution record of `docs/plans/2026-08-29-ios-m6-cycle.md` — 41 of 41
contracted Kotlin cases, 24/24 packages, 781 tests. This document is the other half: everything that
needs a tap, a clock that actually advances, or the OS's own notification store.

Run it before merging a change to `Packages/Features/FeatureCycle`, to
`Packages/SalusUI/Sources/SalusUI/component/SalusPillButton.swift`, or to the shell files the
milestone touched — `App/RootView.swift`, `App/PlaceholderScreen.swift`,
`App/AppCompositionRoot.swift`.

Every step has an expected result and a checkbox. A step that cannot be run from a terminal says so
in its own words rather than being quietly skipped — **§5 is the one that needs a real device**, and
§4 needs you to sit through a two-minute wait twice.

**Language.** The app has no language switch of its own; it follows the device (spec §6.4 — Turkish
is the default *and* the fallback). Sections 1-5 are written with the Turkish strings because that is
what a default simulator shows; §6 switches the device to English and re-checks.

**Wording.** The cycle copy is Android-verbatim, and Android mixes two words: the calendar says
**"Regl"** and the reminder says **"Dönem"**. That is not a typo on either platform — it is copied as
is, and it is recorded in the plan. The app never claims a prediction is a fact: the pinned line under
every calendar screen is **"Bu tıbbi tavsiye değildir."**, and the notification body ends with
**"Tahminler kesin değildir."**

**One thing to know before you start.** Reminder Health does **not** list individual occurrences —
it shows the four permission cards and the *last sync* line. So "the reminder reached the OS" is
proven by three things together, and §4 checks all three: the `reminder_alarms` row, Reminder
Health's *Son hatırlatıcı taraması* line moving, and the notification actually arriving.

---

## 1. Build, install, the entry point, the tab bar, and the calendar

```sh
cd salus-ios
./scripts/build-app.sh            # Debug, generic/platform=iOS Simulator

UDID=$(xcrun simctl list devices available | sed -n 's/.*iPhone 17 Pro (\([-0-9A-F]*\)).*/\1/p' | head -1)
APP="$(xcodebuild -project Salus.xcodeproj -scheme Salus \
        -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2; exit}')/Salus.app"

xcrun simctl boot "$UDID"; open -a Simulator
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.alicansekban.salus
```

Two shell helpers every later section uses:

```sh
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
DB="$DATA/Library/Application Support/salus.db"
```

- [ ] **1.1** The app launches and the tab bar has five tabs (`RootTab` order: home, medications,
  vitals, appointments, more). Cycle is **not** a tab and must never become one — S-23 fixes the five.
- [ ] **1.2** **More** (5th tab) shows two rows: **Hatırlatıcı sağlığı** and **Regl Takibi** with the
  subtitle *"Takvim, tahminler ve belirtiler"*.
  *Expected:* the Regl Takibi row is **unconditional** — it does not yet hide for a male profile. That
  is divergence (h)/M8's job, not a defect here.
- [ ] **1.3 The Reminder Health regression.** Tap **Hatırlatıcı sağlığı**.
  *Expected:* the Reminder Health screen pushes and renders its cards. *Why this step exists:*
  `PlaceholderScreen` grew a second row in Task 12 and the simulator input died before this route
  could be re-smoked — it is the one thing Task 12's own report leaves open.
  While you are here, grant notification permission: **Düzelt** on the *Bildirimler* card → Allow.
  The card flips to *"Bildirimler açık."* §4 has nothing to deliver without it.
- [ ] **1.4** Go back. Tap **Regl Takibi**.
  *Expected:* the cycle calendar pushes, titled **Döngü**.

### The tab bar hides on pushed screens (Task 12b, Android `showBottomBar` parity)

- [ ] **1.5** On the pushed cycle calendar: **there is no tab bar.** The content runs to the bottom of
  the screen and the pinned disclaimer sits above the home indicator, not above a tab bar.
- [ ] **1.6** Tap the system back arrow.
  *Expected:* the More list returns **and the tab bar is back**, with the standard system animation
  (no custom transition was added).
- [ ] **1.7** The rule is the shell's, not Cycle's — check three more pushed screens, one per stack:
  - Medications tab → any medication card → **detail: no tab bar**; back → bar returns.
  - Appointments tab → any appointment → **detail: no tab bar**; back → bar returns.
  - Vitals tab → the weight editor → **no tab bar**; back → bar returns.
  *Expected:* all three behave identically. If one of them still shows the bar, the modifier is on the
  wrong view, not on the tab's `NavigationStack`.
- [ ] **1.8** From the cycle calendar, tap any in-month day → the day log screen pushes.
  *Expected:* **no tab bar** here either (two levels deep), and popping twice brings it back.

### The calendar and its overlay

- [ ] **1.9** The month header reads the current month and year (`LLLL yyyy`, Turkish), with a chevron
  on each side. The weekday strip under it starts on **Monday** (`P S Ç P C C P` in Turkish).
- [ ] **1.10 The grid is square and evenly spaced.** Every day cell is a circle in a square box: the
  cells in a row are the same width, the rows are the same height, and a cell is as tall as it is
  wide. *Why this step exists:* the cells get their squareness from `Color.clear.aspectRatio(1)`
  inside an `HStack`, and no view-body test can catch it going oblong. If they are not square, the
  fallback is a `LazyVGrid`.
  The small horizontal offset between the weekday letters and the columns beneath them is **faithful**
  — Kotlin has the same quirk. Do not "fix" it here.
- [ ] **1.11** Today's cell carries a **2-pt ring** and bold text. Days outside the displayed month are
  drawn dimmed (30 % opacity) and are **not tappable**.
- [ ] **1.12** The legend under the grid has **three** dots: *Regl*, *Tahmin*, *Doğurgan dönem*.
  *Expected:* there is **no ovulation entry in the legend** — Android has none either, although the
  ovulation day does get its own 1-pt border on the cell. Parity, not an omission.
- [ ] **1.13** With no periods recorded yet, the summary card reads **"Tahminleri görmek için en az
  iki regl kaydı ekle."** and nothing else — no day number, no confidence line.
- [ ] **1.14 The disclaimer is pinned, not scrolled.** Scroll the screen to its bottom and back to its
  top.
  *Expected:* **"Bu tıbbi tavsiye değildir."** stays on screen the whole time, centred under the
  scroll area. It is outside the `ScrollView` by design and must be visible in every state, loading
  included.
- [ ] **1.15** Tap the right chevron twice, then the left chevron four times.
  *Expected:* the header follows the months, the grid rebuilds each time, and the summary card does
  **not** change — the summary describes the prediction, not the displayed month.
- [ ] **1.16 Nothing was persisted by looking.** A prediction has no table, and browsing months writes
  nothing:
  ```sh
  sqlite3 "$DB" "select name from sqlite_master where type='table' and name like '%predict%';"
  sqlite3 "$DB" "select count(*) from cycle_periods;"
  ```
  *Expected:* the first query returns **nothing at all** (there is no prediction table, and there
  never will be — that is half the milestone's acceptance), the second returns `0`.

**Acceptance for §1:** Cycle is reachable from More and only from More, the tab bar is hidden on every
pushed screen and returns on pop, the month grid draws square cells with a Monday-first strip and a
three-entry legend, the disclaimer never leaves the screen, and no prediction touched the database.

---

## 2. Starting and ending a period, and the same-day duplicate

- [ ] **2.1** On the calendar, the action pill at the bottom of the scroll area reads **"Regl
  başladı"**. It **spans the full width of the row** — it is a wide capsule, not a content-width pill
  centred in the row. *Why this step exists:* `SalusPillButton` grew a `fillsWidth` parameter in Task
  10's fix round exactly because it did not; a content-width pill floating in the middle is the
  regression.
- [ ] **2.2** The pill is at least a 48-pt tap target and looks like one — measure it against the
  save pill in §3, which uses the same component. It is hand-drawn (`.plain` + a `SalusShapes.pill`
  capsule), so it has **no system press highlight**; that is deliberate and recorded.
- [ ] **2.3 Start.** Tap **Regl başladı**.
  *Expected on screen:* today's cell fills with the cycle accent, the button flips to **"Regl
  bitti"**, and the summary card now shows **"Döngünün 1. günü"**.
  *Expected in the database:* one open period starting today.
  ```sh
  sqlite3 "$DB" "select id, start_date, end_date, flow_peak from cycle_periods order by start_date;"
  ```
  *Expected:* one row, `start_date` = today's epoch day, `end_date` **empty**, `flow_peak` empty.
- [ ] **2.4 The same-day duplicate is a silent no-op.** Force-quit the app (swipe up in the app
  switcher), relaunch, go back to the calendar, and tap **Regl bitti** to close the period; then tap
  **Regl başladı** again on the same day.
  *Expected on screen:* **nothing visible happens the second time** — no error, no toast, no second
  fill. `StartPeriodUseCase` rejects a start on a day that already has one, and the ViewModel
  discards the result. This is faithful to Android and it is an Android follow-up, not a bug to fix
  here.
  *Expected in the database:* still **one** row for today.
  ```sh
  sqlite3 "$DB" "select count(*) from cycle_periods where start_date = cast((julianday('now','localtime') - 2440587.5) as int);"
  ```
  *Expected:* `1`.
- [ ] **2.5** The same silence covers *starting while another period is open*: with an open period,
  the button reads **Regl bitti**, so the calendar gives you no way to try. Reaching the rejection
  needs a second screen the port does not have. Noted so the absence is not read as an untested path
  — `starting while another period is open is rejected` is green in `StartPeriodUseCaseTests`.
- [ ] **2.6 End.** With a period open, tap **Regl bitti**.
  *Expected on screen:* the button flips back to **Regl başladı**; today's cell keeps its fill,
  because the period still covers today.
  *Expected in the database:* `end_date` is today's epoch day on that row.
- [ ] **2.7 The overlay, with two periods.** The prediction needs two recorded starts, and waiting a
  month is not QA. Insert a second, older period directly and relaunch the app:
  ```sh
  # A closed period 28 days before the one you just recorded.
  TODAY=$(sqlite3 "$DB" "select cast((julianday('now','localtime') - 2440587.5) as int);")
  PROFILE=$(sqlite3 "$DB" "select profile_id from cycle_periods limit 1;")
  sqlite3 "$DB" "insert into cycle_periods (id, profile_id, start_date, end_date, flow_peak, note, created_at)
                 values ('qa-prev', '$PROFILE', $TODAY - 28, $TODAY - 23, null, null, 0);"
  ```
  Force-quit and relaunch, then open the calendar.
  *Expected:* the summary card now carries **"Döngünün N. günü"**, a **"Tahmini regl … gün sonra"**
  line, and a **"Tahmin güveni: Düşük"** line — two periods is one usable cycle length, which is
  `LOW` by the ported table. The grid shows the older period's days filled, the predicted next-period
  days in the 25 %-alpha accent, the fertile window in the vitals container colour, and the ovulation
  day with its own 1-pt border.
- [ ] **2.8 A predicted day that is also recorded stays recorded.** Compare the overlay against the
  rows:
  ```sh
  sqlite3 "$DB" "select start_date, end_date from cycle_periods order by start_date;"
  ```
  *Expected:* no cell inside a recorded range is drawn in the pale predicted colour — recorded wins.
  That is the iOS-only case `predicted days that are already recorded stay recorded`, seen from
  outside.

**Acceptance for §2:** one tap opens a period and one tap closes it, both write the row they claim to,
a duplicate start on the same day changes nothing and says nothing, the action pill spans its row at
a 48-pt height, and with two periods the calendar draws a prediction it never stores.

---

## 3. The day log — seeding, the round trip, and the keyboard

- [ ] **3.1 The catalog seeds on first open.** Before opening a day screen for the first time on a
  fresh install:
  ```sh
  sqlite3 "$DB" "select count(*) from symptoms;"
  ```
  Then open the calendar and tap any in-month day.
  *Expected:* the day screen shows **eight** symptom chips — Akne, Bel ağrısı, Şişkinlik, Kramp,
  Yorgunluk, Baş ağrısı, Duygu dalgalanması, Göğüs hassasiyeti — and the table now has eight rows
  with hyphenated ids:
  ```sh
  sqlite3 "$DB" "select id, name_key, is_custom from symptoms order by is_custom, name_key;"
  ```
  *Expected:* `symptom-acne`, `symptom-back-pain`, `symptom-bloating`, `symptom-cramps`,
  `symptom-fatigue`, `symptom-headache`, `symptom-mood-swings`, `symptom-tender-breasts`, all
  `is_custom = 0`, ordered by `name_key` so **acne is first**.
- [ ] **3.2 It seeds once.** Pop back to the calendar and open another day, then re-run the count.
  *Expected:* still **8**. A second collection of the stream must not seed again.
- [ ] **3.3** The day screen shows, in order: the symptom chips (**Belirtiler**), the flow row
  (**Akış**: Lekelenme / Hafif / Orta / Yoğun), the mood row (**Ruh hali**: Harika / İyi / Nötr /
  Keyifsiz / Gergin / Endişeli), the note field (**Not (isteğe bağlı)**), and the save pill
  (**Kaydet**).
- [ ] **3.4 The save pill spans its row**, exactly like §2.1's — same component, same `fillsWidth`.
- [ ] **3.5 Select.** Tap **Kramp** and **Baş ağrısı**, tap flow **Orta**, tap mood **İyi**, and type
  `test notu` into the note field. Tap **Kaydet**.
  *Expected on screen:* the screen pops back to the calendar.
  *Expected in the database:*
  ```sh
  sqlite3 "$DB" "select id, date, flow, mood, note from cycle_daily_entries order by date;"
  sqlite3 "$DB" "select entry_id, symptom_id, severity from cycle_entry_symptoms order by symptom_id;"
  ```
  *Expected:* one entry for that day with `flow = 'MEDIUM'`, `mood = 'GOOD'`, `note = 'test notu'`,
  and **two** link rows — `symptom-cramps` and `symptom-headache` — each with `severity = 1`. The
  enum values are stored **uppercase and Android-verbatim** (S-19); a lowercase value here is a
  defect.
- [ ] **3.6 Round trip.** Re-open the same day.
  *Expected:* Kramp and Baş ağrısı are selected, flow **Orta** is selected, mood **İyi** is selected,
  and the note reads `test notu`.
- [ ] **3.7 The same flow twice clears it.** Tap **Orta** again.
  *Expected:* the flow selection clears — no flow is highlighted. Save, and the row's `flow` column
  is now empty.
- [ ] **3.8 The rewrite replaces the symptom set.** Re-open the day, deselect Baş ağrısı, select
  Yorgunluk, and save.
  *Expected:* the link table has exactly **two** rows for that entry — `symptom-cramps` and
  `symptom-fatigue`. `symptom-headache` is gone, not orphaned.
- [ ] **3.9 The keyboard closes on a tap — including on the `Form`-based weight editor.** Two places,
  because Task 0 added the modifier to editors it could not measure:
  - Cycle day screen: tap into the note field, then tap any blank area of the screen.
    *Expected:* the keyboard dismisses. (The note field is `axis: .vertical`, so its return key
    inserts a newline — the tap is the only way out.)
  - **Vitals tab → the weight editor** (a `Form`, not a `ScrollView`): tap into the weight field, then
    tap a blank area of the form.
    *Expected:* the keyboard dismisses. *Why this step exists:* `salusDismissesKeyboardOnTap()` on a
    `Form` is the one Task 0 deferral nobody has measured — `Form` rows consume taps differently from
    a `ScrollView`, and the modifier may simply never fire. If it does not dismiss, that is the
    deferral coming true, not a new bug.
- [ ] **3.10 The back button is the system's.** The day screen's back affordance is the navigation
  stack's own arrow, with the system swipe-back gesture. The catalog carries a `cycle_back` string
  that nothing reads — divergence (o), ported for key-set parity. Do not look for a custom back
  button; there isn't one, and there should not be.

**Acceptance for §3:** the eight starter symptoms appear on first open and exactly once, a day log
round-trips through the database with Android-verbatim enum values, re-tapping a flow clears it, a
rewrite replaces the symptom set rather than adding to it, and the keyboard has a way out on both a
`ScrollView` and a `Form`.

---

## 4. The reminder card, the sync, and the tap

This section needs §1.3's notification permission and the two periods from §2.7.

- [ ] **4.1** On the calendar, the reminder card is titled **"Dönem hatırlatıcısı"** with a toggle,
  and while the toggle is off the subtitle reads **"Tahmin edilen dönem başlangıcından önce bildirim
  al"**.
- [ ] **4.2 Not enough data says so.** On a fresh install with fewer than two periods, turning the
  toggle on shows **"Yeterli döngü verisi olduğunda bildirim gönderilir"** and no option rows appear
  below it. (Task 12 already saw this; re-check it if you reset the database.)
- [ ] **4.3** With the two periods from §2.7, turn the toggle **on**.
  *Expected:* two option rows appear — **Ne zaman** with the value **"1 gün önce"**, and **Saat** with
  the value **09:00** (24-hour, always).
  The singular reads **"1 gün önce"** and not "1 days before" in Turkish; the English catalog does say
  *"1 days before"*, which is Android-verbatim and a known copy wart, not a defect of this port.
- [ ] **4.4 The lead-days popup has no radio buttons.** Tap the **Ne zaman** row.
  *Expected:* an action sheet with four options — **Tahmin edilen gün**, **1 gün önce**, **2 gün
  önce**, **3 gün önce** — plus **Vazgeç**, and **no tick beside the current one**. That is divergence
  (e): `confirmationDialog` has no selection affordance, and the current value is the row you tapped.
  Pick **2 gün önce**.
  *Expected:* the sheet closes and the row's value updates immediately.
- [ ] **4.5 The time sheet is a wheel.** Tap the **Saat** row.
  *Expected:* a half-height sheet with a wheel hour/minute picker, **Tamam** and **Vazgeç**. Set a
  time about **two minutes** from now and tap **Tamam**. The row's value updates.
- [ ] **4.6 The three settings were written, Android-verbatim.**
  ```sh
  plutil -p "$DATA/Library/Preferences/com.alicansekban.salus.plist" \
    | grep -E 'cycle_reminder_(enabled|lead_days|minute_of_day)'
  ```
  *Expected:* `cycle_reminder_enabled` true, `cycle_reminder_lead_days` 2, and
  `cycle_reminder_minute_of_day` = the minute you picked. The key names are the Android ones (S-19)
  and must not be "improved".
- [ ] **4.7 LOW confidence emits nothing — check this first.** The handler refuses on exactly two
  conditions: the toggle off, and `CycleConfidence.low`. §2.7 left you with two periods, which is one
  usable cycle length and therefore `LOW`. Background and foreground the app once so the window
  synchronizer runs, then:
  ```sh
  sqlite3 "$DB" "select type, entity_id, occurrence_key from reminder_alarms where type = 'CYCLE_PERIOD';"
  ```
  *Expected:* **no rows.** A prediction the app itself calls unreliable never becomes a notification —
  a row here is a real defect (`emits nothing on LOW confidence` is a ported case).
- [ ] **4.8 Give the predictor enough history.** Insert two more older periods at 28-day spacing, then
  force-quit and relaunch:
  ```sh
  sqlite3 "$DB" "insert into cycle_periods (id, profile_id, start_date, end_date, flow_peak, note, created_at)
                 values ('qa-prev2', '$PROFILE', $TODAY - 56, $TODAY - 51, null, null, 0),
                        ('qa-prev3', '$PROFILE', $TODAY - 84, $TODAY - 79, null, null, 0);"
  ```
  *Expected:* the summary card's confidence line now reads **Orta** or **Yüksek** — three usable
  cycle lengths at a steady 28 days. Re-check the **Saat** row and move it to about two minutes from
  now, then background and foreground the app once.
- [ ] **4.9 The occurrence reached the engine.**
  ```sh
  sqlite3 "$DB" "select type, entity_id, occurrence_key,
                        datetime(trigger_at_epoch_ms/1000,'unixepoch') as trigger_utc, state
                 from reminder_alarms where type = 'CYCLE_PERIOD';"
  ```
  *Expected:* **exactly one row**. `entity_id` = `cycle-period`, `occurrence_key` =
  `"<ISO date>|<minuteOfDay>"` with a **pipe** (e.g. `2025-09-01|540`), and the trigger UTC matching
  the time you set, shifted back by the lead days. One occurrence, never a series — that is the whole
  reminder contract.
- [ ] **4.10 Reminder Health saw the sync.** More → **Hatırlatıcı sağlığı**.
  *Expected:* the **Son hatırlatıcı taraması** line shows a timestamp from the last minute or so.
  Reminder Health does **not** list the occurrence itself — it has no per-reminder list — so this
  line plus §4.9's row is what "visible after sync" means here.
- [ ] **4.11 It fires.** Leave the app in the background and wait for the time you set.
  *Expected:* a notification titled **"Dönem yaklaşıyor"** with a body ending in **"Tahminler kesin
  değildir."** — either *"Tahmini dönem başlangıcına N gün var."* or, at lead 0, *"Tahmini dönem
  başlangıcı bugün."* It is a **plain notification**: no full-screen alarm, no action buttons. That
  is S-6 — only medication doses present as alarms.
- [ ] **4.12 The tap opens the calendar on Home.** Tap the notification.
  *Expected:* the app opens on the **Home** tab (not More) with the cycle calendar **pushed** on top
  of it, and — per §1 — no tab bar. This is iOS-only: Android's tap writes extras nobody reads
  (divergence (c)).
- [ ] **4.13 A second tap does not stack a second calendar.** Without popping, re-arm the reminder
  (change the **Saat** row to another two minutes out, background the app so it syncs, wait for the
  second notification) and tap it while the calendar is still on the Home stack.
  *Expected:* you stay on the one calendar. **One** back tap returns you to the Home tab root — if two
  are needed, the memo (`reminderPushedCycleDepth`) is broken and two calendars are stacked.
- [ ] **4.14 Turning it off clears the ledger.** Toggle the reminder off, background and foreground
  once, then re-run §4.9.
  *Expected:* **no** `CYCLE_PERIOD` row.

**Acceptance for §4:** the card writes the three Android-verbatim settings, the handler emits exactly
one occurrence and only above `LOW` confidence, the occurrence reaches the OS as a plain notification
whose body says predictions are not certain, its tap lands on Home with the calendar pushed once, and
turning the toggle off removes the row.

---

## 5. The device pass

**Never run.** Everything above works on a simulator; this section exists because a simulator's clock,
its notification scheduling and its background refresh are all approximations. One iPhone, one
evening.

- [ ] **5.1** Install the Debug build on a real device (`scripts/build-app.sh` builds for the
  simulator; use Xcode's Run against the device, or an ad-hoc archive).
- [ ] **5.2** Repeat §1.1-§1.8 on the device: the entry point, and the tab bar hiding on every pushed
  screen and returning on pop. Check it on the smallest screen you have — the full height is the
  reason the rule exists.
- [ ] **5.3** Seed two-plus periods (§2.3 and §2.7's inserts are simulator-only; on a device, record
  them through the UI over as many taps as it takes, or use a debug build with a temporary seed).
- [ ] **5.4** Set the reminder to a time **ten minutes out**, background the app, and lock the phone.
  *Expected:* the notification arrives **at the configured minute**, on the lock screen, titled
  **"Dönem yaklaşıyor"**. It is a banner, not a full-screen alarm, and it has no action buttons.
- [ ] **5.5** Tap it from the lock screen.
  *Expected:* the app opens on the **Home** tab with the cycle calendar pushed, no tab bar, and the
  disclaimer visible.
- [ ] **5.6** Reboot the phone, wait for the next occurrence, and confirm it still arrives — the
  reminder engine's cold-start path, which the simulator does not exercise honestly.
- [ ] **5.7** Turn the toggle off, background the app, and confirm no further cycle notification
  arrives.

**Acceptance for §5:** on real hardware the single cycle occurrence fires at the minute it was
configured for, presents as a plain notification, survives a reboot, opens the calendar on Home when
tapped, and stops when the toggle is turned off.

---

## 6. TR / EN, Dynamic Type, and the unused pill combination

- [ ] **6.1** Switch the device to English (Settings → General → Language & Region) and relaunch.
  *Expected:* the More row reads **Cycle tracking** / *"Calendar, predictions and symptoms"*, the
  calendar title reads **Cycle**, the legend reads *Period / Predicted / Fertile window*, the flow
  row reads *Spotting / Light / Medium / Heavy*, and the disclaimer reads **"This is not medical
  advice."**
- [ ] **6.2** With the device set to a language that is **neither** Turkish nor English (French, say),
  relaunch.
  *Expected:* the app draws **Turkish**, not English — Turkish is the fallback as well as the default
  (spec §6.4, S-4). An English screen here is a `developmentLanguage` regression.
- [ ] **6.3** Raise Dynamic Type to the largest non-accessibility size.
  *Expected:* the summary card, the reminder card's two option rows and the symptom chips grow and
  wrap without clipping; the day cells stay square; the pills stay at least 48 pt and their labels do
  not truncate mid-word.
- [ ] **6.4 The unused `SalusPillButton` combination.** No shipped screen uses `tonal: true` with an
  accent, so it has no runtime check. Open
  `Packages/SalusUI/Sources/SalusUI/component/SalusPillButton.swift` in Xcode and look at its
  `#Preview` canvas in both light and dark.
  *Expected:* the tonal + accent variant draws a readable label on its container, and the **disabled**
  state is legible — the disabled look is hand-drawn from Material's alphas (container `onSurface`
  @ 12 %, content @ 38 %) and is the one part of ruling 1 no test covers.

**Acceptance for §6:** both project locales render the cycle copy in full, a third locale falls back
to Turkish, the layout survives the largest non-accessibility text size, and the component's untaken
variant is legible in both themes.

---

## 7. Inspection commands

```sh
UDID=<from section 1>
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
DB="$DATA/Library/Application Support/salus.db"

# The four cycle tables.
sqlite3 "$DB" 'select id, profile_id, start_date, end_date, flow_peak, note, created_at
               from cycle_periods order by start_date;'
sqlite3 "$DB" 'select id, profile_id, date, flow, mood, note from cycle_daily_entries order by date;'
sqlite3 "$DB" 'select id, name_key, is_custom, icon_token from symptoms order by is_custom, name_key;'
sqlite3 "$DB" 'select entry_id, symptom_id, severity from cycle_entry_symptoms order by entry_id, symptom_id;'

# There is no prediction table, and this must stay empty.
sqlite3 "$DB" "select name from sqlite_master where type='table' and name like '%predict%';"

# What the engine handed to the OS. entity_id is the constant "cycle-period"; the occurrence key is
# "<ISO date>|<minuteOfDay>" with a PIPE.
sqlite3 "$DB" "select type, entity_id, occurrence_key, request_code,
                      datetime(trigger_at_epoch_ms/1000,'unixepoch') as trigger_utc, state
               from reminder_alarms where type = 'CYCLE_PERIOD';"

# The three Android-verbatim settings keys.
plutil -p "$DATA/Library/Preferences/com.alicansekban.salus.plist" \
  | grep -E 'cycle_reminder_(enabled|lead_days|minute_of_day)'

# Today's epoch day, which every date column above is measured in.
sqlite3 "$DB" "select cast((julianday('now','localtime') - 2440587.5) as int);"

# The app's own log. --info --debug is required: `log show` hides both levels by default.
xcrun simctl spawn "$UDID" log show --last 10m --info --debug \
    --predicate 'subsystem == "com.alicansekban.salus"' --style compact

# Teardown.
xcrun simctl uninstall "$UDID" com.alicansekban.salus
xcrun simctl shutdown "$UDID"
```

---

## What was executed when this document was written (iOS-M6 Task 13)

**Nothing in it.** Task 13 is documentation and verification only: it ran `scripts/ci.sh` end to end
(5/5 green — 24/24 packages, 781 tests, both lint gates and all three custom rules, `** BUILD
SUCCEEDED **`) and wrote this script from the code, the string catalogs and the evidence in the Task
0, 5, 7, 10, 11, 12 and 12b reports.

What **Task 12** ran on a simulator, and what it explicitly did not, is in
`.superpowers/sdd/2026-08-29-ios-m6-cycle/task-12-report.md`: real `CGEvent` taps for More → Regl
Takibi → the calendar with today ringed, start period, a day tap, and the reminder toggle's
`needs_data` subtitle. Its simulator input died before **More → Hatırlatıcı sağlığı** could be
re-smoked — that is why §1.3 exists as its own step. **Task 12b** ran the tab-bar rule on iOS 17.5 and
iOS 26.0 and captured fifteen screenshots (`.superpowers/`, untracked).

**No cycle notification has ever been delivered**, on a simulator or a device. §4.10 and all of §5 are
unexercised.

## What was executed on a device

*(Not yet. Fill this in after the device pass, the way `scripts/m4-manual-qa.md` records its
2026-08-25 run.)*
