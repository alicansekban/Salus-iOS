import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §10 (navigation) and §11 (entrance &
// component motion).
//
// §10 has no motion object in Android's `core/designsystem/`; the one shared motion spec
// lives in `core/navigation/.../SalusTransitions.kt` and governs screen push/pop. §11 adds the
// first motion object in `core/designsystem/` (`Motion.kt`), the sibling entrance/component
// spec. This file holds both groups — wiring them into a navigation stack or an entrance is
// not a token concern.
//
// Behavior contract these constants serve:
//   - The push spec is attached per pushed entry, never to the navigator as a whole. Tab
//     roots keep the instant swap the bottom bar needs.
//   - The back gesture drives the animation's progress rather than replacing it with a jump
//     cut: keep the interactive pop gesture enabled, never substitute a non-interactive
//     dismiss.
//   - Honor `accessibilityReduceMotion` and swap the slide for an instant transition.

/// A cubic Bézier easing curve, as the two control points SwiftUI's `timingCurve` takes.
public struct SalusTimingCurve: Equatable, Sendable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// This curve as a SwiftUI animation of the given duration.
    public func animation(duration: TimeInterval) -> Animation {
        .timingCurve(x1, y1, x2, y2, duration: duration)
    }
}

/// The value of one motion token. The group mixes durations, curves, counts and
/// deliberate absences, so the registry carries a tagged value rather than one scalar type.
public enum SalusMotionToken: Equatable, Sendable {
    case durationSeconds(TimeInterval)
    case timingCurve(SalusTimingCurve)
    case divisor(Int)
    /// No transition at all — an instant swap.
    case noTransition
    case zIndex(Double)
    /// No size transform — every screen fills the same window.
    case noSizeTransform
}

/// §10 — the shared navigation-motion constants. Source: `SalusTransitions.kt`.
public enum SalusMotion {
    /// 400 ms. Source: `SalusTransitions.kt:69` (`DURATION_MILLIS`).
    public static let pushPopDurationSeconds: TimeInterval = 0.4

    /// `FastOutSlowInEasing` — cubic-bezier(0.4, 0.0, 0.2, 1.0).
    /// Source: `SalusTransitions.kt:66`.
    public static let pushPopEasing = SalusTimingCurve(0.4, 0.0, 0.2, 1.0)

    /// The covered screen drifts a quarter of its width. Source: `SalusTransitions.kt:72`.
    public static let parallaxDivisor = 4

    /// The arriving screen draws on top. Source: `SalusTransitions.kt:51-53`.
    public static let enterZIndexPush: Double = 1

    /// The dismissing screen stays above the one it uncovers.
    /// Source: `SalusTransitions.kt:61-62`.
    public static let enterZIndexPop: Double = -1

    /// The push/pop animation: `Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.4)`.
    /// A stock `NavigationStack` push already approximates this shape; only hand-built
    /// transitions need the curve spelled out.
    public static var pushPopAnimation: Animation {
        pushPopEasing.animation(duration: pushPopDurationSeconds)
    }

    /// 300 ms. Source: `SalusTransitions.kt` (`SalusListMotion.MUTATION_DURATION_MILLIS`).
    public static let listMutationDurationSeconds: TimeInterval = 0.3

    /// The list-mutation animation (§10): the moment a row appears, disappears or moves
    /// inside a keyed list — the undo snackbar's resurrected row included, since it is the
    /// same state change read in reverse. The Route wraps the state change in
    /// `withAnimation(SalusMotion.listMutationAnimation)`; the row carries the
    /// `listMutationTransition`. Reduce motion keeps the fade and drops the move.
    public static var listMutationAnimation: Animation {
        pushPopEasing.animation(duration: listMutationDurationSeconds)
    }

    /// Fade only — the reduce-motion form of the list-mutation spec.
    public static var listMutationReducedMotionAnimation: Animation {
        .easeInOut(duration: listMutationDurationSeconds)
    }

    /// The row-level twin of ``listMutationAnimation``: fade plus a short vertical move.
    public static var listMutationTransition: AnyTransition {
        .opacity.combined(with: .move(edge: .bottom))
    }

    /// The reduce-motion form: the fade stays, the move goes (§10).
    public static var listMutationReducedMotionTransition: AnyTransition {
        .opacity
    }

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

    /// The segmented-tabs indicator slide: `tween(SalusMotion.Normal,
    /// FastOutSlowInEasing)` — the same curve a pushed screen travels with
    /// (`SalusSegmentedTabs.kt:86-88`). Named so the slide can never drift into a second
    /// duration/easing pair; duration `= stateChangeDurationSeconds`, easing `= pushPopEasing`
    /// (the §10 push/pop curve, which Android spells `FastOutSlowInEasing`).
    public static let segmentedSlideDurationSeconds: TimeInterval = stateChangeDurationSeconds

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

    /// The eight motion tokens of §10.
    package static var allTokens: [String: SalusMotionToken] {
        [
            "pushPopDuration": .durationSeconds(pushPopDurationSeconds),
            "pushPopEasing": .timingCurve(pushPopEasing),
            "parallaxDivisor": .divisor(parallaxDivisor),
            // Tab roots swap instantly: `EnterTransition.None` / `ExitTransition.None`
            // (`SalusTransitions.kt:31-35`).
            "tabRootTransition": .noTransition,
            "enterZIndexPush": .zIndex(enterZIndexPush),
            "enterZIndexPop": .zIndex(enterZIndexPop),
            // `null` everywhere (`SalusTransitions.kt:53`, `:63`).
            "sizeTransform": .noSizeTransform,
            "listMutationDuration": .durationSeconds(listMutationDurationSeconds)
        ]
    }
}
