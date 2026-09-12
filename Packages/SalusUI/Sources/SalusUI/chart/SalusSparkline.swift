// Ported from `core/ui/.../chart/SalusSparkline.kt:43-92`.
//
// This is the one chart in the app that is NOT `SalusLineChart`, and the Kotlin doc comment says
// why in as many words: "this stays a plain Canvas so it can be ported to iOS as a lightweight
// SwiftUI Path" (`SalusSparkline.kt:39-41`). So there is no Swift Charts here — no engine, no
// `ChartUiModel`, no axes, no labels, no interaction. A dashboard card wants the *shape* of a
// series at 96 × 32 pt, and a `Chart` at that size draws axis furniture instead of a trend.
//
// The drawing rules are transcribed one-for-one into `SparklineGeometry`, a pure function of
// `([Float], CGSize) -> [CGPoint]`. Kotlin used to keep that arithmetic inside the `Canvas`
// lambda, where no unit test could reach it; M15 hoisted it the same way, into the internal
// `sparklinePoints` (`SalusSparkline.kt:99-113`) with `SparklinePointsTest.kt` over it — so the
// two platforms now pin the same numbers from the same shape.
//
// M15 gave the sparkline the same halo as `SalusLineChart`: the swept path is stroked twice,
// `accentGlow` at `GlowThickness` first and the line over it (`SalusSparkline.kt:73-89`). Both
// strokes take the *same* trimmed path, so the halo sweeps in with the line rather than standing
// under a line that is not there yet — Compose strokes its one `drawn` segment twice for exactly
// the same reason. A card's sparkline and the full chart it opens then read as the same line.
//
// A44 — draw-in sweep: the line draws itself in left-to-right over 450 ms on first appearance
// (the twin of Compose's `PathMeasure.getSegment(0, length × sweep)` at `SalusSparkline.kt:67-72`).
// SwiftUI's `Path.trimmedPath(from: 0, to: sweep)` is the same segment operation, animated by
// `SalusMotion.entranceAnimation` (Task 1's 450 ms emphasized curve). The stroke's `lineCap:
// .round` draws a cap at the sweep's leading edge — the rounded tip Compose's `PathMeasure`
// segment + `StrokeCap.Round` leaves mid-sweep. Reduce-motion snaps `sweep` to 1 instantly.

import SalusDesignSystem
import SwiftUI

/// Tiny trend line for dashboard cards: no axes, no labels, no interaction — just the shape of the
/// series, drawn in with a left-to-right sweep and carrying the same halo as the full chart.
/// Full charts go through ``SalusLineChart`` (`SalusSparkline.kt:34-41`).
public struct SalusSparkline: View {
    private let values: [Float]
    private let lineColor: Color?

