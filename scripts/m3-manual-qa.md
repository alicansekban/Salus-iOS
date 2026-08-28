# iOS-M3 manual QA — the reminder engine on a simulator

The five acceptance criteria of iOS-M3 (*reminders survive force-quit, timezone change, DST
boundary, notification-permission revocation, and a 5-day cold period*) are covered by automated
tests — the execution record in `docs/plans/2026-08-23-ios-m3-reminder-engine.md` maps each one to
the test that proves it. What tests cannot prove is that the OS actually holds and delivers the
requests the engine hands it. This document is that half: a walkthrough anybody can run from a
terminal plus a handful of taps, without inventing the steps again each time.

Run it before merging a change to `SalusReminder`, `App/AppCompositionRoot.swift` or the
notification/background entries in `project.yml`.

**Section 9 is different**: it is the M3a on-device checklist, which a simulator cannot run at all.
It is owed before iOS-M5 ships the medication handler, and it needs a human with an unlocked iPhone.

---

## 0. What drives it: the debug handler

No feature owns a reminder yet — the medication, appointment and cycle handlers arrive with
iOS-M4/M5/M6 — so `ReminderHandlerRegistry` is empty in a shipping build and the engine reconciles
an empty window. `App/DebugReminderHandler.swift` fills the gap with one fake `MEDICATION_DOSE`
occurrence:

| Launch argument | Meaning |
| --- | --- |
| `-SalusDebugReminderLeadMinutes <n>` | Arms one occurrence `n` minutes after launch. Absent or `≤ 0` ⇒ the handler is not installed at all. |
| `-SalusDebugReminderPresentation NOTIFICATION\|ALARM` | The `ReminderPresentation` the handler bakes. Absent ⇒ `ALARM`, which is what a real dose is. Use `NOTIFICATION` for the delivery steps below, so AlarmKit's authorization is not in the way. |

Two properties to know before reading the steps:

- **It is `#if DEBUG`.** The file and its call site are both compiled out of a Release build, so
  nothing here can reach a shipped app. `-key value` launch arguments land in `UserDefaults`'
  argument domain, which is volatile — no key is written to the app's defaults plist.
- **The occurrence is anchored per launch.** Each launch arms a fresh trigger instant, and the
  occurrence the *previous* launch armed is withdrawn by the next pass (the handler answers `nil`
  content for it). That withdrawal is itself engine behaviour worth watching in the ledger.

---

## 1. Build and install

```sh
cd salus-ios
./scripts/build-app.sh                       # or: xcodebuild -project Salus.xcodeproj -scheme Salus \
                                             #     -destination 'generic/platform=iOS Simulator' build

# Any iPhone simulator does for sections 2-8; pick one deliberately with
# `xcrun simctl list devices available` if you care which iOS it runs.
UDID=$(xcrun simctl list devices available | sed -n 's/.*iPhone 17 Pro (\([-0-9A-F]*\)).*/\1/p' | head -1)
APP="$(xcodebuild -project Salus.xcodeproj -scheme Salus \
        -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2; exit}')/Salus.app"

xcrun simctl boot "$UDID"; open -a Simulator
xcrun simctl install "$UDID" "$APP"

# Debug-level messages are off by default on a simulator. Without this, section 9's log
# commands show the info lines but not the `debug` ones.
xcrun simctl spawn "$UDID" log config --mode "level:debug" --subsystem com.alicansekban.salus
```

## 2. Grant notification permission

Salus never asks at launch — the prompt belongs to the screen that offers the fix button.

1. `xcrun simctl launch "$UDID" com.alicansekban.salus`
2. Tap the **More** tab (5th), then **Hatırlatıcı sağlığı**.
3. The **Bildirimler** card reads *"Bildirimler kapalı — hatırlatıcılar gösterilemez."* Tap
   **Düzelt**.
4. iOS shows its permission alert. Allow it.
5. The card flips to *"Bildirimler açık."* and, once the other two rows are healthy, the header
   reads *"Her şey yolunda görünüyor — hatırlatıcılar zamanında gelecektir."*

> The **Arka plan yenilemesi** row reports `UIApplication.backgroundRefreshStatus`. It is normally
> healthy on a fresh simulator; section 6 is where it is deliberately made unhealthy.

## 3. Force-quit — the reminder survives the process

This is the acceptance criterion *"reminders survive force-quit"* seen from outside: nothing of ours
runs at fire time, so delivery proves the OS is holding the request.

