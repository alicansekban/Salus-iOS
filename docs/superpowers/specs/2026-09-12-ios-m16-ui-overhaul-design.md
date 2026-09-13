# iOS-M16 — UI Overhaul (Android M15 mirror) — Design

**Branch:** `m16-ui-overhaul` (cut from `main` at `67b7e3a`). **Scope:** iOS only — the visual
mirror of the Android M15 UI overhaul, which shipped in `salus-android` main `529a30f`
(2026-09-12, versionCode 10). **Date:** 2026-09-12.

**Android source of truth** (all paths under `../salus-android/`):

| What | Where |
|---|---|
| The M15 design spec, incl. §13 rulings and §13.1 owner-QA amendments | `docs/superpowers/specs/2026-09-11-m15-ui-overhaul-design.md` |
| Token values and the M15 change log | `docs/design/design-tokens.md` §1–§4, §6, §8.1, §9, §11, §14 |
| Component twins | `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/*.kt` |
| Token twins | `core/designsystem/src/main/kotlin/com/alicansekban/salus/core/designsystem/theme/*.kt` |
| Parity rows this milestone closes | `docs/parity-ledger.md` A43, A47–A62 |
| Owner's manual QA sheet (the iOS sheet mirrors its structure) | `docs/qa/m15-manual-qa.md` |

---

## Goal

Give the iOS app the same "Ambient Emerald Health" look the Android app got in M15 — the new
token set in every mode and palette, the restyled and new shared components, every screen
restyled to the Figma set, and the three-page onboarding — while keeping iOS's native chrome
(system `TabView`, system navigation bar). Phase 1 is visual: no business feature is added.

## Non-goals (Phase 1 boundaries)

- No new business features. Android's §10 Phase-2 candidates stay out.
- No custom tab bar, no custom top bar, no sliding tab pill (decisions Q1/Q2 below).
- No data-layer or Room/GRDB change; no schema, no migration.
- No snapshot-test tooling; views stay `#Preview`-build-only (standing policy).
- No iPad or macOS layout work; macOS stays a test-only platform.
- No Liquid Glass / iOS 26 API adoption; the deployment target stays iOS 17.0.

## Decisions record (brainstorming answers, 2026-09-12)

| # | Question | Decision |
|---|---|---|
| Q1 | Tab bar: custom floating pill (Android twin) / native `TabView` / hybrid | **Native `TabView`, painted with tokens.** The Android `SalusBottomBar` is not mirrored. |
| Q2 | Top bar: native navigation bar everywhere / in-content header on roots / custom overlay | **Native navigation bar everywhere**, inline titles; the shell applies one root toolbar (brand tile, bell, avatar). `SalusScreenHeader` is retired. |
| Q3 | Onboarding: port the 3-page machine / keep 8 steps / hybrid | **Port the Android three-page machine 1:1.** |
| — | Work shape | Bottom-up in M15 order (tokens → components → shell → screens → onboarding → docs/QA), one branch, Opus executors, independent tasks in parallel worktrees. |
| — | Verification | Existing standard: unit tests per package, `scripts/ci.sh` gate, manual QA written by executors and run by the owner. No simulator work in executor steps. |

---

## 1. Token layer (`Packages/SalusDesignSystem`)

Single source: Android `design-tokens.md` §14.1–§14.4 (the M15 change log) and the Kotlin files
it cites. Every value is copied, never re-derived; the executor re-reads the Android file at
execution time and cites `file:line` in the Swift header comment (the M7/M14 drift rule).

### 1.1 Material roles

`SalusColorScheme.light` / `.dark` (`SalusColorScheme.swift`) are re-valued row by row to the
§14.1 (dark) and §14.2 (light) targets. Headline values, for orientation only — the Android
tables are binding:

| Role | Dark | Light |
|---|---|---|
| `primary` / `onPrimary` | `#34D399` / `#022C22` | `#065F46` / (unchanged) |
| `primaryContainer` / `onPrimaryContainer` | `#064E3B` / `#A7F3D0` | `#D1FAE5` / `#064E3B` |
| `tertiary` / `tertiaryContainer` | `#FB7185` / `#4C0519` | `#E11D48` / `#FFE4E6` |
| `background` = `surface` | `#090D0B` | `#F1F5F2` |
| `onSurface` / `onSurfaceVariant` | `#E6EBE7` / `#9CA8A1` | (per §14.2) |
| `outline` / `outlineVariant` | `#2A352E` / `#1C2420` | `#D6E2DA` / `#E4ECE7` |
| surface container ladder (dark) | `#0E1311` → `#131917` → `#182019` → `#1E2823` → `#243029` | (per §14.2) |

### 1.2 Premium palettes

The eight static tables in `SalusPremiumAccents.swift` and the three
`SalusPremiumExtendedColors{Ocean,Sunset,Forest}.swift` files take the §14.4 values, including
the retuned light primaries (OCEAN `#155E75`, SUNSET `#9A3412`, FOREST `#166534`) and the
owner-QA medication accents (OCEAN → azure, FOREST → olive/lime, §14.8). CLASSIC is the §1.1
scheme. `PremiumTheme.swatch(dark:)` is added (`PremiumThemeColors.kt:130-135` twin) for the
theme sheet's swatches.

### 1.3 `SalusExtendedColors` — new fields

`SalusExtendedColors.swift` gains, for every mode × palette, the six Android fields
(`ExtendedColors.kt`): `cardBorder` (= `outline`), `accentGlow` (`primary` at 24 % dark /
16 % light), `overline` (`#10B981` dark / `#065F46` light), `metricUp` (= `primary`),
`metricDown` (= `tertiary`, never moves with the palette), `aiGradient` (a `SalusGradient`
`primary` → `tertiary`). `cycle` becomes the `tertiary` family; `hero` dark becomes canvas →
palette `primaryContainer` (`#090D0B` → `#064E3B` for CLASSIC). `success`, `warning` and the
other feature accents are unchanged. `featureAccents` keeps its shape.

### 1.4 Typography (`SalusTypography.swift`)

