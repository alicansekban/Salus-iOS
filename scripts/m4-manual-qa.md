# iOS-M4 manual QA — appointments on a simulator

iOS-M4's acceptance is *CRUD, multiple reminder offsets, EventKit "add to calendar"*. The automated
half is mapped criterion-by-criterion in the execution record of
`docs/plans/2026-08-24-ios-m4-appointments.md`. This document is the other half: everything that
needs a tap, a system sheet or the OS's own notification store, written down so nobody has to
invent the steps again.

Run it before merging a change to `Packages/Features/FeatureAppointments`,
`Packages/SalusUI/Sources/SalusUI/component/`, or the Appointments wiring in
`App/AppCompositionRoot.swift`.

Every step has an expected result and a checkbox. A step that cannot be run from a terminal says so
in its own words rather than being quietly skipped — sections 4 and 5 are the two that need a real
finger on the screen.

**Language.** The app has no language switch of its own; it follows the device (§6.4 — Turkish is
the default *and* the fallback). Sections 1-9 are written with the Turkish strings because that is
what a default simulator shows; section 10 switches the device to English and re-checks.

---

## 1. Build and install

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

- [ ] **1.1** The app launches and the tab bar has five tabs. The 4th is **Appointments** with a
  calendar glyph. (The label is English on purpose: `nav_appointments` is an M8 hub string, so
  `RootTab.title` still returns the placeholder.)
- [ ] **1.2** Opening the tab shows the empty state — *"Henüz randevu yok. İlk randevunu ekle."* —
  and a **+** FAB at the bottom right.
- [ ] **1.3** Grant notification permission now, or section 3 has nothing to inspect and section 4
  cannot be delivered: **More** (5th tab) → **Hatırlatıcı sağlığı** → **Düzelt** on the
  *Bildirimler* card → Allow. The card flips to *"Bildirimler açık."*

Two shell helpers the later sections use:

```sh
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
DB="$DATA/Library/Application Support/salus.db"
```

## 2. CRUD round trip

The acceptance criterion *CRUD*, seen from the outside. Every step is also checked in the database,
because a row that renders is not yet a row that was written.

- [ ] **2.1 Create.** FAB → the editor titled **Yeni randevu**. Fill **Başlık** = `Kardiyoloji`,
  tap **Tarih seç** and pick *tomorrow*, tap **Saat seç** and pick `09:00`, **Doktor veya klinik** =
  `Dr. Ada`, **Konum** = `Merkez Poliklinik`, **Notlar** = `tansiyon defterini götür`. Tap
  **Kaydet**.
  *Expected:* the editor pops, the list shows a **Yarın** day header with one row.
- [ ] **2.2** The row was written:
  ```sh
  sqlite3 "$DB" 'select id, title, starts_at_local, tz_id, status, duration_minutes from appointments;'
  ```
  *Expected:* one row, `starts_at_local` is `<tomorrow>T09:00` — **no offset and no seconds**, the
  Kotlin `LocalDateTime.toString()` shape — `tz_id` is the device zone, `status = SCHEDULED`.
- [ ] **2.3 Read.** Tap the row.
  *Expected:* **Randevu detayı** with the title, *Saat 09:00 · 60 dakika* (the editor cannot set a
  duration; `Appointment.defaultDurationMinutes` is 60), **Konum** with
  *Haritalarda aç* under it, **Notlar** with the note, and — if the profile has health notes —
  **Doktora söylenecekler**. Toolbar carries **Düzenle** and **Sil**.
- [ ] **2.4 Update.** **Düzenle** → the editor opens as **Randevuyu düzenle** with *every* field
  preloaded, including the reminder chips. Change the title to `Kardiyoloji kontrol`, **Kaydet**.
  *Expected:* the detail screen shows the new title; `select title from appointments;` agrees; the
  row count is still 1 (an update, not an insert).
