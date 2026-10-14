# M17 smoking cessation — manual QA (iOS)

Spec: `docs/superpowers/specs/2026-10-14-ios-m17-smoking-design.md` (the delta over the Android twin's
`2026-09-20-smoking-cessation-design.md`). Plan: `docs/superpowers/plans/2026-10-14-ios-m17-smoking.md`.
Contracts (Android repo, branch `feature/m17-smoking-cessation`): `docs/contracts/smoking-domain-contract.md`
(§8 holds every execution ruling) and `docs/contracts/smoking-health-stages.md`. Branch: `m17-smoking`.
Version under test: **1.1.0 (build 6)**, database migration `v5`. Parity: `docs/parity-ledger.md` § M17 in
the Android repo (rows D-M17-a … ae; the iOS-only rows are folded in §16 below).

Agents never drive a simulator or a device: every step below is for the owner, and nothing in this sheet
has been run on either. Previews were compiled, not looked at.

## What the automated gates already cover

`scripts/dev/gates.sh all` (= `scripts/ci.sh`: toolchain, lint, custom-rule fixtures, `swift test` in every
package, `xcodebuild` of the `Salus` scheme) is green before this sheet is handed over. The unit suites
cover:

- **Numbers:** `SmokingStatsCalculatorTests`, `MilestoneSchedulerTests`, `MilestonePlanningTests`,
  `SmokingInsightsCalculatorTests`, `SmokingReduceAndGoalTests` and `GoldenVectorTests` (the shared vectors
  copied from the Android branch: day counts, money in minor units, stage progress, milestone schedules with
  quiet hours and the first 48 h, 20-year horizons without overflow).
- **Writes:** the repository and use-case tests under `SalusSmokingTests/Repository` (set up, log smoked,
  resolve slip, craving resisted, none today, edit and delete event, edit quit date, switch mode, price,
  currency, savings goal, reset) and the GRDB `v5` migration with `RoomSchemaParityTests`.
- **Screen logic:** the ViewModel tests of setup, main (QUIT, REDUCE, goal), craving (timer, write,
  presenter), timeline, history and settings in `FeatureSmokingTests`; `SmokingReminderHandler` tests under
  `reminder/` (a stale key returns nothing, per-day anchoring per contract §8.13); the Home card, Trends
  smoking section, `PromptBuilderSmokingTests`, `TobaccoUseReportTests`.
- **Copy:** `SmokingStringsTests` and its per-screen render tests (TR/EN key parity, the literal key-set
  pin, overlines stored upper-case, `BannedHealthClaims` clean), `StageCopyTests` (stage text verbatim
  against `smoking-health-stages.md`), the Home, Trends and AI-report string tests.
- **Colour:** `SalusColorSchemeContrastTests` and `SalusPremiumExtendedColorsTests` check the smoking accent
  in both modes under all four palettes.

No gate sees layout, clipping, keyboard behaviour, animation, VoiceOver, real notification delivery and
timing, the OS (permission, time zone, kill and relaunch) or the paywall round trip. That is this sheet.

## Device and set-up

- A simulator or an iPhone on iOS 17 or newer, plus one run on iOS 26 for the notification permission
  prompt. A development build: the dev scripts act on the simulator's database.
- **Two accounts:** a free one and one with the premium test entitlement. Premium-only parts are marked
  **(premium)**. OCEAN / SUNSET / FOREST are locked for a free user.
- **Theme:** Daha Fazla → Görünüm & Tema opens "Görünüm ve Dil": the mode tiles (Sistem / Açık / Koyu) and
  "VURGU & RENK PALETİ" (CLASSIC and, with premium, OCEAN / SUNSET / FOREST). The same sheet holds the
  language tiles ("UYGULAMA DİLİ").
- **States without waiting** (`docs/testing/smoking-testing.md`):
  - `scripts/dev/seed-store-demo.sh [--lang tr|en]` seeds the "Ayşe" data set: a QUIT plan 42 days into its
    second attempt, one slip 17 days ago, about 60 resisted cravings over more than 7 days. It replaces all
    health data of the profile.
  - `scripts/dev/smoking-shift.sh <days>` moves the whole smoking history N days back (stops the app, keeps a
    `.bak`, relaunches). Each run shifts again; re-seed to start over.
  - REDUCE: switch mode in the app (the seeder writes no REDUCE plan). Not set up: Sigara ayarları →
    "Takibi sıfırla".
- Turkish UI copy is quoted as it appears on screen; the English pass is §14.6.

Tick each step or note the deviation next to it. A step marked **open check** was flagged by the
implementing task as unverifiable without a device: look at it with particular care.

---

## 1. Entry points and the setup wizard (Tasks 9 and 16)

1.1 ☐ More → Takip: a "Sigara" row sits after the cycle row (first when the cycle row is hidden for a male
profile), with no mode chip before setup. **Expected:** subtitle "Bırakma ve azaltma takibi, kriz desteği", a
chevron.

1.2 ☐ Fresh install (smoking never set up), open Home. **Expected:** between "Bugünün dozları" and "Yapay
zekâ özeti" a slim row: smoke icon, "Sigarayı bırakmayı mı düşünüyorsun?", chevron, (x). No other smoking
card.

1.3 ☐ Tap the discovery row body. **Expected:** the setup opens with the tab bar hidden; Back returns to Home
with the row still there.