1. Arm a dose three minutes out:

   ```sh
   xcrun simctl terminate "$UDID" com.alicansekban.salus 2>/dev/null || true
   xcrun simctl launch "$UDID" com.alicansekban.salus \
       --args -SalusDebugReminderLeadMinutes 3 -SalusDebugReminderPresentation NOTIFICATION
   ```

2. Confirm the pass ran and the ledger row exists (see section 10 for what the columns mean):

   ```sh
   DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)
   sqlite3 "$DATA/Library/Application Support/salus.db" \
       'select entity_id, occurrence_key, request_code, state from reminder_alarms;'
   ```

   Expected: one `debug-medication | <epoch seconds> | <request code> | SCHEDULED`. The pass is
   asynchronous — if the table is empty, wait a second and read it again.

3. **Force-quit for real**: in the Simulator, swipe up from the bottom edge to open the app
   switcher, then flick the Salus card away. (`xcrun simctl terminate` also kills the process and is
   fine as a shortcut, but the swipe is the gesture users actually perform and the one the criterion
   names.)

4. Wait out the three minutes with Salus **not** running. A banner appears: **"Salus debug dose"**.

   ✅ The reminder was delivered by a process that no longer existed when it was scheduled.

5. Long-press (click and hold) the banner to reveal **Taken** / **Snooze**, and tap **Taken**. iOS
   relaunches Salus in the background to run the action. Check that the handler got it and that the
   window was refilled afterwards:

   ```sh
   xcrun simctl spawn "$UDID" log show --last 2m --info --debug \
       --predicate 'subsystem == "com.alicansekban.salus"' --style compact
   ```

   Expected: `[com.alicansekban.salus:debug] debug reminder action TAKEN on <occurrence key>`.

## 4. Timezone change — the window is reconciled

1. With Salus running (foreground or backgrounded, not force-quit), open the **Settings** app in the
   simulator → **General** → **Date & Time** → turn **Set Automatically** off → **Time Zone** →
   pick a zone far away (e.g. *Auckland*).
2. Return to Salus.
3. Read the last-pass stamp:

   ```sh
   plutil -p "$DATA/Library/Preferences/com.alicansekban.salus.plist" | grep reminder_last_sync
   ```

   Expected: `reminder_last_sync_epoch_ms` has advanced past the value it held in section 3.

   ✅ `NSSystemTimeZoneDidChange` (or the return to `.active`) drove a reconcile.

4. In **Hatırlatıcı sağlığı**, *"Son hatırlatıcı taraması: …"* now renders in the new zone.
5. Relaunch with the arm arguments and re-read the ledger: the previous occurrence is gone and a new
   row stands in its place, which is the withdraw-and-rematerialize path.

> The host Mac's timezone works too (`sudo systemsetup -settimezone Pacific/Auckland`) and the
> simulator follows it, but it needs `sudo` and it moves the machine you are working on. Prefer the
> in-simulator route.

## 5. Notification permission revoked — the red card and its fix

This is the acceptance criterion *"reminders survive notification-permission revocation"*: the
engine must not lose the ledger, and the user must be told plainly.

1. Simulator **Settings** → **Salus** → **Notifications** → turn **Allow Notifications** off.
2. Open Salus → **More** → **Hatırlatıcı sağlığı**.

   ✅ The **Bildirimler** card is in its problem state — *"Bildirimler kapalı — hatırlatıcılar
   gösterilemez."* — and the header no longer says everything looks good.

3. Tap **Düzelt**. Because iOS grants exactly one prompt per install, the second tap does not
   re-prompt: it opens **Settings → Salus → Notifications** directly.

   ✅ The fix deep link lands on the Salus notification page, not on the Settings root.

4. Turn notifications back on, return to Salus, and confirm the card goes healthy without a
   relaunch (the screen re-checks on foreground).
5. Optional, to see the `MISSED` half: revoke notifications, arm a dose one minute out, let the
   minute pass with the app closed, then relaunch and re-read the ledger. The past-due row is
   `MISSED` rather than `FIRED` — the engine will not claim a delivery the OS could not have made.

## 6. Background App Refresh disabled

1. Simulator **Settings** → **General** → **Background App Refresh** → off (globally or for Salus).
2. Open Salus → **Hatırlatıcı sağlığı**.

   ✅ **Arka plan yenilemesi** reads *"Arka plan yenilemesi kapalı — hatırlatıcı listesi yalnızca
   uygulamayı açtığınızda tazelenir."*, and **Düzelt** opens the Salus page in Settings.

