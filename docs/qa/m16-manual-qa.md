# M16 UI overhaul — manual QA (iOS)

Spec: `docs/superpowers/specs/2026-09-12-ios-m16-ui-overhaul-design.md` (deviations in its §9).
Branch: `m16-ui-overhaul`. Tokens: `salus-android/docs/design/design-tokens.md` §8.1 + §14.
Automated coverage: `SalusColorSchemeContrastTests` (WCAG AA across 2 modes × 4 palettes on the
Material and accent-derived roles), `SalusDesignTokensTests` (233 tokens), `SalusThemeTests`
(theme resolution and `swatch(dark:)`), `SalusPremiumExtendedColorsTests` (per-palette extended
values, status colours never move, palette-independent roles never move). Full automation:
`scripts/ci.sh` green before this sheet is run.

This is a **reskin** milestone: no behaviour was meant to change, so anything that behaves
differently from the last milestone is a finding even when it looks right. The deliberate changes
live in the spec, and every recorded iOS divergence is in its §9 — read that before filing a
finding against something this sheet calls a divergence. The sheet is complete: Tasks 1-13 each
appended their rows and Task 14 closed §6.

Sections 1 and 5 need a **premium entitlement** — OCEAN / SUNSET / FOREST are locked for a free
user, so run the matrix (§1) with premium enabled and the paywall-gating checks (§5) on a free
account.

Each step names what to see; tick or note the deviation. Turkish strings are quoted as they
appear on screen.

---

## 1. Theme matrix

Every screen in both modes under all four palettes. Mode is Ayarlar → Görünüm & Tema; palette is
the same sheet's Renk Teması. Tick a cell when the screen shows: text legible against its ground
at a glance, card edges visible (dark: a border and **no** shadow; light: a shadow with a faint
hairline), accent colour following the palette rather than staying emerald, and no element
clipped or overlapping.

L = light, D = dark. Every screen the app has is a row; the last two are chrome rather than a
screen and carry their own contract under the table.

| Screen | Light CLASSIC | Dark CLASSIC | OCEAN L | OCEAN D | SUNSET L | SUNSET D | FOREST L | FOREST D |
|---|---|---|---|---|---|---|---|---|
| Onboarding — cover (page 1) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Onboarding — personal details (page 2) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Onboarding — health notes (page 3) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| App Lock | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Home | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Medications list | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Medication detail | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Medication editor | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Vitals list | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Vitals — weight editor | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Vitals — blood pressure editor | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Vitals — glucose editor | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Appointments list | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Appointment detail | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Appointment editor | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Cycle calendar | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Cycle day | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| More hub | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Theme sheet | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Language sheet | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Profile | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| About | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Reminder Health | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| AI summary | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Doctor report | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Doctor report — PDF preview cover | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Trends | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Paywall | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Tab bar (Task 5) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Navigation bar (Task 5) | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

The two Task 5 rows are the chrome rather than a screen, so tick a cell only when **both** hold:

- **Tab bar** — the bar sits on the near-white `surfaceContainerLowest` in light and on
  `surfaceContainerLow` in dark; in dark a faint `cardBorder` hairline runs along its top edge and
  in light the system's own hairline does. The selected tab's icon and label are the palette's
  `primary` (emerald / teal / amber / green, NOT emerald in all four); the other four are the muted
  `onSurfaceVariant`, legible but clearly quieter. No translucent blur sampling the content.
- **Navigation bar** — the bar sits on `background`, the same colour as the screen under it, so the
  two read as one surface with no seam; the title is `onSurface` at `titleMedium` weight, centred
  and on ONE line (never a large title, never two lines); the brand tile on the left is a
  `primaryContainer` circle with an emerald-equivalent heart, and the bell and avatar on the right
  take the palette's colours too.

The **Home** row is a screen row, and Task 6 is what filled it in. On top of the four generic
checks above, tick a cell only when all of these hold:

- **Hero band** — a full-bleed gradient meeting the navigation bar with no seam or gap; the date
  overline and the greeting are legible on it in **both** modes (light paints the saturated brand
  green and the text is `onPrimary`; dark rises out of the app background and the text is
  `onSurface`); the dose-progress chip sits at the trailing edge of the greeting line and follows
  the palette. No avatar in the band — it is in the navigation bar.
- **Snapshot pager** — the card fills the width inside the screen inset, its ground is one rung
  up the surface ladder from the page (`surfaceContainer`), and the dots under it show the
  palette's `primary` on the active pill.
- **AI card** — the gradient frame around it is visible in every palette and changes colour with
  it (emerald→rose in CLASSIC); the trailing "Detaylı İncele" line and its chevron are the
  palette's `primary`, and the "Yeni Özet" chip — shown only while a free summary is unspent —
  takes the palette's accent.
- **Appointments** — the "YAKLAŞAN RANDEVULAR" overline is upper-case and in the muted overline
  colour, "Tümünü Gör" beside it is `primary`, and each appointment card's time chip follows the
  palette.

The **Doctor report — PDF preview cover** row is the `fullScreenCover` §3.5.6 opens ("Önizle" or
the preview card). It draws its own chrome rather than a navigation bar — a `headline` title, a
share glyph and a close ✕ over a `PDFView` — so tick a cell only when that header row sits legibly
on the screen's ground in the palette, the two glyphs are reachable and distinguishable, and the
rendered page itself is unaffected by the theme (a PDF is paper: it stays white in dark mode, which
is correct and is not a finding).

Onboarding is only reachable on a fresh install; its three rows are §2's three pages and can be
ticked in one walk per palette. Resetting the device (Settings → General → Transfer or Reset
iPhone → Erase All Content and Settings) is heavy, so prefer deleting the app and reinstalling;
check light first, matching the mockups.

---

## 2. Onboarding flow

The one flow change of the milestone (Task 13): eight single-field steps became Android's three
pages — Welcome → Personal details → Health notes and permissions. The gate is drawn **above** the
shell's `TabView`, so it has no navigation bar and no tab bar; every page carries the same header
("ADIM n/3" over three bar segments) and its own two buttons.