    @Environment(\.salusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep: CGFloat = 0

    /// - Parameter lineColor: the line's color. `nil` means the primary role, the twin of Kotlin's
    ///   `MaterialTheme.colorScheme.primary` default (`SalusSparkline.kt:46`) — which cannot be a
    ///   Swift default argument because it is read from the environment. The same shape
    ///   ``SalusLineChart`` uses.
    public init(values: [Float], lineColor: Color? = nil) {
        self.values = values
        self.lineColor = lineColor
    }

    public var body: some View {
        Canvas { context, size in
            let points = SparklineGeometry.points(for: values, in: size)
            guard let start = points.first else { return }

            var path = Path()
            // `if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)` (`SalusSparkline.kt:62`).
            path.move(to: start)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            // `Stroke(width = …, cap = StrokeCap.Round, join = StrokeJoin.Round)` (`:76-80`,
            // `:84-88`). No fill, no gradient, no markers, no baseline — unlike `SalusLineChart`,
            // which draws an area under its line as well as a halo beneath it.
            //
            // The draw-in: `PathMeasure.getSegment(0, length × sweep)` (`SalusSparkline.kt:67-72`)
            // — SwiftUI's `trimmedPath` is the same segment operation. The halo and the line stroke
            // the one swept path, in that order (`:73-89`).
            let drawn = path.trimmedPath(from: 0, to: sweep)
            context.stroke(
                drawn,
                with: .color(theme.extendedColors.accentGlow),
                style: Self.stroke(width: SalusSparklineDefaults.glowWidth)
            )
            context.stroke(
                drawn,
                with: .color(lineColor ?? theme.colorScheme.primary),
                style: Self.stroke(width: SalusSparklineDefaults.lineWidth)
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
        // Hidden from VoiceOver (iOS-M7 plan ruling 7). Compose gives the sparkline no
        // `contentDescription`, so it is silent to TalkBack; a bare port would be an unlabelled
        // image to VoiceOver, which is worse than silence. The card's own text already speaks the
        // value the line trends towards, so there is nothing here VoiceOver would add — and
        // inventing a spoken summary is copy this milestone does not own.
        .accessibilityHidden(true)
    }

    /// `Stroke(width = …, cap = StrokeCap.Round, join = StrokeJoin.Round)`
    /// (`SalusSparkline.kt:76-80`, `:84-88`) — one shape for both passes, so the halo can never
    /// end in a different cap from the line it sits under.
    private static func stroke(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

/// The sparkline's own dimensions. Component constants the Kotlin file spells inline, not
/// `design-tokens.md` tokens.
public enum SalusSparklineDefaults {
    /// `SparklineThickness` (`SalusSparkline.kt:116`) — thinner than `SalusLineChart`'s line: a
    /// sparkline is read as a shape, not as a measurement.
    public static let lineWidth: CGFloat = 2
    /// `GlowThickness` (`SalusSparkline.kt:119`) — the halo, at the same ratio to the line as in
    /// `SalusLineChart` (which strokes 6 pt under 2.5 pt). It is 5, not the full chart's 6,
    /// because the line under it is 2 rather than 2.5.
    public static let glowWidth: CGFloat = 5
}

/// The sparkline's geometry, lifted out of the view so the rules are table-testable.
///
/// Every line below is `sparklinePoints` (`SalusSparkline.kt:99-113`) with Compose's `width` /
/// `height` pair replaced by SwiftUI's `CGSize`.
enum SparklineGeometry {
    /// The polyline the sparkline strokes, in the canvas' own coordinates.
    ///
    /// Returns an empty array for fewer than two values — `if (values.size < 2) return emptyList()`
    /// (`SalusSparkline.kt:100`), i.e. a lone measurement is not a trend and draws nothing.
    static func points(for values: [Float], in size: CGSize) -> [CGPoint] {
        guard values.count >= 2, let min = values.min(), let max = values.max() else { return [] }

        // `(max - min).takeIf { it > 0f } ?: 1f` (`:103`) — the fallback keeps a flat series from
        // dividing by zero. It does not centre it: every value equals the minimum, so the whole
        // line lands at `padY + drawableHeight`, and Android draws it at the same height.
        let range = max - min
        let span = CGFloat(range > 0 ? range : 1)

        // `stepX = width / (values.size - 1)` (`:104`) — the first point sits on the leading
        // edge and the last on the trailing one.
        let stepX = size.width / CGFloat(values.count - 1)
        // 10 % vertical padding so the line never touches the edges (`:106-107`).
        let padY = size.height * Self.verticalPaddingFraction
        let drawableHeight = size.height - 2 * padY

        return values.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * stepX,
                // `y = padY + (1f - (value - min) / span) * drawableHeight` (`:110`) — inverted,
                // because a canvas' y grows downwards on both platforms: higher value, smaller y.
                y: padY + (1 - CGFloat(value - min) / span) * drawableHeight
            )
        }
    }

    /// `height * 0.1f` (`SalusSparkline.kt:106`).
    private static let verticalPaddingFraction: CGFloat = 0.1
}

/// A preview-only wrapper that reads the panel's own resolved theme, so the tinted sample follows
/// whichever palette ``SalusPreviewPalettes`` is drawing — a colour captured outside the panel
/// would pin one palette across all eight.
private struct VitalsTintedSparkline: View {
    let values: [Float]

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusSparkline(values: values, lineColor: theme.extendedColors.vitals.accent)
    }
}

#Preview("Sparkline") {
    SalusPreviewPalettes {
        VStack(alignment: .leading, spacing: SalusSpacing.lg) {
            // The dashboard call site: 96 × 32 pt, tinted with the vitals accent. The halo is
            // `accentGlow` under every one of these, so a palette that loses it shows up here.
            VitalsTintedSparkline(values: [72.4, 71.8, 72.1, 71.1, 70.6, 70.9, 70.2])
                .frame(width: 96, height: 32)
            // The primary-role default.
            SalusSparkline(values: [70, 74, 69, 71])
                .frame(width: 96, height: 32)
            // A flat series — one line along the bottom pad, exactly as Compose draws it.
            SalusSparkline(values: [70, 70, 70])
                .frame(width: 96, height: 32)
        }
    }
}
