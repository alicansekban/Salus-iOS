// The axis furniture the three Swift Charts charts share, in one place.
//
// Compose never writes this rule down: `ProvideVicoTheme(rememberM3VicoTheme())`
// (`SalusLineChart.kt:117`, `SalusBarChart.kt:108`, `SalusMultiSeriesChart.kt:99`) hands Vico the
// whole Material scheme once, and every axis a chart then registers —
// `VerticalAxis.rememberStart` / `HorizontalAxis.rememberBottom` (`SalusLineChart.kt:193-194`) —
// draws its grid, its ticks and its labels from it. Swift Charts has no theme to hand a scheme to:
// each `AxisGridLine`, `AxisTick` and `AxisValueLabel` is styled where it is declared.
//
// So the single Kotlin call becomes eleven Swift call sites, and the thing a theme guaranteed for
// free — that three charts in one card cannot disagree about what a grid line looks like — has to
// be guaranteed here instead. That is this file: the roles are named once, and a chart names the
// helper rather than the role.

#if canImport(Charts)
    import Charts
#endif
import SalusDesignSystem
import SwiftUI

/// The chart axis roles (spec §3.4), named once for every chart in `SalusUI`.
enum ChartAxisStyle {
    /// Grid lines and ticks: `outlineVariant`.
    static func gridColor(_ theme: SalusResolvedTheme) -> Color {
        theme.colorScheme.outlineVariant
    }
}

extension Text {
    /// An axis label: `labelSmall` on `onSurfaceVariant`.
    ///
    /// Takes the resolved theme rather than reading the environment, because an `AxisValueLabel`'s
    /// content is built where the axis is declared — inside the chart's own view, which already
    /// holds the theme.
    func salusChartAxisLabel(theme: SalusResolvedTheme) -> some View {
        font(SalusTypography.labelSmall.font)
            .tracking(SalusTypography.labelSmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
    }
}
