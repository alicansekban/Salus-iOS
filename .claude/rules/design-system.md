---
paths:
  - "**/Packages/SalusUI/**"
  - "**/Packages/SalusDesignSystem/**"
  - "**/Packages/Features/**"
  - "**/App/**"
---
# Salus iOS design-system rules (MANDATORY)

Every rule names its **enforcement point**. Token values come only from
`../salus-android/docs/design/design-tokens.md`. Global rules are in `CLAUDE.md`.

## Design system rules

- **`salus-android/docs/design/design-tokens.md` is the only source of token values.** Never
  invent, round, or eyeball a color, spacing, radius, elevation or duration. If the doc lacks it,
  the doc gets updated on the Android side first.
  — *enforcement: `Packages/SalusDesignSystem/Tests/SalusDesignSystemTests/SalusDesignTokensTests.swift`
  pins **241 tokens** and **6 `FeatureAccent` sets** per theme, plus per-section tables against
  §1–§9 of the doc. Adding a token without the doc line fails the count.*
- **`SalusDesignSystem` is tokens only, no views** (mirrors Android's `:core:designsystem`).
  Shared views live in `SalusUI`. — *review.*
- **The resolved theme travels in the environment, never as a parameter.** A view reads
  `@Environment(\.salusTheme) private var theme` (`SalusThemeEnvironment.swift`); the shell resolves
  it once from the stored `theme_mode` plus the system appearance and applies `.salusTheme(_:)`.
  This is Compose's `MaterialTheme` CompositionLocal, and it is the reason no screen ever declares a
  `theme:` argument — threading one through four intermediate views is how a screen ends up drawing
  a stale palette. — *review; `SalusThemeEnvironmentTests` pins the default (light, classic) so a
  view rendered outside the shell still draws Salus tokens.*
- **Color literals live in `private enum` palettes**, one per theme/scheme
  (`LightPalette`, `DarkPalette`, `LightAccentPalette`, `ClassicLightValues`, …). Hoist
  many-argument literals out of the initializer call: nested `FeatureAccent(...)` /
  `Color(...)` expressions blow the Swift type-checker's expression budget and turn a build into
  a timeout. — *enforcement: the existing shape in
  `Packages/SalusDesignSystem/Sources/SalusDesignSystem/` + review; a regression shows up as a
  compile timeout in `scripts/test-packages.sh`.*
- **No inline hex outside the palette files, and no raw point size outside a `*Defaults`.**
  A `Color(hex:)` / `0xRRGGBB` literal belongs in exactly five files, all in
  `Packages/SalusDesignSystem/Sources/SalusDesignSystem/`: `SalusColorScheme.swift`,
  `SalusExtendedColors.swift` and the three `SalusPremium*.swift` palettes (plus
  `Color+SalusHex.swift`, which defines the initializer, and the design-system tests, which pin the
  values). Anywhere else a colour is `theme.colorScheme.…` / `theme.extendedColors.…`. A number with
  a unit — a size, an inset, a radius, a stroke — is either a `SalusSpacing` / `SalusDimensions` /
  `SalusTypography` token or a named constant on the component's own `…Defaults` enum
  (`SalusFabDefaults`, `HomePagerDefaults`, `MedicationsHeaderDefaults`, …). A bare `44`, `16` or
  `0.24` in a view body is a finding: the `Defaults` enum is where a reader looks for what it is and
  why. — *review; the token half is mechanical through `SalusDesignTokensTests`, the point-size half
  is not.*
- **The shell owns the bars; a feature paints neither.** The tab bar's look and the navigation
  bar's ground, title colour and title font come from `SalusBarAppearance`
  (`Packages/SalusUI/Sources/SalusUI/shell/SalusBarAppearance.swift`), applied once per theme
  resolution; the tab bar's *visibility* is `App/RootView.swift`'s (the rule in `architecture.md`); and the five
  tab roots' toolbar — brand tile, principal title, bell, avatar — is `salusRootToolbar(…)`, applied
  in `App/RootNavigationStack.swift` and nowhere else. A feature never writes a toolbar background,
  never writes `.toolbar(…, for: .tabBar)`, and never adds a second bell or avatar. Since iOS-M16
  (spec §2.2) there is **no in-content screen header** at all: `SalusScreenHeader` is deleted and
  `SalusTopBar` was never ported. — *enforcement: `no_tab_bar_toolbar_in_features` (in `architecture.md`) for the
  tab-bar half; review for the rest.*
- **A pushed screen writes `.navigationTitle` + inline mode + `ToolbarItem` text actions, and
  nothing else.** `.navigationTitle(Text(verbatim: …))`, then
  `#if os(iOS) .navigationBarTitleDisplayMode(.inline) #endif` **last** in the modifier chain — the
  `#if` because the modifier is iOS-only API and every feature package also builds for the macOS
  test host, and *last* because SwiftFormat indents whatever follows an `#endif` one level deeper.
  **There is one toolbar-action shape and it takes no arguments beyond its own:** a plain `Button`
  in `ToolbarItem(placement: .primaryAction)`, drawing `primary` because the shell tints the whole
  `TabView` (`App/RootView.swift`) and a toolbar item inherits that — **never a per-site
  `.tint(…)`**, which is a second place the same colour can drift, and **never a second placement
  spelling**: `.confirmationAction` resolves to the same trailing slot on iOS, so one spelling
  means one thing to check. Icons use `SalusIconButton`, each with an `accessibilityLabel`. The
  system back button stays and is never redrawn. `docs/ios-feature-template.md` §"The title bar is
  the system's" carries the worked example. — *review; `grep -rn "\.tint(" App/ Packages/` has
  exactly two production hits and neither is a toolbar item: the shell's own `TabView` line, and
  `ReminderHealthScreen`'s `.borderedProminent` fill. A third inside a `ToolbarItem` is the
  finding.*
- **The shared components are the vocabulary, and it is closed.** A screen composes what
  `SalusUI` already ships and does not hand-roll a fifth copy of one:
  `SalusAvatar`, `SalusButton`, `SalusExtendedFab`, `SalusFab`, `SalusIconButton`, `SalusCard`,
  `SalusListItem` (+ `SalusListItemChevron`), `SalusSelectableRow`, `SalusCheckRow`,
  `SalusChoiceChip`, `SalusChoiceTile` (+ `SalusSexGlyph`), `SalusStatusChip` (+ `SalusStatus`),
  `SalusIconBadge`, `SalusHeroBand`,
  `SalusMetricTile`, `SalusSectionHeader`, `SalusSegmentedTabs`, `SalusPagerDots`,
  `SalusProgressBar`, `SalusProgressRing`, `SalusEmptyState`, `SalusInfoNote`, `SalusDisclaimer`,
  `SalusTextField`, `SalusStepperField`, `SalusDateField`, `SalusDateTile`, `SalusTimeField`,
  `SalusEntrance` (`.salusEntrance(index:)`), `ChipFlowLayout`, `SalusWeekdaySymbols`,
  `SalusSnackbarHost`, and the three modifiers `.salusBottomSheet(…)`, `.salusDialog(…)`,
  `.salusConfirmDialog(…)` (+ `.salusDismissesKeyboardOnTap()`). Charts are the five in
  `SalusUI/chart/` (`SalusLineChart`, `SalusBarChart`, `SalusMultiSeriesChart`, `SalusSparkline`,
  `SalusHeatmap`). A component that needs a knob gains it in `SalusUI` with its twin's citation —
  never a private copy in a feature. — *review; the list lives in
  `Packages/SalusUI/Sources/SalusUI/component/`, `…/shell/`, `…/snackbar/` and `…/chart/`, which
  is what to re-derive it from — all four, or the snackbar host goes missing.*
- **`SalusSegmentedTabs` is the content-tab control; `Picker(.segmented)` is retired.** iOS-M16
  reversed M14's divergence (b): the native segmented control cannot take the per-palette
  `primaryContainer` pill per instance, so the sliding pill is drawn with `matchedGeometryEffect`
  in `SalusUI`. Every content tab strip — vitals types, appointments upcoming/past, trends ranges —
  is `SalusSegmentedTabs`; a `pickerStyle(.segmented)` anywhere in the tree is a finding.
  — *review; `grep -rn "pickerStyle(.segmented"` over `App/` and `Packages/` must match no call
  site. It has exactly one hit today and it is a comment —
  `FeatureSettings/ui/profile/ProfileScreen.swift:24`, the Material→SwiftUI mapping table in that
  file's header, which records the retirement.*
- **`SalusStepperField` owns no range, and the caller contract that replaces it binds.** The field
  takes the number already written (`value: String`), reports the text an edit produced
  (`onValueChange`) and hands the nudges back; the step, the unit and the bounds stay with the
  feature's state holder, where Kotlin keeps them inside the component. So **a state holder must
  answer every `onValueChange` — by accepting the text as the new `value`, or by clamping it and
  re-emitting the value it will accept.** Silently ignoring one leaves the field displaying a number
  the state holder rejected, and the field cannot tell that from "not answered yet". Recorded as
  spec §9 (i). — *enforcement:
  `Packages/SalusUI/Tests/SalusUITests/SalusStepperFieldTests.swift` ("a caller's clamped
  re-emission replaces the text that was reported") + review of every caller.*
