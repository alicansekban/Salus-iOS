# M16 UI overhaul — manual QA (iOS)

Spec: `docs/superpowers/specs/2026-09-12-ios-m16-ui-overhaul-design.md` (deviations in its §9).
Branch: `m16-ui-overhaul`. Tokens: `salus-android/docs/design/design-tokens.md` §8.1 + §14.
Automated coverage: `SalusColorSchemeContrastTests` (WCAG AA across 2 modes × 4 palettes on the
Material and accent-derived roles), `SalusDesignTokensTests` (233 tokens), `SalusThemeTests`
(theme resolution and `swatch(dark:)`), `SalusPremiumExtendedColorsTests` (per-palette extended
values, status colours never move, palette-independent roles never move). Full automation:
`scripts/ci.sh` green before this sheet is run.

This is a **reskin** milestone: no behaviour was meant to change, so anything that behaves
differently from the last milestone is a finding even when it looks right. The deliberate
changes live in the spec; the token layer alone is covered in Task 1, and the component and
screen restyles land in later tasks and append their rows here.

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

L = light, D = dark. The screen matrix header is the contract later tasks append rows under.

| Screen | Light CLASSIC | Dark CLASSIC | OCEAN L | OCEAN D | SUNSET L | SUNSET D | FOREST L | FOREST D |
|---|---|---|---|---|---|---|---|---|
| Onboarding | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
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