1.4 ☐ Tap the (x). **Expected:** the row disappears; switch tabs and relaunch the app: it stays gone. More →
"Sigara" still opens the setup.

1.5 ☐ More → "Sigara" with nothing set up. **Expected:** the 4-step setup opens, title "Sigara Kurulumu", the tab
bar hidden, "ADIM 1 / 4" and one filled step-bar segment.

1.6 ☐ Step 1: pick each mode. **Expected:** the selected tile gets an amber border and a check; the privacy
note stays.

1.7 ☐ Step 2: pick each of the four products. **Expected:** two tiles per row, amber selection. A tile with a
wrapping caption may be taller than its neighbour at large text sizes (see §15).

1.8 ☐ Step 2: "Elektronik sigara", then step 3. **Expected:** the amount is a weekly spend, with quick-add chips.

1.9 ☐ Step 3 (cigarette): price 95, 20 per pack. **Expected:** "Günde yaklaşık ₺95 · yılda ₺34.675"; "Devam" is
disabled while the price is empty or 0.

1.10 ☐ Step 3 (vape): 400. **Expected:** "Haftada yaklaşık ₺400 · yılda ₺20.800"; +₺50 and +₺100 raise it;
"Değiştir" returns to step 2.

1.11 ☐ Step 4, QUIT: tap the date row. **Expected:** a sheet; a future day or time shows the warning and
disables "Tamam"; a past one is accepted and the row shows it.

1.12 ☐ Step 4, REDUCE. **Expected:** the limit stepper shows 16 dimmed (80 % of 20) until touched; "Öneri: şu
anki miktarının %80'i (Mevcut: 20 adet)".

1.13 ☐ Tap "Başla". **Expected:** the empty "Sigara" screen replaces the setup; Back returns to More, whose row
now has the "Bırakma Modu" or "Azaltma Modu" chip.

1.14 ☐ From step 3, tap finished step-bar segment 1. **Expected:** page 1 reopens with the answers kept. The
system back from any step leaves the wizard and writes nothing (a known difference, §16).

1.15 ☐ Dynamic Type `.accessibility3` on steps 3 and 4, light and dark, all palettes. **Expected:** nothing
clipped, "Devam" stays reachable.

---

## 2. Main screen — QUIT (Task 10)

2.1 ☐ Open More → Sigara with a QUIT plan. **Expected:** "Sigara" as an inline title with the history and
settings icons at the right; a hero card with the days in the smoking accent, "n saat · n dakika" under it and
the "SİGARASIZ" overline; four metric tiles; the "SIRADAKİ AŞAMA" card; "Canım çekti" pinned with a quiet
"Sigara içtim" under it, and nothing else pinned.

2.2 ☐ Watch the hero counter inside the first hour of a fresh attempt. **Expected:** "13 dk 28 sn" style text,
seconds advancing each second, tile captions visible ("İlk sigara pas geçilmek üzere" etc.); after the hour the
text becomes hours/minutes and moves once a minute. **Open check:** the seconds-to-minutes switch of the live
counter is not verifiable off-device. With Reduce Motion on, the digits change without rolling.

2.3 ☐ Tap the next-stage card. **Expected:** the health timeline is pushed with that stage highlighted (§7).

2.4 ☐ Tap "Canım çekti". **Expected:** the craving cover opens (§6).

2.5 ☐ Vape plan. **Expected:** the fourth tile reads "—", no "+n bugün" chip on the first tile.

2.6 ☐ Largest accessibility text size and a VoiceOver pass. **Expected:** nothing clips; the hero is one
VoiceOver stop ("… sigarasız"), each metric tile is one stop.

---

## 3. Slip and trigger sheets (QUIT — Task 10)

3.1 ☐ Tap "Sigara içtim". **Expected:** one sheet "Olur böyle şeyler" with the stepper at 1, "Kaymaydı, devam
ediyorum" preselected, "Yeniden başlıyorum" unselected, "Devam et" and "Şimdilik kapat". "Şimdilik kapat", the
close button and a swipe all close it and nothing changes on the screen.

3.2 ☐ Choose "Kaymaydı, devam ediyorum", 2 units, "Devam et". **Expected:** the same sheet turns into "Ne
tetikledi?" (no flash of an empty sheet); behind it the hero shows "Son sigaradan beri …" and a "1 kayma"
chip, the counter itself unchanged.

3.3 ☐ In the trigger sheet pick "Kahve" and intensity 4; "Kaydet". **Expected:** chips take the smoking accent;
"Kaydet" is disabled until something is chosen; the sheet closes. "Atla" or a swipe also closes it, saving
nothing.

3.4 ☐ Repeat 3.1–3.2 with "Yeniden başlıyorum". **Expected:** the counter restarts from 0 (first-hour layout),
the "1 kayma" chip is gone (new attempt), the trigger sheet still opens.

3.5 ☐ Tap "Devam et" twice quickly in either mode. **Expected:** one entry only (History, or the "kayma" chip
count: 1); both buttons dim while writing.

---

## 4. Main screen — REDUCE (Tasks 11 and 23)

4.1 ☐ Set up REDUCE (limit 10) and open the screen. **Expected:** ring empty "0 / 10 BUGÜN", "Hafif ve
temiz", a large "+1", "Bugün hiç içmedim", the "Son 7 gün" chart with a dashed "Eski ortalaman: 20" line,
the weekly card, a greyed "Bıraktığında seni bekleyenler" card, an outlined "Bırakmaya hazırım"; only "Canım
çekti" pinned.

