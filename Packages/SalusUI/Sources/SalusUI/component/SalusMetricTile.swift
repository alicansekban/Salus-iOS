// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusMetricTile.kt:31-94`.
//
// Kotlin carries the delta as two arguments — the text and a nullable `deltaPositive`
// (`SalusMetricTile.kt:37-38`) — which lets a caller pass a direction with no text, or a text with
// no direction, neither of which draws anything sensible. The iOS port makes them one `Delta`
// value, so the verdict and the words it applies to cannot be set apart. Kotlin's neutral third
// state (`deltaPositive = null` → `onSurfaceVariant`, `:46`) has no case here: spec §3.3 names
// `metricUp` / `metricDown` only, and a movement with no verdict is a caller that wants a plain
// label, not a delta.
//
// `progressTone` (`SalusMetricTile.kt:40`) is likewise not ported — the tile's bar is the primary
// one; a caller that needs another tone places its own ``SalusProgressBar``.

import SalusDesignSystem
import SwiftUI

/// One number and what it means: an overline label, the value with its unit, an optional delta and
/// an optional ``SalusProgressBar``. The tile draws no ground of its own — it is placed inside a
/// ``SalusCard`` or a grid cell, which is what lets two tiles sit side by side without a nested
/// card each (`SalusMetricTile.kt:22-25`).
public struct SalusMetricTile: View {
    /// Which way the number moved, and whether that was the good way — which is not the same as
    /// the sign: a weight that fell and a step count that rose are both ``Delta/up(_:)``
    /// (`SalusMetricTile.kt:27-30`).
    public enum Delta: Equatable, Sendable {
        /// Drawn on `metricUp`.
        case up(String)
        /// Drawn on `metricDown`.
        case down(String)
    }

    private let overline: String
    private let value: String
    private let unit: String?
    private let delta: Delta?
    private let progress: Double?
    private let large: Bool

    @Environment(\.salusTheme) private var theme

    /// - Parameter large: `displaySmall` rather than `headlineMedium` for the value
    ///   (`SalusMetricTile.kt:63-67`) — the one metric a screen leads with.
    public init(
        overline: String,
        value: String,
        unit: String? = nil,
        delta: Delta? = nil,
        progress: Double? = nil,
        large: Bool = false
    ) {
        self.overline = overline
        self.value = value
        self.unit = unit
        self.delta = delta
        self.progress = progress
        self.large = large
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.xs)` (`SalusMetricTile.kt:50`).
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            // `Text(label, labelSmall, color = overline)` (`SalusMetricTile.kt:52-56`).
            Text(verbatim: overline)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
            valueRow
            if let delta {
                Text(verbatim: delta.text)
                    .font(SalusTypography.labelMedium.font)
                    .tracking(SalusTypography.labelMedium.tracking)
                    .foregroundStyle(delta.tint(in: theme))
            }
            if let progress {
                SalusProgressBar(progress: progress)
                    .padding(.top, SalusSpacing.xs)
            }
        }
    }

    /// `Row(verticalAlignment = Alignment.Bottom)` (`SalusMetricTile.kt:57-78`) — the unit sits on
    /// the value's baseline, which `.lastTextBaseline` is the SwiftUI spelling of.
    private var valueRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: SalusSpacing.xs) {
            Text(verbatim: value)
                .font(valueStyle.font)
                .tracking(valueStyle.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            if let unit {
                Text(verbatim: unit)
                    .font(SalusTypography.labelMedium.font)
                    .tracking(SalusTypography.labelMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
        }
    }

    /// `SalusMetricTile.kt:63-67`.
    private var valueStyle: SalusTextStyle {
        large ? SalusTypography.displaySmall : SalusTypography.headlineMedium
    }
}

extension SalusMetricTile.Delta {
    /// The words the delta states.
    var text: String {
        switch self {
        case let .down(text), let .up(text): text
        }
    }

    /// `SalusMetricTile.kt:43-47`.
    func tint(in theme: SalusResolvedTheme) -> Color {
        switch self {
        case .up: theme.extendedColors.metricUp
        case .down: theme.extendedColors.metricDown
        }
    }
}

#Preview("Metric tiles") {
    SalusPreviewPalettes {
        VStack(alignment: .leading, spacing: SalusSpacing.lg) {
            SalusMetricTile(
                overline: "TODAY'S DOSES",
                value: "3/5",
                delta: .up("2 left"),
                progress: 0.6,
                large: true
            )
            SalusMetricTile(
                overline: "WEIGHT",
                value: "72.4",
                unit: "kg",
                delta: .up("−0.6 kg this week")
            )
            SalusMetricTile(
                overline: "RESTING HEART RATE",
                value: "78",
                unit: "bpm",
                delta: .down("+4 bpm"),
                progress: 0.8
            )
        }
    }
}