3. Turn it back on.

## 7. Cold period — five days with no pass (optional)

The automated twin is `a cold period of five days is refilled by one sync`. The manual version costs
a simulator whose clock is wrong afterwards, so run it last, or on a simulator you are willing to
erase.

1. Arm an occurrence and note the ledger row (section 3, steps 1-2).
2. Force-quit Salus. Simulator **Settings** → **General** → **Date & Time** → **Set Automatically**
   off → set the date **five days forward**.
3. Launch Salus and read the ledger again.

   ✅ The old row is no longer `SCHEDULED` — it is past due, so it was marked and pruned — and one
   pass has materialized the window afresh from the newly armed occurrence. `reminder_last_sync_epoch_ms`
   holds the new date.

4. Set **Set Automatically** back on, then `xcrun simctl shutdown` and `erase` the device if
   anything looks odd afterwards.

## 8. Background refresh task — what a simulator can and cannot do

`BGTaskScheduler` **submission is unavailable in the simulator**. Measured in iOS-M3 Task 7:
`_unsafe_submitTaskRequest:` answers `BGTaskSchedulerErrorDomain` code `1`
(`BGTaskSchedulerErrorCodeUnavailable`), so no request is ever pending and
`_simulateLaunchForTaskWithIdentifier:` has nothing to launch — it logs *"No task request with
identifier com.alicansekban.salus.reminder.refresh has been scheduled"*. That refusal is expected
and is logged by the app itself at `debug` level:

```
[com.alicansekban.salus:reminder] background refresh request refused:
    Error Domain=BGTaskSchedulerErrorDomain Code=1
```

What the simulator **does** prove is that registration reached the framework and the post-pass
re-arm asked for the right window (`earliestBeginDate` exactly 12 h out), both visible in:

```sh
xcrun simctl spawn "$UDID" log show --last 5m --info --debug \
    --predicate 'subsystem == "com.apple.BackgroundTasks"' --style compact
```

The launch/expiration simulations are debugger commands, and they belong to section 9 because they
only do anything on a device. Run the app from Xcode, pause, and in the console evaluate:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.alicansekban.salus.reminder.refresh"]
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.alicansekban.salus.reminder.refresh"]
```

Expected after the first: `reminder_last_sync_epoch_ms` advances. Expected after the second: the
pass reports exactly once and the app is not terminated for overrunning. The behaviour underneath
both is executed off device by `BackgroundRefreshTaskBodyTests`; these commands are what confirm the
OS drives it.

## 9. M3a — the on-device checklist

None of this can be done on a simulator. It is owed before iOS-M5 ships the medication handler.
Needs an unlocked iPhone on iOS 26.0 or newer, run from Xcode. (The gate was 26.1 when iOS-M3
shipped; iOS-M5 Task 8 lowered it to 26.0 — see that plan's divergence list.)

- [ ] **AlarmKit authorization prompt.** Reminder Health → **Tam ekran ilaç alarmları** → **Düzelt**
      shows the system prompt, and the sentence in it is `NSAlarmKitUsageDescription` — Turkish on a
      Turkish device, English on an English one (`App/tr.lproj/`, `App/en.lproj/InfoPlist.strings`).
- [ ] **A real AlarmKit schedule.** Launch with `-SalusDebugReminderLeadMinutes 3` and no
      presentation override (so it bakes `ALARM`), lock the phone, and confirm the dose takes over
      the lock screen rather than arriving as a banner.
- [ ] **A real AlarmKit cancel.** Relaunch (which withdraws the previous occurrence) and confirm the
      alarm does not fire. The gateway must route the cancel to the backend that scheduled it.
- [ ] **The `.caf` sound on the AlarmKit path.** `UserNotificationGatewayRoutingTests` pins that the
      request names `salus_alarm.caf`, but whether AlarmKit's `.named` sound resolves a `.caf`
      extension is not verifiable off device. Confirm the alarm plays the bundled sound, not the
      system default. *(The asset itself is still the generated placeholder from
      `scripts/generate-alarm-sound.sh` — a designed ≤30 s sound is owed before release.)*
- [ ] **AlarmKit refused.** Deny the AlarmKit prompt, arm a dose, and confirm it still arrives as a
      time-sensitive notification with the alarm sound. A refusal must degrade, never lose the dose.
- [ ] **OS-driven background launch and expiration.** The two debugger commands in section 8, on a
      device where `BGTaskScheduler.submit` actually succeeds.
- [ ] **The reminder survives a reboot.** Arm a dose ten minutes out, reboot the phone, and let it
      fire. No iOS twin of `BOOT_COMPLETED` exists because iOS holds pending requests across a
      reboot — this is the check that says so out loud.

## 10. Inspection commands

```sh
UDID=<from section 1>
DATA=$(xcrun simctl get_app_container "$UDID" com.alicansekban.salus data)