4.2 ☐ Tap "+1" once. **Expected:** ring "1 / 10", "Bugün hiç içmedim" disappears, snackbar "1 adet eklendi" with
"Geri al".

4.3 ☐ Double-tap "+1" quickly. **Expected:** one unit is added, not two.

4.4 ☐ Tap "Geri al" on the snackbar; repeat, but navigate back and reopen the screen before tapping.
**Expected:** the entry is removed both times.

4.5 ☐ Reach the limit (10), then 12. **Expected:** at 10 the ring is full with "Günü limitinde tuttun"; at 12
the ring stays in the accent with a neutral outer lap, a neutral "+2" chip, "Bugün biraz fazla oldu" copy —
no red or pink anywhere.

4.6 ☐ Tap "Bugün hiç içmedim" on a fresh day. **Expected:** the zero marker is written, the button goes, today's
bar stays empty.

4.7 ☐ Reduce Motion on, add a unit. **Expected:** the ring jumps without sweeping.

4.8 ☐ Tap the greyed stages card. **Expected:** the timeline opens (§7.6).

4.9 ☐ Tap "Bırakmaya hazırım", pick a past moment, "Tamam". **Expected:** the screen switches to the QUIT view
counting from that moment.

4.10 ☐ **Open check.** With a previous closed attempt, pick a moment before it ended, then a future moment.
**Expected:** the first shows "Bu zaman, önceki denemenin bittiği andan önce olamaz." and the sheet stays —
check that this snackbar is actually visible and not hidden under the sheet; the future one is refused inline
("Bırakma zamanı şu andan ileride olamaz.").

4.11 ☐ Vape plan in REDUCE. **Expected:** no "Eski ortalaman" line, the weekly card shows money only.

4.12 ☐ **Open check.** Largest Dynamic Type (`.accessibility3`), VoiceOver on the hero. **Expected:** the ring
text stays readable inside its ring (it scales down) and nothing clips; the ring reads "Bugün N adet, limit 10"
once; "+1" reads "1 adet ekle"; the chip reads "Limitin N adet üzerinde".

4.13 ☐ "None today" is not a slip *(Task 23)*. REDUCE: tap "Bugün hiç içmedim", then switch to QUIT back-dated to
00:00 the same day. **Expected:** slips 0, "since last smoke" equals the elapsed time, the saved amount is
unchanged by the marker.

4.14 ☐ Quit-time refusal wording *(Task 23)*. In REDUCE (after an earlier closed attempt), pick a quit time
before it ended from Main's quit sheet, from the settings and from the timeline's "Bırakma moduna geç".
**Expected:** all three show "Bu zaman, önceki denemenin bittiği andan önce olamaz."

4.15 ☐ Open the Sigara screen after "Takibi sıfırla" from a stale entry point (a delivered notification, §11.9).
**Expected:** Main never shows blank: it replaces itself with the setup wizard, once.

---

## 5. Home smoking card (Task 16)

5.1 ☐ Run the setup choosing quit, return to Home. **Expected:** overline "SİGARA", "0 gün" in amber with
"sigarasız", a ring with "Sonraki aşama: n dakika/saat/gün", "₺… biriktirdin", a full-width "Canım çekti"
button. The discovery row is gone.

5.2 ☐ Tap the card body (not the button). **Expected:** the smoking main screen opens; Back returns to Home.

5.3 ☐ Tap "Canım çekti". **Expected:** the craving cover opens over the tab bar; closing returns to Home.

5.4 ☐ Reset tracking, run the setup choosing reduce with limit 10. **Expected:** "SİGARA", "Bugün 0 / 10", an
empty amber bar, a "+1" button; no "Dün durumu" row.

5.5 ☐ Tap "+1". **Expected:** "Bugün 1 / 10", the bar moves, snackbar "1 adet eklendi" + "Geri al" (about 10 s).

5.6 ☐ Tap "Geri al". **Expected:** back to 0 / 10. Tap "+1" twice and undo only the second snackbar: exactly
one unit is removed.

5.7 ☐ Double-tap "+1" quickly. **Expected:** one unit added.

5.8 ☐ Go past the limit (11, 12 of 10). **Expected:** the bar stays amber and full, the excess is a grey second
lap, a neutral "+1" / "+2" chip beside "Bugün 12 / 10". No red/pink, no warning icon.

5.9 ☐ Tap the REDUCE card body. **Expected:** the main screen opens.

5.10 ☐ VoiceOver on, Dynamic Type at the largest accessibility size, language English. **Expected:** each card
reads one sentence ("Sigara. Bugün 12 adet, günlük sınır 10, sınırın 2 üzerinde."), "+1" is announced as "Bir
adet ekle" / "Add one" and stays a 44 pt target; QUIT figures and ring stack, the REDUCE button drops under the
count; nothing clips; English strings show.

5.11 ☐ Time left on Home *(Task 23)*. See §7.7: Home's "Sonraki aşama" shows the same figure and unit as the
Main card and the timeline.

---

## 6. Craving flow (Task 12)

6.1 ☐ Main (QUIT) → "Canım çekti". **Expected:** a full-screen cover opens (no tab bar, no back arrow), title
"Canım çekti", headline "Bu his 3–5 dakikada geçecek.", a ring counting down from 05:00 with a halo that
swells 4 s, holds 4 s, shrinks 6 s, and the label inside the ring and the lit chip below it changing "Nefes
al / Tut / Ver".