Run the whole section on a **fresh install** (delete the app first — the flow only shows while
`onboarding_completed` is unset), and run 2.13–2.14 on a second fresh install, because the
notification permission can only be asked for once per install.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 2.1 | Launch a fresh install | the Welcome cover, never a flash of Home behind it; header reads "ADIM 1/3" with the first of three segments filled and **no** back button | ☐ |
| 2.2 | Read the cover | shield tile, "Salus'a Hoş Geldiniz", the paragraph, and three chips — "Yalnızca cihazınızda", "Hesap gerektirmez", "Reklamsız"; the chips are plain, not pressable-looking, and none of them claims encryption | ☐ |
| 2.3 | Tap "Gizlilik ve Güvenlik İlkelerimiz" | a bottom sheet titled "Gizlilik ve Güvenlik" with the full privacy paragraph; drag it down, tap the close button and tap the scrim — all three dismiss it and leave the cover exactly where it was | ☐ |
| 2.3a | On that sheet, look at the paragraph's left and right edges | it is inset from both, lining up under the sheet title — never running edge to edge while the title above it sits indented. At the largest text size the paragraph **scrolls inside the sheet**; no line is cut off at the bottom | ☐ |
| 2.4 | Tap "Başla" | page 2 slides in **from the right** while the cover slides left; header reads "ADIM 2/3", two segments filled, and a back button has appeared | ☐ |
| 2.5 | Page 2 without choosing a sex | "Devam Et" **and** "Şimdilik Atla" are both dimmed and do nothing; typing a name does not enable them | ☐ |
| 2.6 | Choose "Kadın", then "Diğer", then "Erkek" | exactly one tile is selected at a time, with the primary edge and the check disc; the cycle note ("Regl ve döngü takibi…") shows for Kadın and Diğer and disappears for Erkek | ☐ |
| 2.7 | Choose a sex, then type "7" in BOY | the field turns red with "50 ile 250 cm arasında bir değer girin." and "Devam Et" dims; clearing the field re-enables it. Same for KİLO with "3" | ☐ |
| 2.8 | Type "170,5" in BOY (Turkish keyboard comma) | no error — the comma is read as a decimal point | ☐ |
| 2.9 | Fill name, birth date, height and weight, then tap "Şimdilik Atla" | page 3 arrives; go **back** to page 2 — the name, the birth date, the height and the weight are all cleared and the **sex is still selected** | ☐ |
| 2.10 | On page 2, tap back | page 1 slides in **from the left** while page 2 slides right; header is back to "ADIM 1/3" with no back button. Tapping back again (there is none) is impossible — the flow cannot be escaped | ☐ |
| 2.11 | Page 3 | document tile, "Son Birkaç Detay", the notes field under its "SAĞLIK NOTLARI & ALERJİLER (İSTEĞE BAĞLI)" overline with the "Yalnızca bu cihazda" chip under it, the privacy note, and the "Zamanında Hatırlatıcılar" row with its switch **on** | ☐ |
| 2.12 | Type several lines of notes | the field grows with the text and the page scrolls; the lock chip sits under the notes field, left-aligned with it — never pushed to the right edge | ☐ |
| 2.13 | Leave the switch **on** and tap "Kurulumu Tamamla ve Başla" | the system notification prompt appears; whichever answer you give, the app lands on Home — the prompt never blocks the finish | ☐ |
| 2.14 | *(second fresh install)* Turn the switch **off**, then tap "Kurulumu Tamamla ve Başla" | **no** system prompt at all, and the app still lands on Home | ☐ |
| 2.15 | *(third fresh install)* On page 3 type some notes, then tap "Daha Sonra Ayarla" | no system prompt, the app lands on Home, and Daha Fazla › Profil shows **no** health notes — the typed text was discarded | ☐ |
| 2.16 | After any of 2.13–2.15, open Daha Fazla › Profil | the name (trimmed), sex, birth date and height are the ones you entered, and Ölçümler holds one weight entry dated today | ☐ |
| 2.17 | Force-quit and relaunch after finishing | Home, never the onboarding gate again | ☐ |
| 2.18 | *(fresh install)* Kill the app while page 3 is saving (rapid tap then swipe up) | the gate is still there on relaunch and the flow replays — never a half-filled profile behind a closed gate | ☐ |
| 2.19 | Settings › Accessibility › Larger Text at the largest size, walk all three pages | nothing clips: the trust chips stack instead of running off the edge, BOY and KİLO stay readable side by side, and every button label fits inside its pill | ☐ |
| 2.20 | Settings › Accessibility › Motion › Reduce Motion on, walk all three pages | the pages swap instantly with no slide and no fade; back still returns to the right page | ☐ |
| 2.21 | VoiceOver, page 1 | the header announces "ADIM 1/3" and the three bar segments are **not** announced; the shield tile is not announced; the trust chips read as plain text | ☐ |
| 2.22 | VoiceOver, page 2 | each sex tile announces its label and reads as selected/not selected; the back button announces "Geri" | ☐ |
| 2.23 | VoiceOver, page 3 | the reminder row reads as one control — title, subtitle and switch state together — and a double-tap flips it | ☐ |

---

## 3. Gestures

Per-screen interaction rows, one subsection per screen task. Swipe-to-delete, undo and the maps
row live with the screen that owns them rather than in a list of their own.

### 3.1 Home's snapshot pager and its entrance (Task 6)

