import Foundation

/// The axis ranges `SalusLineChart` draws with — the Swift twin of the work Vico does for free on
/// Android, and the reason the two platforms draw the same shape from the same `ChartUiModel`.
///
/// `SalusLineChart.kt:83-104` overrides no `rangeProvider`, so `rememberLineCartesianLayer` gives
/// it `CartesianLayerRangeProvider.auto()` (`LineCartesianLayer.kt:1044`), whose rules are ported
/// verbatim below from Vico 3.2.3's `CartesianLayerRangeProvider.kt:42-58`:
///
///   * x is the data's own range, untouched (`:28-31` — `Auto` overrides neither).
///   * y for non-negative data starts at 0, otherwise at the minimum rounded away from zero; the
///     maximum is 0 for wholly negative data, otherwise the maximum rounded away from zero. The
///     all-zero case becomes 0…1 so the chart has a range to draw in.
///
/// Swift Charts has no equivalent hook and no equivalent default: its automatic numeric scale picks
/// *round* tick values and widens the domain to reach them. With epoch days as x (~20 678) that
/// rounds to whole hundreds of days, so the ten days of the manual-test data became a ~9-month
/// domain and the line rendered as a near-vertical sliver. Hence the explicit domains.
enum ChartAxisScale {
    /// The x range in epoch days, or `nil` when there is nothing to plot.
    ///
    /// Both series count, exactly as Vico takes `model.minX`/`model.maxX` over the whole model
    /// (`LineCartesianLayer.kt:896-897`).
    static func xDomain(for model: ChartUiModel) -> ClosedRange<Int>? {
        let days = allDays(of: model)
        guard let minDay = days.min(), let maxDay = days.max() else { return nil }
        // `chartOrNull`'s two-point minimum plus `dailyPoints`' one-point-per-day collapse means
        // two points always fall on two days, so this cannot happen through the Vitals path. It is
        // guarded anyway because a degenerate domain is not a wrong picture, it is a broken one:
        // Swift Charts has nothing to map a zero-width range onto.
        guard minDay < maxDay else { return (minDay - 1) ... (minDay + 1) }
        return minDay ... maxDay
    }

    /// The y range, or `nil` when there is nothing to plot. `CartesianLayerRangeProvider.kt:43-51`.
    static func yDomain(for model: ChartUiModel) -> ClosedRange<Float>? {
        let values = (model.points + model.secondaryPoints).map { Double($0.y) }
        guard let minY = values.min(), let maxY = values.max() else { return nil }
        if minY == 0, maxY == 0 {
            return 0 ... 1
        }
        let lower = minY >= 0 ? 0 : roundedAwayFromZero(minY, otherBound: maxY)
        let upper = maxY <= 0 ? 0 : roundedAwayFromZero(maxY, otherBound: minY)
        return Float(lower) ... Float(upper)
    }

    /// The days the x axis puts a label on.
    ///
    /// Vico's default `HorizontalAxis.ItemPlacer.aligned()` labels x values stepping from the
    /// minimum by the model's x-delta GCD, thinning the step until the labels fit the width — so it
    /// can label a day that carries no measurement. Swift Charts' `AxisMarks(values:)` does no
    /// thinning at all, so the equivalent here is to label the days that *do* carry a measurement
    /// and thin them down to at most ``maxAxisValues``. Both ends are always kept, which is the
    /// property the picture actually depends on: the first and last measurement sit under a date.
    static func xAxisValues(for model: ChartUiModel) -> [Int] {
        let days = Array(Set(allDays(of: model))).sorted()
        guard days.count > maxAxisValues else { return days }
        let lastIndex = Double(days.count - 1)
        let step = lastIndex / Double(maxAxisValues - 1)
        let indices = (0 ..< maxAxisValues).map { Int((Double($0) * step).rounded()) }
        return indices.reduce(into: [Int]()) { picked, index in
            let day = days[index]
            if picked.last != day {
                picked.append(day)
            }
        }
    }

    private static func allDays(of model: ChartUiModel) -> [Int] {
        (model.points + model.secondaryPoints).map(\.xEpochDay)
    }

    /// `CartesianLayerRangeProvider.kt:53-57` (`Double.round(other:)`): round the value away from
    /// zero on a base one order of magnitude below the larger of the two bounds, so a range that
    /// ends at 127 ends at 130 rather than at an arbitrary tick.
    private static func roundedAwayFromZero(_ value: Double, otherBound: Double) -> Double {
        let magnitude = abs(value)
        let base = pow(10, log10(max(magnitude, abs(otherBound))).rounded(.down) - 1)
        return value.sign == .minus ? -ceil(magnitude / base) * base : ceil(magnitude / base) * base
    }

    /// Four dates is what a phone-width chart fits without the labels colliding.
    private static let maxAxisValues = 4
}