6.2 ☐ Same, with Settings → Accessibility → Motion → Reduce Motion on. **Expected:** the halo and the line do
not move, the arc steps once a second, and the label and chips still change on the 4/4/6 rhythm.

6.3 ☐ Background the app 2 minutes mid-flow, then return. **Expected:** the clock is about 2 minutes lower (it
kept running), not frozen.

6.4 ☐ Leave the app until more than 5 minutes pass, then return. **Expected:** the check, "Başardın" and "Beş
dakika doldu. Geçtiyse işaretleyebilirsin."; "Geçti" is still offered and nothing was written (History is
unchanged).

6.5 ☐ Tap "Geçti" (quickly twice). **Expected:** "Başardın", "n. krizi atlattın" (n = the Main tile's count +
1) and "Devam"; exactly one craving entry in History.

6.6 ☐ "Devam" → pick a trigger and intensity → "Kaydet". **Expected:** the sheet closes, the cover closes, you are
back on Main, and the History entry carries the trigger.

6.7 ☐ Tap the X mid-flow. **Expected:** the cover closes, nothing is written.

6.8 ☐ QUIT: tap "Sigara içtim". **Expected:** the slip sheet opens and nothing is written until confirmed;
confirm, then the trigger sheet appears, then the cover closes.

6.9 ☐ REDUCE: tap "Sigara içtim". **Expected:** +1 is logged and the cover closes at once.

6.10 ☐ Home → smoking card → "Canım çekti". **Expected:** the same cover over the tab bar; closing returns to
Home.

6.11 ☐ Force-quit the app mid-flow and relaunch. **Expected:** the app relaunches at its root — iOS restores no
navigation state in this app, so it is not on the cover and not on the Main screen — and nothing was written;
opening the flow again starts at 05:00. (Android resumes its start instant: a known difference, §16.)

6.12 ☐ VoiceOver on the ring. **Expected:** one element reading "Kalan süre 4 dk 12 sn. Nefes al" style text;
the chips announce the lit one as selected.

6.13 ☐ Dynamic Type `.accessibility3` on both states. **Expected:** the body scrolls and the actions stay pinned
and tappable.

6.14 ☐ The cover's only way out is the X (no swipe-down, no back). **Expected:** the X is always reachable and
the VoiceOver escape gesture closes it.

---

## 7. Health timeline and stage sheet (Task 13, with Task 23)

7.1 ☐ Quit mode, product cigarette, attempt 3+ days old. On the main screen tap the next-stage card.
**Expected:** the timeline opens as a pushed screen (back button, inline title "Sağlık takvimi", no tab bar);
the header shows "VÜCUDUNUN İYİLEŞME TAKVİMİ", "TAMAMLANAN 4 / 10" and "SIRADAKİ EŞİK 2 hafta" in the
smoking accent; the tapped stage's row is scrolled to the centre and swells once, then settles.

7.2 ☐ Scroll the list. **Expected:** ten rows in contract order; done rows show a check, the counted row a ring
with "%n", "n gün kaldı" and a thin bar, later rows a lock; every row has a WHO or NHS chip; the disclaimer
closes the list.

7.3 ☐ Tap a row. **Expected:** a bottom sheet titled with the stage: a large ring with its percent, the
statement, a "Kaynak: …" attribution line, the disclaimer; nothing else (no bullets, no share); swipe, close
button and scrim all dismiss it. **Open check:** the stage sheet and the quit-date sheet are two sheet
presentations on one view and never open together; confirm that on a device (this row and 7.7).

7.4 ☐ Log a slip and choose "Devam et", reopen the timeline. **Expected:** stages longer than 72 h that the
attempt had already passed carry a "Yeniden sayılıyor" chip; short stages restart without it.

7.5 ☐ Plan with product heated tobacco or vape. **Expected:** the "12 saat" and "48 saat" rows carry "Yanmalı
tütün için tanımlıdır"; no stage is hidden.

7.6 ☐ REDUCE plan (reach the timeline from the greyed card on the REDUCE main screen). **Expected:** the header
reads "Bıraktığında seni bekleyenler"; all rows are greyed with locks and no bars; "Bırakma moduna geç" is
pinned at the bottom.

7.7 ☐ In REDUCE tap "Bırakma moduna geç". **Expected:** the quit-date sheet opens at the current moment; a
future time shows the warning and disables OK; a past time switches to quit mode, the sheet closes, the rows go
live with checks. The refusal snackbar for a storage fault cannot be reproduced by hand and is unit-tested
only.

7.8 ☐ Reduce Motion on; open the timeline from a milestone notification. **Expected:** the stage row is centred
instantly, no pulse.

