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
| Vitals editors | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
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
  it (emerald→rose in CLASSIC), and the "Yeni Özet" button is the palette's `primary`.
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

---

## 4. Dynamic Type

_To be filled — run at xxxLarge and confirm no clipping or truncation on each root screen._

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
| 5.2.7 | Vitals root: the trends action | still reachable, now as the chart icon in the navigation bar beside the bell and avatar; three trailing controls plus the title must not clip on the narrowest device | ☐ |
| 5.2.8 | Medications root: add a medication to an empty list, then delete the last one, without leaving the screen | the count chip appears and disappears with the list, in the same interaction — it sits in the navigation bar beside the bell and avatar, and its number tracks the list | ☐ |
| 5.2.9 | VoiceOver on any root | the bell announces "Hatırlatıcı sağlığı", the avatar "Profil"; the brand tile is skipped | ☐ |
| 5.2.10 | Cycle calendar (pushed from Home's card and from the More row) | inline title "Döngü" with a back button, no root toolbar | ☐ |

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

**Task 5 — two trailing controls plus a screen action.** Vitals (chart icon) and Medications (count
chip) put a third control in the bar beside the shell's bell and avatar (§5.2.7, §5.2.8). Android
M15 moved both into the content, which Tasks 7 and 8 mirror; until then, check the narrowest
supported device and the largest Dynamic Type size for clipping and note what truncates.

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