Onboarding is only reachable on a fresh install; its row can be checked once per palette by
resetting the app (Settings → General → Transfer or Reset iPhone → Erase All Content and
Settings is heavy, so prefer removing the app's data/reinstall) rather than re-installing;
check light first, matching the mockups.

---

## 2. Onboarding flow

_To be filled by Task 13 — the three-step machine: Welcome → Personal details → Health notes and
permissions._

---

## 3. Gestures

_The remaining rows are filled by the other screen tasks — swipe to delete, undo, maps._

### 3.1 Home's snapshot pager and its entrance (Task 6)

The pager is the one `TabView` outside `App/` (spec §4.1) and the only horizontal gesture on a tab
root, so it is checked on its own. Run 3.1.1–3.1.4 on a profile that has **all three** pages
(medications with a dose today, at least one measurement and cycle tracking on) and 3.1.5 on a
profile with no cycle.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 3.1.1 | Home root: swipe the snapshot card left, then right | it pages one card at a time — doses → Ölçümler → Döngü and back; it never scrolls half a card and never jumps two | ☐ |
| 3.1.2 | Watch the dots under the card while swiping | exactly three dots; the active one is a stretched pill in the palette's `primary` and it moves with the card, not after it | ☐ |
| 3.1.3 | Swipe the pager while the page is scrolled halfway down | the horizontal swipe pages the card and does **not** scroll the screen; a vertical drag starting on the card scrolls the screen and does not page | ☐ |
| 3.1.4 | On the doses page, tap "Alındı" | the dose is recorded (the ring's number goes up) and the Medications tab does **not** open; tapping anywhere else on that card opens Medications | ☐ |
| 3.1.5 | A profile with no cycle tracking | two pages and two dots — never a third, empty card | ☐ |
| 3.1.6 | VoiceOver, swipe between pages | each page announces its own label ("Bugünün dozları kartı", "Ölçümler kartı", "Döngü kartı") and its contents stay individually reachable; the dots are not announced | ☐ |
| 3.1.7 | Cold start on Home, watching the five blocks | hero, readiness card (when shown), pager, AI card and appointments fade and settle **in that order**, one short step apart — never all at once and never out of order | ☐ |
| 3.1.8 | Switch to another tab and come back to Home | Home is already settled — the entrance does **not** replay (spec §3.5). If it does replay, note it: that is the `@SceneStorage` escalation the spec records | ☐ |
| 3.1.9 | Reduce Motion on (Ayarlar → Erişilebilirlik → Hareket), open Home | the five blocks arrive together on one short curve — no staggered ladder down the screen; note anything that still slides a visible distance | ☐ |

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
| 3.3.4 | Tap 7G / 30G / 90G / 1Y inside the chart card | exactly one chip is filled at a time, the chart and the statistics row re-read, and the card's header keeps showing the newest reading with its measured-at chip | ☐ |
| 3.3.5 | Read a history row whose value rose, then one that fell | the rise is `+` with the up arrow, the fall is `−` (a typographic minus, not a hyphen) with the down arrow, and the two are different colours; the oldest row in the window carries no delta at all. Neither colour is red-for-bad: this screen passes no verdict | ☐ |
| 3.3.6 | Tap the + FAB with Kilo selected: look at the value field **before touching anything** | the number is dimmed — it is a suggestion, not a weight the app is claiming — the keyboard is already open on that field, and both "Kaydet" (bar) and "Ölçümü Kaydet" (bottom) are disabled | ☐ |
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

---

---

## 4. Dynamic Type

_Run at xxxLarge (Ayarlar → Erişilebilirlik → Ekran ve Metin Boyutu) and confirm no clipping or
truncation. The remaining rows are filled by the other screen tasks._

| # | Screen | Expect | ☐ |
|---|---|---|---|
| 4.1 | Vitals editors at xxxLarge (Task 8) | each stepper keeps its − and + reachable beside the number, the number itself is not clipped, and the range hint under it wraps instead of truncating. The three blood pressure steppers stack without overlapping | ☐ |
| 4.2 | Vitals list at xxxLarge (Task 8) | the three type tabs still read (a label may shorten but must not be cut mid-word), the four range chips wrap onto a second line inside the chart card rather than overflowing it, and the three statistics tiles stay on one row or wrap cleanly | ☐ |
| 4.3 | Appointments list at xxxLarge (Task 9) | the two segmented tabs still read, the "Yeni Randevu Oluştur" extended pill wraps or shortens without clipping its label, and a card's date tile and time/reminder chips stay readable and unwrapped | ☐ |

---

## 5. Sheets and the live theme switch

_Theme/language sheets (`.medium` detent, swatches, paywall gating, CLASSIC never paywalls) and the
paywall full-screen cover are Task 10's rows._

### 5.1 The theme sheet repaints the bars while it is open (Task 5)

This is the one thing only a device can settle (spec §10, "appearance rebuild timing"): a
`UITabBar.appearance()` change reaches bars created **after** the call, so the shell repaints the
two grounds through SwiftUI (`.toolbarBackground`) and everything else through the appearance
proxy. If any row here fails, the recorded fallback is `.id(theme.isDark)` on the `TabView` in
`RootView.tabs` — deliberately not taken today, because it rebuilds all five tabs' content on every
theme change.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 5.1.1 | Ayarlar → Görünüm & Tema, switch Açık → Koyu without leaving the screen | the tab bar's ground darkens **immediately** — no stale near-white bar under a dark app | ☐ |
| 5.1.2 | Same switch, watching the UNSELECTED tab icons | they move to the dark `onSurfaceVariant` immediately; if they stay light-mode grey until the app is backgrounded and reopened, note it — that is the proxy-timing risk | ☐ |
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
| 5.2.10 | Cycle calendar (pushed from Home's card and from the More row) | inline title "Döngü" with a back button, no root toolbar | ☐ |

### 5.3 The theme and language sheets (Task 10)

The two setting pickers are `.medium` sheets over the More hub (spec §2.3). Each row is a
`SalusSelectableRow`; the mode row opens the three-mode sheet and the colour-theme row opens the
same sheet, so mode and palette share one popup. Both sheets apply their pick live and stay open.

| # | Step | Expect | ☐ |
|---|---|---|---|
| 5.3.1 | More hub → Görünüm & Tema | the appearance sheet slides up at the medium detent, with a drag handle, a close button and the subtitle "Seçimler anında uygulanır"; the mode tiles (Sistem / Açık / Koyu) fill the top row and the four palette rows sit under "VURGU & RENK PALETİ", each leading with its colour swatch and the CLASSIC row carrying a "Varsayılan" badge | ☐ |
| 5.3.2 | Tap the CLASSIC palette row as a free user | it selects immediately — the stored palette is persisted and the sheet stays open; **no** paywall ever (A60) | ☐ |
| 5.3.3 | Tap OCEAN / SUNSET / FOREST as a free user | the paywall opens on top and nothing is written; the stored palette is unchanged and the theme sheet is gone (the paywall is a sheet of its own) | ☐ |
| 5.3.4 | Switch Renk Teması between palettes with premium on | each tap paints the whole app under the open sheet and the row's swatch updates; the sheet stays open until the close button, the swipe or the scrim | ☐ |
| 5.3.5 | Swipe the appearance sheet down, then reopen | nothing is written on the way out — the stored mode and palette are exactly what they were before the sheet opened | ☐ |
| 5.3.6 | More hub → Uygulama dili | the language sheet slides up at the medium detent with three `SalusSelectableRow`s (Sistem dili / Türkçe / English) and the subtitle "Seçim anında uygulanır" | ☐ |
| 5.3.7 | Tap Türkçe, then English, then back to Sistem dili | each tap repaints the whole app (the More hub and its labels included) in the chosen language while the sheet stays open; the row's selection follows the pick | ☐ |
| 5.3.8 | Swipe the language sheet down | the app has already repainted in the last picked language and stays that way; nothing else is written on the way out | ☐ |
| 5.3.9 | Open both sheets one after the other | only one is ever up at a time; the More hub behind shows the drawn palette (a lapsed subscriber sees CLASSIC here while the sheet still draws their stored OCEAN as selected) | ☐ |
| 5.3.10 | VoiceOver on the appearance sheet | each palette row announces "selected" for the stored pick; the lock glyph on a free user's locked rows is announced by its row's label, not as a separate control | ☐ |


---

## 6. Known risks

Each of these is a place the implementation made a judgement that only a device can settle.
Note what actually happens, not just pass/fail.

_To be filled as later tasks surface them — the token layer's recorded shortfalls are the two
CLASSIC-light feature-accent pairs (medications 4.45:1, vitals 4.05:1) kept on the Android
ledger, not fixed by the token test (`salus-android` design-tokens §14.1)._

**Task 5 — appearance-proxy timing.** §5.1 is the whole of it: the unselected tab-item colour and
the navigation-bar title font are set on `UITabBar.appearance()` / `UINavigationBar.appearance()`,
which reach bars created after the call. Nothing automated can run a live theme switch, so §5.1.2
is the row that decides whether `.id(theme.isDark)` on the `TabView` has to be added. Note what
actually happens — "repaints at once", "repaints after a tab switch", or "only after relaunch".

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
