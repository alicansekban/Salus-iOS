# iOS-M16 — UI Overhaul (Android M15 mirror) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every iOS screen adopts the Android M15 "Ambient Emerald" language — new tokens in every mode and palette, a rebuilt `SalusUI` component library with the Android names, the native `TabView` and navigation bars painted with tokens, every screen restyled, and the three-page onboarding — with no business feature added.

**Architecture:** Tokens first (`SalusDesignSystem`), then the shared components (`SalusUI`), then the shell (`App/`), then one pass per feature package, then onboarding, then a docs/strings sweep. Screens never write a hex or a raw point size: they read `@Environment(\.salusTheme)` and compose `SalusUI` components. Every new or rewritten Swift file's header comment names its Kotlin twin `file:line`, re-derived with `grep -n` at execution time.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI (iOS 17.0), Swift Charts, local SwiftPM packages, XcodeGen (`project.yml`), Swift Testing, SwiftLint + SwiftFormat, `scripts/*.sh`.

**Spec:** `docs/superpowers/specs/2026-09-12-ios-m16-ui-overhaul-design.md` — every task cites the spec section it implements; read both. The Android twin spec and token doc are at `../salus-android/docs/superpowers/specs/2026-09-11-m15-ui-overhaul-design.md` and `../salus-android/docs/design/design-tokens.md` (§14 = the M15 change log).

## Global Constraints

- **Branch:** all work on `m16-ui-overhaul` (cut from `main` `67b7e3a`). **No merge to `main`, no push** until Task 14 is done, `scripts/ci.sh` is green, the final review is clean and `docs/qa/m16-manual-qa.md` has been run by the owner.
- **No hex outside `SalusDesignSystem`** (`SalusColorScheme.swift`, `SalusExtendedColors.swift`, `SalusPremiumAccents.swift`, `SalusPremiumExtendedColors*.swift`). No raw point sizes outside a `*Defaults` enum. No new destinations, no GRDB change, no new dependencies, no snapshot tooling, no `TabView`/`NavigationStack` outside `App/`. System font only. Deployment target stays iOS 17.0.
- **Native chrome (spec Q1/Q2):** the tab bar is the system `TabView`; every title bar is the system navigation bar in inline mode; no custom bottom bar, no custom top bar, no `Clearance` constants. Features never write `.toolbar(…, for: .tabBar)` (SwiftLint `no_tab_bar_toolbar_in_features` stays) and never write the root toolbar.
- **Strings:** TR + EN together in each package's `Resources/Localizable.xcstrings`; keys are Android's, copied verbatim (`%1$s` → `%1$@`, `%1$d` → `%1$lld`; plurals as two keys); `Text(verbatim:)` for every resolved string; overlines stored upper-case, never `uppercased()` at runtime. **Banned wording** (test-pinned in each `*StringsTests`): "uyum"/"adherence", "senkronize", model names, "şifreli", "ideal"/"hedef" as medical claims.
- **Accessibility:** every icon button carries `accessibilityLabel`; decorative images `.accessibilityHidden(true)`; tap targets ≥ `SalusTouchTarget.min` (44 pt).
- **Every new/changed component and every `Screen`:** a `#Preview`; components and the Home, Medications, Vitals screens render the 8-palette `SalusPreviewPalettes` preview from Task 3; one `.dynamicTypeSize(.xxxLarge)` preview per root screen. Previews are build-only.
- **Per-task gate:** `scripts/test-packages.sh <touched packages>` + `scripts/build-app.sh` + `scripts/lint.sh` green before every commit; `scripts/clean.sh` after adding a file to a path dependency; SwiftLint limits file 500 / type 300 / function 60 / params 6. Conventional Commits with trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- **No simulator or device work is an executor step.** Visual checks are rows the touching task's executor writes into `docs/qa/m16-manual-qa.md` (created in Task 1, grown by every task); the owner runs them.
- **Spec deviations are already decided** (spec §9 a–h); do not reopen them, do not add new ones without asking.

## File map

| Area | Files |
|------|-------|
| Tokens | `Packages/SalusDesignSystem/Sources/SalusDesignSystem/{SalusColorScheme,SalusExtendedColors,SalusPremiumAccents,SalusPremiumExtendedColors,SalusPremiumExtendedColorsOcean,…Sunset,…Forest,SalusTypography,SalusDimensions,SalusMotion,ThemeSettings+DesignSystem}.swift`; tests `Packages/SalusDesignSystem/Tests/SalusDesignSystemTests/` |
| Components | `Packages/SalusUI/Sources/SalusUI/component/*.swift`, `…/chart/*.swift`, `…/preview/SalusPreviewPalettes.swift` (new), `…/Resources/Localizable.xcstrings`, `…/SalusUIStrings.swift`; tests `Packages/SalusUI/Tests/SalusUITests/` |
| Shell | `App/RootView.swift`, `App/RootNavigationStack.swift`, `App/RootTab.swift`, `App/PaywallHost.swift`, `App/AppStrings.swift`, `App/Localizable.xcstrings` |
| Features | `Packages/Features/<Pkg>/Sources/<Pkg>/ui/**`, `…/Resources/Localizable.xcstrings`, `…/<Pkg>Strings.swift`; tests `Packages/Features/<Pkg>/Tests/<Pkg>Tests/` |
| Docs | `docs/qa/m16-manual-qa.md` (new), `docs/ios-feature-template.md`, `CLAUDE.md`, and in `../salus-android`: `docs/parity-ledger.md`, `docs/design/design-tokens.md` |

Task graph: T1 → (T2 ∥ T3 ∥ T4) → T5 → (T6 … T12 in parallel worktrees) → T13 → T14 → final review.

---

## Task 1 — Token layer (`SalusDesignSystem`) — spec §1

**Files:**
- Modify: `SalusColorScheme.swift:202-278` (`light`/`dark` tables), `SalusExtendedColors.swift` (six new fields, `cycle`, `hero`), `SalusPremiumAccents.swift:54-267` (8 palette tables), `SalusPremiumExtendedColors{,Ocean,Sunset,Forest}.swift` (per-palette extended values), `SalusTypography.swift:46-112`, `SalusDimensions.swift` (`SalusShapes.medium/large`), `SalusMotion.swift` (segmented slide token), `ThemeSettings+DesignSystem.swift` (`swatch(dark:)`)
- Modify tests: `SalusDesignTokensTests.swift`, `SalusPremiumExtendedColorsTests.swift`, `SalusThemeTests.swift`
- Create: `Packages/SalusDesignSystem/Tests/SalusDesignSystemTests/SalusColorSchemeContrastTests.swift`, `docs/qa/m16-manual-qa.md` (skeleton: §1 theme matrix table with an empty row per screen, §2 onboarding, §3 gestures, §4 Dynamic Type, §5 sheets, §6 known risks — later tasks append rows)