- [ ] **2.5 Delete.** **Sil** → the confirm dialog *"Kardiyoloji kontrol silinsin mi?"* /
  *"Randevu ve hatırlatıcıları birlikte silinir."* Tap **Sil**.
  *Expected:* the detail screen pops, and the list shows a snackbar *"Randevu silindi"* with a
  **Geri al** action. Let it expire (section 6 is the timing check).
  ```sh
  sqlite3 "$DB" 'select count(*) from appointments; select count(*) from appointment_reminders;'
  ```
  *Expected:* `0` and `0` — the reminder rows cascade with the appointment.
- [ ] **2.5b Delete from a list row.** Create another appointment (**2.1** again, any title), then
  tap the **trash icon** on its row in the list — not the row itself.
  *Expected:* the row does **not** open the detail screen (the two targets are disjoint by layout,
  which is the whole point of the shape), and the same confirm dialog appears,
  *"<title> silinsin mi?"* / *"Randevu ve hatırlatıcıları birlikte silinir."*
  Tap **Vazgeç**: the dialog closes, the row is still there, and
  `select count(*) from appointments;` is unchanged. Tap the trash again and confirm with **Sil**:
  the row disappears **at once**, the list stays put (nothing pops — the list is already where the
  user is), and the *"Randevu silindi"* snackbar offers **Geri al**. Tap **Geri al** within five
  seconds; the row comes back and the count never moved. Then delete it once more and let the
  window expire — the count drops by one.
  With VoiceOver on, the row announces as a button ("open") and the trash button announces
  separately as **Sil**.
- [ ] **2.6 Past section.** Create one appointment in the past (any date before today) and one
  tomorrow. *Expected:* the past one is **not** in the upcoming list; a **Geçmiş (1)** header
  appears with a **Göster** button; tapping it expands the section and the button becomes **Gizle**.

## 3. Three offsets → pending requests

The acceptance criterion *multiple reminder offsets*. The presets are exactly
`[60, 1440, 10080]` minutes — *1 saat önce*, *1 gün önce*, *1 hafta önce* — multi-select, no custom
value.

**Nothing outside the app can enumerate `UNUserNotificationCenter`'s pending requests.** `simctl`
has no command for it and the simulator writes nothing readable to disk. What *is* observable is
the engine's own ledger, `reminder_alarms`: its rows are written **after**
`UserNotificationGateway.schedule` returns, and that call throws if `UNUserNotificationCenter.add`
fails — so a `SCHEDULED` row is proof that the notification centre accepted the request.

```sh
sqlite3 "$DB" "select occurrence_key, datetime(trigger_at_epoch_ms/1000,'unixepoch') as trigger_utc, state
               from reminder_alarms order by trigger_at_epoch_ms;"
```

- [ ] **3.1 A near appointment.** Create one **2 hours from now** with all three chips selected.
  *Expected:* `appointment_reminders` holds **three** rows with **colon** ids — `<id>:60`,
  `<id>:1440`, `<id>:10080` — and `reminder_alarms` holds exactly **one**, `<id>|60`, with a
  **pipe**. The other two are correct to be missing: their triggers (24 hours and 7 days *before* a
  start that is 2 hours away) are in the past, i.e. before the sync window's `from`. The two
  separators are not a typo — the storage id uses `:`, the reminder occurrence key uses `|`.
  ```sh
  sqlite3 "$DB" 'select id, offset_minutes, enabled from appointment_reminders order by offset_minutes;'
  ```
- [ ] **3.2 All three at once.** Edit that appointment so it starts in the narrow band
  `[now + 7 days, now + 7 days + 1 hour)` — e.g. today's clock time, seven days out — and save.
  *Expected:* three `SCHEDULED` rows, `<id>|10080` / `<id>|1440` / `<id>|60`, triggering at T−7d,
  T−1d and T−1h. That band is the only one in which all three land inside the 7-day window (spec
  §6.1), which is why this step exists as a separate one.
- [ ] **3.3 Deselecting an offset withdraws it.** Edit again, deselect **1 hafta önce**, save.
  *Expected:* `appointment_reminders` is down to two rows, and the `<id>|10080` alarm row is
  `CANCELLED` rather than deleted.
