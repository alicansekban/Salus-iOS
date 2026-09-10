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
