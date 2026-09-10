# Post-Launch Motion Mirror (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror the Android `feature/post-launch-motion` branch on iOS — the motion token set (A42), the Home entrance stagger (A43), the sparkline draw-in (A44), and the animated progress ring + onboarding step transitions (A45) — so both platforms move with the same rhythm, per the parity ledger rows the Android branch recorded.

**Architecture:** Motion tokens land in `SalusDesignSystem/SalusMotion.swift` beside the existing §10 navigation-motion constants (they are a new §11 group, not a rewrite of §10). The entrance modifier and the sparkline sweep live in `SalusUI`; the ring sweep stays inside `SalusProgressRing`; Home and Onboarding consume. The system tab bar is NOT bounced (Android's bar is a custom in-app view, iOS's is the platform's — the twin of the §6.2 divergence class: platform furniture is not ours to reimplement, and the ledger's A45 wording "spring-scale tab icon" describes Android's custom bar only). Tab-icon motion on iOS is **out of scope, parked in the ledger as a deliberate platform divergence**.

**Tech Stack:** SwiftUI, Swift 6 strict concurrency, Swift Testing (`swift test` per package via `scripts/test-packages.sh`), `swiftformat`/`swiftlint` via `scripts/lint.sh`.

**Spec:** `salus-android/docs/parity-ledger.md` rows A42–A45 (the binding contract, written by the Android branch), `salus-android/docs/design/design-tokens.md` (token source of truth), Android reference implementation at `salus-android` `feature/post-launch-motion` commits `bf97cbd`, `dbf9c24`, `37fc51f`, `dee9d23`, `0cc6c85`.

## Global Constraints

Copied from the project rules; every task implicitly includes these:

- **Token doc first:** `design-tokens.md` is the only source of token values. The new §11 motion constants must be **added to that doc on the Android side in the same change-set** (the doc lives in the Android repo; this plan adds one task to update it — the Android branch is merged locally, un-pushed, so the doc update rides the same branch).
- iOS mirrors values exactly: durations 150/300/450 ms, easing `CubicBezierEasing(0.2f, 0f, 0f, 1f)` → SwiftUI `timingCurve(0.2, 0.0, 0.0, 1.0)`, stagger 40 ms/step capped at 200 ms (cap index 5).
- **Reduce motion honored** everywhere: `@Environment(\.accessibilityReduceMotion)` — entrances collapse to an instant or opacity-only appearance, the sparkline draws instantly, the ring jumps, onboarding swaps instantly. Android's branch did not wire reduce-motion (Compose `animateTo` has no system gate); on iOS this is a platform expectation and the §10 behavior contract already mandates it — this is a deliberate one-directional improvement, recorded in the ledger rows' completion note, not a divergence from A42–A45.
- Swift 6 language mode, no downgrades; no force unwrapping/cast/try; `swiftformat --lint` + `swiftlint --strict` clean; 120-char max width.
- Docs/comments/commits in English; no user-facing strings in this plan (motion only).
- Each task: `swift test` for the touched packages green + lint clean + conventional commit(s) on branch `feature/post-launch-motion` (matching the Android branch name). Run `scripts/ci.sh` at the end of the last task.
- No new dependencies of any kind (nothing is needed — all SwiftUI).
- Tests via Swift Testing (`import Testing`, `@Test`, `#expect`); pure helpers testable without a host app (`nonisolated static` where needed).

---

### Task 1 — §11 entrance tokens in the token doc + `SalusMotion` (Android doc + iOS `SalusDesignSystem`)

**Files:**
- Modify: `salus-android/docs/design/design-tokens.md` — add §11 "Entrance & component motion" (rides the Android `feature/post-launch-motion` branch).
- Modify: `salus-ios/Packages/SalusDesignSystem/Sources/SalusDesignSystem/SalusMotion.swift`
- Test: `salus-ios/Packages/SalusDesignSystem/Tests/SalusDesignSystemTests/SalusDesignTokensTests.swift` (extend `MotionTokenTests`)

**Interfaces:**
- Consumes: Android `SalusMotion` (`Motion.kt`) — `Fast=150`, `Normal=300`, `Slow=450`, `Emphasized=CubicBezierEasing(0.2f, 0f, 0f, 1f)`, `StaggerStepMs=40`, `StaggerCapIndex=5`.
- Produces (used by Tasks 2–5):
  - `SalusMotion.entranceDurationSeconds: TimeInterval` = 0.45 (`Slow`)
  - `SalusMotion.feedbackDurationSeconds: TimeInterval` = 0.15 (`Fast`)
  - `SalusMotion.stateChangeDurationSeconds: TimeInterval` = 0.3 (`Normal`)
  - `SalusMotion.emphasizedEasing = SalusTimingCurve(0.2, 0.0, 0.0, 1.0)`
  - `SalusMotion.entranceStaggerStepSeconds: TimeInterval` = 0.04
  - `SalusMotion.entranceStaggerCapIndex = 5`
  - `SalusMotion.entranceAnimation` — timingCurve, 0.45 s
  - `SalusMotion.entranceReducedMotionAnimation` — `.easeInOut(duration: 0.3)` (the §10 reduced-motion pattern: fade-capable, no travel)
  - `package static var entranceTokens: [String: SalusMotionToken]` — the six §11 values for the token-count test.

- [ ] **Step 1.1: Write the failing test**

In `SalusDesignTokensTests.swift`, extend `MotionTokenTests` with:

```swift
    @Test("entrance tokens match design-tokens.md §11")
    func entranceTokens() {
        #expect(SalusMotion.entranceDurationSeconds == 0.45)
        #expect(SalusMotion.feedbackDurationSeconds == 0.15)
        #expect(SalusMotion.stateChangeDurationSeconds == 0.3)
        #expect(SalusMotion.emphasizedEasing == SalusTimingCurve(0.2, 0.0, 0.0, 1.0))
        #expect(SalusMotion.entranceStaggerStepSeconds == 0.04)
        #expect(SalusMotion.entranceStaggerCapIndex == 5)
        #expect(SalusMotion.entranceTokens.count == 6)
    }
```

- [ ] **Step 1.2: Run it to see it fail**

Run: `cd salus-ios/Packages/SalusDesignSystem && swift test --filter MotionTokenTests`
Expected: compile FAIL — `entranceDurationSeconds` unresolved.

- [ ] **Step 1.3: Add §11 to the token doc (Android side)**

In `salus-android/docs/design/design-tokens.md`, after §10's behavior contract, add:

```markdown
## 11. Entrance & component motion

Added 2026-09-10 by the post-launch motion branch (parity rows A42–A45). Source:
`core/designsystem/.../theme/Motion.kt` — the first motion object in `core/designsystem/`,
sibling of the §10 navigation spec.

| Token | Value | Source |
|---|---|---|
| fast (feedback) | `150 ms` | `Motion.kt` (`Fast`) |
| normal (state change) | `300 ms` | `Motion.kt` (`Normal`) |
| slow (entrance / sweep / travel) | `450 ms` | `Motion.kt` (`Slow`) |
| emphasized easing | `CubicBezierEasing(0.2f, 0f, 0f, 1f)` — cubic-bezier(0.2, 0.0, 0.0, 1.0) | `Motion.kt` (`Emphasized`) |
| entrance stagger step | `40 ms` per index | `Motion.kt` (`StaggerStepMs`) |
| entrance stagger cap | `200 ms` (index 5+) | `Motion.kt` (`StaggerCapIndex`) |

Behavior contract, both platforms:

- Entrances are fade + short upward settle (24 dp / 24 pt); the sparkline sweeps in; the dose
  ring sweeps to its new value; onboarding steps slide directionally (quarter width, both
  platforms). Durations and easing come from this table only — never ad-hoc at a call site.
- iOS additionally honors `accessibilityReduceMotion` everywhere an entrance plays (Android's
  Compose animations have no system gate; recorded as a one-directional platform expectation,
  not a divergence).
- The iOS twin of the token object is `SalusDesignSystem/SalusMotion.swift` beside §10's
  navigation constants.
```

Also append to the doc's changelog table: `| 2026-09-10 | Added entrance & component motion tokens (§11) — parity rows A42–A45. |`

- [ ] **Step 1.4: Add the tokens to `SalusMotion.swift`**

Append to `SalusMotion` (after `listMutationReducedMotionTransition`):

```swift
    // MARK: §11 — entrance & component motion (parity rows A42–A45)

    /// 450 ms. Source: `Motion.kt` (`Slow`) — entrances, sweeps, directional travel.
    public static let entranceDurationSeconds: TimeInterval = 0.45

    /// 150 ms. Source: `Motion.kt` (`Fast`) — feedback-level state changes.
    public static let feedbackDurationSeconds: TimeInterval = 0.15

    /// 300 ms. Source: `Motion.kt` (`Normal`) — colour cross-fades and mid-size changes.
    public static let stateChangeDurationSeconds: TimeInterval = 0.3

    /// `CubicBezierEasing(0.2f, 0f, 0f, 1f)` — cubic-bezier(0.2, 0.0, 0.0, 1.0).
    /// Source: `Motion.kt` (`Emphasized`).
    public static let emphasizedEasing = SalusTimingCurve(0.2, 0.0, 0.0, 1.0)

    /// 40 ms per stagger index. Source: `Motion.kt` (`StaggerStepMs`).
    public static let entranceStaggerStepSeconds: TimeInterval = 0.04

    /// Stagger delays stop growing at this index (5 × 40 ms = 200 ms).
    /// Source: `Motion.kt` (`StaggerCapIndex`).
    public static let entranceStaggerCapIndex = 5

    /// The entrance animation: emphasized easing over 450 ms (`Motion.kt` + `SalusEnter.kt`).
    public static var entranceAnimation: Animation {
        emphasizedEasing.animation(duration: entranceDurationSeconds)
    }

    /// Reduce-motion form of an entrance: opacity only, no travel (§11 behavior contract).
    public static var entranceReducedMotionAnimation: Animation {
        .easeInOut(duration: stateChangeDurationSeconds)
    }

    /// The six §11 tokens, for the doc-count test.
    package static var entranceTokens: [String: SalusMotionToken] {
        [
            "entranceDuration": .durationSeconds(entranceDurationSeconds),
            "feedbackDuration": .durationSeconds(feedbackDurationSeconds),
            "stateChangeDuration": .durationSeconds(stateChangeDurationSeconds),
            "entranceEasing": .timingCurve(emphasizedEasing),
            "entranceStaggerStep": .durationSeconds(entranceStaggerStepSeconds),
            "entranceStaggerCap": .divisor(entranceStaggerCapIndex)
        ]
    }
```

Update the file's header comment to note it now carries §10 (navigation) **and** §11 (entrance) groups.

- [ ] **Step 1.5: Run the tests**

Run: `cd salus-ios/Packages/SalusDesignSystem && swift test`
Expected: all PASS (the §10 assertions untouched — `allTokens` is not modified, so `counts["motion"] == 8` stays true; §11 has its own `entranceTokens` dictionary).

- [ ] **Step 1.6: Lint + commit (both repos)**

Android: `cd salus-android && git add docs/design/design-tokens.md && git commit -m "docs: add §11 entrance & component motion tokens to the token doc"`
iOS: `cd salus-ios && git checkout -b feature/post-launch-motion && git add Packages/SalusDesignSystem && git commit -m "feat(designsystem): add §11 entrance motion tokens to SalusMotion"`

---

### Task 2 — `salusEntrance(index:)` modifier (`SalusUI`)

**Files:**
- Create: `salus-ios/Packages/SalusUI/Sources/SalusUI/component/SalusEntrance.swift`
- Test: create `salus-ios/Packages/SalusUI/Tests/SalusUITests/SalusEntranceTests.swift`

**Interfaces:**
- Consumes: Task 1's tokens; `SalusProgressRing.swift`'s `nonisolated static` precedent for pure helpers.
- Produces (Task 3 uses on Home sections):
  - `public extension View { func salusEntrance(index: Int = 0) -> some View }` — opacity 0→1 + 24 pt upward settle, delayed `index × 40 ms` capped at index 5, 450 ms emphasized; reduce-motion → opacity-only, no delay.
  - `nonisolated static func salusEntranceDelaySeconds(index: Int) -> TimeInterval` on `SalusEntrance` — the pure stagger ladder, table-tested.

- [ ] **Step 2.1: Write the failing test**

`salus-ios/Packages/SalusUI/Tests/SalusUITests/SalusEntranceTests.swift`:

```swift
import SalusDesignSystem
import Testing
@testable import SalusUI

/// The §11 stagger ladder — `salusStaggerDelay` in `SalusEnter.kt:64-65`, in seconds.
/// One step per index, floored at zero and capped so a long Home column still arrives in
/// one gesture instead of dribbling in.
@Suite("SalusEntrance")
struct SalusEntranceTests {
    @Test("zero and negative indices start immediately", arguments: [0, -3])
    func floor(_ index: Int) {
        #expect(SalusEntrance.delaySeconds(index: index) == 0)
    }

    @Test("each index adds one stagger step", arguments: [(1, 0.04), (3, 0.12), (5, 0.2)])
    func steps(_ index: Int, _ expected: TimeInterval) {
        #expect(SalusEntrance.delaySeconds(index: index) == expected)
    }

    @Test("delays stop growing at the cap", arguments: [6, 100])
    func cap(_ index: Int) {
        #expect(SalusEntrance.delaySeconds(index: index) == 0.2)
    }
}
```

- [ ] **Step 2.2: Run to see it fail**

Run: `cd salus-ios/Packages/SalusUI && swift test --filter SalusEntranceTests`
Expected: compile FAIL — `SalusEntrance` unresolved.

- [ ] **Step 2.3: Implement**

`salus-ios/Packages/SalusUI/Sources/SalusUI/component/SalusEntrance.swift`:

```swift
import SalusDesignSystem
import SwiftUI

/// Entrance for content that appears on first composition: a fade plus a short upward settle,
/// delayed by one §11 stagger step per index so a column of sections arrives in order instead of
/// all at once. The twin of Android's `Modifier.salusEnter(index)`
/// (`core/ui/.../anim/SalusEnter.kt:31-54`, parity row A43).
///
/// `delaySeconds(index:)` is the pure ladder — `salusStaggerDelay` (`SalusEnter.kt:64-65`) —
/// lifted out so the floor/step/cap rules are table-testable, the pattern
/// `SparklineGeometry` set (`SalusSparkline.swift:71`).
public enum SalusEntrance {
    /// `index.coerceIn(0, StaggerCapIndex) * StaggerStepMs` (`SalusEnter.kt:64-65`), in seconds.
    nonisolated public static func delaySeconds(index: Int) -> TimeInterval {
        let capped = min(max(index, 0), SalusMotion.entranceStaggerCapIndex)
        return TimeInterval(capped) * SalusMotion.entranceStaggerStepSeconds
    }

    /// `(1f - progress) * EnterTravel.toPx()` (`SalusEnter.kt:53-54`) — the settle distance.
    /// `EnterTravel = 24.dp` (`SalusEnter.kt:57`); pt ≡ dp between the twins.
    static let travel: CGFloat = 24
}

/// `Modifier.salusEnter(index)` (`SalusEnter.kt:36-54`): opacity 0→1 plus the upward settle.
public extension View {
    /// - Parameter index: the stagger position; higher indices arrive later, capped at §11's 200 ms.
    func salusEntrance(index: Int = 0) -> some View {
        modifier(SalusEntranceModifier(index: index))
    }
}

/// The state machine behind ``View/salusEntrance(index:)``: a progress 0→1 driven once on appear,
/// mapped to opacity and a 24 pt upward offset — `graphicsLayer { alpha; translationY }`
/// (`SalusEnter.kt:51-54`) as opacity + offset here, so the render stays GPU-backed.
private struct SalusEntranceModifier: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .opacity(Double(progress))
            .offset(y: (1 - progress) * SalusEntrance.travel)
            .onAppear {
                let delay = reduceMotion ? 0 : SalusEntrance.delaySeconds(index: index)
                withAnimation(
                    reduceMotion
                        ? SalusMotion.entranceReducedMotionAnimation
                        : SalusMotion.entranceAnimation.delay(delay)
                ) {
                    progress = 1
                }
            }
    }
}
```

- [ ] **Step 2.4: Run the tests**

Run: `cd salus-ios/Packages/SalusUI && swift test`
Expected: SalusEntranceTests PASS, all existing suites stay green.

- [ ] **Step 2.5: Lint + commit**

Run: `cd salus-ios && ./scripts/lint.sh`
Then: `git add Packages/SalusUI && git commit -m "feat(ui): add the salusEntrance staggered entrance modifier"`

---

### Task 3 — Home stagger + ring sweep consumption (`FeatureHome`)

**Files:**
- Modify: `salus-ios/Packages/Features/FeatureHome/Sources/FeatureHome/ui/HomeScreen.swift` (sections column, ~lines 169-213)
- Modify: `salus-ios/Packages/Features/FeatureHome/Sources/FeatureHome/ui/HomeHeader.swift:89-96` (ring call)
- Modify: `salus-ios/Packages/SalusUI/Sources/SalusUI/component/SalusProgressRing.swift`

**Interfaces:**
- Consumes: Task 2's `salusEntrance(index:)`; Task 1's tokens.
- Produces: no public API changes. Ring animates internally on `progress` change; sections stagger in with indices mirroring Android (header 0, readiness 1, doses 2, appointments 3, cycle 4, vitals 5, AI 6).

- [ ] **Step 3.1: Animate the ring**

In `SalusProgressRing.swift`, change the body's progress `Circle` to animate its trim on `progress` changes. Add at the top of the struct:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Change the progress circle to:

```swift
            Circle()
                .trim(from: 0, to: ringSweep)
                .stroke(.white, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
```

with the computed sweep plus the change-driven animation. Use the `.animation(_, value:)` modifier form attached to the trimmed circle (idempotent on appearance, re-animates on change, no `onAppear` needed):

```swift
    /// The animated trim fraction: the twin of `animateFloatAsState` over `progress`
    /// (`SalusProgressRing.kt:36-41`, parity row A45) — 450 ms emphasized; reduce motion jumps.
    private var ringSweep: CGFloat { CGFloat(progress) }
```

and on the trimmed circle:

```swift
                .animation(
                    reduceMotion ? nil : SalusMotion.entranceAnimation,
                    value: progress
                )
```

(When `progress` first arrives the circle animates from 0 — the same sweep-in Android's `Animatable` produces on first composition, since SwiftUI animates the first value change too when the view appears with the initial value already applied; the visual result matches: the ring sweeps to its first position on appearance.)

Update the file-header port comment with the A45 note (450 ms sweep, reduce-motion instant).

- [ ] **Step 3.2: Stagger the Home sections**

In `HomeScreen.swift`'s `sections` view, wrap each block per the Android indices — readiness group, doses group (header+card), appointments group, cycle group, vitals group, AI group — each with `.salusEntrance(index: N)` where N mirrors Android (readiness 1 … AI 6), and add `.salusEntrance(index: 0)` to the `HomeHeader(...)` call in `content`. **Keep the `VStack(spacing: SalusSpacing.xs)` rhythm untouched** — attach the modifier to existing views/`Group`s rather than inserting wrapper stacks, so no spacing doubles. Read lines 168-240 first and mirror the Android wrapping decision (Task 5 of the Android plan; the trailing spacer equivalent does not exist here — iOS `sections` ends at the AI card).

- [ ] **Step 3.3: Run the tests**

Run: `cd salus-ios && ./scripts/test-packages.sh 2>&1 | grep -E "FeatureHome|SalusUI|error|failed" | head -20` (or targeted `swift test` in `Packages/SalusUI` and `Packages/Features/FeatureHome`).
Expected: all green (no logic touched).

- [ ] **Step 3.4: Lint + commit**

Run: `cd salus-ios && ./scripts/lint.sh`
Then: `git add Packages/SalusUI Packages/Features/FeatureHome && git commit -m "feat(home): stagger Home's sections in and sweep the dose ring"`

---

### Task 4 — Sparkline draw-in sweep (`SalusUI`)

**Files:**
- Modify: `salus-ios/Packages/SalusUI/Sources/SalusUI/chart/SalusSparkline.swift`
- Test: extend `salus-ios/Packages/SalusUI/Tests/SalusUITests/SalusSparklineTests.swift`

**Interfaces:**
- Consumes: Task 1's tokens; existing `SparklineGeometry`.
- Produces: unchanged public signature `SalusSparkline(values:lineColor:)`. The line now draws itself in over 450 ms on first appearance — the twin of Android's `PathMeasure` segment (`SalusSparkline.kt:48`, parity row A44).

- [ ] **Step 4.1: Implement the sweep**

In `SalusSparkline.swift`: keep `SparklineGeometry.points` untouched (its table tests pin the mapping — the A44 pure-mapping port already exists and is green). Add sweep state + `onAppear` driving, and trim the stroked path by sweeping a "fraction drawn" over the path's length. The simplest SwiftUI twin of `PathMeasure.getSegment` is `Path.trimmedPath(from: 0, to: fraction)`:

```swift
public struct SalusSparkline: View {
    private let values: [Float]
    private let lineColor: Color?

    @Environment(\.salusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep: CGFloat = 0

    // … init unchanged …

    public var body: some View {
        Canvas { context, size in
            let points = SparklineGeometry.points(for: values, in: size)
            guard let start = points.first else { return }

            var path = Path()
            path.move(to: start)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            // The draw-in: `PathMeasure.getSegment(0, length × sweep)` (`SalusSparkline.kt:48-53`)
            // — SwiftUI's `trimmedPath` is the same segment operation.
            context.stroke(
                path.trimmedPath(from: 0, to: sweep),
                with: .color(lineColor ?? theme.colorScheme.primary),
                style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .onAppear {
            guard !reduceMotion else {
                sweep = 1
                return
            }
            withAnimation(SalusMotion.entranceAnimation) {
                sweep = 1
            }
        }
        .accessibilityHidden(true)
    }
}
```

Note the stroke's `lineCap: .round` on a trimmed path draws a cap at the sweep's leading edge — the same rounded tip Compose's `PathMeasure` segment + `StrokeCap.Round` leaves mid-sweep.

- [ ] **Step 4.2: Test the geometry is untouched — no new pure surface**

`SparklineGeometry` tests already pin the mapping; the sweep is draw-phase state with no extractable pure function beyond `trim`. Add **one** regression pin to `SalusSparklineTests.swift`'s suite doc note (no new test needed — nothing pure changed). If the implementer finds a pure seam worth testing (e.g. a `Self.clampedSweep(_:)`), prefer extracting + testing it, but do not invent one for coverage theater.

- [ ] **Step 4.3: Run the tests**

Run: `cd salus-ios/Packages/SalusUI && swift test`
Expected: SalusSparklineTests and all suites green.

- [ ] **Step 4.4: Lint + commit**

Run: `cd salus-ios && ./scripts/lint.sh`
Then: `git add Packages/SalusUI && git commit -m "feat(ui): sweep SalusSparkline in on first appearance"`

---

### Task 5 — Onboarding directional step transitions (`FeatureOnboarding`)

**Files:**
- Modify: `salus-ios/Packages/Features/FeatureOnboarding/Sources/FeatureOnboarding/ui/OnboardingScreen.swift` (the `steps` view, ~lines 157-168)

**Interfaces:**
- Consumes: Task 1's tokens.
- Produces: no API changes. Steps slide directionally: forward steps enter from the trailing edge, back from the leading; quarter-width travel (`parallaxDivisor`'s 4 is the §10 sibling of Android's `full / 4`); slide 450 ms emphasized + fade 300 ms; reduce motion → instant swap.

- [ ] **Step 5.1: Implement the transition**

Replace the single `OnboardingStepContent(state: state, onEvent: onEvent)` inside `steps` with a transition container keyed on `state.stepIndex` (the twin of Android's `AnimatedContent(targetState = state.stepIndex)`, `OnboardingScreen.kt:124-137`, parity row A45):

```swift
    /// `AnimatedContent(targetState = state.stepIndex)` (`OnboardingScreen.kt:124-137`) — steps
    /// travel in the flow's direction: forward from the trailing edge, back from the leading one.
    private var steps: some View {
        GeometryReader { proxy in
            ScrollView {
                OnboardingStepContent(state: state, onEvent: onEvent)
                    .id(state.stepIndex)
                    .padding(.horizontal, SalusSpacing.lg)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .transition(.asymmetric(
                        insertion: stepTransition(forward: isForward),
                        removal: stepTransition(forward: !isForward)
                    ))
                // `.opacity` fade rides the same transition container.
            }
            .scrollDismissesKeyboard(.interactively)
            .salusDismissesKeyboardOnTap()
            .animation(reduceMotion ? nil : SalusMotion.entranceAnimation, value: state.stepIndex)
        }
    }
```

The exact mechanism is implementer's choice within these bounds (ZStack-both-steps vs `.id()`-rebind are both acceptable SwiftUI forms; `.id(state.stepIndex)` + `transition` + container-level `.animation(value:)` is the idiomatic one). Requirements, non-negotiable:
- Keyed on `state.stepIndex` (an `Int`), forward = target ≥ current, exactly like Android.
- Quarter-width horizontal travel, 450 ms emphasized; fade 300 ms (`stateChangeDurationSeconds`) — combine slide+fade in one asymmetric transition.
- Reduce motion → no animation (instant swap).
- `state` is a value struct — the outgoing step renders `OnboardingStepContent(state: state)` unchanged; no `copy(stepIndex:)` is needed on iOS because the transition reads the identity change, not a derived state.
- Keyboard dismissal + scroll behaviors unchanged; footer and header untouched.

- [ ] **Step 5.2: Run the tests**

Run: `cd salus-ios/Packages/Features/FeatureOnboarding && swift test`
Expected: OnboardingViewModel/UiState tests green (no logic touched).

- [ ] **Step 5.3: Lint + commit**

Run: `cd salus-ios && ./scripts/lint.sh`
Then: `git add Packages/Features/FeatureOnboarding && git commit -m "feat(onboarding): slide between steps instead of swapping instantly"`

---

### Task 6 — Parity ledger close-out + full CI

**Files:**
- Modify: `salus-android/docs/parity-ledger.md` — A42–A45's iOS columns: `open` → `landed`, citing the iOS commits.
- (iOS side) run `scripts/ci.sh` as the merge gate.

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces: the ledger rows closed; iOS branch ready for merge.

- [ ] **Step 6.1: Full CI**

Run: `cd salus-ios && ./scripts/ci.sh`
Expected: all five gates green (toolchain, lint, custom rules, all-package tests, app build).

- [ ] **Step 6.2: Update the ledger (Android side)**

In `salus-android/docs/parity-ledger.md`, rows A42–A45: change the iOS-side status from `open — …` to `landed (<short-ios-commit>) — <one-line note>`, and append the reduce-motion note: "iOS additionally honors `accessibilityReduceMotion` at every §11 site (platform expectation; recorded, not a divergence). A45's tab-bounce is Android-only: iOS's tab bar is the system's, custom-bar motion has no twin there."

- [ ] **Step 6.3: Commit (Android side)**

Run: `cd salus-android && git add docs/parity-ledger.md && git commit -m "docs: close parity rows A42-A45 for the iOS motion mirror"`

---

## Manual smoke checklist (after merge, on simulator)

1. Home: hero + sections arrive in order (~0.2-0.7 s); taking a dose sweeps the ring.
2. Vitals sparkline on Home draws left-to-right on first appearance.
3. Onboarding (fresh install): steps slide forward; back slides the other way.
4. Settings → accessibility → Reduce Motion ON: everything appears instantly, no travel.
5. Dark theme + premium palettes: repeat 1-4 (motion uses no palette values, but verify).
6. VoiceOver: staggered entrance must not change element order or reachability.

## Out of scope (parked in the ledger, deliberate)

- **Tab-icon bounce (A45, iOS half):** iOS's tab bar is the system `TabView` furniture; animating its selected icon means replacing it with a custom bar — a redesign decision, not a port. Android's row describes its own custom bar. Recorded as a platform difference, not a bug.
- **Custom icon set:** same as Android — awaits designer assets.