- [ ] **3.4 Deleting the appointment cancels every offset.** Delete it and let the undo window
  expire. *Expected:* no `appointments` / `appointment_reminders` rows, and every `reminder_alarms`
  row for that id is `CANCELLED`.

## 4. Notification banner → the detail screen

Decision (2): a tapped appointment notification switches to the Appointments tab and pushes
`AppointmentDetailKey(id)`. Android opens the launcher, so this is iOS-only.

**This is the one criterion that cannot be automated.** `xcrun simctl` has no tap primitive, and
the delivery below is only half the test — the tap is the half that used to crash (a pre-existing
iOS-M3 bug, fixed in Task 10b).

Take a real appointment id and title out of the database, then push a payload carrying the exact
`userInfo` keys the gateway writes (`ReminderUserInfo.swift`). The delegate's `didReceive` path is
identical for a remote and a local request, so this exercises the router without waiting an hour:

```sh
sqlite3 "$DB" 'select id, title, starts_at_local from appointments;'   # take an id

cat > /tmp/salus-m4-payload.apns <<'JSON'
{
  "Simulator Target Bundle": "com.alicansekban.salus",
  "aps": { "alert": { "title": "Randevu", "body": "Kardiyoloji — yarin 09:00" },
           "sound": "default", "category": "salus.reminder.APPOINTMENT" },
  "salus.extra.REMINDER_TYPE": "APPOINTMENT",
  "salus.extra.REMINDER_ENTITY_ID": "<PASTE THE ID>",
  "salus.extra.REMINDER_OCCURRENCE_KEY": "<PASTE THE ID>|60"
}
JSON

xcrun simctl spawn "$UDID" log stream --predicate 'process == "Salus"' &   # optional watch
xcrun simctl push "$UDID" com.alicansekban.salus /tmp/salus-m4-payload.apns
```

- [ ] **4.1** The banner appears. (Authorization must have been granted in 1.3; the payload is
  silently dropped otherwise.)
- [ ] **4.2 Tap the banner.** If it has already gone, swipe down from the top edge and tap it in
  Notification Center.
  *Expected:* **no crash**, the app stays in the foreground, the **Appointments** tab is selected,
  and the **detail screen for that appointment** is pushed on top of it.
  *Fail looks like:* `NSInternalInconsistencyException: 'Call must be made on main thread'` in the
  log and a fresh `~/Library/Logs/DiagnosticReports/Salus-*.ips`. Count the reports before and
  after if you want the check to be mechanical:
  ```sh
  ls ~/Library/Logs/DiagnosticReports/Salus-*.ips 2>/dev/null | wc -l
  ```
- [ ] **4.3 Foreground presentation.** With the app open on any tab, push again.
  *Expected:* the banner still appears (an appointment reminder is a **standard notification** —
  spec §6.1 — so the delegate's `willPresent` answers banner + sound + list, and nothing is
  suppressed).

## 5. Add to calendar — the EventKitUI sheet

Decision (1): "Takvime ekle" is a prefilled `EKEventEditViewController` the user confirms. It
replaces Android's `ACTION_INSERT` intent, and the sheet brings its own calendar chooser.

**What this step is really checking is the absence of a prompt.** The app declares no calendar
usage description and asks for no authorization; on iOS 17+ the system sheet is a separate process
that writes on the user's behalf. If a permission alert appears, that assumption has broken and the
finding belongs in the record.

- [ ] **5.1 From the detail screen.** Open an appointment → **Takvime ekle**.
  *Expected:* the system event editor slides up, **prefilled** with the title, the start, the
  duration-derived end and the location. **No permission alert.**
- [ ] **5.2** The body is the appointment's **notes alone** (divergence (d): the detail screen
  sends `notes`, the editor sends `doctor + "\n" + notes` — ported verbatim from Kotlin, and an
  Android follow-up to unify).
- [ ] **5.3 Cancel is harmless.** Tap **Cancel**. *Expected:* the sheet dismisses, nothing is
  written, the detail screen is unchanged.
- [ ] **5.4 Save lands in Calendar.** **Takvime ekle** again → **Add**. Open the built-in
  **Calendar** app on the simulator and go to the appointment's day.
  *Expected:* the event is there with the title, time and location.
