// Ported from `core/ui/.../chart/SalusSparkline.kt:19-51`.
//
// This is the one chart in the app that is NOT `SalusLineChart`, and the Kotlin doc comment says
// why in as many words: "this stays a plain Canvas so it can be ported to iOS as a lightweight
// SwiftUI Path" (`SalusSparkline.kt:16-17`). So there is no Swift Charts here — no engine, no
// `ChartUiModel`, no axes, no labels, no interaction. A dashboard card wants the *shape* of a
// series at 96 × 32 pt, and a `Chart` at that size draws axis furniture instead of a trend.
//
// The drawing rules are transcribed one-for-one from the `Canvas` lambda (`:26-40`) into
// `SparklineGeometry`, which is deliberately a pure function of `([Float], CGSize) -> [CGPoint]`:
// the Kotlin arithmetic is unreachable from a unit test because it lives inside a draw scope, and
// hoisting it out is what lets `SalusSparklineTests` pin the same numbers Android draws.

import SalusDesignSystem
import SwiftUI

/// Tiny trend line for dashboard cards: no axes, no labels, no interaction — just the shape of the
/// series. Full charts go through ``SalusLineChart`` (`SalusSparkline.kt:14-18`).
public struct SalusSparkline: View {
    private let values: [Float]
    private let lineColor: Color?

    @Environment(\.salusTheme) private var theme

    /// - Parameter lineColor: the line's color. `nil` means the primary role, the twin of Kotlin's
    ///   `MaterialTheme.colorScheme.primary` default (`SalusSparkline.kt:23`) — which cannot be a
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
            // `if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)` (`SalusSparkline.kt:39`).
            path.move(to: start)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            // `Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)`
            // (`:44-48`). No fill, no gradient, no markers, no baseline — unlike `SalusLineChart`,
            // which draws an area under its line.
            context.stroke(
                path,
                with: .color(lineColor ?? theme.colorScheme.primary),
                style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        // Hidden from VoiceOver (iOS-M7 plan ruling 7). Compose gives the sparkline no
        // `contentDescription`, so it is silent to TalkBack; a bare port would be an unlabelled
        // image to VoiceOver, which is worse than silence. The card's own text already speaks the
        // value the line trends towards, so there is nothing here VoiceOver would add — and
        // inventing a spoken summary is copy this milestone does not own.
        .accessibilityHidden(true)
    }

    /// `2.dp` (`SalusSparkline.kt:45`). A component dimension the Kotlin file spells inline, not a
    /// `design-tokens.md` token.
    private static let lineWidth: CGFloat = 2
}

/// The sparkline's geometry, lifted out of the view so the rules are table-testable.
///
/// Every line below is `SalusSparkline.kt:26-40` with Compose's `size` replaced by SwiftUI's.
enum SparklineGeometry {
    /// The polyline the sparkline strokes, in the canvas' own coordinates.
    ///
    /// Returns an empty array for fewer than two values — `if (values.size < 2) return@Canvas`
    /// (`SalusSparkline.kt:26`), i.e. a lone measurement is not a trend and draws nothing.
    static func points(for values: [Float], in size: CGSize) -> [CGPoint] {
        guard values.count >= 2, let min = values.min(), let max = values.max() else { return [] }

        // `(max - min).takeIf { it > 0f } ?: 1f` (`:29`) — the fallback keeps a flat series from
        // dividing by zero. It does not centre it: every value equals the minimum, so the whole
        // line lands at `padY + drawableHeight`, and Android draws it at the same height.
        let range = max - min
        let span = CGFloat(range > 0 ? range : 1)

        // `stepX = size.width / (values.size - 1)` (`:30`) — the first point sits on the leading
        // edge and the last on the trailing one.
        let stepX = size.width / CGFloat(values.count - 1)
        // 10 % vertical padding so the line never touches the edges (`:31-33`).
        let padY = size.height * Self.verticalPaddingFraction
        let drawableHeight = size.height - 2 * padY

        return values.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * stepX,
                // `y = padY + (1f - (value - min) / span) * drawableHeight` (`:38`) — inverted,
                // because a canvas' y grows downwards on both platforms: higher value, smaller y.
                y: padY + (1 - CGFloat(value - min) / span) * drawableHeight
            )
        }
    }

    /// `size.height * 0.1f` (`SalusSparkline.kt:32`).
    private static let verticalPaddingFraction: CGFloat = 0.1
}

#Preview("Sparkline") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.lg) {
            // The dashboard call site: 96 × 32 pt, tinted with the vitals accent.
            SalusSparkline(
                values: [72.4, 71.8, 72.1, 71.1, 70.6, 70.9, 70.2],
                lineColor: theme.extendedColors.vitals.accent
            )
            .frame(width: 96, height: 32)
            // The primary-role default.
            SalusSparkline(values: [70, 74, 69, 71])
                .frame(width: 96, height: 32)
            // A flat series — one line along the bottom pad, exactly as Compose draws it.
            SalusSparkline(values: [70, 70, 70])
                .frame(width: 96, height: 32)
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 220)
    .salusTheme(theme)
}
