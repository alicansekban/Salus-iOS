# iOS-M5 manual QA — medications, and the dose that rings

iOS-M5's acceptance is *medication CRUD with the schedule builder, the per-medication reminder
toggle, and a dose that presents as an **alarm** with actions that write an intake log from the
background* — plus the iOS-M3a clause the milestone finally exercises: a dose rings as a full-screen
AlarmKit alarm on iOS 26, as a time-sensitive notification below it, while an appointment reminder
stays a plain notification. The automated half is mapped case-by-case in the execution record of
`docs/plans/2026-08-27-ios-m5-medications.md`. This document is the other half: everything that needs
a tap, a locked screen, or the OS's own alarm store.

Run it before merging a change to `Packages/Features/FeatureMedications`,
`Packages/SalusReminder/Sources/SalusReminder/{api,engine,platform}/`, or the medications wiring in
`App/AppCompositionRoot+Reminder.swift` / `App/Reminder/`.

Every step has an expected result and a checkbox. A step that cannot be run from a terminal says so
in its own words rather than being quietly skipped — **§4 and §5 are the two that need a real finger
on a screen, and §5 needs a real device**.

**Language.** The app has no language switch of its own; it follows the device (spec §6.4 — Turkish
is the default *and* the fallback). Sections 1-6 are written with the Turkish strings because that
is what a default simulator shows; §7 switches the device to English and re-checks.

**Wording.** This document, like the app, says **"kaydedilen doz" / "recorded doses"**. The list
card's seven-day figure is a fact about what was written down, not a claim about anyone's treatment
— see decision 1 and divergence (a) in the execution record.

**One label to know before you start.** The dose notification's first action is
`notification_action_taken`, which reads **"İçtim"** in Turkish and **"Taken"** in English (the
Android string, ported verbatim). The plan's prose calls it "Aldım"; the shipped string is "İçtim",
and the string is what you will see. The second action is **"10 dk ertele"** / **"Snooze 10 min"**
(`notification_action_snooze`), and the alarm's stop button is **"Kapat"** / **"Dismiss"**
(`alarm_dismiss`, `SalusReminder`).

---

## 1. Build, install, and the CRUD round trip

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

- [ ] **1.1** The app launches and the tab bar has five tabs. The **2nd** is **Medications**
  (`RootTab` order: home, medications, vitals, appointments, more). The label is English on purpose:
  `nav_medications` is an M8 hub string, so `RootTab.title` still returns the placeholder.
- [ ] **1.2** Opening the tab shows the empty state — **"Henüz ilaç yok"** over *"Doz hatırlatıcıları
  almak ve kullanımını takip etmek için bir ilaç ekle."* — and a **+** FAB at the bottom right.
- [ ] **1.3** Grant notification permission now, or §3 has an empty ledger and §4 cannot be
  delivered: **More** (5th tab) → **Hatırlatıcı sağlığı** → **Düzelt** on the *Bildirimler* card →
  Allow. The card flips to *"Bildirimler açık."*

### The round trip

Every step is also checked in the database, because a row that renders is not yet a row that was
written.

- [ ] **1.4 Create.** FAB (**İlaç ekle**) → the editor titled **Yeni ilaç**. Fill **Ad** = `Aspirin`,
  **Form** = **Tablet**, **Doz gücü** = `100` with **Birim** = `mg`, **Stok adedi** = `10`,
  **Talimatlar** = `yemeklerden sonra`; under **Plan** leave **Her gün**; under **Doz saatleri** the
  editor already offers one default time — set it to `09:00`. Tap **Kaydet**.
  *Expected:* the editor pops and the list shows one card: the form glyph in a circular badge, the
  name, `100 mg`, and the schedule line *"Her gün · 09:00"*.
