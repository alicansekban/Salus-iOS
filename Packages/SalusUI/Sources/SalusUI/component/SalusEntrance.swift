import SalusDesignSystem
import SwiftUI

/// Entrance for content that appears on first composition: a fade plus a short upward settle,
/// delayed by one §11 stagger step per index so a column of sections arrives in order instead of
/// all at once. The twin of Android's `Modifier.salusEnter(index)`
/// (`core/ui/.../anim/SalusEnter.kt:31-54`, parity row A43).
///
/// `delaySeconds(index:)` is the pure ladder — `salusStaggerDelay` (`SalusEnter.kt:64-65`) —
/// lifted out so the floor/step/cap rules are table-testable, the pattern
/// `SparklineGeometry` set (`SalusSparkline.swift:71`); ``progress(for:played:)`` is the
/// entrance-once rule beside it (spec §3.5, divergence (g)).
public enum SalusEntrance {
    // swiftlint:disable modifier_order
    /// `index.coerceIn(0, StaggerCapIndex) * StaggerStepMs` (`SalusEnter.kt:64-65`), in seconds.
    public nonisolated static func delaySeconds(index: Int) -> TimeInterval {
        let capped = min(max(index, 0), SalusMotion.entranceStaggerCapIndex)
        return TimeInterval(capped) * SalusMotion.entranceStaggerStepSeconds
    }
    // swiftlint:enable modifier_order

    /// `(1f - progress) * EnterTravel.toPx()` (`SalusEnter.kt:53-54`) — the settle distance.
    /// `EnterTravel = 24.dp` (`SalusEnter.kt:57`); pt ≡ dp between the twins.
    static let travel: CGFloat = 24

    /// What one appearance of ``SwiftUI/View/salusEntrance(index:)`` does.
    public struct Progress: Equatable, Sendable {
        /// The progress the content is drawn at once the appearance is handled. Always `1` — an
        /// entrance ends settled whether it travelled there or was already there.
        public let target: CGFloat
        /// How long before the travel starts, or `nil` when there is nothing to animate.
        public let delay: TimeInterval?

        /// Whether this appearance animates at all.
        public var animates: Bool { delay != nil }
    }

    // swiftlint:disable modifier_order
    /// The entrance plays **once per view instance** (spec §3.5, divergence (g)).
    ///
    /// `TabView` keeps a tab's root alive, so returning to a tab re-runs `onAppear` on content
    /// that has already arrived — and replaying the fade there reads as the screen reloading
    /// rather than as the screen being there all along. A view that has played is therefore
    /// *settled*: drawn at its target, animating nothing.
    ///
    /// Pure, so the rule is table-testable without rendering: the flag it is given is the
    /// modifier's own `@State`.
    ///
    /// - Parameters:
    ///   - index: the stagger position, which sets the delay of a first appearance.
    ///   - played: whether this view instance has already played its entrance.
    public nonisolated static func progress(for index: Int, played: Bool) -> Progress {
        Progress(target: 1, delay: played ? nil : delaySeconds(index: index))
    }
    // swiftlint:enable modifier_order
}

/// `Modifier.salusEnter(index)` (`SalusEnter.kt:36-54`): opacity 0→1 plus the upward settle.
extension View {
    /// - Parameter index: the stagger position; higher indices arrive later, capped at §11's 200 ms.
    public func salusEntrance(index: Int = 0) -> some View {
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
    /// Spec §3.5, divergence (g): the played flag is `@State` on the modifier, so it lives
    /// exactly as long as the view instance does. It escalates to `@SceneStorage` only if a task
    /// proves a tab's root is re-created rather than kept alive.
    @State private var played = false

    func body(content: Content) -> some View {
        content
            .opacity(Double(progress))
            .offset(y: (1 - progress) * SalusEntrance.travel)
            .onAppear {
                let step = SalusEntrance.progress(for: index, played: played)
                guard let delay = step.delay else {
                    // Already arrived: draw it where it landed, animate nothing.
                    progress = step.target
                    return
                }
                let animation = reduceMotion
                    ? SalusMotion.entranceReducedMotionAnimation
                    : SalusMotion.entranceAnimation.delay(delay)
                withAnimation(animation) {
                    progress = step.target
                } completion: {
                    played = true
                }
            }
    }
}