System font (SF) stays. Changes per §14.6: `displaySmall` is added (36 / Bold, Dynamic Type
`.largeTitle` base); `headlineMedium` 26 / Bold / −0.5 tracking; `titleLarge` 20 / SemiBold;
`labelMedium` pinned 12 / Medium (chip role); `labelSmall` 11 / SemiBold / +1.2 tracking (the
overline role). The 1:1 sp→pt rule and the existing Dynamic Type style mapping stay.

### 1.5 Shape, elevation, motion

- `SalusShapes.medium` 16 → 14 pt, `.large` 24 → 20 pt; `extraSmall` 8, `small` 12,
  `extraLarge` 28 unchanged (`SalusDimensions.swift`).
- Elevation semantics change, not the constants: in **dark** mode nothing draws a shadow —
  hierarchy is the `cardBorder` line plus a surface-container step; in **light** mode
  `SalusShadow` applies as today. `SalusCard` (§3) is the only place that decides this.
- `SalusMotion.swift` adds the segmented-tabs slide (`stateChangeDurationSeconds` + the
  push/pop easing — Android `tween(Normal, FastOutSlowIn)`) as a named token, and the
  entrance-once rule (§3.5). No bottom-bar spring: there is no custom bar (Q1).

### 1.6 Tests (`SalusDesignSystemTests`)

`SalusDesignTokensTests` is re-pinned to the new values. The contrast suite grows to the
Android pairs (`SalusColorSchemeContrastTest` / `PremiumExtendedColorsTest` twins): for each of
2 modes × 4 palettes, WCAG AA ≥ 4.5:1 on `onSurface`/`surface`, `primary`/`onPrimary`,
`onSurfaceVariant`/`surfaceContainerLow`, `overline`/`surfaceContainerLow`, `error`/`surface`,
`metricUp`/`surfaceContainerLow`; `cardBorder` differs from `surfaceContainerLow` by the same
minimum luminance delta Android asserts. The existing "status colours never move" and "premium
differs from classic" tests stay. Known and accepted: the two CLASSIC light pairs Android
records as below AA (`salus-premium-theme-feature-accents` note) stay documented, not fixed
here.

### 1.7 Documentation

Android `design-tokens.md` is the shared token doc: its `iOS pending (M16)` cells flip to iOS
`file:line` in a docs commit in `salus-android` at the end of this milestone (docs only, no
code). The iOS repo carries no second token doc.

---

## 2. App shell (`App/`)

### 2.1 Tab bar — system `TabView`, painted

`RootView.swift` keeps `TabView(selection:)` over `RootTab.allCases` and the per-tab
`NavigationStack`s of `RootNavigationStack.swift`. Painting:

- Bar ground: `surfaceContainerLow` in dark, `surfaceContainerLowest` in light, always
  visible (`.toolbarBackground(_, for: .tabBar)` + `.toolbarBackgroundVisibility(.visible,
  for: .tabBar)`); hairline: system default in light, `cardBorder` in dark.
- Selected item `primary` (`.tint`), unselected `onSurfaceVariant`. SwiftUI has no unselected
  colour API, so a `UITabBarAppearance` is built from the resolved theme and applied to
  `UITabBar.appearance()` once per theme resolution in `RootView` (the same place
  `.preferredColorScheme` is driven). Label font and icon size stay native.
- SF Symbols stay as mapped in `RootTab.swift`; selected = filled variant where one exists.
- Visibility on pushed screens stays exactly `.toolbar(backStacks.isAtRoot(tab) ? .visible :
  .hidden, for: .tabBar)` on the stack (`RootView.swift:233`); features never write it.

### 2.2 Navigation bar — native, inline, everywhere

- Every root and every pushed screen: `.navigationBarTitleDisplayMode(.inline)`; bar ground
  `background`, title `onSurface` in `titleMedium` weight via `.toolbarColorScheme` +
  `UINavigationBarAppearance` set beside the tab-bar appearance. Large titles are off.
- **Root toolbar** — one modifier in `SalusUI`, `salusRootToolbar(title:onBell:onAvatar:)`,
  applied by the shell in `RootNavigationStack` to each of the five roots (never by a feature):
  leading `ToolbarItem` = the brand tile (`SalusIconBadge` 24 with the heart glyph on
  `primaryContainer`), principal = the tab title, trailing = bell (→ Reminder Health) and
  avatar (`SalusAvatar` 32, → Profile). Both destinations live in `FeatureSettings`; the shell
  reaches them through the existing cross-feature closures (template rule L268+).
- **Pushed screens** keep the system back button and `.navigationTitle`. Trailing text actions
  ("Kaydet", "Düzenle", "Sil") are plain `Button`s in `ToolbarItem(placement:
  .topBarTrailing)` tinted `primary` — the twin of Android's `TextButton` rule; icon actions
  use `SalusIconButton`. Subtitles Android shows under a pushed title move into the content's
  first row.
- `SalusScreenHeader` is deleted from `SalusUI` and from its five call sites (Medications,
  Appointments, Vitals, More, Cycle); Home's `HomeHeader` becomes the `SalusHeroBand` (§4.1).

### 2.3 Sheets and full-screen presentations

- Theme picker and language picker leave `MoreScreen`'s `salusDialog` for `.sheet` with
  `.presentationDetents([.medium])`, wrapped in `SalusBottomSheet` chrome (§3.3): drag
  indicator, title/subtitle, close button, `surfaceContainer` ground, `extraLarge` top corners.
  Each row is a `SalusSelectableRow` with a palette swatch (`PremiumTheme.swatch(dark:)`).
  CLASSIC never routes to the paywall (A60).
- The paywall stays a `fullScreenCover` (`App/PaywallHost.swift`) and is restyled in §4.10.
- Calendar and cycle time-picker sheets keep their presentation and adopt the sheet chrome.
- Confirm dialogs (`salusConfirmDialog`) stay dialogs, restyled by tokens only.

### 2.4 Not mirrored — by decision