- [ ] **5.5 From the editor.** Open an appointment for editing, change the doctor and the notes
  *without saving*, then **Takvime ekle**.
  *Expected:* the sheet is prefilled from the **edited** text, and the body is
  `doctor` + newline + `notes`.

## 6. The undo window

Divergence (b): the delete snackbar dies with the undo window — its duration is
`PendingDeleteController.undoWindowMillis` (**5000 ms**) rather than Material's default, so the
offer never outlives the thing it offers. Android still has the mismatch (follow-up A10).

**Where deletes start.** An appointment is deleted from the **detail screen**, from the **editor**,
or from a **list row's trash icon** (divergence (p), closed by Task 12 — §2.5b walks the row path).
The checks below begin on the detail screen because that is the path with a screen pop in it.

- [ ] **6.1 Undo inside the window.** Open an appointment → **Sil** → confirm → tap **Geri al**
  within five seconds.
  *Expected:* the detail screen pops **first**, the snackbar is raised on the list behind it, the
  row reappears in the list, and **nothing was written** — the row was only ever hidden.
  `select count(*) from appointments;` is unchanged from before the delete.
- [ ] **6.2 Let it expire.** Delete again and wait without touching anything.
  *Expected:* the snackbar disappears at about five seconds — not before, and not only on the next
  tap — and the row is gone from the database at that moment, together with its
  `appointment_reminders` rows.
- [ ] **6.3 Delete from the editor.** Open an appointment for editing and use the toolbar's **Sil**.
  *Expected:* the same confirm dialog, the same deferred write, the same snackbar; the editor closes
  rather than saving anything.

## 7. The maps link

Divergence (a): **Haritalarda aç** is shown whenever `location` is non-blank. Android asks the
package manager whether anything answers `geo:`; iOS has no equivalent question a sandboxed app may
ask, and Maps is not removable, so the row is unconditional.

The encoding is the part worth testing by hand, because `.urlQueryAllowed` — the obvious choice —
is wrong: it leaves `& + = ? ; / ,` alone, so the query value ends early.

- [ ] **7.1** Create an appointment with **Konum** = `Smith & Sons A+ Poliklinik, Kat 3`.
- [ ] **7.2** Open its detail and tap **Haritalarda aç**.
  *Expected:* Apple Maps opens and searches for the **whole** string — the `&` did not truncate it
  and the `+` did not become a space. Anything less means `CharacterSet.salusUriEncodeAllowed` has
  been widened.
- [ ] **7.3** An appointment with a blank location shows **no** *Haritalarda aç* row at all.

## 8. Dynamic Type

Two spots were flagged during review and are unverified: the reminder chip row is an `HStack` with
no wrap, and the editor's date/time pair uses `.labelsHidden()` pickers side by side.

```sh
# Largest non-accessibility size, then the largest accessibility size:
xcrun simctl ui "$UDID" content-size extra-extra-extra-large
xcrun simctl ui "$UDID" content-size accessibility-extra-extra-extra-large
xcrun simctl ui "$UDID" content-size medium        # back to normal when done
```

- [ ] **8.1 The chip row** (editor, **Hatırlatıcılar**). *Expected at XXXL:* all three chips
  readable, none clipped, each still at least 48 pt tall.
  *Known risk at accessibility sizes:* the row does not wrap, so the third chip can be cut off. If
  it is, that is the deferred T9 finding confirmed — record it, do not fix it here.
- [ ] **8.2 The date/time pair** (editor, **Tarih seç** / **Saat seç**). *Expected:* both fields
  remain tappable and their values readable on the narrowest device you have; a compressed layout
  that hides one of the two values is the deferred T9 finding.
- [ ] **8.3 The list rows and the day headers** stay legible; a long title truncates rather than
  pushing the time off the row.

## 9. Inspection commands