7.9 ☐ Largest accessibility text size, dark mode, English. **Expected:** header figures stack, rows and chips
wrap without clipping; EN copy matches the stage file ("Health timeline", "NEXT THRESHOLD", "Counting
again").

7.10 ☐ One time-left snapshot on four surfaces *(Task 23, §8.15)*. Set up QUIT, then slip so the next stage is
about 3 days away (or edit the quit date so a stage is under 24 h away). Compare Home's "Sonraki aşama", the
Main next-stage card, the timeline row and its stage sheet. **Expected:** all four show the same figure and
unit. A stage 23 h 59 min away reads "1 gün" (never "24 saat"); one 59 min 30 s away reads "1 saat" (never "60
dk"); under a minute reads "1 dk".

7.11 ☐ English days plural *(Task 23)*. Switch the app language to English. **Expected:** exactly one day left
reads "1 day left" on Main and the timeline, and "3 days left" for three; Turkish stays "N gün kaldı".

---

## 8. Savings goal and insights teaser — premium locks (Task 15)

8.1 ☐ Free account, QUIT main screen. **Expected:** under the next-stage card a "TASARRUF HEDEFİ" card with a
lock, "Biriktirdiğin parayı bir hedefe bağla ve ilerlemeni izle." and "Premium ile aç", and an "İÇGÖRÜLER"
card with a lock; tapping either opens the paywall headed "Tasarruf hedefine eriş" / "Kriz içgörülerine
eriş".

8.2 ☐ **(premium)** No goal. **Expected:** "İlk tasarruf hedefini belirle" with a chevron; tap opens "Tasarruf
hedefi" with "HEDEF ADI" / "HEDEF TUTARI", no note, "Kaydet" off until a name and an amount above zero are
entered; "0" or "abc" shows "Geçerli bir tutar gir."; the name stops at 40 characters.

8.3 ☐ Save "Yeni bisiklet" / 8000. **Expected:** the sheet closes; the card shows the name, "₺x / ₺8.000", a
progress bar in the smoking accent (no red/pink) and "yaklaşık n gün" when there is a daily rate.

8.4 ☐ Tap the card again. **Expected:** the sheet opens with the name and amount filled and the note "Bu hedef
için biriktirdiğin tutar korunur."; change name and/or target and save: the card keeps the saved amount (it does
not restart from ₺0).

8.5 ☐ Edit the target down to or below the saved amount. **Expected:** the card turns into "Hedefine ulaştın"
with "Yeni bisiklet · ₺…" and "Yeni hedef belirle".

8.6 ☐ Tap the reached card. **Expected:** an empty goal sheet without the note; saving creates a new goal that
counts from zero.

8.7 ☐ Open the goal sheet, then let the premium entitlement lapse (or use a free account after having a goal).
**Expected:** the sheet closes, the card shows the lock again; after becoming premium again the same goal is
back.

8.8 ☐ **(premium)** Tap "İÇGÖRÜLER". **Expected:** the Trends screen opens (no paywall); a free account gets the
paywall instead.

8.9 ☐ REDUCE main screen. **Expected:** the same two cards sit after the weekly card and above the greyed
timeline preview.

8.10 ☐ Largest Dynamic Type with a long goal name. **Expected:** the in-progress title truncates to one line;
nothing overlaps; VoiceOver reads each card as one button.

8.11 ☐ Dark mode and a premium palette. **Expected:** the cards and the sheet read in the smoking accent; the
lock, trophy and flag icons are legible.

---

## 9. History (Task 14)

9.1 ☐ Main screen → the top-right history icon. **Expected:** "Geçmiş" opens with the "TOPLAM YOLCULUK" card, an
attempt card ("Devam ediyor" chip, "En uzun seri" on the longest), the "Yolculuk düz bir çizgi değil" card and
"Günlük kayıtlar" grouped by day ("Bugün", "Dün", then "8 Mart 2026"), the tab bar hidden.

9.2 ☐ A fresh plan with no entries. **Expected:** the attempt card stays, the "Kayıt nasıl oluşur?" explainer
sits under "Günlük kayıtlar". With a reset plan and no attempt: the empty state "Henüz bir kayıt yok" and "Ana
ekrana dön" goes back.

9.3 ☐ Tap a log row. **Expected:** the "Kaydı düzenle" sheet with the entry's day, time, units (smoked only),
trigger chips and intensity 1–5; choosing a time after now shows the warning and turns "Kaydet" off; saving
moves/updates the row; moving a slip before the quit start drops that attempt's slip count.

9.4 ☐ In the editor tap "Kaydı sil". **Expected:** a "Bu kayıt silinsin mi?" alert over the sheet; "Sil" removes
only that entry and closes the sheet; "İptal" keeps the sheet. **Open check:** the alert is hosted on the
editor sheet and held down while the write runs; confirm it appears every time.

9.5 ☐ Edit a "Hiç içilmedi" marker. **Expected:** the units stepper may sit at 0 with the "0, o gün hiç içilmediği
anlamına gelir." line; moving it onto a day that has an entry shows the "Bu değişiklik kaydedilemedi…"
snackbar.

---

## 10. Settings and its sheets (Tasks 14 and 23)

Two confirmations follow a closing sheet (the currency change, the quit date): they appear about half a
second after the sheet has gone, by design (`SettingsConfirmHost`), so SwiftUI does not drop them. That wait is
not a finding; an alert that never appears is. Steps 10.4, 10.5 and 9.4 check it.

10.1 ☐ Main screen → the settings icon. **Expected:** "Sigara ayarları" with the four groups; in QUIT: quit date
row, no limit row, no evening row; in REDUCE: limit row + "Akşam hatırlatması · 20:30", no quit date.

10.2 ☐ "Fiyatı güncelle". **Expected:** the sheet opens at the pack price (x20; a vape: weekly spend), "Kaydet"
off for an unreadable or zero amount; saving updates the row's "₺x / adet" ("/ gün" for a vape).

10.3 ☐ Para birimi, with the plan in TRY *(Task 23, §8.11)*. **Expected:** the choices are TRY, EUR, USD, GBP,
CHF (no JPY or KWD). With the plan in JPY (set up with it): the sheet offers only JPY. The setup wizard's
currency list is unchanged.

10.4 ☐ Para birimi → another currency. **Expected:** the sheet closes, then "Para birimi değişsin mi?" appears
("Tutarlar dönüştürülmez…"); "Değiştir" relabels, the saved total on the main screen keeps the same number.

10.5 ☐ Bırakma tarihi → pick a date. **Expected:** the confirmation "Yeni tarihten önce kaydedilmiş kaymalar bu
denemeye sayılmaz."; a time earlier than the previous attempt's end gives the "…çakışıyor" snackbar and changes
nothing.

10.6 ☐ Bildirimler on with notifications denied in iOS Settings. **Expected:** the switch stays on and Reminder
Health opens.

10.7 ☐ "Azaltma moduna geç" (QUIT) / "Bırakma moduna geç" (REDUCE). **Expected:** the limit sheet (80 %
suggestion, note) / the quit-date sheet; the screen turns into the other mode's rows.

10.8 ☐ "Takibi sıfırla". **Expected:** a destructive "Takip sıfırlansın mı?" alert; "Sıfırla" empties everything
and lands on More (two screens popped), the More row offers the setup again.

10.9 ☐ Dynamic Type at the largest accessibility size, light and dark, on both screens and all sheets.
**Expected:** nothing clipped, the sheets scroll.

---

## 11. Notifications — timing and quiet hours (Task 17, with Task 23)

Notifications on, permission granted. To reach a milestone without waiting use the shift tool, or pick the quit
time in the setup's date row.

11.1 ☐ Set up QUIT with notifications on, quit "now" (or use the shift-back tool for N days) and background the
app. **Expected:** a notification "Yeni aşama: 20 dakika · Nabız ve tansiyon" arrives about 20 minutes after
the quit instant, body "Takvimde görmek için dokun.", no action buttons, no alarm UI.

11.2 ☐ Tap that notification. **Expected:** the More tab opens on the smoking main screen with the health
timeline pushed over it highlighting the 20-minute stage; back lands on the main screen. Tap an old copy of
the same notification again: no second stack of screens.

11.3 ☐ Open Smoking from More first (the main screen showing), then tap a delivered stage notification.
**Expected:** only the timeline is pushed over the main screen (no second main screen). Tap a notification for
another stage while the first timeline is showing: the highlight changes and one back press lands on the main
screen.

11.4 ☐ Quiet hours: arrange a milestone that falls between 22:00 and 08:00 (quit at 10:00: the 12-hour stage).
**Expected:** nothing before 08:00 the next morning; the notification appears at 08:00.

11.5 ☐ Log a slip (smoked) right after the first notification was scheduled but before it fires. **Expected:** the
pending 20-minute notification moves (arrives 20 minutes after the slip), not at the original time.

11.6 ☐ Reset smoking (or switch to REDUCE) with a milestone pending. **Expected:** no smoking notification
arrives afterwards.

11.7 ☐ REDUCE with the evening reminder on. **Expected:** "Bugünü kaydetmek ister misin?" at 20:30; if you log an
entry or "none today" earlier that day, it does not arrive.

11.8 ☐ Turn the smoking notifications switch off. **Expected:** no milestone notification; the evening reminder
(REDUCE) is controlled by its own switch only.

11.9 ☐ Stale notification after reset *(Task 23)*. Schedule a milestone notification, reset tracking ("Takibi
sıfırla"), then tap the delivered notification. **Expected:** the app opens the setup wizard directly; Back from
the setup does not land on an empty Main; this happens once.

11.10 ☐ Switch the app language TR ↔ EN between two milestones. **Expected:** each notification is in the language
the app had at the sync that scheduled it (open the app once after switching to rebake).

11.11 ☐ The first 48 hours (contract §4 as amended). In that window a day may carry two notifications (an early
one and a late one). **Expected:** at most two notifications on any day however often you open the app.

11.12 ☐ Reminder Health (bell) with medications, appointments, the cycle and smoking all active. **Expected:**
the smoking milestones are listed among the pending reminders; the engine caps the total at the 64 pending
requests iOS allows and the nearest smoking milestone is always included (unit-tested; the on-device count
is not).

---

## 12. Trends "SİGARA" section (Task 18, premium)

12.1 ☐ **(premium)** A QUIT plan set up with entries on 8+ days (the Ayşe demo seed). Open Trends. **Expected:**
after the existing four cards, a "SİGARA" overline and cards "Tetikleyiciler" (amber bars with %), "Krizlerin
zamanı" (a 7x7 amber heatmap, caption "En yoğun aralık: … · payı %N"), "Denemeler" (bars with "N gün"); no
"Azaltma eğrisi" card.

12.2 ☐ Same account, a window with two or more vitals metrics. **Expected:** the "Metrikler bir arada" chart
shows a dashed amber "Bıraktın" line at each quit day inside the plotted span, none outside it.

12.3 ☐ REDUCE plan with 2+ weeks. **Expected:** the "Azaltma eğrisi" line chart in amber, x labels "1.
hafta"…; no "Denemeler" card.

12.4 ☐ Plan with entries on fewer than 7 days. **Expected:** under "SİGARA" a single empty state "Henüz yeterli veri
yok" naming 7 different days.

12.5 ☐ No smoking plan. **Expected:** no "SİGARA" section at all.

12.6 ☐ Free account. **Expected:** the existing locked body only; no smoking card behind the blur.

12.7 ☐ Switch the language to English. **Expected:** "SMOKING", "Triggers", "Craving times", heatmap cells read
"… N entries" (VoiceOver), the marker "You quit".

12.8 ☐ Largest accessibility text size. **Expected:** the section scrolls, row labels wrap, heatmap headers
shrink, nothing clips.

---

## 13. AI summary and doctor PDF (Tasks 19 and 23, premium)

The statistics are aggregate-only; the exact wording is parity row D-M17-j.

13.1 ☐ **(premium)** QUIT with at least one slip and at least one vitals record in the period. AI Health →
create the doctor report (Turkish). **Expected:** between the dose summary and "Yapay zekâ değerlendirmesi" a
"Tütün kullanımı" section with "Durum: bırakma sürecinde", "Bırakma tarihi: <date>", "Bırakma tarihinden bu
yana: <n> gün", "Bu denemedeki kayma sayısı: <n>" (Task 23 renamed "kaçamak" to "kayma"); no amount, no
currency symbol, no craving count, no reason.

13.2 ☐ REDUCE with some days logged; regenerate. **Expected:** "Durum: azaltma sürecinde" and "Günlük ortalama
(son 7 günün kayıtlı günleri): <x.y>"; no quit date, duration or slip line.

13.3 ☐ English. **Expected:** "Tobacco use", "Status: quit attempt in progress" or "Status: reducing", "Quit date:
…", "Time since quit date: … days", "Slips during this attempt: …", "Daily average (logged days of the last 7):
…".

13.4 ☐ Smoking reset (or never set up). **Expected:** no "Tütün kullanımı" / "Tobacco use" section; the report is
as on `main`.

13.5 ☐ Share the PDF. **Expected:** the section appears exactly as in the preview, and every page still carries
the disclaimer footer.

13.6 ☐ "Yapay zekâ özeti" with smoking set up (the demo seed). **Expected:** the summary may mention tracked
days, slips, frequent triggers or the busiest time band; it never quotes your reason, never says smoking caused
a vitals change and gives no medical advice about smoking. Without smoking set up the summary reads as on
`main`.

---

## 14. Cross-cutting checks

### 14.1 Theme matrix — light and dark under every palette

Mode is Daha Fazla → Görünüm & Tema; the palette is the same sheet's Renk Teması (premium for three of them).
Tick a cell when the screen is legible at a glance, card edges are visible (dark: a border and no shadow; light:
a shadow with a faint hairline), the accent follows the smoking amber of that palette rather than staying one
colour, nothing is clipped, and **nothing is red or pink**.

| Screen | CLASSIC L | CLASSIC D | OCEAN L | OCEAN D | SUNSET L | SUNSET D | FOREST L | FOREST D |
|---|---|---|---|---|---|---|---|---|
| Setup wizard (steps 1–4) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Main — QUIT | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Slip sheet and trigger sheet | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Main — REDUCE (under and over the limit) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Craving cover (breath and done states) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Health timeline and stage sheet | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Goal card, goal sheet and insights teaser | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| History and the event editor | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Settings and its four sheets | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Home smoking card (QUIT and REDUCE) and the discovery row | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Trends "SİGARA" section | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Doctor report preview with "Tütün kullanımı" | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

14.1a ☐ The SF Symbols were picked by name (`nosign`, `banknote`, `shield`, `hourglass`,
`figure.mind.and.body`, `cup.and.saucer`, `bolt`, `wineglass`, `fork.knife`, `person.3`, `sparkles`,
`clock.arrow.circlepath`, `gearshape`). **Expected:** every icon renders; a wrong name draws nothing and no
test sees it.

### 14.2 Dynamic Type — xxxLarge and the accessibility sizes

14.2.1 ☐ Settings → Display & Brightness → Text Size to xxxLarge, then Accessibility → Display & Text Size → Larger
Text to the third and the largest accessibility size. Walk the setup (every step), Main (QUIT and REDUCE), the slip and trigger sheets, the
craving cover, the timeline and the stage sheet, the goal card and sheet, History, Settings and its sheets, the
Home card, Trends "SİGARA", the PDF preview. **Expected:** nothing clips or overlaps; long copy wraps; sheets and
bodies scroll with their primary action pinned and tappable; the hero numbers and the REDUCE ring scale down
rather than overflow. The per-screen steps above name the cases that were flagged.

### 14.3 VoiceOver — order and labels

14.3.1 ☐ VoiceOver on, swipe through Main (QUIT). **Expected:** the order follows the screen top to bottom; the
hero is one stop ("… sigarasız"), each metric tile one stop, then the next-stage card, "Canım çekti" and
"Sigara içtim".

14.3.2 ☐ Same on Main (REDUCE). **Expected:** the ring reads once ("Bugün N adet, limit 10"), "+1" reads "1 adet
ekle", the over-limit chip reads "Limitin N adet üzerinde", the chart reads its days.

14.3.3 ☐ The craving cover, the timeline rows (state announced: done / counting / locked), the stage sheet, the
goal and teaser cards (one button each), the Home cards, the heatmap cells ("… N entries"). **Expected:** every
control has a label; nothing is read twice; the sheet that is open is the only thing reachable behind its
scrim.

### 14.4 Reduce Motion

14.4.1 ☐ Reduce Motion on (Settings → Accessibility → Motion). **Expected:** the hero digits change without
rolling (the data still updates each second), the REDUCE ring jumps without sweeping, the craving halo and line
do not move (the arc steps once a second), the timeline highlight does not pulse and the row is centred at
once.

### 14.5 Notification timing and quiet hours

See §11. In particular 11.4 (22:00–08:00), 11.5 (a slip moves the pending notification), 11.6 (reset cancels)
and 11.9 (a stale tap).

### 14.6 English

14.6.1 ☐ Switch the app language to English and walk every screen above. **Expected:** English copy everywhere
(the setup, "Health timeline", the notification texts, the PDF section "Tobacco use"), overlines upper-case, no
Turkish string left, no key name shown.

---

## 15. Known risks

Note what you see; each is a candidate for the fix wave, not a pass or fail by itself.

- **Live counter cadence:** whether the `TimelineView` honours the one-second to one-minute switch on a real
  device was not verified (2.2).
- **Equal-height product tiles** (Android `IntrinsicSize.Min`) are not reproduced: a tile with a wrapping
  caption may be taller than its neighbour at large text sizes (1.7).
- **Two sheets on one view:** the stage sheet and the quit-date sheet are separate `.sheet` presentations on the
  timeline; they never open together by design (7.3).
- **Alerts after a sheet:** the currency and quit-date confirmations wait 0.5 s for the sheet to settle; the
  delete alert lives on the editor sheet. An alert that is dropped would be a bug (9.4, 10.4, 10.5).
- **Snackbar under a sheet:** the REDUCE quit sheet's overlap refusal may sit behind the sheet's scrim (4.10).
- **Ring text at large sizes:** the REDUCE hero ring text scales down inside its 168 pt ring; check the legibility
  at `.accessibility3` (4.12).
- **Notification tap after a slip:** the tap opens the timeline highlighting the stage stored in the
  notification; after a slip moved the stages, the highlighted row may differ from the stage the user expects.
  Notification text is baked when it is scheduled (D-M17-i-5): a stale one can fire only if the app was
  suspended or killed mid-sync.
- **Keyboard:** the goal sheet (8.2) and the price sheet (10.2) may let the keyboard cover "Kaydet". Note the
  device and text size if so.
- **No state restoration:** a force quit relaunches at the root (6.11); the craving flow always restarts at
  05:00.
- **Editing a goal keeps its progress (§8.17):** saving the prefilled sheet updates the same goal and its saved
  amount stays; only a new goal (from none or after a reached one) counts from ₺0 (8.4, 8.6).
- **`smoking-shift` across DST:** a shift over a DST change moves the local time of day by an hour, so a
  milestone can land an hour away from where you expected it; that is the script, not the app.
- **Demo seed:** the store-demo seed replaces all health data on the device; use a demo simulator.

---

## 16. Known differences

### From `main` (1.0.1, build 5)

- New: the Sigara feature (setup, main QUIT/REDUCE, craving flow, timeline, history, settings), the More
  "Sigara" row, the Home smoking card and discovery row, the Trends "SİGARA" section and "Bıraktın" markers, the
  doctor PDF "Tütün kullanımı" section, smoking lines in the AI summary prompt, and two paywall headlines
  ("Tasarruf hedefine eriş", "Kriz içgörülerine eriş").
- Database migration `v5` (five `smoking_*` tables, copied from the Android Room export); version 1.1.0 (6).
- Privacy: App Privacy needs no change (nothing new is collected); the data-safety note in
  `docs/appstore/store-listing.md` gains the tobacco-use line, and the hosted privacy policy gains a
  "Tütün kullanımı" paragraph on the Android side.

### From Android (`feature/m17-smoking-cessation`; parity ledger § M17)

- **Setup back (D-M17-setup-back / Android D-M17-s):** the system back leaves the wizard from any step and
  writes nothing; stepping back is a tap on a finished step-bar segment. Android steps back one page. The owner
  confirms this in QA (1.14).
- **"+1" undo snackbar (D-M17-i-3 / D-M17-u):** iOS shows it for 10 s; Android keeps it until dismissed.
- **Craving flow after termination (D-M17-i-7):** iOS restarts the flow at 05:00 and writes nothing (it
  restores no navigation state); Android restores the start instant and the logged craving after process
  death (6.11).
- **Notification content (D-M17-i-5):** the text is baked at sync time (`UNNotificationRequest` is immutable);
  every write resyncs, which re-bakes, moves or cancels requests. Android re-plans at fire time. Same
  observable rule; a stale request can fire only if a sync pass did not finish.
- **Anchor (D-M17-i-6):** iOS anchors a day at local 22:00 of the day before minus 1 ms, per contract §8.13;
  Android's code still uses the start of the day minus 2 h. The two differ only where DST changes at midnight.
- **Heatmap count copy (D-M17-i-2):** "kayıt" / "entries" per §8.12; Android's string reached parity at its own
  close-out.
- **Home discovery flag and plurals (D-M17-i-4):** a plain `UserDefaults` bool under the same key string,
  outside the backup; `<plurals>` become `_one` twin keys. A mapping note, not a behaviour.
- **Scheduler cap (D-M17-i-1):** `MilestoneScheduler.plan` caps `limit` at 1000; `limit ≤ 0` plans nothing.
  Android has no cap. Invisible to the user.
- **Unreached on iOS:** the "Saati seç" time-dialog string has no reader (the time is a wheel); it stays in the
  catalog for key-set parity.

---

## Result

Date, device, iOS version, account (free / premium):

Findings (step number, what you saw):
