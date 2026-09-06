// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusProgressRing.kt:27-59`.
//
// Kotlin's composable takes `progress`, `label`, `strokeWidth` (defaulting to
// `SalusProgressRingDefaults.StrokeWidth` = 6), `trackColor` (defaulting to
// `Color.White.copy(alpha = 0.24f)`) and `progressColor` (defaulting to `Color.White`). The iOS
// port keeps the two knobs that have callers — `progress` and `label` — plus `size` and
// `strokeWidth`, and hardcodes the white track/progress defaults because the ring renders on dark
// surfaces (the hero gradient band) exactly as Kotlin's defaults do (`SalusProgressRing.kt:22-25`).
//
// Divergence (c), recorded in the M14 plan: Android defers clamping `progress` to 0...1; iOS takes
// the cheap fix now. `CircularProgressIndicator` clamps its own value, but the port clamps at the
// boundary so the stored value is always in range and the clamp is testable.
//
// Divergence (j), the determinate ring (M14 QA row 1.4, user-verified bug): the M3 mapping note
// `CircularProgressIndicator → ProgressView` no longer applies. `ProgressView(value:total:)` with
// `.progressViewStyle(.circular)` renders as an INDETERMINATE spinner on iOS 17 — `.circular`
// ignores the value, so the user saw a spinning wheel instead of a static "3/5" ring. The ring is
// therefore drawn by hand: a `Circle().trim(from: 0, to: progress)` stroke, rotated `-90°` so the
// arc starts at 12 o'clock (Compose's `CircularProgressIndicator` starts at top; SwiftUI's `trim`
// starts at 3 o'clock). The track stays a full-circle stroke behind it.

import SalusDesignSystem
import SwiftUI

/// Determinate circular progress ring with a centered label — the shared dose-progress visual used
/// on Home. Renders on dark surfaces (e.g. the hero gradient band), hence the white defaults
/// (`SalusProgressRing.kt:22-25`).
public struct SalusProgressRing: View {
    private let progress: Float
    private let label: String
    private let size: CGFloat
    private let strokeWidth: CGFloat

    /// - Parameters:
    ///   - progress: the fraction filled, clamped to 0...1 (divergence (c), M14 plan).
    ///   - label: the centered text, e.g. "3/5" (`SalusProgressRing.kt:48-52`).
    ///   - size: the ring's diameter (`SalusProgressRingDefaults.Size` = 64).
    ///   - strokeWidth: the ring's stroke width (`SalusProgressRingDefaults.StrokeWidth` = 6).
    public init(
        progress: Float,
        label: String,
        size: CGFloat = SalusProgressRingDefaults.size,
        strokeWidth: CGFloat = SalusProgressRingDefaults.strokeWidth
    ) {
        self.progress = Self.clamped(progress)
        self.label = label
        self.size = size
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        ZStack {
            // The track: `trackColor = Color.White.copy(alpha = 0.24f)` (`SalusProgressRing.kt:33`),
            // drawn as a full circle stroke behind the progress ring.
            Circle()
                .stroke(.white.opacity(0.24), lineWidth: strokeWidth)
            // The progress: `CircularProgressIndicator(progress = { progress }, …)` with
            // `color = Color.White` and `strokeCap = StrokeCap.Round` (`SalusProgressRing.kt:40-47`).
            // Drawn with `trim` because `.progressViewStyle(.circular)` ignores determinate values
            // on iOS 17 and renders an indeterminate spinner (divergence (j), M14 QA row 1.4).
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(.white, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: label)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    /// Clamps `progress` to 0...1 (divergence (c), M14 plan — Android deferred it).
    /// `nonisolated` so the pure helper is callable from a nonisolated test context, like
    /// `SalusAvatar.initials(from:)`.
    nonisolated static func clamped(_ progress: Float) -> Float {
        min(max(progress, 0), 1)
    }
}

/// `object SalusProgressRingDefaults` (`SalusProgressRing.kt:56-59`). Component dimensions, not
/// design tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusProgressRingDefaults {
    /// `SalusProgressRingDefaults.Size` (`SalusProgressRing.kt:57`).
    public static let size: CGFloat = 64
    /// `SalusProgressRingDefaults.StrokeWidth` (`SalusProgressRing.kt:58`).
    public static let strokeWidth: CGFloat = 6
}

#Preview("Progress ring") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.primary
        SalusProgressRing(progress: 0.6, label: "3/5")
            .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}
