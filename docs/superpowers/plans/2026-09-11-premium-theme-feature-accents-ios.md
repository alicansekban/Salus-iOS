# Premium Theme → Feature Accents (iOS mirror) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror Android's `premiumExtendedColors` so an entitled OCEAN / SUNSET / FOREST theme repaints the per-feature accents and the hero gradient on iOS (Home, Medications, Vitals, Appointments, Cycle, Trends, profile band).

**Architecture:** `SalusTheme.resolve` (`Packages/SalusDesignSystem/Sources/SalusDesignSystem/SalusTheme.swift:56-84`) currently calls `extendedColors(dark:)`, which only picks `SalusExtendedColors.light/.dark`. Add `extendedColors(dark:premiumTheme:)` backed by a new `SalusPremiumExtendedColors.swift` holding six `SalusExtendedColors` values with the **exact hexes** from Android's `PremiumExtendedColors.kt`. All 33 consumer files already read `extendedColors.<feature>`, so no view changes.

**Tech Stack:** Swift 5.10+, SwiftUI, Swift Testing (`@Suite`/`@Test`/`#expect`), SwiftPM; gate = `scripts/test-packages.sh SalusDesignSystem` + `scripts/lint.sh`.

**Spec:** Android source of truth `salus-android/core/designsystem/src/main/kotlin/com/alicansekban/salus/core/designsystem/theme/PremiumExtendedColors.kt` and `salus-android/docs/design/design-tokens.md` §4.6 (both land in the Android task first). Read them before writing a single hex.

## Global Constraints

- Hex parity with Android is byte-for-byte; the test table below is the parity check. Do not "improve" a colour on iOS.
- `.classic` returns `SalusExtendedColors.light` / `.dark` unchanged (`==`), mirroring Android's identity rule.
- `success`/`warning` unchanged across themes; every non-accent token untouched.
- Follow `SalusPremiumAccents.swift` conventions: one `private enum <Theme><Mode>ExtendedValues` per palette with `static let` per hex (no inline hex in an initializer), doc comment citing the Kotlin `file:line`.
- Keep `.macOS(.v14)` test-host concession as is; no new dependencies.
- Commit per task, Conventional Commits, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

---

### Task 1: `SalusPremiumExtendedColors.swift` + resolution + tests

**Files:**
- Create: `Packages/SalusDesignSystem/Sources/SalusDesignSystem/SalusPremiumExtendedColors.swift`
- Modify: `Packages/SalusDesignSystem/Sources/SalusDesignSystem/SalusTheme.swift:56-84` — `resolve` passes `premiumTheme` into the extended-colour pick; keep `extendedColors(dark:)` as a one-line forwarder with `premiumTheme: .default` so existing callers/tests compile.
- Create: `Packages/SalusDesignSystem/Tests/SalusDesignSystemTests/SalusPremiumExtendedColorsTests.swift`

**Interfaces:**
- Produces: `public static func extendedColors(dark: Bool, premiumTheme: PremiumTheme) -> SalusExtendedColors` on `SalusTheme`.
- Produces: `extension SalusExtendedColors { static let oceanLight, oceanDark, sunsetLight, sunsetDark, forestLight, forestDark }` — each built as `SalusExtendedColors.light`/`.dark` with the six accent members replaced (a `with(...)`-style private helper or memberwise init; `success`/`warning` must come from the brand value, not be retyped).

**Behaviour to pin in `SalusPremiumExtendedColorsTests` (Swift Testing):**
- [ ] `classic is the brand set`: `SalusTheme.extendedColors(dark: false, premiumTheme: .classic) == .light`, dark likewise.
- [ ] `resolve threads the palette through`: `SalusTheme.resolve(systemIsDark: false, premiumTheme: .ocean).extendedColors == .oceanLight` (and one dark case).
- [ ] `hex parity with Android` — a literal table `[(PremiumTheme, dark: Bool, feature: KeyPath<SalusExtendedColors, FeatureAccent>, accent: UInt32, onAccent: UInt32, container: UInt32, onContainer: UInt32)]` covering 3 themes × 2 modes × 5 features (30 rows) plus a 6-row hero table `(theme, dark, top: UInt32, bottom: UInt32)`; assert each resolved `Color == Color(hex:)`. Copy the hexes from the Kotlin file, not from memory.
- [ ] `status colours never move`: for every theme×mode, `success`/`warning` `==` brand's.
- [ ] `WCAG AA on the parity table`: compute contrast from the `UInt32` hexes in the table (relative luminance per sRGB, `(max+0.05)/(min+0.05)`), assert ≥ 4.5 for (onAccent, accent) and (onContainer, container). This guards against a mistranscribed hex that still "looks" right.

**Steps:**
- [ ] Write the test file first; run `scripts/test-packages.sh SalusDesignSystem` → compile failure (expected).
- [ ] Create `SalusPremiumExtendedColors.swift`; wire `SalusTheme.swift`.
- [ ] Run `scripts/test-packages.sh SalusDesignSystem` → green. Run `scripts/lint.sh` → clean.
- [ ] Run `scripts/build-app.sh` (or the xcodebuild step `scripts/ci.sh` uses) → the app scheme still links.
- [ ] Commit: `feat(designsystem): mirror Android's premium feature accents and hero`.

### Task 2: Ledger + token doc pointer

**Files:**
- Modify: `salus-android/docs/parity-ledger.md` row **A46** (added by the Android task): status → shipped, iOS file + commit SHA. (Ledger lives in the Android repo; commit it there on the same Android branch, `docs(ledger): close A46`.)
- Modify: `Packages/SalusDesignSystem/Sources/SalusDesignSystem/SalusTheme.swift` header comment (lines 1-30) — one line noting extended colours now resolve per palette, citing `PremiumExtendedColors.kt`.

- [ ] Commit (iOS): `docs(designsystem): note per-palette extended colour resolution`.

## Verification (reviewer)

```bash
scripts/test-packages.sh SalusDesignSystem && scripts/lint.sh
```
Expected: green; `git diff main --stat` touches only the three files in Task 1 plus the header comment.