# The app's own log. --info --debug is required: `log show` hides both levels by default, which is
# what made an earlier smoke run look like the app logged nothing at all.
xcrun simctl spawn "$UDID" log show --last 10m --info --debug \
    --predicate 'subsystem == "com.alicansekban.salus"' --style compact
# Live instead of after the fact:
xcrun simctl spawn "$UDID" log stream --level debug \
    --predicate 'subsystem == "com.alicansekban.salus"'

# The alarm ledger. `state` is SCHEDULED / FIRED / MISSED / CANCELLED; `request_code` is the Kotlin
# string hash of the occurrence identity and is also the notification request's identifier.
sqlite3 "$DATA/Library/Application Support/salus.db" \
    'select entity_id, occurrence_key, request_code, trigger_at_epoch_ms, state from reminder_alarms;'

# When the last pass completed (iOS-local key, not one of the thirteen Android settings keys).
plutil -p "$DATA/Library/Preferences/com.alicansekban.salus.plist" | grep reminder_last_sync

# Teardown.
xcrun simctl uninstall "$UDID" com.alicansekban.salus
xcrun simctl shutdown "$UDID"
```

The three categories under the `com.alicansekban.salus` subsystem are `boot` (database and launch
diagnostics), `reminder` (the engine and the background scheduler) and `debug` (the handler in
section 0). Nothing health-related is ever written to any of them — spec §12.

## What was executed when this document was written (iOS-M3 Task 9)

Run on iPhone 17 Pro / iOS 26.4, Debug build: sections 1, 3 step 2, 8's log evidence, and 10. The
engine walked end to end from the launch argument to the ledger — `debug-medication | 1787578507 |
-919929169 | SCHEDULED`, with `reminder_last_sync_epoch_ms` stamped and
`[com.alicansekban.salus:debug] debug reminder armed …` in the log.

Everything that needs a tap or a wait — the banner itself, the action tap, the Settings toggles, the
Reminder Health cards — is written from the code and the strings that produce it and has **not**
been observed. Section 9 has not been run at all.

## What was executed on a device (2026-08-25, after iOS-M4)

Run by Alican on his **iPhone 14 Pro Max** (iOS 26, AlarmKit available), Debug build from Xcode with
`-SalusDebugReminderLeadMinutes 1` / `2` in the scheme's launch arguments. Section 9, items 1-5:

- [x] **1. AlarmKit authorization prompt** — granted from Reminder Health.
- [x] **2. A real AlarmKit schedule** — `debug reminder armed for … as ALARM` in the console; the dose
      took over the lock screen one minute after launch.
- [x] **3. A real AlarmKit cancel** — a second launch inside the lead time withdrew the first
      occurrence; only the re-armed one fired.
- [x] **4. The `.caf` sound on the AlarmKit path** — the bundled placeholder pattern played, not the
      system default.
- [x] **5. AlarmKit refused** — with the permission switched off in Settings the dose arrived as a
      time-sensitive notification with the alarm sound.
- [x] **6. OS-driven background launch and expiration** — `_simulateLaunchForTaskWithIdentifier:`
      advanced the last-sync stamp. A pass completes in well under a second, so a separate
      expiration simulation answers *"not currently being simulated"*; issuing launch and expiration
      in one lldb expression ran without error and without terminating the app. (The expiration
      handler itself is pinned off device by `BackgroundRefreshTaskBodyTests`.)
- [x] **7. The reminder survives a reboot** — armed ten minutes out with
      `-SalusDebugReminderLeadMinutes 10`, Xcode stopped, phone rebooted and unlocked once; the alarm
      fired on time.

**Section 9 is complete (7/7).** The M3a prerequisite for iOS-M5 is closed; the designed alarm sound
(`salus_alarm.caf` is still the generated placeholder) remains owed before release.