**Interfaces (produces):**
```swift
// SalusExtendedColors.swift — added after `hero`, same order as ExtendedColors.kt
public var cardBorder: Color; public var accentGlow: Color; public var overline: Color
public var metricUp: Color; public var metricDown: Color; public var aiGradient: SalusGradient
// ThemeSettings+DesignSystem.swift — the theme sheet's swatches (Task 10) read it
public extension PremiumTheme { func swatch(dark: Bool) -> Color }   // the palette's `primary` for that mode; CLASSIC = brand primary
// SalusTypography.swift
public static let displaySmall: SalusTextStyle   // 36 / lineHeight 44 / .bold / tracking 0 / .largeTitle
// SalusMotion.swift
public static let segmentedSlideDurationSeconds: Double   // = stateChangeDurationSeconds; easing = pushPopEasing
```

- [ ] `SalusColorScheme.swift`: re-value `dark` and `light` row by row from Android `design-tokens.md` §14.1 / §14.2 (cite each hex's Android `Color.kt:<line>`); every hex on its own named `private static let` as the file already does.
- [ ] `SalusExtendedColors.swift`: add the six fields (types above); light/dark CLASSIC values per Android `ExtendedColors.kt` (`cardBorder` = scheme `outline`; `accentGlow` = `primary.opacity(0.24)` dark / `0.16` light; `overline` `#10B981` dark / `#065F46` light; `metricUp` = `primary`; `metricDown` = `tertiary`; `aiGradient` = `SalusGradient(top: primary, bottom: tertiary)`); `cycle` = tertiary family; `hero` dark = `#090D0B` → `#064E3B`.
- [ ] `SalusPremiumAccents.swift` + the three `SalusPremiumExtendedColors*.swift`: per palette × mode from Android `PremiumThemeColors.kt` / `PremiumExtendedColors.kt` (OCEAN medications azure `#1B6FA8`/`#7CC4F5`, containers `#D6EAF8`/`#123A55`; FOREST medications `#6B7A16`/`#D4E157`, containers `#EDF3C8`/`#3E4A12`; light primaries OCEAN `#155E75`, SUNSET `#9A3412`, FOREST `#166534`); each palette restates `accentGlow`, `overline`, `metricUp`, `aiGradient.top` from its own primary; `metricDown` never moves; `hero` dark = `#090D0B` → the palette's dark `primaryContainer`.
- [ ] `SalusTypography.swift`: add `displaySmall`; `headlineMedium` 26 / 34 / `.bold` / −0.5; `titleLarge` 20 / 28 / `.semibold`; `labelMedium` 12 / 16 / `.medium`; `labelSmall` 11 / 16 / `.semibold` / +1.2. `SalusDimensions.swift`: `SalusShapes.medium` 14, `.large` 20. `SalusMotion.swift`: the slide token. `ThemeSettings+DesignSystem.swift`: `swatch(dark:)`.
- [ ] Test `SalusColorSchemeContrastTests` (Swift Testing; reuse `relativeLuminance`/`contrastRatio` from `SalusPremiumExtendedColorsTests.swift:196-236` — move them to a shared `ContrastMath.swift` in the test target): for every `PremiumTheme` × `dark ∈ {false, true}` resolve `SalusTheme.resolve(...)` and assert ≥ 4.5 on `onSurface/surface`, `primary/onPrimary`, `onSurfaceVariant/surfaceContainerLow`, `overline/surfaceContainerLow`, `error/surface`, `metricUp/surfaceContainerLow`; assert `|L(cardBorder) − L(surfaceContainerLow)| ≥ 0.02`; keep the existing "status colours never move" and "premium differs from classic" cases. Record the two CLASSIC-light pairs Android documents below AA as `.disabled` cases with the Android ledger reference, never by loosening the threshold.
- [ ] Re-pin `SalusDesignTokensTests` / `SalusThemeTests` to the new values (typography sizes, shapes, `displaySmall`, `swatch(dark:)` returns `primary` for each palette).
- [ ] Run `scripts/test-packages.sh SalusDesignSystem` — tune hexes until green (never loosen a threshold). Then `scripts/build-app.sh` to prove consumers still compile. `scripts/lint.sh`.
- [ ] Create `docs/qa/m16-manual-qa.md` skeleton (§1–§6 headers, the §1 matrix header row: Screen | Light CLASSIC | Dark CLASSIC | OCEAN L/D | SUNSET L/D | FOREST L/D). Commit: `feat(designsystem): M16 emerald tokens, extended roles, type and shape`.

---

## Task 2 — Renames and restyles (`SalusUI`) — spec §3.1, §3.2, §3.6

**Files:**
- Rename (git mv, type + file): `SalusPillButton.swift` → `SalusButton.swift` (delete `SalusPillLabel`), `SalusPillTextField.swift` → `SalusTextField.swift`, `SalusFilterChip.swift` → `SalusChoiceChip.swift`, `SalusOptionRow.swift` → `SalusSelectableRow.swift`, `SalusListItemChevron.swift` → `SalusListItem.swift`
- Modify: `SalusCard.swift`, `SalusSectionHeader.swift`, `SalusEmptyState.swift`, `SalusStatusChip.swift` (+ `SalusStatus.swift`), `SalusFab.swift`, `SalusDateField.swift`, `SalusDateTile.swift`, `SalusProgressRing.swift`, `SalusAvatar.swift`, `SalusIconBadge.swift`, `SalusConfirmDialog.swift`, `SalusShadow.swift`
- Modify call sites so the tree compiles at every commit: `SalusPillButton` (12 files), `SalusPillTextField` (2), `SalusFilterChip` (6), `SalusOptionRow` (3), `SalusListItemChevron` (3) — find with `grep -rl --include='*.swift' <Name> Packages/Features App | grep -v .build`
- Tests: rename `SalusPillTextFieldTests.swift` → `SalusTextFieldTests.swift`, `SalusOptionRowTests.swift` → `SalusSelectableRowTests.swift`; modify `SalusStatusTests.swift`, `SalusAvatarProgressRingDateTileTests.swift`

**Interfaces (produces; Android twin in `core/ui/.../component/`):**
```swift
public struct SalusCard<Content: View>: View {
    public enum Tone { case standard, elevated, accent, accentOutlined }
    public init(tone: Tone = .standard, selected: Bool? = nil, onTap: (() -> Void)? = nil,
                contentPadding: EdgeInsets = SalusCardDefaults.contentPadding, @ViewBuilder content: () -> Content)
}   // dark: cardBorder 1 pt line + container step (standard = surfaceContainerLow, elevated = surfaceContainer), no shadow; light: SalusShadow + faint line. selected != nil → radio trait + 1.5 pt primary edge when true.
public struct SalusButton: View {
    public enum Variant { case primary, secondary, outlined, destructive }
    public enum Size { case large, medium }   // 56 full-width / 44
    public init(_ title: String, variant: Variant = .primary, size: Size = .large, systemImage: String? = nil,
                enabled: Bool = true, action: @escaping () -> Void)
}
public struct SalusTextField: View   // same init as SalusPillTextField today, corners `medium`, fill surfaceContainerHigh, label above, supporting text below
public struct SalusChoiceChip: View { public init(label: String, isSelected: Bool, systemImage: String? = nil, action: @escaping () -> Void) }
public struct SalusSelectableRow: View { public init(title: String, subtitle: String? = nil, swatch: Color? = nil, systemImage: String? = nil, accent: FeatureAccent? = nil, isSelected: Bool, action: @escaping () -> Void) }
public struct SalusListItem<Trailing: View>: View {
    public init(title: String, subtitle: String? = nil, systemImage: String? = nil, accent: FeatureAccent? = nil,
                titleColor: Color? = nil, onTap: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing)
    public init(title: String, subtitle: String? = nil, systemImage: String? = nil, accent: FeatureAccent? = nil,
                titleColor: Color? = nil, onTap: (() -> Void)? = nil) where Trailing == SalusListItemChevron
}
public struct SalusListItemChevron: View   // stays, as the default trailing
public enum SalusStatus { case success, warning, error, neutral, accent }
public struct SalusIconBadge { public enum Size { case small /*24*/, medium /*40*/, large /*48*/ } }
```

- [ ] **Commit A (mechanical):** the five `git mv` renames + type renames + call-site renames, no styling change; `scripts/build-app.sh` green. Commit: `refactor(ui): rename SalusUI components to the M15 names`.
- [ ] `SalusCard`: `tone` + `selected` + the dark/light rule; `SalusShadow` is applied only when `!theme.isDark`. `SalusSectionHeader`: `labelSmall` on `extendedColors.overline`. `SalusEmptyState`: icon tile on `surfaceContainerHigh`, centred in its space. `SalusStatusChip`: 6 pt dot + text, `.accent` tone added. `SalusFab`: `primary` disc + `accentGlow` shadow in both modes; keep `contentDescription` → `accessibilityLabel`. `SalusDateField`/`SalusDateTile`: `medium` corners, `surfaceContainerHigh`. `SalusProgressRing`: stroke 8, track `surfaceContainerHigh`. `SalusAvatar`: glyph on `primaryContainer`. `SalusIconBadge`: three sizes. `salusConfirmDialog`: tokens only.
- [ ] `SalusButton`: four variants (primary = `primary` fill + `onPrimary`, dark adds `accentGlow` shadow; secondary = `primaryContainer`/`onPrimaryContainer`; outlined = `cardBorder` stroke + `primary` text; destructive = `error` fill + `onError`), two sizes, disabled at 0.38. `SalusTextField`, `SalusChoiceChip`, `SalusSelectableRow`, `SalusListItem` per the interfaces.
- [ ] Tests: `SalusTextFieldTests` (renamed, same cases), `SalusSelectableRowTests` (renamed), `SalusStatusTests` (+ `.accent` tint = `primary`), a new `SalusCardTests` case: `selected: true` exposes `.isSelected` trait and `selected: nil` exposes `.isButton` only when `onTap != nil` (test via the view's `accessibilityTraits` helper the file exposes, as `SalusOptionRowTests` does today).
- [ ] Every touched component: 8-palette `#Preview` (use `SalusPreviewPalettes` if Task 3 has landed in this worktree; otherwise `#Preview` light + dark and leave a `// TODO(T3)`-free note in the task report — Task 5 upgrades any remaining previews). `scripts/test-packages.sh SalusUI` + `scripts/build-app.sh` + `scripts/lint.sh`. Commit: `feat(ui): restyle the shared components to the M15 tokens`.

---

## Task 3 — New components + entrance-once + preview helper (`SalusUI`) — spec §3.3, §3.5, §3.7

**Files:**
- Create: `component/SalusIconButton.swift`, `component/SalusSegmentedTabs.swift`, `component/SalusChoiceTile.swift`, `component/SalusMetricTile.swift`, `component/SalusStepperField.swift`, `component/SalusProgressBar.swift`, `component/SalusHeroBand.swift`, `component/SalusInfoNote.swift`, `component/SalusBottomSheet.swift`, `component/SalusPagerDots.swift`, `component/SalusCheckRow.swift`, `component/SalusDisclaimer.swift`, `preview/SalusPreviewPalettes.swift`
- Modify: `component/SalusEntrance.swift` (once per instance), `Resources/Localizable.xcstrings` + `SalusUIStrings.swift` (keys `salus_sheet_close`, `salus_stepper_decrease`, `salus_stepper_increase`, `salus_stepper_suggested` — Android `core/ui/src/main/res/values{,-en}/strings.xml`)
- Tests: create `SalusStepperFieldTests.swift`, `SalusSegmentedTabsTests.swift`, `SalusPagerDotsTests.swift`; modify `SalusEntranceTests.swift`, `SalusUIStringsTests.swift`

**Interfaces (produces):**
```swift
public struct SalusIconButton: View { public enum Tone { case standard, accent, destructive }
    public init(systemImage: String, accessibilityLabel: String, tone: Tone = .standard, action: @escaping () -> Void) }   // 40 pt disc, 44 pt target
public struct SalusSegmentedTabs<T: Hashable>: View {
    public init(options: [T], selected: T, enabled: Bool = true, label: @escaping (T) -> String, onSelected: @escaping (T) -> Void) }
    // one primaryContainer pill, matchedGeometryEffect in a Namespace, animation .easeInOut(segmentedSlideDurationSeconds); selected outside options → no pill
public struct SalusChoiceTile: View { public init(label: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) }
public struct SalusMetricTile: View { public enum Delta { case up(String), down(String) }
    public init(overline: String, value: String, unit: String? = nil, delta: Delta? = nil, progress: Double? = nil, large: Bool = false) }
public struct SalusStepperField: View {
    public init(label: String, value: String, placeholder: Bool = false, rangeHint: String, autoFocus: Bool = false,
                keyboard: UIKeyboardType = .decimalPad, parse: @escaping (String) -> Bool, onValueChange: @escaping (String) -> Void,
                onDecrement: @escaping () -> Void, onIncrement: @escaping () -> Void) }
    // placeholder → value drawn at onSurfaceVariant, field text empty; autoFocus once per view instance (@State fired); commit on submit
public struct SalusProgressBar: View { public enum Tone { case primary, primarySoft, rose, warning }; public init(progress: Double, tone: Tone = .primary) }
public struct SalusHeroBand<Chip: View>: View { public init(overline: String?, title: String, subtitle: String? = nil, @ViewBuilder chip: () -> Chip) }
public struct SalusInfoNote: View { public enum Tone { case info, warning, neutral }; public init(text: String, systemImage: String, tone: Tone = .info) }
public extension View { func salusBottomSheet<C: View>(isPresented: Binding<Bool>, title: String, subtitle: String? = nil,
    detents: Set<PresentationDetent> = [.medium], @ViewBuilder content: @escaping () -> C) -> some View }
public struct SalusPagerDots: View { public init(count: Int, index: Int) }   // active 18 pt pill, inactive 6 pt at 0.4 alpha
public struct SalusCheckRow: View { public init(title: String, trailing: String? = nil) }
public struct SalusDisclaimer: View { public init(_ text: String) }
public struct SalusPreviewPalettes<Content: View>: View { public init(@ViewBuilder content: () -> Content) }   // 4 palettes × 2 modes stacked, each wrapped in .salusTheme(SalusTheme.resolve(...))
```

- [ ] Write the tests first: `SalusStepperFieldTests` — `placeholder: true` reports `hasValue == false`; `parse` rejecting text keeps the last value; submit commits. `SalusSegmentedTabsTests` — `indicatorIndex(options:selected:)` (a `static func` the view exposes) returns `nil` for a selection not in `options` and the position otherwise. `SalusPagerDotsTests` — index clamped into `0..<count`. `SalusEntranceTests` — the modifier's `hasPlayed` flag flips after the animation and a second appearance animates nothing (drive the pure `SalusEntrance.progress(for:played:)` helper). `SalusUIStringsTests` — the four new keys exist in TR and EN.
- [ ] Implement the twelve components per the interfaces and Android `core/ui/.../component/<Name>.kt` (cite lines). `SalusSegmentedTabs`: track `surfaceContainerHigh` capsule, 4 pt inset, segments ≥ 44 pt, `Role`-equivalent `.accessibilityAddTraits(.isSelected)`, `enabled == false` → `.opacity(0.38)` + `.accessibilityHidden(false)` + `.disabled(true)`.
- [ ] `SalusEntrance`: `@State private var played = false`; skip the animation when `played`; set `played = true` after it completes (spec §3.5, divergence (g)).
- [ ] `SalusPreviewPalettes` + an 8-palette `#Preview` on every new component. `scripts/test-packages.sh SalusUI` + `scripts/build-app.sh` + `scripts/lint.sh`. Commit: `feat(ui): add the M15 primitives, entrance-once and the palette preview helper`.

---

## Task 4 — Charts (`SalusUI/chart`) — spec §3.4

**Files:** modify `chart/SalusLineChart.swift`, `chart/SalusSparkline.swift`, `chart/SalusBarChart.swift`, `chart/SalusMultiSeriesChart.swift`; tests `SalusSparklineTests.swift`, `ChartUiModelTests.swift` (unchanged models — assert no API drift)

- [ ] Line + multi-series + sparkline: draw the series twice — first a `LineMark` with `lineStyle(StrokeStyle(lineWidth: 6))` in `extendedColors.accentGlow`, then the 2.5 pt `primary` line on top (Android `SalusLineChart.kt:97,118-134`: glow layer **first**). Grid `outlineVariant`; axis labels `labelSmall` on `onSurfaceVariant`; marker/annotation on `surfaceContainerHigh` with `cardBorder`. Bar chart: bars `primary`, track `surfaceContainerHigh`, `small` corners.
- [ ] Sparkline keeps its sweep-in (post-launch motion); the glow layer sweeps with it (same `trim`).
- [ ] 8-palette previews on each chart. `scripts/test-packages.sh SalusUI` + `scripts/build-app.sh` + `scripts/lint.sh`. Commit: `feat(ui): chart glow layer and M15 chart tokens`.

---

## Task 5 — Shell: painted `TabView`, inline navigation bars, root toolbar (`App/`, `SalusUI`) — spec §2

**Files:**
- Create: `Packages/SalusUI/Sources/SalusUI/shell/SalusBarAppearance.swift`, `Packages/SalusUI/Sources/SalusUI/shell/SalusRootToolbar.swift`; tests `SalusUITests/SalusBarAppearanceTests.swift`
- Modify: `App/RootView.swift:172-191` (tabs), `App/RootNavigationStack.swift` (apply the root toolbar to the five roots, pass bell/avatar closures), `App/AppStrings.swift` + `App/Localizable.xcstrings` (`salus_topbar_bell_cd`, `salus_topbar_profile_cd` — Android `core/ui` keys; put them in `SalusUIStrings` if `App` has no strings test)
- Delete: `Packages/SalusUI/Sources/SalusUI/component/SalusScreenHeader.swift` and its five call sites (`VitalsListSections.swift:32`, `AppointmentsScreen.swift:92`, `CycleScreen.swift:33`, `MedicationsScreen.swift:78`, `MoreScreen.swift:217`) → each root gets `.navigationTitle(<existing title string>)` + `.navigationBarTitleDisplayMode(.inline)` instead (Home's `HomeHeader` is Task 6's)

**Interfaces (produces):**
```swift
public enum SalusBarAppearance {
    public static func tabBar(for theme: SalusResolvedTheme) -> UITabBarAppearance      // ground surfaceContainerLow (dark) / surfaceContainerLowest (light); selected primary; unselected onSurfaceVariant; shadow = cardBorder in dark, default in light
    public static func navigationBar(for theme: SalusResolvedTheme) -> UINavigationBarAppearance   // ground background; title onSurface titleMedium; no large title
    public static func apply(_ theme: SalusResolvedTheme)   // sets UITabBar.appearance().standardAppearance/scrollEdgeAppearance and UINavigationBar.appearance() likewise
}
public extension View { func salusRootToolbar(title: String, onBell: @escaping () -> Void, onAvatar: @escaping () -> Void) -> some View }
    // .toolbar { leading: SalusIconBadge(.small, heart) ; principal: Text(verbatim: title) titleMedium ; trailing: SalusIconButton(bell) + SalusAvatar(32, onTap) } + inline mode
```

- [ ] Test `SalusBarAppearanceTests`: for CLASSIC dark and light, `tabBar(for:)` selected/normal item colours and background equal the theme's `primary` / `onSurfaceVariant` / the ground role (compare `UIColor` components within 0.01); `navigationBar(for:)` background = `background`.
- [ ] `RootView`: call `SalusBarAppearance.apply(theme)` in `.onChange(of: theme, initial: true)`; keep `.tint(primary)`; replace the `surfaceContainer` tab-bar ground with the theme-split ground; add `.id(theme.isDark)` on the `TabView` **only if** the live theme switch does not repaint (record the ruling in the task report per spec §10). Every stack: `.navigationBarTitleDisplayMode(.inline)` at the stack level is not inherited by pushed screens — so also add it inside `salusRootToolbar` and instruct T6–T13 to set it on pushed screens.
- [ ] `RootNavigationStack`: apply `salusRootToolbar(title: tab.label, onBell: { root.navigator.navigate(ReminderHealthKey()) }, onAvatar: { root.navigator.navigate(ProfileKey()) })` on each of the five roots — `settingsDestinations()` is already registered on the stacks that need it (Home, Medications, More); add it to Vitals and Appointments so `ReminderHealthKey`/`ProfileKey` resolve there too (the same registrar shape the file already documents).
- [ ] Delete `SalusScreenHeader` and migrate the five roots. `PaywallHost` unchanged. Update `docs/ios-feature-template.md:180-217` (root toolbar is the shell's; pushed screens inline title + `ToolbarItem` text actions; reference screens). Append QA rows: tab bar colours per palette, nav bar inline on every root and pushed screen, bell → Reminder Health and avatar → Profile from every tab, tab bar hidden on push.
- [ ] `scripts/test-packages.sh SalusUI` + `scripts/build-app.sh` + `scripts/lint.sh`. Commit: `feat(shell): paint the TabView and navigation bars with M15 tokens; root toolbar`.

---

## Task 6 — Home (`FeatureHome`) — spec §4.1

**Files:** modify `ui/HomeScreen.swift:150-240`, `ui/HomeHeader.swift` → replace with `SalusHeroBand`, `ui/HomeDosesCard.swift`, `ui/HomeVitalsCard.swift`, `ui/HomeCycleCard.swift`, `ui/HomeAppointmentsCard.swift`, `ui/HomeReminderReadinessCard.swift`, `Resources/Localizable.xcstrings`, `HomeStrings.swift`; tests `HomeStringsTests.swift`

- [ ] Order (Android `HomeScreen.kt`): `SalusHeroBand(overline: today date, title: greeting + name, chip: doseProgress)` `.salusEntrance(index: 0)` → `HomeReminderReadinessCard` only when `report` is a problem `.salusEntrance(1)` → snapshot pager: `TabView(.page)` with `indexDisplayMode(.never)` over the doses card, vitals card and (when visible) cycle card + `SalusPagerDots` below `.salusEntrance(2)` → AI card (`SalusCard(.accentOutlined)` with an `aiGradient` stroke, title, "Yeni özet" `SalusButton(.medium)`) `.salusEntrance(3)` → appointments section (`SalusSectionHeader` "BUGÜNKÜ RANDEVULAR" + cards → detail) `.salusEntrance(4)`.
- [ ] Strings (Android `feature/home` M15 additions): `home_overline_today`, `home_view_details`, `home_see_all`, `home_ai_new_summary`, `home_pager_doses`, `home_pager_vitals`, `home_pager_cycle`, `home_next_dose`, `home_next_dose_none`, `home_last_dose`, `today_appointments_title`, `home_take_dose`; delete the 4 keys Android removed (compare `git -C ../salus-android diff 3391896..529a30f -- feature/home/src/main/res/values/strings.xml`). `HomeStringsTests` key pins updated.
- [ ] 8-palette + xxxLarge previews. QA rows (§1 Home row; §3 pager swipe). `scripts/test-packages.sh FeatureHome` + build + lint. Commit: `feat(home): M15 hero, readiness placement, snapshot pager, AI card`.

---

## Task 7 — Medications list, detail, editor (`FeatureMedications`) — spec §4.2, §4.6, §4.8

**Files:** modify `ui/list/{MedicationsScreen,MedicationsUiState,MedicationsViewModel,MedicationCard}.swift`, `ui/detail/{MedicationDetailScreen,MedicationDetailSections,MedicationDetailUiState,MedicationDetailViewModel}.swift`, `ui/editor/{MedicationEditorScreen,MedicationEditorSections,DoseTimesSection}.swift`, `Resources/Localizable.xcstrings`, `MedicationsStrings.swift`; tests `MedicationsViewModelTests.swift`, `MedicationDetailViewModelTests.swift`, `MedicationsStringsTests.swift`

**Interfaces:** `MedicationsUiState.nextDoseMinuteOfDay: Int?` (earliest pending dose today; nil when none; recomputed per emission from the clock — Android `MedicationsViewModel.kt` `dayRefresh`); `MedicationDetailUiState.daysOfSupply: Int?` = `stockCount / dosesPerDay` with `dosesPerDay` recurrence-weighted (Android `MedicationDetailViewModel.kt`).

- [ ] Tests first (twins of Android `MedicationsViewModelTest` / `MedicationDetailViewModelTest` M15 cases): next dose = earliest pending today, nil when all taken, changes across midnight (advance the fake clock and re-emit); days of supply for daily / every-other-day / weekly recurrence, nil without stock.
- [ ] List: overline "BUGÜN • <date>" + "Tedavi & Rutin" title block; three `SalusMetricTile`s (Aktif ilaç = count, Kaydedilen doz = `recordedDosePercent` with `progress`, Sıradaki doz = formatted `nextDoseMinuteOfDay` or `medications_metric_none`); `MedicationCard` on `SalusCard(.standard)` with the form icon in a `SalusIconBadge(.medium, accent: medications)`, dose-time `SalusStatusChip`s, "Şimdi al" `SalusButton(.medium)`; `SalusFab` extended "İlaç ekle".
- [ ] Detail: toolbar trailing `SalusStatusChip(.accent, "Aktif Takip")` + "Düzenle" `Button`; hero `SalusCard(.elevated)`; reminders `SalusListItem(trailing: Toggle)`; "Kullanım Planı" `SalusMetricTile`s; supply card "≈ %lld gün yetecek" / "Günde %lld kez".
- [ ] Editor: inline title "Yeni İlaç Ekle" / "İlacı Düzenle", trailing "Kaydet"; `SalusCard(.standard)` sections: name `SalusTextField`, form = 8 `SalusChoiceTile`s in a 4-column `LazyVGrid`, strength + unit, instructions, plan (recurrence `SalusSegmentedTabs` days / interval), dose times `SalusChoiceChip`s + add, dates, stock.
- [ ] Strings: the 41 Android `feature/medications` M15 additions (list them from the Android diff; e.g. `medications_overline_today`, `medications_title_routine`, `medications_metric_active/recorded/next/none`, `medications_take_now`, `medications_fab_add`, `editor_section_*`, `editor_*_placeholder`, `medication_detail_*`, `medications_detail_days_of_supply`, `medications_detail_per_day`, `recurrence_tab_days/interval`) and delete the 17 removed. Key pins updated; banned-word test kept.
- [ ] Previews (8-palette on the list), QA rows. `scripts/test-packages.sh FeatureMedications` + build + lint. Commit: `feat(medications): M15 list metrics, detail hero and editor sections`.

---

## Task 8 — Vitals list + editors (`FeatureVitals`) — spec §4.3, §4.7

**Files:** modify `ui/list/{VitalsScreen,VitalsListSections,VitalsUiState,VitalsViewModel,VitalsStateBuilders}.swift`, `ui/editor/{Weight,BloodPressure,Glucose}Editor{Screen,UiState,ViewModel}.swift`, `ui/editor/VitalsEditorField.swift` → `VitalsEditorChrome.swift` (shared toolbar/title/tip), `Resources/Localizable.xcstrings`, `VitalsStrings.swift`; create `domain/VitalsLimits.swift` (shared ranges: kg 20–300, systolic 60–250, diastolic 30–150, pulse 30–220, glucose 20–600 — copy from Android `feature/vitals/.../domain/VitalsLimits.kt`); tests `VitalsViewModelTests.swift`, `{Weight,BloodPressure,Glucose}EditorViewModelTests.swift`, `VitalsStringsTests.swift`, create `VitalsLimitsTests.swift`

**Interfaces:** `VitalsUiState.selectedType: VitalType`, `VitalsRow.delta: String?` + `trend: Trend?`; each editor `UiState.isSaveEnabled: Bool` (false while the value is the placeholder suggestion), `hasValue: Bool`.

- [ ] Tests first: `VitalsLimitsTests` (use cases and editors reject the same bounds); list delta/trend vs the previous entry; create mode starts with `hasValue == false` and `isSaveEnabled == false`, `−`/`+` from the suggestion makes it a value; edit mode starts with a value.
- [ ] List: `SalusSegmentedTabs` over `VitalType` (Kilo / Tansiyon / Şeker with the latest value in the label as Android's KPI chips); chart card: header = latest value + unit + `SalusStatusChip` (measured at), range `SalusChoiceChip`s inside the card, `SalusLineChart`; "GEÇMİŞ" section rows `SalusListItem` with value + unit + delta on `metricUp`/`metricDown`; `SalusFab` icon opens the selected type's editor.
- [ ] Editors: per type, no type switch; `VitalsEditorChrome(title:subtitle:tip:onSave:)` provides inline title, trailing "Kaydet" (disabled per `isSaveEnabled`), `SalusInfoNote(tip)`; fields on `SalusStepperField(placeholder: !hasValue, autoFocus: isCreate)`; BP = systolic + diastolic side by side + pulse; note `SalusTextField`; measured-at `SalusDateField` + time.
- [ ] Strings: the 26 Android `feature/vitals` M15 additions (`vitals_kpi_*`, `vitals_latest_label`, `vitals_chart_section`, `vitals_history_section`, `vitals_metric_max/avg/min`, `vitals_editor_title_new/edit`, `vitals_editor_subtitle`, `vitals_editor_tip`, `vitals_bp_hint_sys/dia`, `vitals_save_measurement`, `vitals_*_label`, `vitals_note_placeholder`, `vitals_value_none`, `vitals_edit`), delete the 19 removed; pins updated.
- [ ] 8-palette + xxxLarge previews on the list; QA rows (§1 Vitals; §3 create-mode placeholder + autofocus; §4 stepper at xxxLarge). `scripts/test-packages.sh FeatureVitals` + build + lint. Commit: `feat(vitals): M15 type tabs, chart card, per-type editors with suggestions`.

---

## Task 9 — Appointments list, detail, editor (`FeatureAppointments`) — spec §4.4, §4.9, §4.10

**Files:** modify `ui/list/{AppointmentsScreen,AppointmentsUiState,AppointmentsViewModel,AppointmentCard}.swift`, `ui/detail/{AppointmentDetailScreen,AppointmentDetailUiState,AppointmentDetailViewModel,MapsLink}.swift`, `ui/editor/AppointmentEditorScreen.swift`, `Resources/Localizable.xcstrings`, `AppointmentsStrings.swift`; tests `AppointmentsViewModelTests.swift`, `AppointmentDetailViewModelTests.swift`, `AppointmentsStringsTests.swift`

**Interfaces:** `AppointmentsUiState.selectedTab: AppointmentsTab` (`.upcoming`, `.past`) replaces `isPastExpanded`; `AppointmentDetailUiState.relativeDay: RelativeDay` (`.today`, `.tomorrow`, `.inDays(Int)`, `.past`) derived per emission from the clock (Android A62 ruling).

- [ ] Tests first: `selectedTab` defaults to `.upcoming`, `.past` shows the past list; `relativeDay` for today / tomorrow / +3 / yesterday and that it changes when the fake clock crosses midnight.
- [ ] List: `SalusSegmentedTabs` "Yaklaşan (%lld)" / "Geçmiş (%lld)"; day headers as `SalusSectionHeader`; `AppointmentCard` on `SalusCard` with `SalusDateTile`, time chip, reminder chip, trailing delete `SalusIconButton(.destructive)`; extended `SalusFab` "Yeni Randevu"; empty states `SalusEmptyState`.
- [ ] Detail (full screen, no card): inline title, trailing "Düzenle"; centred hero — `SalusIconBadge(.large, accent: appointments)`, title `headlineMedium`, full date line, `SalusStatusChip(.accent, relativeDay)`; "DETAYLAR": date row (time chip trailing), doctor row or "Doktor ekle" placeholder (`titleColor: onSurfaceVariant`, taps → editor), location row with subtitle "Haritalarda aç" + chevron opening `mapsURL(for:)` (existing `MapsLink.swift`) when non-empty else "Konum ekle", reminders row or "Hatırlatıcı ekle"; "NOTLAR" or "Not ekle"; health-notes `SalusInfoNote`; `SalusButton("Takvime Ekle", .primary)` + `SalusButton("Sil", .destructive)`; **no bottom "Düzenle"**.
- [ ] Editor: `SalusTextField`s (title, doctor, location, notes), `SalusDateField` + `SalusTimeField`, reminder offsets as `SalusChoiceChip`s + add, large primary "Kaydet".
- [ ] Strings: the 25 Android `feature/appointments` M15 additions (`appointments_tab_upcoming/past`, `appointments_*_placeholder`, `appointments_datetime_label`, `appointments_reminders_label`, `appointments_add_to_calendar`, `appointment_detail_notes`, `appointments_detail_tell_doctor`, `appointment_detail_open_maps`, `appointment_detail_section_details`, `appointment_detail_add_doctor/location/reminder/note`, `appointment_detail_relative_today/tomorrow/past/in_days`, `appointments_day_today/tomorrow`, `appointments_no_past`, `appointments_new`), delete the 18 removed; pins updated.
- [ ] Previews, QA rows (§1; §3 maps row, swipe delete/undo). `scripts/test-packages.sh FeatureAppointments` + build + lint. Commit: `feat(appointments): M15 tabs, full-screen detail with maps row, editor`.

---

## Task 10 — More hub, theme + language sheets, Profile, About, Reminder Health (`FeatureSettings`) — spec §2.3, §4.5, §4.11, §4.17

**Files:** modify `ui/more/{MoreScreen,MoreScreenComponents,MoreUiState,MoreViewModel}.swift`, delete `ui/more/MoreSelectionDialog.swift`, create `ui/more/ThemeSheet.swift` + `ui/more/LanguageSheet.swift`, modify `ui/profile/ProfileScreen.swift`, `ui/about/AboutScreen.swift`, `ui/reminderhealth/ReminderHealthScreen.swift`, `Resources/Localizable.xcstrings`, `SettingsStrings.swift`; tests `MoreViewModelTests.swift`, `SettingsStringsTests.swift`

**Interfaces:** `MoreUiState.presentedSheet: MoreSheet?` (`.theme`, `.language`) replaces the `.theme/.colorTheme/.language` dialog enum; `ThemeSheet(state:onEvent:)` shows mode rows (system / light / dark) + palette rows with `PremiumTheme.swatch(dark:)` swatches, "Varsayılan" badge on CLASSIC; selecting a premium palette without entitlement keeps the existing `colorThemeSelected` → paywall path, CLASSIC never does (A60).

- [ ] Tests first: `MoreViewModelTests` — opening theme sets `presentedSheet == .theme`; selecting CLASSIC never emits the paywall effect; selecting OCEAN without premium does; language sheet selection calls the locale controller.
- [ ] More: profile `SalusCard` (avatar, name, sex chip, "PRO" `SalusStatusChip(.accent)` when premium) → Profile; premium band `SalusCard(.accent)`; sections "SAĞLIK" / "GÖRÜNÜM" / "BİLDİRİMLER" / "GÜVENLİK" / "UYGULAMA" of `SalusListItem`s (trends, cycle when visible, theme, language, reminder health, app lock, about); footer version. Theme and language rows open `.salusBottomSheet` (`.medium` detent) with `SalusSelectableRow`s.
- [ ] Profile: `SalusHeroBand` variant (avatar + live name + sex chip); `SalusTextField` name; sex as three `SalusChoiceTile`s + cycle `SalusInfoNote` (change-confirm dialog untouched); birth date / height / weight fields; health notes; trailing "Kaydet". About: rows with `SalusIconBadge(.small)` icons. Reminder Health: `SalusStatusChip` per status (`reminder_health_status_ok/warning/error`), `SalusCard` sections.
- [ ] Strings: the 31 Android `feature/settings` M15 additions (`more_section_*`, `more_theme_mode`, `more_language`, `more_pro_badge`, `more_premium_cta`, `more_footer`, `theme_sheet_title/subtitle`, `theme_section_mode/palette`, `theme_default_badge`, `theme_system`, `language_sheet_subtitle`, `profile_*`, `about_features_title`, `reminder_health_status_*`), delete the 24 removed; pins updated.
- [ ] Previews, QA rows (§1 More/Profile/About; §5 theme sheet live switch repaints tab bar, language sheet). `scripts/test-packages.sh FeatureSettings` + build + lint. Commit: `feat(settings): M15 More hub, theme and language sheets, profile hero`.

---

## Task 11 — AI summary, Doctor report, Trends (`FeatureAIHealth`, `FeatureTrends`) — spec §4.12, §4.13, §4.16

**Files:** modify `FeatureAIHealth/ui/{AiSummaryScreen,AiSummaryUiState,AiSummaryViewModel,DoctorReportScreen,DoctorReportPreviewScreen}.swift`, `FeatureTrends/ui/{TrendsScreen,MetricSummaryCard,DoseWeeksCard,LockedCallout}.swift`, both `Resources/Localizable.xcstrings` + `*Strings.swift`; tests `AiSummaryViewModelTests.swift`, `AiHealthStringsTests.swift`, `TrendsStringsTests.swift`

**Interfaces:** `AiSummaryUiState.metricSnapshot: AiMetricSnapshot?` (average BP, dose %, average pulse for the selected period — Android `AiSummaryViewModel.kt`).

- [ ] Test first: `metricSnapshot` aggregates the period's stats and is nil without data.
- [ ] AI summary: toolbar share `SalusIconButton`; `SalusSegmentedTabs` Haftalık / Aylık; `SalusCard(.accent)` banner "Yapay zekâ analizi" + generated-at `SalusStatusChip`; three `SalusMetricTile`s; summary paragraphs as a mint-dotted list; loading / empty / error **centred** in the card (`frame(maxWidth: .infinity, minHeight:)` + `.multilineTextAlignment(.center)`); "Yeni özet" `SalusButton`.
- [ ] Doctor report: tabs; "Raporun Hazır" `SalusCard(.accent)` with tiles; "BELGE ÖNİZLEME" section (existing preview) with "Büyüt"; "RAPORA DAHİL EDİLENLER" `SalusCheckRow`s; sticky "PDF olarak paylaş" `SalusButton`.
- [ ] Trends: `SalusSegmentedTabs` over `TrendsRange` with `enabled: !state.isLocked`; one `SalusCard(.standard)` per metric: overline (`trends_metric_*_overline`), chart, `SalusMetricTile(delta:)`; `LockedCallout` on `SalusCard(.accentOutlined)`; paywall behaviour unchanged.
- [ ] Strings: the 20 Android `feature/aihealth` and 4 `feature/trends` M15 additions (`ai_summary_banner_title`, `ai_summary_share_pdf`, `ai_summary_refresh`, `ai_summary_open_report`, `ai_summary_metric_*`, `ai_summary_state_fresh/cached`, `doctor_report_preview_*`, `doctor_report_pdf_chip`, `doctor_report_includes_title`, `doctor_report_section_*`; `trends_metric_*_overline`, `trends_summary_count`), delete the removed ones; pins updated; banned-word test kept (no model names).
- [ ] Previews, QA rows. `scripts/test-packages.sh FeatureAIHealth FeatureTrends` + build + lint. Commit: `feat(aihealth,trends): M15 tabs, banners, metric tiles, centred states`.

---

## Task 12 — Cycle, Paywall, App Lock (`FeatureCycle`, `FeaturePaywall`, `App/Lock`) — spec §4.14, §4.15, §4.10b, §4.17

**Files:** modify `FeatureCycle/ui/calendar/{CycleScreen,CycleCalendarSections,CycleSummarySections,CycleReminderSections}.swift`, `ui/day/CycleDayScreen.swift`, `FeaturePaywall/ui/PaywallSheet.swift` (+ `PaywallUiState.swift` for `selectedPlan` if absent), `App/Lock/AppLockScreen.swift`, `App/PaywallHost.swift` (no presentation change), both `Resources/Localizable.xcstrings` + `*Strings.swift`; tests `CycleStringsTests.swift`, `PaywallStringsTests.swift`, `PaywallFeatureListTests.swift`

- [ ] Cycle: inline title "Döngü & Regl Takibi", trailing "today" `SalusIconButton` (jumps to today); month row; grid cells: period `tertiary` fill, predicted dashed `tertiary` ring (`strokeBorder(style: StrokeStyle(dash:))`), fertile `primaryContainer`, ovulation dot, today `primary` ring; legend row; "BUGÜNÜN BELİRTİLERİ" chips; analysis `SalusCard` with confidence `SalusStatusChip`; reminder `SalusListItem(trailing: Toggle)`. Cycle day: verify whether `CycleDayRoute` is pushed or a sheet (`grep -n "sheet\|navigate" CycleRoute.swift CycleDayRoute.swift`); pushed → inline title + trailing "Kaydet"; sheet → `salusBottomSheet` chrome. Record which in the task report. Content: flow `SalusChoiceChip`s, mood `SalusChoiceTile`s, symptom chips, note `SalusTextField`.
- [ ] Paywall (stays `fullScreenCover`): hero (`SalusIconBadge(.large)`, title, subtitle), feature rows as `SalusListItem`s with feature-tinted icons, plan cards `SalusCard(selected: plan == state.selectedPlan, onTap:)` in a group with `.accessibilityElement(children: .contain)`, primary CTA `SalusButton`, "Geri yükle" `SalusButton(.outlined, .medium)`, terms `SalusDisclaimer`, close `SalusIconButton` (`paywall_close`). Do **not** add a "Şifreli yedekleme" line (`PaywallFeatureListTests` pins the list).
- [ ] App lock: `SalusButton`s and tokens only.
- [ ] Strings: the 13 Android `feature/cycle` additions (`cycle_symptoms_title`, `cycle_flow_title`, `cycle_mood_title`, `cycle_overline`, `cycle_today_cd`, `cycle_today_symptoms`, `cycle_see_all`, `cycle_no_symptoms_today`, `cycle_analysis_title`, `cycle_confidence_chip`, `cycle_period_due_today`, `cycle_reminder_summary`, `cycle_note_placeholder`) and `paywall_close`; delete the removed; pins updated.
- [ ] Previews, QA rows (§1 Cycle; §5 paywall cover, day editor). `scripts/test-packages.sh FeatureCycle FeaturePaywall` + build + lint. Commit: `feat(cycle,paywall): M15 calendar, day editor chrome, full-screen paywall`.

---

## Task 13 — Onboarding (`FeatureOnboarding`) — spec §5

**Files:** modify `ui/OnboardingUiState.swift`, `ui/OnboardingViewModel.swift`, `ui/OnboardingScreen.swift`, `ui/OnboardingHeader.swift`, `ui/OnboardingHero.swift`; replace `ui/OnboardingStepContent.swift` with `ui/OnboardingWelcomePage.swift`, `ui/OnboardingPersonalPage.swift`, `ui/OnboardingHealthPage.swift`; `Resources/Localizable.xcstrings`, `OnboardingStrings.swift`; tests rewrite `OnboardingViewModelTests.swift`, `OnboardingUiStateTests.swift`, `OnboardingStringsTests.swift`

**Interfaces (twin of Android `OnboardingUiState.kt:13-104`, `OnboardingViewModel.kt`):**
```swift
public enum OnboardingStep: String, CaseIterable, Sendable { case welcome, personalDetails, healthAndPermissions }
public struct OnboardingUiState { // keep: steps, stepIndex, name, sex, birthDateEpochDay, heightText, weightText, healthNotes, isSaving, lastStepDirection
    public var remindersEnabled: Bool = true; public var remindersAvailable: Bool = true
    public var showCycleNote: Bool { sex == .female || sex == .other }
    public var canContinue: Bool   // personalDetails: sex != nil && !showInvalidHeight && !showInvalidWeight; others true
    public var canSkip: Bool       // personalDetails: sex != nil; healthAndPermissions: true; welcome: false
}
public enum OnboardingEvent { /* existing cases */ case remindersToggled(Bool) }
public enum OnboardingEffect { case requestNotificationPermission }   // emitted from advance() on the last step when remindersAvailable && remindersEnabled
```
`OnboardingSection` and the per-field steps are deleted. `steps` = `[.welcome, .personalDetails, .healthAndPermissions]` always (three pages whether or not notifications can be asked for; `remindersAvailable` hides the toggle).

- [ ] Rewrite `OnboardingViewModelTests` as the Android `OnboardingViewModelTest` twin (13 cases, camelCase of the backtick names): `theFlowIsThreePagesWhetherOrNotNotificationsCanBeAskedFor`, `remindersStartOnAndFollowTheSwitch`, `continuingFromThePersonalPageWaitsForASex`, `skippingThePersonalPageWaitsForASexToo`, `skippingThePersonalPageClearsItsOptionalAnswersAndKeepsTheSex`, `skippingTheLastPageClearsTheNotesAsksForNothingAndFinishes`, `finishingAsksForTheNotificationPermissionWhileTheSwitchIsOn`, `finishingAsksForNothingOnceTheSwitchIsOff`, `finishingAsksForNothingWhenRemindersAreUnavailable` (the API-33 twin), `backStepsBetweenThePagesAndDoesNothingOnTheFirst`, `anUnusableMeasurementBlocksThePageButABlankOneDoesNot`, `finishingWritesTheProfileTheFirstWeightAndTheCompletionFlag`, `aSkippedWeightWritesNoMeasurementAndBlankNotesStayNull`. Negative "no effect" cases await the fake's settle (`WaitUntil.swift`) before asserting.
- [ ] Implement the state, events and view model per the interfaces; `finish()` unchanged; `skip()` on `personalDetails` clears name/birth date/height/weight, keeps sex; on `healthAndPermissions` clears notes and finishes without a request.
- [ ] Pages per spec §5.2 on `SalusUI` components (`SalusIconBadge(.large)` glyph tiles, `SalusChoiceChip` trust chips, `SalusTextField`, three `SalusChoiceTile`s + `SalusInfoNote`, `SalusDateField`, height/weight `SalusTextField`s side by side, notes field + "Yalnızca bu cihazda" chip, reminders `Toggle` row, `SalusButton`s). `OnboardingHeader`: "ADIM %lld/3" + three-segment bar. Privacy link → `salusBottomSheet` with the About privacy text (`SettingsStrings` is another package — copy the key into `FeatureOnboarding` as `onboarding_privacy_body`, Android did the same). Keep the existing step-slide transition between pages; the gate stays above the `TabView` with its own safe-area handling.
- [ ] Strings: the 28 Android `feature/onboarding` M15 additions (`onboarding_step_of`, `onboarding_trust_local/no_account/no_ads`, `onboarding_start`, `onboarding_privacy_link/title/body`, `onboarding_personal_title/body`, `onboarding_name_label`, `onboarding_sex_label`, `onboarding_cycle_note`, `onboarding_birth_label`, `onboarding_age_caption`, `onboarding_height_label`, `onboarding_weight_label`, `onboarding_next`, `onboarding_skip`, `onboarding_health_title/body`, `onboarding_notes_label`, `onboarding_only_device`, `onboarding_reminders_title/subtitle`, `onboarding_finish`, `onboarding_later`, `onboarding_later_caption`), delete the 32 removed; `OnboardingStrings.swift` accessors and pins updated.
- [ ] Previews (three pages, light + dark, xxxLarge); QA rows §2 (full flow, skip paths, permission prompt on/off, back). `scripts/test-packages.sh FeatureOnboarding` + build + lint. Commit: `feat(onboarding): three-page flow mirrored from Android M15`.

---

## Task 14 — Sweep: orphans, rules, ledger, tokens doc, QA sheet — spec §3.6, §6, §8.2 (6), §8.3, §11

**Files:** every `Localizable.xcstrings` + `*Strings.swift` (orphans), `CLAUDE.md` (§"Design system rules", §"Copy and localisation rules"), `docs/ios-feature-template.md`, `docs/qa/m16-manual-qa.md` (§6 known risks; consistency pass), and in `../salus-android`: `docs/parity-ledger.md` (rows A43, A47, A50–A62 → "landed (`<iOS commit>`)" with iOS `file:line`; A48, A49 → "diverged by decision — spec §2.4"), `docs/design/design-tokens.md` (every `iOS pending (M16)` cell → iOS `file:line`)

- [ ] Orphan sweep: for each package, list `*Strings.swift` accessors with zero call sites (`grep -c` per accessor) and delete them plus their xcstrings entries; run each `*StringsTests`. Grep the tree for `SalusScreenHeader`, `SalusPillButton`, `SalusPillLabel`, `SalusPillTextField`, `SalusFilterChip`, `SalusOptionRow`, `MoreSelectionDialog`, `OnboardingSection`, `pickerStyle(.segmented)` — all must be zero outside `.build`.
- [ ] `CLAUDE.md` + `docs/ios-feature-template.md`: the §8.3 rules (shell owns tab-bar look and root toolbar; pushed screens inline title + `ToolbarItem` text actions; the full `SalusUI` component list; no hex / no raw points; `SalusSegmentedTabs` replaces `Picker(.segmented)`; overlines upper-case; banned words; QA in `docs/qa/`).
- [ ] Android docs commit (in `../salus-android`, on `main`, docs only): ledger rows + token-doc flips; commit `docs: close the M15 iOS-pending rows for M16`. Do not push it — the owner pushes with the iOS merge.
- [ ] QA sheet: fill §6 known risks (live theme switch repaint, xxxLarge stepper, sheets on iPad-class widths), check every screen has a §1 row. Full gate `scripts/ci.sh`. Commit: `chore: M16 sweep — orphaned strings, rules, ledger, QA sheet`.

---

## Final review

Dispatch one Opus reviewer over `git diff main...HEAD` against the spec with the M15 review prompt shape (spec compliance table per section; Critical / Important / Minor). Fix Critical and Important in a fix wave (each fix its own commit, gated), then hand `docs/qa/m16-manual-qa.md` to the owner. Merge (`git rebase main` → `git merge --ff-only`) and the `CURRENT_PROJECT_VERSION` bump happen only after the owner's QA, on the owner's word.
