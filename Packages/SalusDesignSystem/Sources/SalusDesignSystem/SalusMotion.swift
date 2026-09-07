import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §10.
//
// There is no motion object in Android's `core/designsystem/`; the one shared motion spec
// lives in `core/navigation/.../SalusTransitions.kt` and governs screen push/pop. This file
// holds those constants only — wiring them into a navigation stack is not a token concern.
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

/// §10 — the shared motion constants. Source: `SalusTransitions.kt`.
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
