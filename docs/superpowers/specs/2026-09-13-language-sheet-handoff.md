# 2026-09-13 — HANDOFF: Language picker joins the appearance sheet

> **Status: done.** The merge shipped on both platforms, together with two
> owner-QA follow-ups the design doc records: the sheet opens at its own
> content height (`skipPartiallyExpanded` / `.fitted`), and each named language
> leads with its flag (🇹🇷 / 🇺🇸) while "system language" keeps the globe. The
> debug hooks named below are reverted. What is kept here is the evidence trail
> for the iOS 26 sheet-squeeze, which is the reason the merge happened at all.

> **Purpose of this file.** If the current session hits its limit, another
> model (any model, any harness) should be able to pick the work up from this
> document alone. Read top to bottom, then execute the "Remaining steps"
> checklist. Turkish is the conversation language with the owner; all code,
> comments, commits and docs are English.

## The one-paragraph version

The owner reported the iOS language bottom sheet not filling the screen's
width (gaps at both edges) while the theme sheet was fine. Root cause, proven
by experiment: **iOS 26 Liquid Glass horizontally squeezes sheets whose
custom-height detent is below ≈360 pt (26.0) / ≈400 pt (26.4)** — the language
sheet is 244 pt, hence ≈11 pt gaps per side; no SwiftUI modifier disables it
(seven attempts, all verified failures). The owner-approved fix is **not** an
iOS hack: merge the language picker into the appearance sheet on **both
platforms** (a third section, three `SalusChoiceTile`s: Sistem dili / Türkçe /
English), delete the separate `LanguageSheet`, rename the sheet title to
"Görünüm ve Dil". The merged sheet is tall enough that the squeeze never
triggers, on any OS version. The design is fully written and approved:
**`docs/superpowers/specs/2026-09-13-language-joins-appearance-sheet-design.md`**
(in the **Android** repo — it is the source of truth). Android must land first
or in the same change window; iOS mirrors it 1:1.

## State of the tree right now

**Committed work:** the redesign milestone's QA-round commits (up to
`abfffda fix(settings): the profile form keeps the twin's lg above its first
label` on `salus-ios`). Both repos are on their milestone branches; run
`git status` / `git log --oneline -5` in each to confirm the starting point.

**UNCOMMITTED — TEMPORARY DEBUG HOOKS that must be REVERTED before any
final commit.** Three edits exist solely so QA automation could open the
sheets without touch synthesis:

1. `salus-ios/Packages/Features/FeatureSettings/Sources/FeatureSettings/ui/more/MoreScreen.swift`
   — an `.onAppear` after `#endif` in the `MoreScreen` body that reads launch
   args `-qaOpenLanguageSheet` / `-qaOpenThemeSheet` and fires
   `onEvent(.languageSheetOpened)` / `onEvent(.themeSheetOpened)`.
2. `salus-ios/App/RootView.swift` — an `.onAppear` on the `TabView` chain
   reading `-qaTabMore` and calling `backStacks.switchTopLevel(.more)`.