- [ ] **1.5** The rows were written — **one** medication and **one** active schedule, in **one**
  transaction (divergence (d)):
  ```sh
  sqlite3 "$DB" 'select id, name, form, strength_value, strength_unit, stock_count,
                        reminders_enabled, is_active from medications;'
  sqlite3 "$DB" 'select id, medication_id, recurrence, time_of_day_minutes, dose_amount,
                        interval_days, days_of_week_mask, is_active from medication_schedules;'
  ```
  *Expected:* `form = TABLET`, `stock_count = 10.0`, `reminders_enabled = 1`, `is_active = 1`; the
  schedule is `recurrence = DAILY`, `time_of_day_minutes = 540` (9 × 60), `dose_amount = 1.0`.
- [ ] **1.6 Read.** Tap the card.
  *Expected:* **İlaç detayı** with the name and **Tablet · 100 mg** under it, a **Hatırlatıcılar**
  card whose switch is **on** with *"Doz saatlerinde bildirim gelir."*, a **Kullanım** section
  (**Ne zaman** *Her gün · 09:00*, **Doz** *1 birim*, **Talimatlar** *yemeklerden sonra*), a **Stok**
  section (**Kalan** *10*), and **Son 30 gün** with *"Bu ilaç için henüz kayıt yok."* Two actions at
  the bottom: **Düzenle** and **Sil**, both pill-shaped (`SalusPillButton`'s twin).
- [ ] **1.7 Update.** **Düzenle** → the editor opens as **İlacı düzenle** with *every* field
  preloaded, including the dose-time rows. Change **Ad** to `Aspirin 100`, **Kaydet**.
  *Expected:* the detail screen shows the new name; `select name from medications;` agrees; the row
  count is still 1 (an update, not an insert), and `select count(*) from medication_schedules where
  is_active = 1;` is still 1 — the save *replaces* the active schedule set rather than appending.
- [ ] **1.8 Delete from the detail screen, then undo.** **Sil** → the confirm dialog
  *"Aspirin 100 silinsin mi?"* / *"Kullanım planı ve alım geçmişi de birlikte silinir."* Tap **Sil**.
  *Expected:* the detail screen pops **first**, the list shows the snackbar *"İlaç silindi"* with
  **Geri al**, and the card is already gone from the list. Tap **Geri al** within five seconds.
  *Expected:* the card comes back and **nothing was written** —
  `select count(*) from medications;` never moved.
- [ ] **1.9 Delete from a list row, then let the window expire.** Tap the **trash icon** on the card
  — not the card itself.
  *Expected:* the detail screen does **not** open (the two tap targets are disjoint by layout, which
  is the whole point of divergence (j)), and the same confirm dialog appears. Tap **Vazgeç**: the
  dialog closes, the card stays, the count is unchanged. Tap the trash again and confirm with
  **Sil**: the card disappears at once, the list stays put (nothing pops), and the snackbar offers
  **Geri al**. This time wait without touching anything.
  *Expected:* the snackbar disappears at about **five seconds** — `PendingDeleteController.undoWindowMillis`,
  iOS-M4's divergence (b) — and at that moment:
  ```sh
  sqlite3 "$DB" 'select count(*) from medications;
                 select count(*) from medication_schedules;
                 select count(*) from medication_intake_logs;'
  ```
  *Expected:* `0`, `0`, `0` — schedules and intake logs cascade with the medication.
  With VoiceOver on, the card announces as a button and the trash announces separately as **Sil**.
- [ ] **1.10 Undo from the list, the other direction.** Create a medication again (**1.4**), delete
  it from the **detail** screen and let the window expire without tapping **Geri al**.
  *Expected:* the row is gone from the database at the five-second mark, and the ledger rows for its
  schedule are `CANCELLED` (see §3's query) rather than deleted.

## 2. Editor validation — the five errors, and `AS_NEEDED`

`SaveMedicationUseCase` rejects five things, and each one surfaces as the banner at the top of the
editor while the form stays intact. There is no per-field error tint: SwiftUI's
`TextField` has no `isError`, so the banner is the single error surface.

- [ ] **2.1 Blank name.** New editor, leave **Ad** empty, **Kaydet**.
  *Expected:* **"Lütfen bir ad gir."** The editor does **not** close and nothing is written.
- [ ] **2.2 No dose times.** Give it a name, then remove the default dose-time row with **Saati
  kaldır**, **Kaydet**.
  *Expected:* **"En az bir doz saati ekle."**
- [ ] **2.3 Interval below one.** Add a dose time back, switch **Plan** to **Gün aralıklı**, set
  **Kaç günde bir** to `0`, **Kaydet**.
  *Expected:* **"Gün aralığı en az 1 olmalı."**
- [ ] **2.4 Days of week with no day selected.** Switch **Plan** to **Haftanın günleri** and leave
  every day chip (**Pzt Sal Çar Per Cum Cmt Paz**) unselected, **Kaydet**.
  *Expected:* **"Haftanın en az bir gününü seç."**
- [ ] **2.5 End date before start date.** Switch back to **Her gün**, tap the end-date field
  (placeholder **"Bitiş tarihi yok"**) and pick a day *before* the start date, **Kaydet**.
  *Expected:* **"Bitiş tarihi başlangıç tarihinden önce."** Tap **Bitiş tarihini kaldır** and the
  field goes back to the placeholder.
- [ ] **2.6 A valid save clears the banner.** Fix the last error and **Kaydet**.
  *Expected:* the editor pops. The name is stored **trimmed** — type `"  Aspirin  "` once and check
  `select '['||name||']' from medications;` reads `[Aspirin]`.
- [ ] **2.7 `AS_NEEDED`.** Create a medication with **Plan** = **Gerektiğinde** and one dose time.
  *Expected on the card:* the schedule line reads **"Gerektiğinde"** alone — no time.
  *Expected in the database:* the schedule row is still written, with its time (divergence (n) — the
  silent row is kept, and **no** ad-hoc logging UI was invented on either platform):
  ```sh
  sqlite3 "$DB" "select recurrence, time_of_day_minutes, is_active from medication_schedules
                 where medication_id = (select id from medications where name like '%erektiğinde%'
                                        or name = 'PRN');"
  ```
  *Expected:* `AS_NEEDED`, the minute you set, `1`.
- [ ] **2.8 An `AS_NEEDED` medication never rings.** With the app foregrounded once (so a sync has
  run), check the ledger:
  ```sh
  sqlite3 "$DB" "select count(*) from reminder_alarms
                 where entity_id in (select id from medication_schedules
                                     where recurrence = 'AS_NEEDED');"
  ```
  *Expected:* `0`. `DoseOccurrenceGenerator` emits nothing for `AS_NEEDED` — the generator's own
  ported case, seen from the outside.

## 3. The reminder toggle silences the ledger

Spec §11 A9, and the reason schema v4 exists. Toggling reminders off for **one** medication must
withdraw only that medication's occurrences: the handler stops emitting them, the next sync cancels
their ledger rows, and every sibling keeps ringing.

Set up two medications whose next dose is inside the window — say `Aspirin` at `now + 30 min` and
`D vitamini` at `now + 45 min`, both **Her gün**. Foreground the app once so the engine syncs, then:

```sh
sqlite3 "$DB" "select m.name, s.id as schedule_id, r.occurrence_key,
                      datetime(r.trigger_at_epoch_ms/1000,'unixepoch') as trigger_utc, r.state
               from reminder_alarms r
               join medication_schedules s on s.id = r.entity_id
               join medications m on m.id = s.medication_id
               where r.type = 'MEDICATION_DOSE'
               order by m.name, r.trigger_at_epoch_ms;"
```

The occurrence key is `"<epochDay>|<minuteOfDay>"` — a **pipe**, and both halves are integers
(`DoseOccurrenceKey`). `entity_id` is the **schedule** id, not the medication id.

- [ ] **3.1 Both ring.** *Expected:* `SCHEDULED` rows for both medications, one per dose time per day
  inside the 7-day / 60-slot window (spec §6.1).
- [ ] **3.2 Toggle one off.** Open **Aspirin**'s detail and turn the **Hatırlatıcılar** switch off.
  *Expected on screen, immediately:* the description flips to *"Bildirim gelmez; dozlar Ana Sayfa'da
  görünmeye ve işaretlenmeye devam eder."*, and a warning chip **"Hatırlatıcılar kapalı"** appears
  under the header — and on the **list card** too.
  *Expected in the database:*
  ```sh
  sqlite3 "$DB" "select name, reminders_enabled from medications order by name;"
  ```
  `Aspirin` is `0`, `D vitamini` is `1`. The write is immediate — no undo window, no save button.
- [ ] **3.3 The ledger follows.** Re-run the join query from above.
  *Expected:* every `Aspirin` row is now **`CANCELLED`** (the state changes; the row is not deleted),
  and every `D vitamini` row is still `SCHEDULED`. This is the ported case *"a silenced medication
  contributes no occurrences while its sibling still does"*, seen against the real ledger.
- [ ] **3.4 Toggle it back on.** *Expected:* the chip disappears, the description returns to *"Doz
  saatlerinde bildirim gelir."*, and fresh `SCHEDULED` rows for `Aspirin` reappear — the ported case
  *"a re-enabled medication rings again"*.
- [ ] **3.5 An appointment is untouched.** If an appointment with a reminder exists, its rows keep
  `type = 'APPOINTMENT'` and are unaffected by the medication toggle:
  ```sh
  sqlite3 "$DB" "select type, count(*), state from reminder_alarms group by type, state;"
  ```

## 4. The fallback notification path, with the app killed

This is the **iOS 17-25** presentation and the simulator's only path: below iOS 26 there is no
AlarmKit, so a dose is delivered as a **time-sensitive notification** carrying the handler's two
actions. The actions are answered by `ReminderNotificationDelegate` →
`ReminderActionDispatcher` → `MarkDoseTakenUseCase` / `SnoozeDoseUseCase`, and the whole point of
this section is that the app does **not** have to be running.

**`xcrun simctl` has no tap primitive**, so the two action presses are the steps a person has to do.
The delivery itself can be driven, either by waiting for a real dose or by pushing the exact payload
the gateway writes.

Take a real schedule id out of the database first:

```sh
sqlite3 "$DB" "select s.id, m.name, s.time_of_day_minutes from medication_schedules s
               join medications m on m.id = s.medication_id where s.is_active = 1;"
```

- [ ] **4.1 Arm a real dose.** Edit a medication so its only dose time is **two minutes from now**
  (round the simulator's clock up so the minute has not already passed), save, and confirm the
  ledger has a `SCHEDULED` row at that minute (§3's query). Then **force-quit the app** — swipe up in
  the app switcher — and lock the simulator (`⌘L`).
- [ ] **4.2 It arrives.** *Expected at the dose minute:* a notification titled **"Aspirin zamanı"**
  with the body **"1 × 100 mg al"** (`notification_dose_text`; a medication with no strength gets
  **"1 doz al"**, `notification_dose_text_plain`). Long-press or pull it down: the two actions read
  **"İçtim"** and **"10 dk ertele"**.
  *If you would rather not wait*, push the same payload — the delegate's `didReceive` path is
  identical for a remote and a local request:
  ```sh
  cat > /tmp/salus-m5-dose.apns <<'JSON'
  {
    "Simulator Target Bundle": "com.alicansekban.salus",
    "aps": { "alert": { "title": "Aspirin zamanı", "body": "1 × 100 mg al" },
             "sound": "default", "category": "salus.reminder.MEDICATION_DOSE",
             "interruption-level": "time-sensitive" },
    "salus.extra.REMINDER_TYPE": "MEDICATION_DOSE",
    "salus.extra.REMINDER_ENTITY_ID": "<PASTE THE SCHEDULE ID>",
    "salus.extra.REMINDER_OCCURRENCE_KEY": "<epochDay>|<minuteOfDay>"
  }
  JSON
  xcrun simctl push "$UDID" com.alicansekban.salus /tmp/salus-m5-dose.apns
  ```
  The category is registered from the handler's actions, so the two buttons appear on the pushed
  notification exactly as on the scheduled one.
- [ ] **4.3 "İçtim" with the app killed.** Press **İçtim** — do **not** open the app first. That is
  the leg that exercises the action reaching a process iOS launched for it.
  *Expected, checked from the terminal without launching the app:*
  ```sh
  sqlite3 "$DB" "select status, dose_amount,
                        datetime(taken_at_epoch_ms/1000,'unixepoch') as taken_utc,
                        snoozed_until_epoch_ms
                 from medication_intake_logs order by rowid desc limit 1;"
  sqlite3 "$DB" "select name, stock_count from medications where name like 'Aspirin%';"
  ```
  *Expected:* one log row with `status = TAKEN`, `taken_at_epoch_ms` at about now, and
  `stock_count` **decremented by the dose amount** (10 → 9). The notification is gone from
  Notification Center, and the ledger row for that occurrence is resolved.
- [ ] **4.4 The window is refilled.** Re-run §3's join query.
  *Expected:* the answered occurrence is no longer `SCHEDULED`, and **tomorrow's** dose is — every
  action ends with a `requestSync()`, so the ledger is topped back up without the app being opened.
- [ ] **4.5 "İçtim" twice is not two decrements.** Push the same payload again (same occurrence key)
  and press **İçtim** again.
  *Expected:* `select count(*) from medication_intake_logs;` is unchanged and `stock_count` is still
  9 — the ported case *"taken is idempotent - no double stock decrement"*, against the real database.
- [ ] **4.6 "10 dk ertele" on a second dose.** Arm another dose (a second medication is easiest),
  force-quit again, and press **10 dk ertele**.
  *Expected:*
  ```sh
  sqlite3 "$DB" "select status,
                        datetime(snoozed_until_epoch_ms/1000,'unixepoch') as snoozed_utc,
                        taken_at_epoch_ms
                 from medication_intake_logs order by rowid desc limit 1;"
  ```
  a `PENDING` log row whose `snoozed_until_epoch_ms` is **exactly ten minutes** past the press
  (`SnoozeDoseUseCase.snoozeDuration == 600` seconds), `taken_at_epoch_ms` still `NULL`, and
  **`stock_count` unchanged**.
- [ ] **4.7 It rings again in ten minutes.** Leave the app killed and wait.
  *Expected:* the same dose fires again at the snooze instant, with the **same occurrence key** —
  the handler re-emits it with `snoozed_until` as the trigger, which is why the key must not change.
  The ledger row's `trigger_at_epoch_ms` moved forward by ten minutes:
  ```sh
  sqlite3 "$DB" "select occurrence_key, datetime(trigger_at_epoch_ms/1000,'unixepoch'), state
                 from reminder_alarms where type = 'MEDICATION_DOSE' order by trigger_at_epoch_ms;"
  ```
- [ ] **4.8 "İçtim" after a snooze clears it.** Press **İçtim** on the re-fired dose.
  *Expected:* the log row flips to `TAKEN`, `snoozed_until_epoch_ms` is `NULL`, and stock drops by
  the dose amount — the ported case *"taken after snooze clears the snooze and marks taken"*.
- [ ] **4.9 Tapping the notification body lands on the tab root.** Push once more and tap the banner
  itself rather than an action.
  *Expected:* **no crash**, the app comes to the foreground, the **Medications** tab is selected, and
  the list is on screen — **not** a pushed detail. Decision 3: a dose's `entityId` is a *schedule*
  id, so there is nothing to push, and Android does the same.
- [ ] **4.10 Foreground presentation.** With the app open on any tab, push again.
  *Expected:* the banner still appears with both actions; a dose is time-sensitive, so it is not
  suppressed while the app is in front.

## 5. The device pass — AlarmKit, iOS 26.x

**None of this can be done on a simulator**, and none of it has been run. It needs an unlocked
iPhone on **iOS 26.0 or newer**, installed from Xcode, plus the AlarmKit authorization grant. It
closes the iOS-M3a acceptance clause that has been owed since M3, and it is why the `--ff-only`
merge is held for the user.

Before you start: fresh install, launch, allow notifications, and — on iOS 26 — allow the alarm
prompt (`NSAlarmKitUsageDescription`). Confirm **both** in **More → Hatırlatıcı sağlığı**; the
AlarmKit card is **"Tam ekran ilaç alarmları"**.

- [ ] **5.1 A dose takes over the screen.** Create `Aspirin`, **Tablet**, **Stok adedi** `10`,
  **Her gün**, one dose time **two minutes out**. Force-quit the app and **lock the phone**.
  *Expected at the dose minute:* a **full-screen alarm** over the lock screen with the alarm-stream
  sound, looping until answered — not a banner. The title is **"Aspirin zamanı"**. There is **no
  body text**: `AlarmPresentation.Alert` has a title and no body slot, so `"1 × 100 mg al"` does not
  reach the alarm surface, where Android's `AlarmScreen` shows both (divergence (c)).
- [ ] **5.2 The two buttons.** *Expected:* exactly **two**.
  - **iOS 26.0:** the stop button carries the app's own label, **"Kapat"** (`alarm_dismiss`).
  - **iOS 26.1+:** the stop button is the **system's own** localized one — there is no parameter for
    its copy. Decision 4's *semantics* still hold on both: stop runs `stopIntent`, the engine reads
    it as `ReminderActionIds.dismiss`, and stop is **never** mapped to taken.
  - The secondary button is **"İçtim"** on both — the handler's *first* action.
  - **"10 dk ertele" is absent, and that is correct** (divergence (c), decision 4): an alert has room for one
    secondary button, so snooze survives only on the notification path of §4.
- [ ] **5.3 "İçtim" with the app killed.** Press the secondary button. Do **not** open the app first.
  *Expected:* the alarm stops. Then open the app and check, in this order:
  - the medication's **Son 30 gün** history shows today's dose as **Alındı**;
  - **Kalan** reads **9**, not 10;
  - the ledger row for that occurrence is resolved — no second alarm at the same minute;
  - **the window is refilled** — tomorrow's dose is scheduled, i.e. the sync ran after the action.
  **If the dose is recorded but the window is *not* refilled**, do not call it a lost sync: the
  intent's `perform()` awaits a full window refill inside the AppIntents execution budget, and a
  truncated budget is the first thing to suspect. Recorded at Task 13's review as a deferred finding;
  the fix, if this is what it is, is to make the refill fire-and-forget.
- [ ] **5.4 Stop leaves the dose pending.** Arm a second dose, lock, and press the **stop** button
  (**"Kapat"** on 26.0, the system's on 26.1+).
  *Expected:* the alarm stops **and the dose stays unresolved** — no intake log row for that
  occurrence, `stock_count` unchanged. Silencing an alarm is never a taken dose; an unattended stop
  that forged an intake record is the failure decision 4 exists to prevent.
- [ ] **5.5 An appointment reminder stays a plain notification.** Create an appointment an hour out
  with the **1 saat önce** offset, force-quit, lock.
  *Expected:* it arrives as an ordinary banner with its own sound — **not** a full-screen alarm, and
  it does not take over the lock screen. Spec §6.1: only the handler decides, and only a medication
  dose is `ALARM`.
- [ ] **5.6 The bundled sound.** *Expected:* the alarm plays `salus_alarm.caf`, not the system
  default. `UserNotificationGatewayRoutingTests` pins that the request *names* the file; whether
  AlarmKit's `.named` sound resolves a `.caf` extension is only answerable here. **The asset is still
  the generated placeholder** from `scripts/generate-alarm-sound.sh` (divergence (l)) — a designed
  ≤ 30 s sound is owed before release, so judge the routing, not the music.
- [ ] **5.7 AlarmKit refused degrades, never loses the dose.** Deny the AlarmKit prompt on a fresh
  install, arm a dose, lock.
  *Expected:* it still arrives, as the §4 time-sensitive notification with **İçtim** and **10 dk
  ertele**, with the alarm sound. A refusal must cost the full-screen presentation and nothing else.
- [ ] **5.8 The reminder survives a reboot.** Arm a dose ten minutes out, reboot the phone, and let
  it fire. iOS holds pending requests across a reboot, so there is no `BOOT_COMPLETED` twin to
  port — this is the check that says so out loud.

## 6. The older simulator — the time-sensitive path below iOS 26

The same medication on a runtime with **no AlarmKit** must still wake the user. `@available(iOS 26.0)`
gates the whole alarm surface (the gate was lowered from 26.1 during Task 8 — the 26.1+ stop button
is system-provided, but everything else exists from 26.0), and below it the gateway routes to
`UserNotificationGateway` with `.timeSensitive`.

```sh
xcrun simctl list runtimes | grep iOS          # pick one below 26.0
```

- [ ] **6.1** Boot an **iOS 17.x-25.x** simulator, install, grant notifications, and run §4.1-§4.3
  on it.
  *Expected:* the dose arrives as a **time-sensitive** notification — it breaks through Focus, it
  carries **İçtim** / **10 dk ertele**, and pressing **İçtim** with the app killed writes the
  `TAKEN` row and decrements stock exactly as on iOS 26. Nothing about the *answer* path differs;
  only the presentation does.
- [ ] **6.2** No AlarmKit authorization prompt appears anywhere on this runtime, and **More →
  Hatırlatıcı sağlığı** does not offer the **Tam ekran ilaç alarmları** card as fixable — the
  capability is absent, not broken.
- [ ] **6.3** An appointment on the same runtime is still a plain, non-time-sensitive notification.

## 7. TR / EN and Dynamic Type on the chip rows

The 86 keys exist in both languages and their parity is mechanical (`MedicationsStringsTests`). What
a test cannot see is the layout under the longer string, and the chip rows are the place M4 already
flagged: `ChipFlowLayout` was lifted into `SalusUI` in Task 9 precisely so a chip row wraps instead
of clipping, and the T9 review left a note that it proposes `.unspecified` to its children, so a
single over-wide chip can still overflow.

```sh
# Set the language for one launch:
xcrun simctl launch "$UDID" com.alicansekban.salus -AppleLanguages '(en)'

# Largest non-accessibility size, then the largest accessibility size:
xcrun simctl ui "$UDID" content-size extra-extra-extra-large
xcrun simctl ui "$UDID" content-size accessibility-extra-extra-extra-large
xcrun simctl ui "$UDID" content-size medium        # back to normal when done
```

- [ ] **7.1 English.** *Expected:* **No medications yet** / *"Add a medication to get dose reminders
  and track your intake."*, **Add medication**, **New medication** / **Edit medication**,
  **Schedule** with **Every day** / **Days of week** / **Every N days** / **As needed**, **Dose
  times**, **Stock count**, **Reminders** with *"You get a notification at each dose time."*,
  **Last 30 days**, **Taken** / **Pending** / **Skipped** / **Missed**, and the card's
  **"Recorded doses, last 7 days: 57%"**.
- [ ] **7.2** No key leaks through as its own name (a bare `medications_…` or `editor_…` on screen
  means the catalog lookup missed the bundle).
- [ ] **7.3 The percent sign survives both languages.** The Turkish string puts it **before** the
  number (*"Son 7 gün kaydedilen doz %57"*) and the English one **after** (*"Recorded doses, last 7
  days: 57%"*); both are one literal `%%` in the catalog. A doubled or missing `%` is a format-string
  bug, not a copy choice.
- [ ] **7.4 A third language falls back to Turkish.** Set the device to German.
  *Expected:* the app is **Turkish**, not English — spec §6.4.
- [ ] **7.5 The list card's chip row at XXXL.** Give a medication a low stock **and** turn its
  reminders off, so both warning chips are on the card at once (**"Hatırlatıcılar kapalı"** and
  **"Stok azaldı: 2 kaldı"**), then raise the content size.
  *Expected:* the chips **wrap** onto a second line rather than clipping, each stays at least 44 pt
  tall, and the name and the schedule line above them are still readable. In English the two labels
  are longer still (**"Reminders off"**, **"Low stock: 2 left"**) — check both languages.
  *Known risk at accessibility sizes:* `ChipFlowLayout` proposes `.unspecified` to its children, so a
  chip wider than the row can still overflow. If it does, that is the deferred Task 9 finding
  confirmed — record it, do not fix it here.
- [ ] **7.6 The detail screen's chips.** Same two chips plus the history rows' status chips
  (**Alındı** / **Bekliyor** / **Atlandı** / **Kaçırıldı**) at XXXL.
  *Expected:* readable, wrapped, nothing clipped; the history row's time and dose stay on the row.
- [ ] **7.7 The editor's day-of-week chips.** **Haftanın günleri** draws seven chips
  (**Pzt Sal Çar Per Cum Cmt Paz**).
  *Expected at accessibility sizes:* they wrap across lines and every one stays tappable. This is the
  densest chip row in the app and the most likely place to see the overflow above.
- [ ] **7.8 The editor's date pair.** **Başlangıç** / **Bitiş** use `.labelsHidden()` fields side by
  side (the M4 shape). *Expected:* both stay tappable and their values readable on the narrowest
  device you have; a compressed layout that hides one of the two values is the deferred iOS-M4
  finding, still open.

## 8. Inspection commands

```sh
UDID=<from section 1>
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
DB="$DATA/Library/Application Support/salus.db"

# The three medication tables.
sqlite3 "$DB" 'select id, name, form, strength_value, strength_unit, stock_count, stock_threshold,
                      reminders_enabled, is_active, start_date, end_date from medications;'
sqlite3 "$DB" 'select id, medication_id, recurrence, time_of_day_minutes, dose_amount, interval_days,
                      days_of_week_mask, anchor_date, is_active from medication_schedules;'
sqlite3 "$DB" "select id, schedule_id, medication_id, scheduled_date, scheduled_minutes, status,
                      datetime(taken_at_epoch_ms/1000,'unixepoch') as taken_utc,
                      datetime(snoozed_until_epoch_ms/1000,'unixepoch') as snoozed_utc, dose_amount
               from medication_intake_logs order by scheduled_date, scheduled_minutes;"

# What the engine actually handed to the OS. entity_id is the SCHEDULE id; the occurrence key is
# "<epochDay>|<minuteOfDay>" with a PIPE.
sqlite3 "$DB" "select type, entity_id, occurrence_key, request_code,
                      datetime(trigger_at_epoch_ms/1000,'unixepoch') as trigger_utc, state
               from reminder_alarms order by trigger_at_epoch_ms;"

# Everything joined up, which is what §3 reads.
sqlite3 "$DB" "select m.name, s.recurrence, r.occurrence_key,
                      datetime(r.trigger_at_epoch_ms/1000,'unixepoch') as trigger_utc, r.state
               from reminder_alarms r
               join medication_schedules s on s.id = r.entity_id
               join medications m on m.id = s.medication_id
               where r.type = 'MEDICATION_DOSE' order by r.trigger_at_epoch_ms;"

# The app's own log. --info --debug is required: `log show` hides both levels by default.
xcrun simctl spawn "$UDID" log show --last 10m --info --debug \
    --predicate 'subsystem == "com.alicansekban.salus"' --style compact

# Teardown.
xcrun simctl uninstall "$UDID" com.alicansekban.salus
xcrun simctl shutdown "$UDID"
```

---

## What was executed when this document was written (iOS-M5 Task 14)

**Nothing in it.** Task 14 is documentation and verification only: it ran `scripts/ci.sh` end to end
(24/24 packages, 675 tests, `** BUILD SUCCEEDED **`) and a Release build (green, 0 warnings), and
wrote this script from the code, the strings and the evidence in the task 8, 10, 11, 12 and 13
reports.

What **Task 13** did run on a simulator, and what it explicitly did not, is in
`.superpowers/sdd/2026-08-27-ios-m5-medications/task-13-report.md`: the app launches with the
Medications tab wired, the empty state renders, and a tap on **İlaç ekle** pushes the editor — real
`CGEvent` taps against the Simulator window, not a code-path shortcut. It did **not** run the
notification-action smoke; §4 is written from its own list of the steps that need a person.

**§5 has never been run at all.** It is the iOS-M3a acceptance clause, owed since iOS-M3, and it is
the reason the `--ff-only` merge is held for the user.

## What was executed on a device

*(Not yet. Fill this in after the device pass, the way `scripts/m4-manual-qa.md` records its
2026-08-25 run.)*
