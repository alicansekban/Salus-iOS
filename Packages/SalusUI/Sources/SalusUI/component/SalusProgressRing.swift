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
//
// A45 — the progress ring sweeps on `progress` changes with `SalusMotion.entranceAnimation`
// (450 ms emphasized), the twin of Android's `animateFloatAsState` over `progress`
// (`SalusProgressRing.kt:36-41`). `.animation(_, value: progress)` animates the trim on subsequent
// `progress` changes; the first composition draws the initial value directly (Android's
// `animateFloatAsState` behaves the same — it snaps to the initial value on first composition and
// sweeps on subsequent changes). Reduce-motion jumps instantly (`nil` animation). The struct
// already clamps `progress` in `init` (divergence (c)), so the sweep animates the clamped value.
//
// iOS-M17 Task 8 (design review R2) adds two defaulted knobs, so every existing call site compiles
// unchanged: `accent` (the sweep's colour, handed in by the feature — `SalusUI` knows no feature)
// and `overflowPermille` (the excess over a limit, drawn as a neutral second lap in
// `outlineVariant` over the full accent ring, from 12 o'clock like the sweep — never a hue change).

import SalusDesignSystem
import SwiftUI

/// Determinate circular progress ring with a centred label — the shared dose-progress visual used
/// on Home. Track, sweep and label come from the theme (`SalusProgressRing.kt:28-33`), so the ring
/// reads the same on a card as it does on a hero band.
public struct SalusProgressRing: View {
    private let progress: Float
    private let label: String
    private let size: CGFloat
    private let strokeWidth: CGFloat
    private let accent: Color?
    private let overflow: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - progress: the fraction filled, clamped to 0...1 (divergence (c), M14 plan).
    ///   - label: the centered text, e.g. "3/5" (`SalusProgressRing.kt:63-67`).
    ///   - size: the ring's diameter (`SalusProgressRingDefaults.Size` = 64).
    ///   - strokeWidth: the ring's stroke width (`SalusProgressRingDefaults.StrokeWidth` = 8).
    ///   - accent: the sweep's colour; `nil` is the `primary` role, as before (iOS-M17 Task 8).
    ///   - overflowPermille: the excess over the limit in permille of one lap, 0 for none. Drawn
    ///     over the full ring in `outlineVariant`, capped at one lap (design review R2).
    public init(
        progress: Float,
        label: String,
        size: CGFloat = SalusProgressRingDefaults.size,
        strokeWidth: CGFloat = SalusProgressRingDefaults.strokeWidth,
        accent: Color? = nil,
        overflowPermille: Int = 0
    ) {
        self.progress = Self.clamped(progress)
        self.label = label
        self.size = size
        self.strokeWidth = strokeWidth
        self.accent = accent
        overflow = SalusProgressOverflow.fraction(forPermille: overflowPermille)
    }

    public var body: some View {
        ZStack {
            // The track: `trackColor = surfaceContainerHigh` (`SalusProgressRing.kt:40`), drawn as
            // a full circle stroke behind the progress ring.
            Circle()
                .stroke(theme.colorScheme.surfaceContainerHigh, lineWidth: strokeWidth)
            // The progress: `CircularProgressIndicator(progress = { progress }, …)` with
            // `color = colorScheme.primary` and `strokeCap = StrokeCap.Round`
            // (`SalusProgressRing.kt:55-61`). Drawn with `trim` because
            // `.progressViewStyle(.circular)` ignores determinate values on iOS 17 and renders an
            // indeterminate spinner (divergence (j), M14 QA row 1.4).
            // The A45 sweep: `.animation(_, value: progress)` animates the trim on `progress`
            // changes; first composition draws the initial value directly (Android's
            // `animateFloatAsState` behaves the same — parity row A45).
            Circle()
                .trim(from: 0, to: ringSweep)
                .stroke(
                    accent ?? theme.colorScheme.primary,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : SalusMotion.entranceAnimation,
                    value: progress
                )
            // R2: the excess is a neutral second lap over the full accent ring. `outlineVariant`
            // is deliberately not the track colour, so the lap reads against both the track and
            // the sweep; it is absent (not a zero-length cap dot) when there is no overflow.
            if overflow > 0 {
                Circle()
                    .trim(from: 0, to: overflow)
                    .stroke(
                        theme.colorScheme.outlineVariant,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? nil : SalusMotion.entranceAnimation,
                        value: overflow
                    )
            }
            Text(verbatim: label)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
        }
        .frame(width: size, height: size)
    }

    /// The animated trim fraction: the twin of `animateFloatAsState` over `progress`
    /// (`SalusProgressRing.kt:46-50`, parity row A45) — 450 ms emphasized; reduce motion jumps.
    private var ringSweep: CGFloat { CGFloat(progress) }

    /// Clamps `progress` to 0...1 (divergence (c), M14 plan — Android deferred it).
    /// `nonisolated` so the pure helper is callable from a nonisolated test context, like
    /// `SalusAvatar.initials(from:)`.
    nonisolated static func clamped(_ progress: Float) -> Float {
        min(max(progress, 0), 1)
    }
}

/// `object SalusProgressRingDefaults` (`SalusProgressRing.kt:71-76`). Component dimensions, not
/// design tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusProgressRingDefaults {
    /// `SalusProgressRingDefaults.Size` (`SalusProgressRing.kt:72`).
    public static let size: CGFloat = 64
    /// `SalusProgressRingDefaults.StrokeWidth` (`SalusProgressRing.kt:75`).
    public static let strokeWidth: CGFloat = 8
    /// The ring a screen's hero shows, with its own content drawn over the middle (iOS-M17 Task 11;
    /// Android `HeroSize`). An empty `label` then draws nothing visible.
    public static let heroSize: CGFloat = 168
    /// Proportioned to ``heroSize``: the default stroke would read as a hairline on it.
    public static let heroStrokeWidth: CGFloat = 12
}

#Preview("Progress ring") {
    SalusPreviewPalettes {
        HStack(spacing: SalusSpacing.lg) {
            SalusProgressRing(progress: 0.6, label: "3/5")
            // Over the limit (R2): full in the accent, the excess a neutral lap, no hue change.
            SalusProgressRing(progress: 1, label: "12/10", overflowPermille: 200)
        }
    }
}

#Preview("Progress ring, accessibility3") {
    HStack(spacing: SalusSpacing.lg) {
        SalusProgressRing(progress: 1, label: "12/10", overflowPermille: 200)
        SalusProgressRing(progress: 0.6, label: "3/5")
    }
    .padding(SalusSpacing.lg)
    .dynamicTypeSize(.accessibility3)
}