```sh
UDID=<from section 1>
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
DB="$DATA/Library/Application Support/salus.db"

# Appointments and their reminder rows (storage ids use a COLON).
sqlite3 "$DB" 'select id, title, starts_at_local, tz_id, status, duration_minutes from appointments;'
sqlite3 "$DB" 'select id, appointment_id, offset_minutes, enabled from appointment_reminders order by offset_minutes;'

# What the engine actually handed to the OS (occurrence keys use a PIPE).
sqlite3 "$DB" "select entity_id, occurrence_key, request_code,
                      datetime(trigger_at_epoch_ms/1000,'unixepoch') as trigger_utc, state
               from reminder_alarms order by trigger_at_epoch_ms;"

# The app's own log. --info --debug is required: `log show` hides both levels by default.
xcrun simctl spawn "$UDID" log show --last 10m --info --debug \
    --predicate 'subsystem == "com.alicansekban.salus"' --style compact

# Teardown.
xcrun simctl uninstall "$UDID" com.alicansekban.salus
xcrun simctl shutdown "$UDID"
```

## 10. TR / EN

The 46 keys exist in both languages and their parity is mechanical (`AppointmentsStringsTests`).
What a test cannot see is the layout under the longer string and the date formatting, which follows
`Locale.current`.

```sh
# Simulator → Settings → General → Language & Region → iPhone Language → English,
# or set the language for one launch:
xcrun simctl launch "$UDID" com.alicansekban.salus -AppleLanguages '(en)'
```

- [ ] **10.1** In English: *No appointments yet. Add your first appointment.*, **Add appointment**,
  **New appointment**, **Reminders**, **1 hour before** / **1 day before** / **1 week before**,
  **Add to calendar**, **Open in maps**, **Past (1)** / **Show** / **Hide**, **Today** /
  **Tomorrow**, *At 09:00 · 60 minutes*.
- [ ] **10.2** No key leaks through as its own name (a bare `appointments_…` on screen means the
  catalog lookup missed the bundle).
- [ ] **10.3** Back in Turkish, check the status chip. **No screen can set a status** — Android has
  no status editing either, and a row only ever changes status by migration or restore — so write
  one directly and relaunch:
  ```sh
  sqlite3 "$DB" "update appointments set status = 'CANCELLED' where title = 'Kardiyoloji';"
  xcrun simctl terminate "$UDID" com.alicansekban.salus
  xcrun simctl launch "$UDID" com.alicansekban.salus
  ```
  *Expected:* the row moves to the **Geçmiş** section, and opening its **detail** shows an
  **İptal edildi** chip under the header (`COMPLETED` gives **Tamamlandı**). *Planlı*
  (`appointment_status_scheduled`) is never rendered — the chip is drawn only when
  `status != .scheduled` — which is why divergence (f) could reword it.
- [ ] **10.4** Set the device to a **third** language (say German). *Expected:* the app is
  **Turkish**, not English — §6.4, Turkish is the fallback as well as the default.

---

## What was executed when this document was written (iOS-M4 Task 11)

**Nothing in it.** Task 11 is documentation and verification only: it ran `scripts/ci.sh` end to
end and a Release build, both green, and wrote this script from the code, the strings and the
evidence in the task 8, 10 and 10b reports.

Sections 2, 3, 5 and 6 were executed *by task 10* on a simulator during implementation, with the
results in its report (`.superpowers/sdd/2026-08-24-ios-m4-appointments/task-10-report.md`): the
CRUD round trip, the undo window in both directions, and the `|60` / `|1440` / `|10080` occurrence
keys including the seven-day band of step 3.2. Section 5's *no permission prompt* was measured in
task 8 with a probe app. Section 4's push was executed in task 10b; **section 4.2 — the tap — has
never been run**, because the build host has no Accessibility trust and `simctl` has no tap
primitive. It is the one open item of iOS-M4's done criterion.

## What was executed on a device (2026-08-25)

Run by Alican on his iPhone 14 Pro Max (iOS 26) right after the merge: the appointment CRUD round
trip, the reminder banner, **§4.2 — tapping the banner landed on the appointment's detail screen**,
add-to-calendar, and undo were all confirmed working. The Dynamic Type checks in §8 were not run.

