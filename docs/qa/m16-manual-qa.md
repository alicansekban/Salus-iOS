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

_To be filled by the component and screen tasks — swipe, delete, undo, maps._

---

## 4. Dynamic Type

_To be filled — run at xxxLarge and confirm no clipping or truncation on each root screen._

---

## 5. Sheets

_To be filled by Tasks 5 and 10 — theme/language sheets (`.medium` detent, swatches, paywall
gating, CLASSIC never paywalls) and the paywall full-screen cover._

---

## 6. Known risks

Each of these is a place the implementation made a judgement that only a device can settle.
Note what actually happens, not just pass/fail.

_To be filled as later tasks surface them — the token layer's recorded shortfalls are the two
CLASSIC-light feature-accent pairs (medications 4.45:1, vitals 4.05:1) kept on the Android
ledger, not fixed by the token test (`salus-android` design-tokens §14.1)._

---

## Result

| Section | Pass | Notes |
|---|---|---|
| 1 theme matrix | | |
| 2 onboarding | | |
| 3 gestures | | |
| 4 Dynamic Type | | |
| 5 sheets | | |
| 6 known risks | | |