The pager is the one `TabView` outside `App/` (spec §4.1) and the only horizontal gesture on a tab
root, so it is checked on its own. Run 3.1.1–3.1.4 on a profile that has **all three** pages
(medications with a dose today, at least one measurement and cycle tracking on) and 3.1.5 on a
profile with no cycle.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 3.1.1 | Home root: swipe the snapshot card left, then right | it pages one card at a time — doses → Ölçümler → Döngü and back; it never scrolls half a card and never jumps two | ☐ |
| 3.1.2 | Watch the dots under the card while swiping | exactly three dots; the active one is a stretched pill in the palette's `primary` and it moves with the card, not after it | ☐ |
| 3.1.2a | Look at the vertical gap between the bottom of the snapshot card and the dots, on **each** of the three pages | the dots sit one `md` step under the card on every page — no empty band between a short card and the dots. The box is the **tallest** page's height, so the doses page (the tallest) has no slack under it at all and the other two sit top-aligned in the same box; a page that ends halfway up a visibly empty box is the owner-QA-round-1 B2 regression | ☐ |
| 3.1.3 | Swipe the pager while the page is scrolled halfway down | the horizontal swipe pages the card and does **not** scroll the screen; a vertical drag starting on the card scrolls the screen and does not page | ☐ |
| 3.1.4 | On the doses page, tap "Alındı" | the dose is recorded (the ring's number goes up) and the Medications tab does **not** open; tapping anywhere else on that card opens Medications | ☐ |
| 3.1.5 | A profile with no cycle tracking | two pages and two dots — never a third, empty card | ☐ |
| 3.1.6 | VoiceOver, swipe between pages | each page announces its own label ("Bugünün dozları kartı", "Ölçümler kartı", "Döngü kartı") and its contents stay individually reachable; the dots are not announced | ☐ |
| 3.1.7 | Cold start on Home, watching the five blocks | hero, readiness card (when shown), pager, AI card and appointments fade and settle **in that order**, one short step apart — never all at once and never out of order | ☐ |
| 3.1.8 | Switch to another tab and come back to Home | Home is already settled — the entrance does **not** replay (spec §3.5). If it does replay, note it: that is the `@SceneStorage` escalation the spec records | ☐ |
| 3.1.9 | Reduce Motion on (Ayarlar → Erişilebilirlik → Hareket), open Home | the five blocks arrive together on one short curve — no staggered ladder down the screen — and **nothing travels**: each block fades in exactly where it will sit, with no upward slide at all. A visible slide is a regression (spec §11, opacity only) | ☐ |
| 3.1.10 | Home: tap an appointment card in "YAKLAŞAN RANDEVULAR" | **that appointment's own detail opens, pushed onto Home** — the full-screen detail of the appointment on the card, with a system back button and no tab bar. The Appointments tab does **not** become selected; back returns to Home with Home's scroll position intact (parity row A58) | ☐ |
| 3.1.11 | Home: tap "Tümünü Gör" beside "YAKLAŞAN RANDEVULAR" | the **Appointments tab** opens at its root (tab bar visible, Upcoming selected) — the header action switches tabs where a card opens one appointment | ☐ |
| 3.1.12 | From 3.1.10's detail, tap "Düzenle", then back twice | the editor opens on the same stack, back returns to the detail, and back again to Home — the pushed screens are Home's, not the Appointments tab's | ☐ |
| 3.1.13 | Home: tap a card's row anywhere along its full height, and tap "Tümünü Gör" at the very top and very bottom of its text | both respond everywhere inside their rows — the header action is a ≥44 pt target, not just the glyph height of its label | ☐ |

### 3.2 Medications — the dose on offer, the count and the day boundary (Task 7)

Run 3.2.1–3.2.6 on a profile with **at least two** medications: one taken daily with a dose time
already past (so its card offers "Hemen Al") and one taken as needed. 3.2.7 needs the app left open
across midnight, or the device clock moved forward a day with the app in the background — it is the
one row that checks Android's M15 critical fix, so it is worth the clock change.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 3.2.1 | Medications root: tap "Hemen Al" on a card whose dose time has passed | the dose is recorded — the card's chip turns to "Alındı", the button goes, the stock line drops by the dose amount, and the "Kaydedilen doz" tile moves. The detail screen does **not** open | ☐ |
| 3.2.2 | Tap "Hemen Al" twice quickly on the same card | exactly one intake row: the stock drops once, not twice (the button goes through the same use case as the notification action, which is idempotent) | ☐ |
| 3.2.3 | Look at the top of the Medications root | the count is the first metric tile ("Aktif ilaç"), **not** a chip in the navigation bar — the bar carries only the shell's brand tile, bell and avatar | ☐ |
| 3.2.4 | A card of a medication taken as needed | its chip reads "İhtiyaç halinde", it shows the plan's own words instead of a clock time, and it offers no "Hemen Al" | ☐ |
| 3.2.5 | Tap the trash on a card, confirm, then tap "Geri al" in the snackbar | the card leaves the grid at once and comes back in its place; nothing is deleted. Let a second delete's snackbar time out and the medication is gone for good | ☐ |
| 3.2.6 | VoiceOver on a card: swipe through it | the card is announced as one button (name, strength, next dose, stock), and the trash and "Hemen Al" are each reachable as their own controls with their own labels | ☐ |
| 3.2.7 | Leave Medications open past midnight (or set the device clock a day forward and return to the app), then tap the "Hemen Al" the card was already showing | **nothing is recorded against yesterday.** The overline date moves to the new day, the "Sıradaki doz" tile re-reads, and the card offers the new day's dose — tapping that one records it, dated today | ☐ |
| 3.2.8 | Medication detail of a medication with stock: read the "Kutu & Stok" card | "≈ N gün yetecek" is there and the number is plausible for the plan (an every-other-day dose lasts about twice as long as a daily one of the same amount); the bar turns rose at or below the warning threshold | ☐ |
| 3.2.9 | Medication detail: tap the reminders switch off, then back on | the switch answers immediately, the subtitle swaps between "Doz vaktinde hatırlat" and the "no notifications" line, and the dose still shows on Home either way | ☐ |
| 3.2.10 | Medication editor: tap through all eight form tiles | each has its own glyph, only one is selected at a time, and the four-column grid does not clip a label at the default text size | ☐ |
| 3.2.11 | Medication editor: switch the plan tabs Her gün → Belirli günler → Aralıklı → Gerektiğinde | the pill slides between segments; the weekday chips appear only under "Belirli günler" and the day stepper only under "Aralıklı"; "Gerektiğinde" hides the dose-times card entirely | ☐ |
| 3.2.12 | Medication editor: tap − and + on a dose amount, then type a number into it | the nudges move by 0.5 and stop at 0.5 and 99; a typed number is accepted on the keyboard's Done or on leaving the field, and a non-number reverts to what was there | ☐ |
| 3.2.12a | Medication editor: choose "Aralıklı", then tap into the day-interval field | the keyboard that opens is the **number pad** — no letters, no QWERTY. Same for every dose-amount and stock field: a field that only accepts digits never opens an alphabetic keyboard | ☐ |
| 3.2.13 | Medication editor: turn "Stok takibi" off | the two stock fields disappear and saving stores no stock; turning it back on leaves them empty rather than restoring the old numbers | ☐ |

### 3.3 Vitals — the suggestion, the tabs and the chart card (Task 8)

Run 3.3.1–3.3.5 on a profile that has **at least three** weight readings (so the chart, the
statistics row and a delta all exist) and at least one blood pressure reading. 3.3.6–3.3.10 are
the editors, and 3.3.6 is the row the whole "suggestion, not a value" design rests on.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 3.3.1 | Vitals root: tap Tansiyon, then Şeker, then Kilo | one pill slides between the three segments — it never fades out and back in, and never jumps two segments at once. The chart, the statistics row and the history rows all follow the selected type | ☐ |
| 3.3.2 | Look at the top of the Vitals root | the navigation bar carries **only** the shell's brand tile, title, bell and avatar — no chart icon. The trends link is "Analizler" beside the "GRAFİK" overline, inside the content | ☐ |
| 3.3.3 | Tap "Analizler" | Trends opens (a free user meets Trends' own lock there, which is correct — the link is deliberately ungated) | ☐ |
| 3.3.3a | Tap "Analizler" at the very top and the very bottom of its row, beside the "GRAFİK" overline | it responds from both — the whole ≥44 pt row height is tappable, not only the text's own glyph box | ☐ |
| 3.3.4 | Tap 7G / 30G / 90G / 1Y inside the chart card | exactly one chip is filled at a time, the chart and the statistics row re-read, and the card's header keeps showing the newest reading with its measured-at chip | ☐ |
| 3.3.5 | Read a history row whose value rose, then one that fell | the rise is `+` with the up arrow, the fall is `−` (a typographic minus, not a hyphen) with the down arrow, and the two are different colours; the oldest row in the window carries no delta at all. Neither colour is red-for-bad: this screen passes no verdict | ☐ |
| 3.3.6 | Tap the + FAB with Kilo selected: look at the value field **before touching anything** | the number is dimmed — it is a suggestion, not a weight the app is claiming — the keyboard is already open on that field, and both "Kaydet" (bar) and "Ölçümü Kaydet" (bottom) are disabled | ☐ |
| 3.3.6b | Same first frame, compare the suggestion with the − and + glyphs beside it *(both modes, owner QA round 2 C1)* | the suggestion is **visibly dimmer than a typed value** and dimmer than the two glyphs — a placeholder at a glance, without having to notice that Save is off. Read it once in light and once in dark: it must stay legible as a figure in both, never fade to invisible | ☐ |
| 3.3.6a | Same first frame, read what is INSIDE the value field | the dimmed suggestion is the **only** thing in it — the field's own label ("BÜYÜK TANSİYON", "KİLO", "DEĞER") appears once, as the small overline above the − / + row, and never a second time as large dimmed text behind or across the number. Two overlaid strings in the field is the owner-QA-round-1 B1 regression | ☐ |
| 3.3.7 | Tap + once | the dimmed number becomes a real one (full contrast), and both save actions turn on | ☐ |
| 3.3.8 | Open a saved weight reading in edit mode | the value is real, not a dimmed suggestion, so both "Kaydet" (bar) and "Ölçümü Kaydet" (bottom) are on from the first frame — the exact contrast to 3.3.6 when the value was still only a suggestion | ☐ |
| 3.3.9 | With Tansiyon selected, tap the FAB | the blood pressure editor opens (not weight's), the systolic field opens focused, and save stays off until **both** systolic and diastolic have a value — the pulse may be left as its suggestion and saves without one | ☐ |
| 3.3.10 | Glucose editor: tap mmol/L while the value is still only a suggestion | the suggestion converts (about 5,5), the field is still empty and save is still off. Switching back lands on 100 again | ☐ |
| 3.3.11 | Any editor: nudge a value to the very bottom or top of its range, then tap past it | the number stops at the bound rather than running past it, and saving a value at the bound is accepted | ☐ |
| 3.3.12 | Editor: rotate the device part-way through typing | focus stays where the caret is — the opening focus does not drag back to the first field | ☐ |

### 3.4 Appointments — the tabs, the maps row and delete/undo (Task 9)

Run 3.4.1–3.4.3 on a profile with at least two upcoming appointments (one today and one later) and
at least one past appointment. 3.4.3 needs a location text on one appointment; 3.4.5 is the
full-screen detail of the M15 shape that spec §4.9 describes.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 3.4.1 | Appointments root: read the two segmented tabs | "Yaklaşan (n)" / "Geçmiş (n)" — the Upcoming count is the number of appointment **cards**, not of day headers; the pill slides between the two segments and only one half of the list is on screen at once | ☐ |
| 3.4.2 | Tap "Geçmiş", then back to "Yaklaşan" | each tap moves the pill and switches the list under it; the day headers ("BUGÜN", "YARIN", a locale-spelled weekday) stay pinned per day in Upcoming; past rows show no day headers | ☐ |
| 3.4.3 | On an upcoming card with a location, tap the whole card → detail; then tap the location row | the card opens the full-screen detail (centred hero, no card behind it), and the location row shows the address with "Haritalarda aç" as its subtitle and a chevron; tapping it opens the address in Apple Maps | ☐ |
| 3.4.4 | On a detail without a location, doctor or notes | each is drawn as a dimmed placeholder row — "Konum ekle", "Doktor adı ekle", "Not ekle" — with a chevron, and tapping it opens the editor | ☐ |
| 3.4.5 | On the detail: read the four "DETAYLAR" rows and below | date row (with a time chip trailing), doctor or its placeholder, location or its placeholder, reminders or "Hatırlatıcı ekle"; then "NOTLAR" (or "Not ekle"), then the profile's health-notes note; then "Takvime Ekle" (primary) and "Sil" (destructive) — **no bottom "Düzenle"**; "Düzenle" lives in the top bar alone | ☐ |
| 3.4.6 | Tap the row's trash on a list card, confirm, then "Geri al" in the snackbar | the card leaves the list at once and comes back; nothing is written until a confirmed delete's snackbar times out | ☐ |
| 3.4.7 | VoiceOver on a list card: swipe through it | the card is announced as one button (title, doctor, location, time chip, reminder chips), the trash as its own destructive control, and the extended pill "Yeni Randevu Oluştur" is a single button | ☐ |
| 3.4.8 | Appointments root: tap the extended "Yeni Randevu Oluştur" | the editor opens; tapping a reminder offset chip selects/deselects it and the "HATIRLATICILAR" overline stays put | ☐ |

### 3.5 AI summary, doctor report and Trends — the M15 bodies (Task 11)

Run with enough logged records for the summary and the report to generate (at least three recorded
days in a week, more for a month), and on a free account for the paywall rows.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 3.5.1 | AI summary: open it; switch Haftalık / Aylık | `SalusSegmentedTabs` — the pill slides between the two labels, the selection survives a reload (the spinner shows while the next summary loads), and the new summary replaces the old | ☐ |
| 3.5.2 | AI summary: with a finished summary on screen | the accent banner "Yapay zekâ analizi" with a generated-at `SalusStatusChip` ("Yeni oluşturuldu" when fresh, "Önceki özet" when read from cache); below it the three metric tiles (ORT. TANSİYON, KAYDEDİLEN DOZ, ORT. NABIZ), each dropped when its figure is absent; the prose as a mint-dotted paragraph list; the disclaimer under it | ☐ |
| 3.5.3 | AI summary: the two pinned actions under the text | "PDF olarak paylaş" (primary) and "Analizi güncelle" (secondary); tapping refresh re-requests a summary and keeps the selected period | ☐ |
| 3.5.4 | AI summary: with too few records / a daily limit / an error | the empty, error and limit blocks render **centred** in the body (a short message sits mid-screen, a long one scrolls); the top bar's share icon (accessibility label "Doktor raporunu aç") opens the doctor report | ☐ |
| 3.5.5 | Doctor report: open it; select a period and "Rapor oluştur" | the ready body shows the accent "Raporun hazır" card with a "PDF" chip and the three metric tiles; the "BELGE ÖNİZLEME" section with a tappable preview card and its "Büyüt" trailing action; the "RAPORA DAHİL EDİLENLER" checklist with a count per section (zero counts unchecked) and the narrative row when included | ☐ |
| 3.5.5a | Doctor report: tap "Büyüt" at the very top and the very bottom of its row, beside the "BELGE ÖNİZLEME" overline | it responds from both — the whole ≥44 pt row height is tappable, not only the text's own glyph box | ☐ |
| 3.5.6 | Doctor report: preview and sharing | tapping the preview card or "Önizle" opens the in-app PDF reader; the primary "Paylaş" hands the file to the system share sheet; "Yeniden oluştur" replaces it | ☐ |
| 3.5.7 | Doctor report: with no records / no entitlement | the "Bu dönemde kayıt yok" and "Premium'a özel" blocks are centred like the summary's; only the paywall button opens the sheet | ☐ |
| 3.5.8 | Trends: open it (free) | the range tabs (1 ay / 3 ay / 6 ay / 1 yıl) are **disabled** — dimmed, not selectable, announced unavailable; the locked blur + paywall card unchanged | ☐ |
| 3.5.9 | Trends: unlock with Premium | the tabs become selectable; each metric card shows its upper-case overline (TANSİYON / KAN ŞEKERİ / KİLO), its chart, and a summary tile with the period average, the count line and the change sentence | ☐ |

### 3.6 Cycle — the "today" jump, the month and the day editor (Task 12)

Run with cycle tracking on and at least two recorded periods, so the prediction markers (recorded
`container` fill, predicted `dashed` ring, fertile `primaryContainer`, ovulation dot, today
`primary` ring) are distinguishable.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 3.6.1 | Cycle calendar: tap the "today" icon in the top bar (accessibility label "Bugüne git") | the grid jumps to the month containing today and the today cell wears the `primary` ring — from any other month | ☐ |
| 3.6.2 | Cycle calendar: tap the left/right chevrons | the month title and the grid move one month at a time; the chevrons are reachable (≥44 pt), each announced with its own label | ☐ |
| 3.6.3 | Cycle calendar: tap a cell | the **day editor opens pushed** — a system back button, an inline date title, and the tab bar slides away. It is NOT a sheet. Back returns to the same calendar month | ☐ |
| 3.6.4 | Cycle calendar: tap "Tümünü Gör" beside "BUGÜNÜN BELİRTİLERİ" | today's day editor opens pushed; the chips above are read-only (nothing on the calendar is a picker) | ☐ |
| 3.6.4a | Tap "Tümünü Gör" at the very top and the very bottom of its row, beside the "BUGÜNÜN BELİRTİLERİ" overline | it responds from both — the whole ≥44 pt row height is tappable, not only the text's own glyph box | ☐ |
| 3.6.5 | Cycle day editor: save with one symptom, a flow and a mood | editing today through the editor updates the "BUGÜNÜN BELİRTİLERİ" chips on the way back (the calendar observes the day log) | ☐ |
| 3.6.6 | Cycle day editor at a large system font | the SYMPTOMS / AKIŞ / RUH HALİ overline headers, the chip rows and the optional note all wrap without clipping | ☐ |

---

---

## 4. Dynamic Type

_Run at xxxLarge (Ayarlar → Erişilebilirlik → Ekran ve Metin Boyutu) and confirm no clipping or
truncation._ Onboarding's own xxxLarge walk is §2.19, and the screens not listed here are covered
by the generic "nothing clipped or overlapping" check of §1.

| # | Screen | Expect | ☐ |
|---|---|---|---|
| 4.1 | Vitals editors at xxxLarge (Task 8) | each stepper keeps its − and + reachable beside the number, the number itself is not clipped, and the range hint under it wraps instead of truncating. The three blood pressure steppers stack without overlapping | ☐ |
| 4.2 | Vitals list at xxxLarge (Task 8) | the three type tabs still read (a label may shorten but must not be cut mid-word), the four range chips wrap onto a second line inside the chart card rather than overflowing it, and the three statistics tiles stay on one row or wrap cleanly | ☐ |
| 4.3 | Appointments list at xxxLarge (Task 9) | the two segmented tabs still read, the "Yeni Randevu Oluştur" extended pill wraps or shortens without clipping its label, and a card's date tile and time/reminder chips stay readable and unwrapped | ☐ |
| 4.4 | Home at xxxLarge, swiping the snapshot pager through all three pages (Task 6) | the pager box is the tallest page's own measured height at this text size, so **no page is cut at the bottom** and no page leaves an empty band above the dots — the doses page with an empty state is the tallest and the one to watch; the hero's greeting and date wrap instead of truncating, and the "Tümünü Gör" action stays beside its overline rather than under it | ☐ |
| 4.5 | Medications list and editor at xxxLarge (Task 7/9) | the "İlaç ekle" extended pill keeps its label, the three metric tiles ("Aktif ilaç", "Kaydedilen doz", "Sıradaki doz") wrap rather than clip, the eight form tiles keep their labels, and a dose amount's − / + stay reachable beside the number with its range hint wrapping | ☐ |

---

## 5. Sheets and the live theme switch

The theme and language sheets (`.medium` detent, swatches, paywall gating, CLASSIC never
paywalls) are §5.3; the paywall full-screen cover is §5.4. §5.1 is the live theme switch, which is
the one row set that can force a shell change.

### 5.1 The theme sheet repaints the bars while it is open (Task 5)

This is the one thing only a device can settle (spec §10, "appearance rebuild timing"). Owner QA
round 1 found the risk to be real — a `UITabBar.appearance()` / `UINavigationBar.appearance()`
change reaches only bars created **after** the call, and every bar in the app is made once at
launch and kept — so the shell no longer relies on the proxy for the live case. It now paints the
bars three ways at once: `SalusBarRepainter` walks the live window (the tab bar, the current
stack's navigation bar, any pushed screen's bar, and the sheet's own bar, which is presented while
the user is tapping) and installs the new appearances on each; `.toolbarBackground` and
`.toolbarColorScheme` tell SwiftUI what it paints for itself; and the appearance proxies still
cover bars made after the switch. The `.id(theme.isDark)` fallback is **retired**, not pending —
it rebuilt all five tabs' content on every theme change and there is nothing left for it to fix.
A failure in this section is a bug to report, not a trigger for that fallback.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 5.1.1 | Ayarlar → Görünüm & Tema, switch Açık → Koyu without leaving the screen | the tab bar's ground darkens **immediately**, with the sheet still open and without touching the tab bar — no stale near-white bar under a dark app, and no waiting for a tab switch | ☐ |
| 5.1.2 | Same switch, watching the UNSELECTED tab icons | they move to the dark `onSurfaceVariant` **immediately**, in the same frame as the ground. Staying light-mode grey until a tab switch, a backgrounding or a relaunch is the owner-QA-round-1 B3 regression | ☐ |
| 5.1.2a | Push a screen first (Ayarlar → Profil, say), then open the theme sheet from it and switch Açık → Koyu | the **pushed** screen's navigation bar — its ground, its title and its back chevron — repaints at once too, not only the tab root's. Back out afterwards: the root's bar is right as well | ☐ |
| 5.1.3 | Same switch, watching the navigation bar | ground and title follow at once; the bar never shows the old ground behind the new title | ☐ |
| 5.1.4 | Switch Renk Teması CLASSIC → OCEAN → SUNSET → FOREST with premium on | the selected tab's icon/label follow the palette's `primary` each time, immediately | ☐ |
| 5.1.5 | Switch mode to Sistem, then flip iOS's own appearance from Control Centre | both bars repaint on return to the app | ☐ |

### 5.2 The root toolbar (Task 5)
| # | Step | Expect | ☐ |
|---|---|---|---|
| 5.2.1 | Open each of the five tabs in turn | every root shows the same bar: heart tile left, the tab's own title centred ("Ana Sayfa", "İlaçlar", "Ölçümler", "Randevular", "Daha Fazla"), bell + avatar right. No in-content header above the content anywhere | ☐ |
| 5.2.2 | Tap the bell on **each** of the five tabs | Reminder health (Hatırlatıcı sağlığı) opens, pushed onto that tab's own stack; Back returns to the tab it was opened from, not to Home | ☐ |
| 5.2.3 | Tap the avatar on **each** of the five tabs | Profile opens, pushed onto that tab's own stack; Back returns to the same tab | ☐ |
| 5.2.4 | On any pushed screen (detail, editor, Cycle, Reminder health, Profile) | NO brand tile, NO bell, NO avatar — a system back button, an inline title, and at most the screen's own trailing action | ☐ |
| 5.2.5 | Push from a tab root and look at the back button's label | it reads the root's title ("İlaçlar", "Ölçümler", …) or "Geri" when the title is too long — never blank | ☐ |
| 5.2.6 | Push anything from any tab | the tab bar slides away and comes back on Back, exactly as before (the rule is unchanged) | ☐ |
| 5.2.7 | Vitals root: the trends action | the navigation bar carries **only** the brand tile, the title, the bell and the avatar — no chart icon (Task 8 moved the action into the content, the Android M15 shape; 3.3.2 checks the same thing from the other side) | ☐ |
| 5.2.8 | Medications root: add a medication to an empty list, then delete the last one, without leaving the screen | the count is the "Aktif ilaç" metric tile in the list's own header and its number tracks the list in the same interaction. The navigation bar carries **only** the brand tile, the title, the bell and the avatar — no count chip (Task 7 retired it; 3.2.3 checks the same thing from the other side) | ☐ |
| 5.2.9 | VoiceOver on any root | the bell announces "Hatırlatıcı sağlığı", the avatar "Profil"; the brand tile is skipped | ☐ |
| 5.2.10 | Cycle calendar (pushed from Home's card and from the More row) | inline title "Döngü" with a back button, no root toolbar — and today's "Bugüne git" icon as the one trailing action | ☐ |

### 5.3 The theme and language sheets (Task 10)

The two setting pickers open over the More hub (spec §2.3). Each row is a `SalusSelectableRow`;
the mode row opens the three-mode sheet and the colour-theme row opens the same sheet, so mode and
palette share one popup. Both sheets apply their pick live and stay open.

**Run 5.3.1–5.3.10 in PORTRAIT at the DEFAULT text size first** — that is the configuration most
of the install base is in, and the one the sheet heights were wrong in. The appearance sheet's
content (three mode tiles, a section header and four palette rows) is taller than the `.medium`
detent on every iPhone, so it opens at `.medium`, scrolls inside it and drags up to `.large`. Only
after that pass, repeat 5.3.1 and 5.3.6 at the largest text size and in landscape.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 5.3.1 | More hub → Görünüm & Tema *(portrait, default text size)* | the appearance sheet slides up at the medium detent, with a drag handle, a close button and the subtitle "Seçimler anında uygulanır"; the mode tiles (Sistem / Açık / Koyu) fill the top row and the four palette rows sit under "VURGU & RENK PALETİ", each leading with its colour swatch and the CLASSIC row carrying a "Varsayılan" badge | ☐ |
| 5.3.1a | On that medium sheet, scroll the content with a drag that starts on a palette row | **every row is reachable without resizing the sheet** — the FOREST row and the gap under it can be scrolled to, and the sheet itself does not move while the content still has somewhere to go | ☐ |
| 5.3.1b | Drag the sheet's handle upwards | it snaps to full height and the whole list is visible at once; drag it back down and it returns to the medium detent, still open, with the selection unchanged | ☐ |
| 5.3.1c | Repeat 5.3.1a at the largest text size, then on the smallest device you have (SE) and in landscape | the same: the content scrolls and nothing — least of all the last palette row or the close button — is cut off or unreachable at any of them | ☐ |
| 5.3.2 | Tap the CLASSIC palette row as a free user | it selects immediately — the stored palette is persisted and the sheet stays open; **no** paywall ever (A60) | ☐ |
| 5.3.3 | Tap OCEAN / SUNSET / FOREST as a free user | the paywall opens on top and nothing is written; the stored palette is unchanged and the theme sheet is gone (the paywall is a sheet of its own) | ☐ |
| 5.3.4 | Switch Renk Teması between palettes with premium on | each tap paints the whole app under the open sheet and the row's swatch updates; the sheet stays open until the close button, the swipe or the scrim | ☐ |
| 5.3.5 | Swipe the appearance sheet down, then reopen | nothing is written on the way out — the stored mode and palette are exactly what they were before the sheet opened | ☐ |
| 5.3.6 | More hub → Uygulama dili | the language sheet slides up at the medium detent with three `SalusSelectableRow`s (Sistem dili / Türkçe / English) and the subtitle "Seçim anında uygulanır"; the three rows fit without scrolling, and the sheet has gained no scroll bounce it did not have before | ☐ |
| 5.3.7 | Tap Türkçe, then English, then back to Sistem dili | each tap repaints the whole app (the More hub and its labels included) in the chosen language while the sheet stays open; the row's selection follows the pick | ☐ |
| 5.3.8 | Swipe the language sheet down | the app has already repainted in the last picked language and stays that way; nothing else is written on the way out | ☐ |
| 5.3.9 | Open both sheets one after the other | only one is ever up at a time; the More hub behind shows the drawn palette (a lapsed subscriber sees CLASSIC here while the sheet still draws their stored OCEAN as selected) | ☐ |
| 5.3.10 | VoiceOver on the appearance sheet | each palette row announces "selected" for the stored pick; the lock glyph on a free user's locked rows is announced by its row's label, not as a separate control | ☐ |
| 5.3.11 | VoiceOver on the mode tiles (Sistem / Açık / Koyu), then on the language sheet's three rows | each group reads as **one radio set** — swiping moves within it and the chosen one announces "selected" — while each tile and each row stays individually reachable; neither group is read as three unrelated buttons | ☐ |

### 5.4 The paywall full-screen cover (Task 12)

The paywall stays a `fullScreenCover` — above the tab bar, outside every `NavigationStack`. Run on
a free account from More → a locked palette, or from a locked feature (Trends free).

| # | Step | Expect | ☐ |
|---|---|---|---|
| 5.4.1 | Open the paywall | it is full-screen (no partial sheet, no visible tab bar), slides up, and shows: the sparkles hero badge, a headline naming the feature that was locked, the subtitle, the four promises in one card, annual-first plan cards, and pinned actions below | ☐ |
| 5.4.2 | Tap a plan card | it selects — a `primary` edge and radio dot move to it, and a screen reader reads the group as one radio set ("plan of plan, selected") | ☐ |
| 5.4.3 | VoiceOver over the feature card | the four promises each announce with their own label; their small tinted tiles are decorative and skipped | ☐ |
| 5.4.4 | Tap the close button (accessibility label "Kapat") | the cover slides down and returns to what was behind it, unchanged — no purchase, no stored palette change | ☐ |
| 5.4.5 | On a flaky connection (plans failed to load) | the "Planlar şu an yüklenemedi" note and a "Tekrar dene" button appear; retry asks the store again without leaving the cover | ☐ |

---

## 6. Known risks

Each of these is a place the implementation made a judgement that only a device can settle.
Note what actually happens, not just pass/fail.

**Task 1 — two CLASSIC-light accent pairs below AA.** The token layer's recorded shortfalls are
the medications (4.45:1) and vitals (4.05:1) feature-accent pairs in CLASSIC light, carried on the
Android ledger and not fixed by the token test (`salus-android` design-tokens §14.1). They are
Android's numbers and they are the same here; any *new* pair below AA fails
`SalusColorSchemeContrastTests`. Note only whether either reads as illegible on a device — the
pairs themselves are a cross-platform decision, not an iOS finding.

**Task 5 — repainting the live bars.** §5.1 is the whole of it. The appearance proxies reach only
bars created after the call, which owner QA round 1 confirmed is every bar in the app: they are
made once at launch and kept. `SalusBarRepainter` now walks the live window on every theme change
and paints the bars it finds, and `.toolbarColorScheme` tells SwiftUI's own title and chrome
colours the same news. Nothing automated can run a live theme switch — the walk itself is unit
tested (`SalusBarRepainterTests`), but every `UIKit` line around it is compiled out of the macOS
host that runs `swift test` — so §5.1.1, §5.1.2 and §5.1.2a are the rows that settle it. Note what
actually happens on each: "repaints at once", "repaints after a tab switch", or "only after
relaunch". The `.id(theme.isDark)` fallback is retired; a failure here is a bug to report.

**Task 5 — a third trailing control beside the shell's own two: closed.** Both screens that used
to add one have given it up — Task 7 moved Medications' count into the list's own "Aktif ilaç"
metric tile (§3.2.3, §5.2.8) and Task 8 moved Vitals' trends icon into the chart section header
(§3.3.2, §5.2.7), each following the Android M15 shape. No root adds a trailing control to the
shell's bell and avatar any more; §5.2.7 and §3.2.3 are now the rows that prove it stayed that way.

**Task 8 — the stepper's commit, and the opening focus.** `SalusStepperField` commits a typed
number on the keyboard's Done or on the field losing focus, and opens focused once per view
instance; neither is something a unit test can observe. §3.3.6–§3.3.8 and §3.3.12 are the rows
that settle them. Note in particular whether a value typed and then saved **without** dismissing
the keyboard is the value that gets stored.

**Task 10 — sheet hosting on a wide layout.** §5.3 is the whole of it: the appearance and
language pickers are `.medium`-detent sheets presented from the `MoreScreen` body, and a detent is
a fraction of the *presenting* container. On an iPad-class width, or on an iPhone in landscape, a
medium detent can leave the palette rows below the fold or, in the other direction, leave half the
sheet empty. Nothing automated can measure a detent. Run §5.3.1 and §5.3.6 once in landscape and
once on the widest device available, and note whether the four palette rows and the three language
rows are all reachable without the sheet having to be dragged up.

**Tasks 3 and 6 — xxxLarge: the stepper's range hint and the Home pager's measured height.**
(a) `SalusStepperField` draws its range hint under the number; §4.1 is the row that says whether it
wraps or truncates at xxxLarge, and the medication editor's dose amount (§3.2.12) is the second
caller. (b) Home's snapshot pager has no intrinsic height of its own — SwiftUI's `TabView(.page)`
never has (spec §9 (p)) — so since owner QA round 1 it measures a hidden copy of its pages at the
pager's width and takes the tallest one's natural height. That removes the clipping-and-gap
judgement the old fixed `HomePagerDefaults.height` carried, but it moves the risk rather than
deleting it: the measurement is a layout pass behind the first frame
(`HomePagerDefaults.fallbackHeight` seeds that one pass), and a hidden second copy of three cards
is laid out on every Home update. §3.1.2a and §4.4 are the rows. Note any visible one-frame jump in
the box's height on arrival at Home or on a Dynamic Type change, and any page still cut at the
bottom at xxxLarge.

**Task 13 — the onboarding finish is a race the tests can only half-see.** §2.13 and §2.14 are
the rows. The completion flag is written from a detached task and the notification prompt is the
system's, so "the effect arrived" and "the flag was written" are two events on a device and the
unit tests wait on the second only. What a device settles: whether the prompt ever blocks the
landing on Home (it must not), whether declining is as harmless as accepting, and whether a kill
mid-save (§2.18) replays the flow rather than leaving a half-filled profile behind a closed gate.

**Task 13 — the reminder row is one accessibility element, not a whole-row tap target.** Android
makes the `SalusListItem` clickable *and* puts a `Switch` in it; on iOS a `Button` wrapped around
a `Toggle` swallows the toggle's own gesture, so the row is combined instead
(`.accessibilityElement(children: .combine)`): VoiceOver reads title + subtitle + state as one
control and a double-tap flips it (§2.23), while a *sighted* user must hit the switch itself — a
native ≥44 pt target, but a smaller one than the whole row. Recorded as spec §9 (w). Note whether
tapping the row's text and getting nothing reads as broken on a device; if it does, the fix is a
`Toggle` with a custom label, which stops being `SalusListItem`.

**Task 12 — the Cycle top-bar overline is a content line.** Android's `SalusTopBar.Pushed(overline:)`
puts "SALUS HEALTH" inside the top bar above the title; iOS's pushed nav bar has no overline slot,
so the overline is spent in content above the month header (the same convention Profile's
"HESAP" and Home's "BUGÜN" already use). Nothing is lost but its attachment to the scroll: it
scrolls away with the month header. This is a recorded divergence, not a bug — §3.6 has no row for
it because the intended position is the content line. Note only if it reads as a defect on screen.

---

## Result

| Section | Pass | Notes |
|---|---|---|
| 1 theme matrix | | |
| 2 onboarding | | |
| 3 gestures | | |
| 4 Dynamic Type | | |
| 5 sheets + live switch | | |
| 6 known risks | | |