`SalusBottomBar`, `SalusTopBar.Home/Pushed`, `SalusTopBarDefaults.Clearance`,
`SalusBottomBarDefaults.*`, the sliding bottom-bar pill and the bottom-bar label step ladder
have no iOS twin: the native tab bar lives in the safe area, so scroll content and FABs clear
it without a reserved clearance. Parity rows A48 and A49 close as "diverged by decision (Q1/Q2)"
with this spec as the reference.

### 2.5 Tests

Unit tests where logic exists: the root-toolbar closures reach the right destinations (the
shell's `RootNavigationStack` tests), `UITabBarAppearance`/`UINavigationBarAppearance` builders
map the resolved theme to the expected colours (pure functions in `SalusUI`, tested against
`SalusResolvedTheme` fixtures). Visual checks are QA-sheet rows (§7).

---

## 3. Component library (`Packages/SalusUI`)

Every component keeps the Android name and parameter names (Swift-cased); the Swift file header
cites the Kotlin twin `file:line`. Every component has a `#Preview` that renders 4 palettes ×
2 modes through a new `SalusPreviewPalettes` helper (Android `SalusPreview` twin); previews are
build-only.

### 3.1 Restyled existing components (11)

| Component | Change |
|---|---|
| `SalusCard` | `tone: .standard / .elevated / .accent / .accentOutlined`; dark = `cardBorder` line + container step, no shadow; light = `SalusShadow` + faint line. `selected: Bool?` gives the radio role and a 1.5 pt `primary` edge (plan cards); `onTap` keeps the button role. |
| `SalusSectionHeader` | Overline role: `labelSmall` on `overline`; the string is upper-case in resources. |
| `SalusEmptyState` | Icon tile on `surfaceContainerHigh`, `titleMedium`, `bodyMedium` on `onSurfaceVariant`; content centred in the space it owns. |
| `SalusStatusChip` | Dot + text pill; tones `.success / .warning / .error / .neutral / .accent`; dot 6 pt. |
| `SalusFab` | `primary` disc with `accentGlow` shadow in both modes; extended variant keeps its label. |
| `SalusDateField` / `SalusDateTile` | `medium` corners, `surfaceContainerHigh` fill; tile 56×60 unchanged. |
| `SalusProgressRing` | Track `surfaceContainerHigh`, stroke 8 pt; centred label. |
| `SalusAvatar` | 48 / 72 unchanged; glyph on `primaryContainer`. |
| `SalusIconBadge` | Sizes 24 / 40 / 48; tint from a `FeatureAccent`. |
| `salusConfirmDialog` | Tokens only. |

### 3.2 Renamed to the Android API (5)

| iOS today | Becomes | Contract |
|---|---|---|
| `SalusPillButton` (+`SalusPillLabel`) | `SalusButton` | `variant: .primary / .secondary / .outlined / .destructive`, `size: .large (56, full width) / .medium (44)`, optional leading icon, `enabled`; `.primary` carries the `accentGlow` shadow in dark mode. |
| `SalusPillTextField` | `SalusTextField` | `medium` corners, `surfaceContainerHigh` fill, label above, supporting text below, trailing slot; every field declares its keyboard type and submit label. |
| `SalusFilterChip` | `SalusChoiceChip` | Selectable chip; selected = `primaryContainer` fill + `onPrimaryContainer` text. |
| `SalusOptionRow` | `SalusSelectableRow` | Leading swatch or icon, title, subtitle, trailing radio/check; `selectableGroup` semantics on the parent. |
| `SalusListItemChevron` | `SalusListItem` | Leading icon tile tinted by a `FeatureAccent`, title (`titleColor` override), subtitle, trailing slot (chevron / chip / toggle), button role when tappable. |

The old names are deleted, not aliased.

### 3.3 New components (12)

| Component | Contract (Android twin in `core/ui/.../component/`) |
|---|---|
| `SalusIconButton` | Tinted circle, tones `.standard / .accent / .destructive`, 40 pt, ≥ 44 pt target. |
| `SalusSegmentedTabs<T>` | Pill segment control over `[T]` with a label closure; **one** `primaryContainer` pill that slides between segments (`matchedGeometryEffect`, §1.5 token) — the M14 divergence (b) `Picker(.segmented)` mapping is **reversed** for every use that Android draws as `SalusSegmentedTabs` (vitals type, appointments Upcoming/Past, AI/report period, trends range, cycle where present); `enabled: false` dims to 0.38 and marks the control unavailable for VoiceOver. No haptic, no ripple-like feedback. |
| `SalusChoiceTile` | Icon + label tile for grids (medication form, sex, theme mode); selected = `primary` border + check badge. |
| `SalusMetricTile` | Overline, `displaySmall` or `headlineMedium` value, unit, optional delta on `metricUp` / `metricDown`, optional `SalusProgressBar`. |
| `SalusStepperField` | Editable numeric value with − / + and a range hint; `placeholder: Bool` draws the value dimmed and reports no value; `autoFocus` once per view instance; `parse` closure; commit on submit. |
| `SalusProgressBar` | 6 pt rounded bar, tones `.primary / .primarySoft / .rose / .warning`, track `surfaceContainerHigh`. |
| `SalusHeroBand` | Date overline slot, greeting in `headlineMedium`, chip slot; `hero` gradient (Home, Profile). |
| `SalusInfoNote` | Leading icon + text; tones `.info / .warning / .neutral`. |
| `SalusBottomSheet` | A `salusBottomSheet(isPresented:title:subtitle:detents:content:)` modifier over `.sheet`: drag indicator, title/subtitle, close button, `surfaceContainer` ground, `extraLarge` top corners. |
| `SalusPagerDots` | Page indicator; active dot stretches to an 18 pt pill; inactive at 0.4 alpha. |
| `SalusCheckRow` | Read-only row with a check glyph and a trailing count/chip. |
| `SalusDisclaimer` | Centred `bodySmall` on `onSurfaceVariant`. |

### 3.4 Charts (`SalusUI/chart`)

`SalusLineChart`, `SalusSparkline`, `SalusBarChart`, `SalusMultiSeriesChart` (Swift Charts):
the line is drawn twice — a 6 pt `accentGlow` pass under the 2.5 pt `primary` line; grid lines
`outlineVariant`; axis labels `labelSmall` on `onSurfaceVariant`; the marker restyled on
`surfaceContainerHigh`. Models are unchanged (A52).

### 3.5 Entrance

`salusEntrance(index:)` plays **once per view instance** (A43 amendment): the played flag is
`@State` on the modifier; because `TabView` keeps root views alive, returning to a tab shows the
settled layout. If a task finds the root re-created on tab return, the flag moves to
`@SceneStorage` keyed by screen, and the ruling is recorded.

### 3.6 Removed

`SalusScreenHeader`, `SalusPillLabel`, and the five pre-rename files. `SalusUIStrings` keys
that only they used are deleted; the key-set pin test is updated in the same commit.

### 3.7 Tests

Unit tests for the logic that exists: `SalusStepperField` parse/clamp/placeholder state,
`SalusSegmentedTabs` index resolution (selection outside `options` draws no pill),
`SalusPagerDots` bounds, the appearance builders (§2.5), `SalusUIStrings` key pins. Views are
preview-built only.

---

## 4. Screens

Content follows Android spec §4.1–§4.17 plus the §13.1 owner-QA amendments; the Kotlin
`Screen.kt` is the layout twin, the `UiState.kt` the state twin. UiState changes are limited to
the ones Android made (listed per screen); mappers and use cases are ported case-for-case.

| # | Screen (iOS file) | Layout | UiState change |
|---|---|---|---|
| 4.1 | Home (`FeatureHome/ui/HomeScreen.swift`) | Root toolbar → `SalusHeroBand` (date overline, greeting + name, dose chip) → reminder-readiness card **between the hero and the pager, only when there is a problem** → horizontal snapshot pager (vitals, cycle when visible) with `SalusPagerDots` → AI card (`aiGradient` border) → appointments section (card → detail, A58). `salusEntrance` indices 0–4 as Android. | none |
| 4.2 | Medications list (`ui/list/MedicationsScreen.swift`) | Overline "BUGÜN • date" + title; three `SalusMetricTile`s (active count, recorded-dose %, next dose time); medication cards with dose-time chips; extended FAB. | `nextDoseTime` (recurrence-weighted, re-read per emission — Android's critical fix) |
| 4.8 | Medication detail (`ui/detail/MedicationDetailScreen.swift`) | Toolbar: "Aktif Takip" chip + "Düzenle". `elevated` hero card, reminder toggle row, "Kullanım Planı" metric tiles, "≈ N gün yetecek". | `daysLeft` |
| 4.6 | Medication editor (`ui/editor/MedicationEditorScreen.swift`) | Card sections: name, form as eight `SalusChoiceTile`s, strength + unit, instructions, plan, reminders; trailing "Kaydet". | none |
| 4.3 | Vitals list (`ui/list/VitalsScreen.swift` + `VitalsListSections.swift`) | `SalusSegmentedTabs` type selector; chart card with the latest value in its header and range chips inside; rows with delta/trend; icon FAB opens the selected type's editor. | `selectedType`, row `delta`/`trend` |
| 4.7 | Vitals editors (`ui/editor/{Weight,BloodPressure,Glucose}EditorScreen.swift`) | One editor per type, no type switch. Create mode: value field empty with the suggestion as a placeholder, autofocus once, Save disabled until a real value; edit mode unchanged. Shared `VitalsEditorChrome` for the toolbar. Ranges from a `VitalsLimits` twin shared with the use cases. | `isSaveEnabled` |
| 4.4 | Appointments list (`ui/list/AppointmentsScreen.swift`) | `SalusSegmentedTabs` Yaklaşan (n) / Geçmiş (n); date tiles; extended FAB. | `isPastExpanded` → `selectedTab` (A55) |
| 4.9 | Appointment detail (`ui/detail/AppointmentDetailScreen.swift`) | **Full screen, no card:** centred hero (`SalusIconBadge` 48, title `headlineMedium`, full date line, Bugün / Yarın / N gün sonra / Geçti chip); "DETAYLAR" `SalusListItem` rows (date + time chip, doctor, location → **Apple Maps** via `MKMapItem`/`maps://` search, reminders) with "…ekle" placeholder rows in `onSurfaceVariant`; "NOTLAR"; health-notes `SalusInfoNote`; actions "Takvime Ekle" (`.primary`) + "Sil" (`.destructive`); no bottom "Düzenle" (A62). | `relativeDay` per emission |
| 4.10 | Appointment editor (`ui/editor/AppointmentEditorScreen.swift`) | `SalusTextField`s, date/time fields, reminder offsets as `SalusChoiceChip`s, large primary "Kaydet". | none |
| 4.5 | More (`FeatureSettings/ui/more/MoreScreen.swift`) | Profile card (avatar, name, sex chip, PRO badge) → Profile; premium band (`.accent` card); grouped `SalusListItem` rows; theme + language `.sheet`s (§2.3). | none |
| 4.11 | Profile (`ui/profile/ProfileScreen.swift`) | `SalusHeroBand` variant with avatar + live name + sex chip; fields; sex as three `SalusChoiceTile`s + cycle `SalusInfoNote`; the change-confirm dialog untouched. | none |
| 4.17 | About (`ui/about/AboutScreen.swift`) | Rows get feature-tinted icons (A61); token restyle otherwise. | none |
| 4.12 | AI summary (`FeatureAIHealth/ui/AiSummaryScreen.swift`) | Toolbar share icon; `SalusSegmentedTabs` Haftalık / Aylık; `.accent` banner with generated-at chip; three `SalusMetricTile`s; summary paragraphs; loading / empty / error **centred**. | `metricSnapshot` |
| 4.13 | Doctor report (`ui/DoctorReportScreen.swift` + preview) | Tabs; "Raporun Hazır" `.accent` card with tiles; preview card with "Büyüt"; `SalusCheckRow`s; sticky share/preview actions. | none |
| 4.16 | Trends (`FeatureTrends/ui/TrendsScreen.swift`) | `SalusSegmentedTabs` over `TrendsRange` (`enabled: false` while locked); one card per metric: chart + delta tile; locked blur + paywall unchanged. | none |
| 4.14 | Cycle (`FeatureCycle/ui/calendar/CycleScreen.swift`) | Toolbar "today" icon; month row; grid: period `tertiary` fill, predicted dashed `tertiary` ring, fertile `primaryContainer`, ovulation dot, today `primary` ring; legend; phase chips. | none |
| 4.15 | Cycle day (`ui/day/CycleDayScreen.swift`) | Keeps its presentation; `SalusBottomSheet` chrome if a sheet, native toolbar if pushed (the plan verifies which). | none |
| 4.10b | Paywall (`FeaturePaywall/ui/PaywallSheet.swift`) | Stays `fullScreenCover`; content on M15 components: hero, feature rows with icons, plan cards as `SalusCard(selected:)` in a radio group, primary CTA, restore + terms as `SalusDisclaimer`. The "Şifreli yedekleme" claim is **not** copied (Android product question, open). | none |
| — | Reminder Health, App Lock, Alarm, Onboarding gate | Token restyle only; onboarding content per §5. | none |

Every root reserves nothing at the top or bottom (native bars). FABs sit at the bottom
trailing/centre inside the safe area, lifted by `SalusSpacing.lg` only.

---

## 5. Onboarding (`Packages/Features/FeatureOnboarding`) — flow change

### 5.1 Step machine

`OnboardingStep` becomes `welcome`, `personalDetails`, `healthAndPermissions`
(`OnboardingUiState.swift`); `OnboardingSection` is deleted. `stepIndex`, `isLastStep`, the
field state and field events stay. The `notifications` step no longer exists; its request is a
`Toggle` on page 3. `includeNotificationStep` keeps its meaning: when false the toggle row is
hidden and nothing is requested. `OnboardingViewModel.swift` is rewritten as the twin of
Android's `OnboardingViewModel.kt`.

### 5.2 Pages

- **Page 1 — Welcome:** shield glyph in a mint tile, "Salus'a Hoş Geldiniz", description, three
  trust chips ("Yalnızca cihazınızda · Hesap gerektirmez · Reklamsız"), "Başla" `.primary`,
  "Gizlilik ve Güvenlik İlkelerimiz" opening the existing About privacy text in a
  `SalusBottomSheet`. Header "ADIM 1/3" + three-segment bar (the existing `OnboardingHeader`
  restyled).
- **Page 2 — Personal details:** person glyph, "Sizi Tanıyalım"; name (`SalusTextField`), sex
  (three `SalusChoiceTile`s + cycle `SalusInfoNote`), birth date (`SalusDateField`), height +
  weight side by side. "Devam Et" and "Şimdilik Atla" enabled only when `sex != nil`; skip
  clears name, birth date, height, weight, keeps sex, advances. Numeric rules unchanged.
- **Page 3 — Health notes and permissions:** document glyph, "Son Birkaç Detay"; multi-line
  notes with a "Yalnızca bu cihazda" chip, privacy `SalusInfoNote`, "Zamanında Hatırlatıcılar"
  toggle (default on, shown only when `includeNotificationStep`). "Kurulumu Tamamla ve Başla":
  if the toggle is on and permission is not granted, the existing request effect fires;
  `finish()` runs regardless. "Daha Sonra Ayarla": clears notes, requests nothing, finishes.
  Caption "Daha Fazla > Ayarlar'dan güncelleyebilirsiniz".

### 5.3 Presentation, persistence, tests

The gate stays above the `TabView` (`OnboardingScreen.swift`, `RootView`), keeps its own
safe-area handling, and moves between pages with the existing step-slide transition (the
post-launch motion work) — the direction rule is unchanged. `finish()` and persistence are
unchanged. `OnboardingViewModelTests` is rewritten as the Android `OnboardingViewModelTest`
twin: next/skip locked until sex is chosen; skip clears exactly the page-2 optional fields; the
permission effect fires only when the step is included and the toggle is on; finish writes the
same profile and weight as today. Negative cases advance the scheduler before asserting
"no event" (the Android vacuous-test lesson).

---

## 6. Strings

- Each feature's `Localizable.xcstrings` gets TR + EN together for every new key; keys are
  Android's, copied verbatim (`%1$s` → `%1$@`, `%1$d` → `%1$lld`; plurals as two keys with the
  count-selected variant, the M14 (e) precedent). Groups: section overlines, metric labels,
  theme/language sheet copy, onboarding copy, "Yaklaşan (%lld)" / "Geçmiş (%lld)", medication
  detail ("≈ %lld gün yetecek", "Günde %lld kez"), AI/report banner copy, empty states,
  appointment detail placeholders and "Haritalarda aç" / "Open in Maps".
- **Upper-case rule:** overline strings are stored upper-case; no runtime `uppercased()`.
- **Banned wording:** "uyum/adherence", "senkronize", any model name, "şifreli" claims,
  "ideal/hedef" medical claims — the Android pin tests get iOS twins.
- **Accessibility:** every icon button carries an `accessibilityLabel`; decorative images are
  `.accessibilityHidden(true)`. `Text(verbatim:)` for every resolved string (M7 rule).
- Keys orphaned by retired components and the old onboarding steps are deleted in the sweep
  task; key-set pin tests are updated in the same commit.

---

## 7. Testing and verification

- **Per task:** `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` +
  `scripts/lint.sh` green before commit; SwiftLint limits (file 500 / type 300 / function 60 /
  params 6) and SwiftFormat clean; `scripts/clean.sh` after adding files to a path dependency.
- **Before merge:** `scripts/ci.sh` (toolchain → lint → custom rules → all package tests →
  app build).
- **Token gate:** §1.6 contrast tests are the AA gate; no snapshot tests.
- **ViewModel tests** for every derivation Android added (§4 table, §5.3); existing tests are
  updated, never deleted.
- **Previews:** every component and every `Screen` has a `#Preview`; components and Home,
  Medications, Vitals render the 8-palette preview; one `.dynamicTypeSize(.xxxLarge)`
  preview per root screen.
- **Manual QA:** `docs/qa/m16-manual-qa.md`, the structure of Android's `m15-manual-qa.md`:
  §1 screen × (2 modes × 4 palettes) matrix, §2 onboarding flow, §3 gestures (swipe, delete,
  undo, maps), §4 Dynamic Type xxxLarge, §5 sheets and the paywall cover, §6 known risks.
  Written by the executors of the touching tasks, run by the owner before the merge. No
  simulator work in any executor step.

---

## 8. Delivery

### 8.1 Branching

Everything on `m16-ui-overhaul` off `main` `67b7e3a`. Linear history; no merge to `main` and
no push until every task is done, the final review is clean, and the owner has run the QA
sheet. `CURRENT_PROJECT_VERSION` is bumped in the merge commit's predecessor, as in earlier
milestones.

### 8.2 Task order (the implementation plan expands each)

1. **T1 tokens** — §1 (`SalusDesignSystem` + tests).
2. **T2–T4 components** (parallel worktrees, all on T1): T2 card/list/chip/row/button/text
   field (§3.1–3.2), T3 the twelve new components (§3.3) + entrance-once (§3.5), T4 charts
   (§3.4) + `SalusPreviewPalettes`.
3. **T5 shell** — §2 (tab-bar/nav-bar appearance, root toolbar, sheet chrome for theme and
   language, `SalusScreenHeader` removal).
4. **T6–T12 screens** (parallel worktrees, all on T5): T6 Home, T7 Medications (list, detail,
   editor), T8 Vitals (list, three editors, `VitalsLimits`), T9 Appointments (list, detail,
   editor, maps), T10 More/Profile/About/Reminder Health, T11 AI summary + Doctor report +
   Trends, T12 Cycle + Paywall + App Lock.
5. **T13 onboarding** — §5.
6. **T14 sweep** — strings orphans, `SalusUIStrings` pins, `docs/qa/m16-manual-qa.md`,
   parity-ledger rows in `salus-android` (A43, A47, A50–A62 → "landed"; A48/A49 → "diverged
   by decision"), the `iOS pending (M16)` flips in `design-tokens.md`, `docs/ios-feature-template.md`
   and `CLAUDE.md` rule updates (§8.3).
7. **Final review** (Opus) over `main..HEAD`, fix wave, then the owner's QA.

Each task: tests + build green before commit; the review package per task as in M15.

### 8.3 Rule updates (`CLAUDE.md`, `docs/ios-feature-template.md`)

- The shell owns the tab bar's look and the root toolbar; features never write toolbar
  backgrounds, tab-bar visibility, or the root toolbar.
- Pushed screens use `.navigationTitle` + inline mode + `ToolbarItem` text actions; never a
  custom header.
- Shared components + tokens are mandatory (the §3 list, spelled out); no inline hex outside
  `SalusExtendedColors.swift`/`SalusColorScheme.swift`; no raw point sizes outside
  `*Defaults`.
- `SalusSegmentedTabs` replaces `Picker(.segmented)` for content tabs (the M14 (b) reversal).
- Overlines upper-case in resources; the banned-word list.
- Manual QA lives in `docs/qa/m<N>-manual-qa.md` (the newer pattern), not `scripts/`.

---

## 9. Recorded iOS divergences (decided now)

| # | Divergence |
|---|---|
| (a) | Tab bar and navigation bar are native (Q1/Q2). Android's `SalusBottomBar`, `SalusTopBar`, `Clearance` constants, sliding bottom-bar pill and label step ladder have no twin. |
| (b) | `SalusSegmentedTabs` is custom SwiftUI (sliding pill via `matchedGeometryEffect`), reversing M14 divergence (b): the native segmented control cannot take the per-palette `primaryContainer` pill per instance. |
| (c) | Unselected tab-item colour and navigation-bar title styling go through `UITabBarAppearance` / `UINavigationBarAppearance`, rebuilt on theme resolution — SwiftUI exposes no token-level API for them. |
| (d) | `SalusBottomSheet` is a modifier over `.sheet` + `presentationDetents`, not a view, and its height is one `SalusSheetSizing` argument rather than a detent set: `.fitted` measures the body (a hidden copy of header + content, laid out at the sheet's width with `fixedSize(horizontal: false, vertical: true)`, plus the sheet's bottom safe-area inset) and presents at `.height(measured)`, falling back to `.medium` for the one layout pass before the first measurement; `.detents(…)` names fixed heights. **The copy is what is measured, never the presented body** — a height read off the sheet on screen is the height the detent gave it, and feeding that back into the detent is a layout loop. The language picker and the onboarding privacy sheet are `.fitted`, the twin of `ModalBottomSheet` wrapping its content (owner QA round 2 C2: at `[.medium]` three rows sat in a half-screen sheet); the theme picker keeps `.detents([.medium, .large])` because its content (mode tiles + section header + four palette rows) is taller than a medium sheet on every iPhone (final-review I4). The sheet **body scrolls** its caller's content in every case, because a SwiftUI sheet clips where Compose's `ModalBottomSheet` column scrolls — which is also the cap on a fitted sheet whose body outgrows the screen at a large Dynamic Type (`Packages/SalusUI/Sources/SalusUI/component/SalusBottomSheet.swift:36-58`, `:131-144`, `:179-213`). |
| (e) | Android's tonal-elevation switch has no iOS equivalent; the dark-mode "no shadow" rule is enforced in `SalusCard` alone. |
| (f) | Appointment location opens Apple Maps (`MKMapItem` search on the location text), the twin of Android's `geo:` intent; the row shows "Haritalarda aç" only when the location is non-empty. |
| (g) | Entrance-once uses `@State` on the modifier (TabView keeps roots alive); escalates to `@SceneStorage` only if a task proves roots are re-created. |
| (h) | Plurals are two keys selected in code (M14 (e) precedent). |
| (i) | `SalusStepperField` owns no `range`, `step` or `format`: the value is a `String`, the arithmetic and the bounds stay with the caller's state holder, where Kotlin clamps inside the component (`SalusStepperField.kt:80-92`, `:151`). The **caller contract** that replaces the clamp binds — a state holder answers every `onValueChange`, by accepting the text as the new `value` or by clamping it and re-emitting the value it will accept; silently ignoring one is a bug in the caller (T3, `Packages/SalusUI/Sources/SalusUI/component/SalusStepperField.swift:13-15`). |
| (j) | The root toolbar's avatar is the shared `SalusAvatar` — `primaryContainer` ground, `onPrimaryContainer` glyph — where `SalusTopBar.kt:174-186` draws `primary`/`onPrimary`. A toolbar-only tone would be a second avatar to keep in step (T5, `Packages/SalusUI/Sources/SalusUI/shell/SalusRootToolbar.swift:116`, `:136`). |
| (k) | The four root title keys `medications_title`, `vitals_title`, `appointments_title` and `more_title` stay on iOS although Android's M15 deleted all five of its own (Home's included): the shell's toolbar paints the principal title, but `.navigationTitle` is still what names the system back button of everything a root pushes and what VoiceOver reads for the screen (T6+, `Packages/Features/FeatureMedications/Sources/FeatureMedications/ui/list/MedicationsScreen.swift:103-108`). The orphan sweep spares them. **Belt-and-braces, and deliberately so:** `salusRootToolbar` sets `.navigationTitle(Text(verbatim: title))` itself (`Packages/SalusUI/Sources/SalusUI/shell/SalusRootToolbar.swift:63`) from the title the shell hands it, so a root's own `.navigationTitle` is a second writer of the same string. The four keys stay anyway — a root that is ever rendered outside `salusRootToolbar` (a preview, a future non-tab host) would otherwise push a back button with no label — and the copy is one string in one catalog, not a behaviour that can drift. |
| (l) | A medication's dose times are `SalusTimeField` rows, not Android's chip that opens a `TimePickerDialog`: SwiftUI's `DatePicker` *is* the button plus its picker, so the chip, the dialog and its two actions collapse into the field the rest of the app already uses (T7, `Packages/Features/FeatureMedications/Sources/FeatureMedications/ui/editor/DoseTimesSection.swift:11-16`). |
| (m) | `SalusLineChart` draws **no press marker**. M15 *added* one on Android (`SalusLineChart.kt:159-178`); this port never had chart selection, so there was nothing to restyle, and building it is an interaction (selection state, gesture, delta formatter) rather than the restyle A52 scopes (T4, `Packages/SalusUI/Sources/SalusUI/chart/SalusLineChart.swift:29-31`). |
| (n) | `SalusMultiSeriesChart` has **no glow layer**: the twin has none (`SalusMultiSeriesChart.kt:103-117`) and A52 lists it as token-styled only. Overlapping translucent halos would also turn into a colour none of the lines is, which is the one thing that chart must not do (T4, `Packages/SalusUI/Sources/SalusUI/chart/SalusMultiSeriesChart.swift:77-82`). |
| (o) | The sparkline's halo is **5 pt under a 2 pt line** (`GlowThickness = 5.dp`, `SalusSparkline.kt:119`), not the full chart's 6 under 2.5 — the same ratio over a thinner line (T4, `Packages/SalusUI/Sources/SalusUI/chart/SalusSparkline.swift:113-116`). |
| (p) | Home's snapshot pager **measures its own pages**, because SwiftUI's `TabView(.page)` has no intrinsic height to take from its tallest page the way Compose's `HorizontalPager` does: a hidden copy of every page is laid out at the pager's width, each reports its natural height through a `PreferenceKey` that keeps the maximum, and the `TabView` is framed to that. `HomePagerDefaults.fallbackHeight` seeds the one layout pass before the first measurement lands and is never a floor afterwards (T6 + owner QA round 1 B2, `Packages/Features/FeatureHome/Sources/FeatureHome/ui/HomeSnapshotPager.swift:111-116`, `:145-170`, `:206-213`, `:293-306`). The original shape was a fixed `@ScaledMetric` constant, which was a floor as well as a ceiling and left short pages in a 260 pt box with a visible gap above the dots. |
| (q) | Cycle's "SALUS HEALTH" overline is a **content line above the month header**, not a bar slot: a pushed iOS navigation bar has no overline, and putting it in content is the convention Profile's "HESAP" and Home's "BUGÜN" already set (T12, `Packages/Features/FeatureCycle/Sources/FeatureCycle/ui/calendar/CycleScreen.swift:100-107`). |
| (r) | The cycle day editor is a pushed screen whose "Kaydet" is a footer `SalusButton`, with no trailing toolbar action — the twin's own shape (`CycleDayScreen.kt:70-78`, `:147-151`), not the house "text action in `.primaryAction`" rule (T12, `Packages/Features/FeatureCycle/Sources/FeatureCycle/ui/day/CycleDayScreen.swift:150-157`). |
| (s) | The paywall's restore is a quiet **text button**, the twin of `TextButton(paywall_restore)` (`PaywallScreen.kt:288-296`) — the brief's outlined/medium `SalusButton` was superseded by the Kotlin (T12, `Packages/Features/FeaturePaywall/Sources/FeaturePaywall/ui/PaywallSheet.swift:214-219`). |
| (t) | Trends' change sentence is a neutral line **under** the metric tile rather than inside it: `SalusMetricTile`'s delta slot has no neutral case, and inventing one would restyle a shared component for one caller (T11, `Packages/Features/FeatureTrends/Sources/FeatureTrends/ui/MetricSummaryCard.swift:85-89`). |
| (u) | `SalusIconBadge` takes no `shape` and is **always a circle** (`SalusShapes.pill` over a square frame). Android's onboarding hero passes `shapes.large`, a 24 pt rounded square, at 72/32; the iOS hero matches the size and not the shape (T13, `Packages/SalusUI/Sources/SalusUI/component/SalusIconBadge.swift:77-82`). |
| (v) | `SalusChoiceTile` takes no `accent:` (nor Kotlin's `subtitle`): spec §3.3 names the tile as icon + label, and every M16 grid that uses one is exactly that, so Android's per-accent tint on the sex tiles has no twin (T13, `Packages/SalusUI/Sources/SalusUI/component/SalusChoiceTile.swift:4-7`). |
| (w) | The onboarding reminder row is **one combined accessibility element**, not a whole-row tap target: a `Button` wrapped around a `Toggle` swallows the toggle's own gesture on iOS, so VoiceOver reads title + subtitle + state as one control while a sighted user hits the switch's native ≥44 pt target (T13, `Packages/Features/FeatureOnboarding/Sources/FeatureOnboarding/ui/OnboardingHealthPage.swift:134-136`). |
| (x) | `onboarding_step_of` takes **two** arguments — `ADIM %1$lld / %2$lld` — because Android's value does; hard-coding the total into the string would have been the one place the port invented copy (T13, `Packages/Features/FeatureOnboarding/Sources/FeatureOnboarding/OnboardingStrings.swift:105-108`). |
| (y) | `SalusIconButtonDefaults.circleSize` is **40 pt**, where `SalusIconButtonDefaults.CircleSize` (`SalusIconButton.kt:97`) is 36 dp — a spec §3.3 decision, not a drift. The disc is what is seen and the tappable box is the full `SalusTouchTarget.min` on both platforms; 40 is the size that reads as a bar-weight control against iOS's larger default glyph metrics without crowding a row of them (`Packages/SalusUI/Sources/SalusUI/component/SalusIconButton.swift:106-111`). `IconSize` is ported unchanged. |
| (z) | `SalusStepperField` draws the create-mode suggestion at reduced opacity — `onSurfaceVariant` at `SalusStepperFieldDefaults.suggestionOpacity` (0.45, above Material's 0.38 disabled floor) — where Android draws it at the full `onSurfaceVariant` tone (`SalusStepperField.kt:201-206`). A shared weakness the owner met on iOS: at full tone the suggestion reads as a number the user typed while Save stays disabled. The committed value's colour is unchanged, and `SalusUIStrings.stepperSuggested` still says the same thing to VoiceOver (owner QA round 2 C1, `Packages/SalusUI/Sources/SalusUI/component/SalusStepperField.swift:40-47`, `:172-186`). |
| (aa) | The sex tiles draw the **Unicode signs `♀ ♂ ⚧`** where Android draws `Icons.Outlined.Female / Male / Transgender` (`ProfileScreen.kt:259-263`, `OnboardingPages.kt:379-383`): SF Symbols ships no venus, mars or transgender glyph. `SalusChoiceTile` therefore takes a `SalusChoiceTileGlyph` — `.symbol(String)` for an SF Symbol, `.text(String)` for a sign drawn in the same slot at the same `SalusChoiceTileDefaults.iconSize` and tint — with the `systemImage:` init kept for every other grid. The three signs are chosen in **one** place, `SalusSexGlyph.glyph(for:)` in `SalusUI` (Kotlin can afford its two private `Sex.icon()` copies because a Material icon is the same object in both files; a hand-chosen glyph is a decision, and the profile editor and onboarding page 2 must not disagree). Each sign carries U+FE0E so the system draws the plain glyph in the tile's tint rather than a colour emoji. The port's first answer — one neutral `person.crop.circle` on all three tiles — is what owner QA round 2 C3 found (`Packages/SalusUI/Sources/SalusUI/component/SalusSexGlyph.swift:26-40`, `Packages/SalusUI/Sources/SalusUI/component/SalusChoiceTile.swift:21-30`, `:104-111`). |

## 10. Risks

- **SwiftUI toolbar styling limits** — inline titles and `UINavigationBarAppearance` are
  well-trodden on iOS 17, but the bell/avatar trailing pair must fit beside the system back on
  pushed screens: the root toolbar is applied to roots only, so this never combines.
- **Appearance rebuild timing** — `UITabBar.appearance()` changes apply to bars created after
  the call; T5 must verify the theme sheet's live switch repaints the existing bar (re-set
  `standardAppearance`/`scrollEdgeAppearance` on the `UITabBar` through an introspection-free
  path: a `.id(theme)` on the `TabView` is the fallback, recorded if used).
  **Realised, and closed by owner QA round 1 B3.** Every bar in the app is made once at launch and
  kept, so the proxies painted none of them on a live switch. The bars on screen are now repainted
  directly by `SalusBarRepainter`
  (`Packages/SalusUI/Sources/SalusUI/shell/SalusBarRepainter.swift`), a zero-size view the shell
  plants that walks the window and its presentation chain on every theme change; `.toolbarBackground`
  and `.toolbarColorScheme` carry the colours SwiftUI paints for itself, and the proxies keep the
  bars made after the switch. The `.id(theme)` fallback is **retired, not taken** — it would rebuild
  all five tabs' content on every theme change.
- **Component renames touch every feature** — T2 lands the renames with the shell and screens
  still compiling (mechanical rename commits before restyle commits), so T6–T12 start green.
- **Onboarding rewrite** deletes the 8-step machine and its tests; the Android test twin is
  the safety net, and the QA sheet §2 walks the flow.
- **Contrast on premium light palettes** — the same two CLASSIC light pairs Android carries
  below AA stay documented; any new pair below AA fails the token test and is fixed in T1.

## 11. Parity-ledger index

| Row | Outcome at M16 close |
|---|---|
| A43 entrance stagger (once-only amendment) | landed (§3.5) |
| A47 M15 token layer | landed (§1) |
| A48 `SalusTopBar` + shell overlay contract | diverged by decision (Q2, §2.2/§2.4) |
| A49 bottom-bar geometry, ring and dot | diverged by decision (Q1, §2.1/§2.4) |
| A50 new primitives · A51 new composites | landed (§3.2/§3.3) |
| A52 chart restyle | landed (§3.4) |
| A53 onboarding three-step machine | landed (§5) |
| A54 vitals editor type tabs · A56 editable stepper · A57 `SalusSegmentedTabs(enabled)` | landed (§4.7, §3.3) |
| A55 appointments tabs · A58 Home appointment card → detail · A62 appointment detail full screen | landed (§4.4, §4.1, §4.9) |
| A59 theme and language sheets · A60 CLASSIC never paywalls · A61 paywall overlay + About icons | landed (§2.3, §4.5, §4.10b, §4.17) |
