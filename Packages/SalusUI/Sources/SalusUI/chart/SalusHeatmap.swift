// iOS-M17 Task 8 (spec §7, design review R1/R2; screenshot `08-trends`): the hour-band × weekday
// craving heatmap on the Trends "Sigara" section.
//
// A plain `Grid`, not Swift Charts: a heatmap is a table of coloured cells and Charts' `RectangleMark`
// would add a categorical axis system the picture does not need. It lives in `chart/` because it
// is a chart to the feature that uses it, and `SalusUI` is the only layer allowed to draw one.
//
// The scale is the accent at five alpha steps over `surfaceContainerHigh` — one hue, so the grid
// reads as "more / less" and never as good / bad (R1: no red or pink anywhere). A zero cell is the
// bare `surfaceContainerHigh`. The accent comes in as a parameter, `SalusUI` knows no feature.
// Cells carry no number: each is one VoiceOver element whose description the feature supplies, which
// is where the count and the unit are worded in the right language.

import SalusDesignSystem
import SwiftUI

/// Rows × columns of counts drawn as a five-step accent heat grid with row and column headers.
public struct SalusHeatmap: View {
    private let rows: [String]
    private let columns: [String]
    private let values: [[Int]]
    private let accent: FeatureAccent
    private let cellDescription: (Int, Int, Int) -> String

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - rows: the row headers, top to bottom (the hour bands).
    ///   - columns: the column headers, left to right (the weekdays).
    ///   - values: `values[row][column]` counts. A missing cell reads as 0.
    ///   - accent: the feature accent whose `accent` colour the steps are drawn in.
    ///   - cellDescription: the spoken description of one cell, called with `(row, column, value)`.
    public init(
        rows: [String],
        columns: [String],
        values: [[Int]],
        accent: FeatureAccent,
        cellDescription: @escaping (Int, Int, Int) -> String
    ) {
        self.rows = rows
        self.columns = columns
        self.values = values
        self.accent = accent
        self.cellDescription = cellDescription
    }

    public var body: some View {
        let maxValue = Self.maxValue(in: values)
        Grid(horizontalSpacing: SalusHeatmapDefaults.cellSpacing, verticalSpacing: SalusHeatmapDefaults.cellSpacing) {
            GridRow {
                // The corner above the row headers stays empty and hidden from VoiceOver.
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
                    .accessibilityHidden(true)
                ForEach(columns.indices, id: \.self) { column in
                    header(columns[column])
                }
            }
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    header(rows[row]).gridColumnAlignment(.leading)
                    ForEach(columns.indices, id: \.self) { column in
                        cell(row: row, column: column, maxValue: maxValue)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func header(_ text: String) -> some View {
        Text(verbatim: text)
            .font(SalusTypography.labelSmall.font)
            .tracking(SalusTypography.labelSmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .lineLimit(1)
            .minimumScaleFactor(SalusHeatmapDefaults.headerMinScale)
            // Each cell's description already names its row and column, so a spoken header would
            // read the same words a second time.
            .accessibilityHidden(true)
    }

    private func cell(row: Int, column: Int, maxValue: Int) -> some View {
        let value = Self.value(in: values, row: row, column: column)
        let step = Self.bucket(for: value, max: maxValue)
        return SalusShapes.rounded(SalusHeatmapDefaults.cellRadius)
            .fill(Self.fill(step: step, accent: accent.accent, empty: theme.colorScheme.surfaceContainerHigh))
            .frame(minWidth: SalusHeatmapDefaults.cellMinSize, minHeight: SalusHeatmapDefaults.cellMinSize)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: cellDescription(row, column, value)))
    }

    /// Which of the five accent steps a count lands on: `0` for an empty cell, otherwise
    /// `1 ... 5` in fifths of `max`, rounding up, so any non-zero count is visible and the maximum
    /// is always the strongest step. A grid with no positive maximum is all empty.
    nonisolated static func bucket(for value: Int, max maxValue: Int) -> Int {
        guard value > 0, maxValue > 0 else { return 0 }
        let steps = SalusHeatmapDefaults.alphaSteps.count
        let step = (value * steps + maxValue - 1) / maxValue
        return min(max(step, 1), steps)
    }

    /// The largest count in the grid, 0 when there is none to speak of.
    nonisolated static func maxValue(in values: [[Int]]) -> Int {
        values.lazy.compactMap { $0.max() }.max().map { Swift.max($0, 0) } ?? 0
    }

    /// `values[row][column]`, 0 outside the rows the caller actually supplied.
    nonisolated static func value(in values: [[Int]], row: Int, column: Int) -> Int {
        guard values.indices.contains(row), values[row].indices.contains(column) else { return 0 }
        return values[row][column]
    }

    private static func fill(step: Int, accent: Color, empty: Color) -> Color {
        guard step > 0 else { return empty }
        return accent.opacity(SalusHeatmapDefaults.alphaSteps[step - 1])
    }
}

/// The heatmap's own dimensions and scale — component constants, not design tokens.
public enum SalusHeatmapDefaults {
    /// The five accent opacities, weakest to strongest. Even fifths: the scale is read as "more or
    /// less", so nothing in it is meant to stand out (R1).
    public static let alphaSteps: [Double] = [0.2, 0.4, 0.6, 0.8, 1]
    /// The gap between cells, both ways.
    public static let cellSpacing: CGFloat = 4
    /// Cells grow with the width the grid is given and never shrink under a comfortable swatch.
    public static let cellMinSize: CGFloat = 24
    /// A cell's corner radius — `SalusShapes.extraSmall` would round a 24 pt swatch into a pill.
    public static let cellRadius: CGFloat = 4
    /// How far a header may shrink before it truncates, for the larger Dynamic Type sizes.
    public static let headerMinScale: CGFloat = 0.7
}

#if DEBUG
    private enum HeatmapPreviewData {
        static let rows = ["08-10", "10-12", "12-14", "14-16", "16-18", "18-22"]
        static let columns = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        static let values: [[Int]] = [
            [1, 0, 2, 1, 0, 0, 0],
            [0, 1, 0, 0, 1, 0, 0],
            [2, 3, 2, 1, 3, 1, 0],
            [5, 6, 5, 6, 4, 3, 2],
            [1, 2, 0, 1, 2, 2, 0],
            [0, 1, 0, 1, 2, 1, 0]
        ]
    }

    private struct HeatmapPreview: View {
        @Environment(\.salusTheme) private var theme

        var body: some View {
            SalusHeatmap(
                rows: HeatmapPreviewData.rows,
                columns: HeatmapPreviewData.columns,
                values: HeatmapPreviewData.values,
                // No smoking accent exists yet (Task 2); `cycle` stands in so the preview exercises
                // the same `FeatureAccent` path a feature will use.
                accent: theme.extendedColors.cycle
            ) { row, column, value in
                "\(HeatmapPreviewData.rows[row]), \(HeatmapPreviewData.columns[column]): \(value)"
            }
        }
    }

    #Preview("Heatmap") {
        SalusPreviewPalettes {
            HeatmapPreview()
        }
    }

    #Preview("Heatmap, accessibility3") {
        ScrollView {
            HeatmapPreview()
                .padding(SalusSpacing.lg)
        }
        .dynamicTypeSize(.accessibility3)
    }
#endif