3. `salus-ios/Packages/SalusUI/Sources/SalusUI/component/SalusBottomSheet.swift`
   — two `// TEMPORARY QA DEBUG — revert before commit.` `print("[QA] …")`
   lines (one in `onPreferenceChange`, one `onAppear` inside the measuring
   copy's `GeometryReader`).

Each is marked `// TEMPORARY QA DEBUG — revert before commit.` —
`grep -rn "TEMPORARY QA DEBUG" salus-ios/` finds them all. **The merge work
deletes some of their host code anyway (the language-sheet event disappears),
but the hooks must not survive into the final diff.**

**Throwaway, outside the repos:** `/tmp/sheet-harness/` (an isolated SwiftUI
app that embedded the real `salusBottomSheet` to bisect the squeeze) and
`/tmp/salus-qa/` (screenshots + logs). Ignore or delete; nothing there is
referenced by the repos.

## Evidence trail (why the fix is "merge", not a modifier)

If anyone re-questions the root cause, the proof chain is:

1. **Repro in the real app**: built `Salus.app`, launched on the iPhone 17 Pro
   Max simulator (iOS 26.0) with the debug hooks above, screenshotted, and
   pixel-scanned the `surfaceContainer` (light `0xF1F6F2`) span. Language
   sheet: x 33..1286 px on a 1320 px screen (≈11 pt gaps/side). Theme sheet:
   x 9..1310 — full width. Same component, same anchor, same modifier chain.
2. **Isolation**: an out-of-repo harness app drove the *real*
   `salusBottomSheet` with a fitted sheet at different measured heights:
   191 pt → 415/440 pt wide (squeezed), 244 pt → squeezed, ~308 pt → mildly,
   ≥~360 pt → full width. So: **the squeeze is a pure function of detent
   height on iOS 26**.
3. **Version check**: iOS 17.5 (SE) and iOS 18.2 — no squeeze at any height;
   iOS 26.0 threshold ≈360 pt, iOS 26.4 (17 Pro) threshold ≈400 pt, inset
   scales with missing height (10 pt/side at 244 pt on 26.4). Threshold is
   OS-dependent → hardcoding a min detent height would be fragile.
4. **API dead ends, all tested on-simulator**: `presentationSizing(.page)`,
   `.automatic.fitted(horizontal:vertical:)`, `.automatic.sticky(...)`,
   removing `presentationCornerRadius`, `presentationDragIndicator(.hidden)`,
   detent sets like `[.height(h), .large]` / `[.height(h), .medium]`,
   `presentationBackground` with a 5000-pt-wide bleeding view, and dropping
   `presentationBackground` to paint the content instead — the squeeze applies
   to the container AND the content frame (proven: content's own red
   background measured 431 pt on a 440 pt screen). Nothing in
   `grep "func presentation" SwiftUI.swiftinterface` disables it.
5. **The fitted measurement is correct** (244 pt logged from the hidden
   measuring copy; header + 3 rows + spacer). `SalusBottomSheet` itself is
   fine — do not "fix" it.

## The approved design (summary — full text in the spec)

- One sheet: Görünüm modu tiles → Renk paleti rows → **UYGULAMA DİLİ tiles
  (new)** → trailing spacer. Language tiles: Sistem dili / Türkçe / English,
  `globe` icon each, selection via the tile's own state, tap sends the
  existing `SelectLanguage(AppLanguage)` event (apply-straight-through
  unchanged).
- Hub unchanged (3 rows, value previews); the language row now sends
  `ThemeSheetOpened`.
- Delete `LanguageSheet` (kt + swift), `isLanguageSheetOpen`,
  `LanguageSheetOpened`, `LanguageSheetDismissed` on both platforms.
- Title: `theme_sheet_title` → "Görünüm ve Dil" / "Appearance and Language".
  New overline key `theme_section_language` ("UYGULAMA DİLİ" / "APP
  LANGUAGE", upper-case in the resource per the overline rule). Reuse
  `language_system`/`language_turkish`/`language_english` verbatim. Delete the
  orphaned `language_title` and `language_sheet_subtitle` keys. `more_language`
  stays.
- iOS sizing stays `.detents([.medium, .large])`; Android needs nothing.
- Owner rulings, already made — do not re-ask: merge on both platforms; tiles
  (not rows) for language; language section at the BOTTOM, no scroll-to
  behaviour; hub rows stay; sheet title updated.
- Tests: Android unit tests adapt; iOS `MoreViewModelTests` folds the
  language-sheet open/close tests into theme-sheet ones and deletes the
  dismiss ones; settings string-parity pins updated. QA sheets: rewrite iOS
  M16 §5.3 rows for the merged sheet and add a full-width pixel-scan row.
- **Do NOT touch** `SalusBottomSheet`/`salusBottomSheet`, the onboarding
  privacy sheet, or anything outside `feature/settings` (Android) /
  `FeatureSettings` (iOS) + the shared string catalogs.

## Remaining steps (in order)

1. **Revert the three debug hooks** (`grep -rn "TEMPORARY QA DEBUG"
   salus-ios/`); keep the grep output empty before the final commit.
2. **Android first** (source of truth): apply the design to
   `ThemeSheet.kt`, `LanguageSheet.kt` (delete), `MoreSections.kt`,
   `MoreScreen.kt`, `MoreUiState.kt`, `MoreViewModel.kt`, `strings.xml`
   (base + `values-en`), previews. Run the module's unit tests
   (`./gradlew :feature:settings:test` from `salus-android/`) and lint.
3. **iOS mirror**: the same file set under
   `salus-ios/Packages/Features/FeatureSettings/…` + `SettingsStrings.swift`
   + `Localizable.xcstrings`; delete `LanguageSheet.swift`; run
   `scripts/lint.sh` (repo root) and `swift test` inside the
   `FeatureSettings` package; string-parity test updated in the same commit.
4. **Docs**: iOS `docs/qa/m16-manual-qa.md` §5.3 rewritten; the M16 spec's
   §9 language-sheet rationale note superseded (the new design doc is the
   reference); Android QA doc updated likewise if an equivalent row exists.
5. **Verify visually** (the loop is proven): rebuild the iOS app, boot the
   iPhone 17 Pro Max simulator, reinstall, and — with the debug hooks
   temporarily re-applied if needed, then reverted — open the merged sheet
   and pixel-scan: the sheet's ground must span the full screen width at
   `.medium`, and the language section must be reachable by scrolling at the
   largest Dynamic Type. Android: emulator/phone check of the same rows.
6. **Commits**: one conventional commit per platform (e.g.
   `feat(settings): merge the language picker into the appearance sheet`),
   English, no secrets, hooks reverted before commit. Do not push/PR unless
   the owner asks.

## Owner's QA loop for this fix (what "done" looks like)

- More hub → any of the three appearance rows → the merged sheet opens
  full-width on iOS 26 (no gaps), scrolled: mode tiles, palette rows, then
  UYGULAMA DİLİ tiles at the bottom.
- Tap Türkçe/English/Sistem dili → whole app repaints in the chosen language
  and the sheet closes with the repaint (a locale change recreates Android's
  activity; iOS mirrors it — owner ruling, 2026-09-13). Reopen: the tile picked
  is the selected one.
- Both hub sheets' open/close flows: nothing else written on dismissal.
- iOS 17-18 device if available: identical behaviour (squeeze never existed
  there; the merged sheet must not regress it).
- `scripts/ci.sh` green on iOS; Android build + tests green.