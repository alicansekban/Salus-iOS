import Testing

@testable import SalusUI

/// The table behind `ChartAxisScale`, read off Vico 3.2.3's `CartesianLayerRangeProvider.auto()`
/// (`compose-android-3.2.3-sources.jar`,
/// `commonMain/com/patrykandpatrick/vico/compose/cartesian/data/CartesianLayerRangeProvider.kt:42-58`),
/// which is the range provider `rememberLineCartesianLayer` defaults to
/// (`LineCartesianLayer.kt:1044`) and which `SalusLineChart.kt:83-104` therefore gets, since it
/// overrides no `rangeProvider`.
///
/// Swift Charts has no such thing: left to itself it picks *round* numbers for a numeric axis and
/// widens the domain to them, so ten days around epoch day 20 678 became a ~9-month domain and the
/// line collapsed into a near-vertical sliver. These expectations are what Vico computes for the
/// same points, so the two platforms draw the same shape.
@Suite("ChartAxisScale")
struct ChartAxisScaleTests {
    /// The manual-test case that found the bug: 100.0 kg on 13 Aug, 80.0 on 17 Aug, 70.0 on
    /// 23 Aug 2026 — epoch days 20678, 20682, 20688.
    private static let weightPoints = [
        ChartPoint(xEpochDay: 20678, y: 100),
        ChartPoint(xEpochDay: 20682, y: 80),
        ChartPoint(xEpochDay: 20688, y: 70)
    ]

    private func model(
        _ points: [ChartPoint],
        secondaryPoints: [ChartPoint] = []
    ) -> ChartUiModel {
        ChartUiModel(points: points, xLabel: { String($0) }, secondaryPoints: secondaryPoints)
    }

    // MARK: - x

    @Test("the x domain is the data's own span, nothing wider (getMinX/getMaxX, :28-31)")
    func xDomainIsTheDataSpan() {
        let domain = ChartAxisScale.xDomain(for: model(Self.weightPoints))

        #expect(domain == 20678 ... 20688)
        // Ten days, not the nine months Swift Charts' automatic scale invented.
        #expect(domain.map { $0.upperBound - $0.lowerBound } == 10)
    }

    @Test("the x domain covers the secondary series too (LineCartesianLayer.kt:896-897)")
    func xDomainCoversBothSeries() {
        let domain = ChartAxisScale.xDomain(
            for: model(
                [ChartPoint(xEpochDay: 20682, y: 128), ChartPoint(xEpochDay: 20688, y: 124)],
                secondaryPoints: [
                    ChartPoint(xEpochDay: 20678, y: 82),
                    ChartPoint(xEpochDay: 20690, y: 79)
                ]
            )
        )

        #expect(domain == 20678 ... 20690)
    }

    @Test("a single distinct day widens by a day either side rather than collapsing")
    func xDomainGuardsAgainstOneDay() {
        let domain = ChartAxisScale.xDomain(
            for: model([
                ChartPoint(xEpochDay: 20678, y: 100),
                ChartPoint(xEpochDay: 20678, y: 70)
            ])
        )

        #expect(domain == 20677 ... 20679)
    }

    @Test("no points means no domain, and the chart falls back to its own scale")
    func xDomainIsNilWithoutPoints() {
        #expect(ChartAxisScale.xDomain(for: model([])) == nil)
        #expect(ChartAxisScale.yDomain(for: model([])) == nil)
    }

    // MARK: - y

    @Test("y for non-negative data starts at zero (auto.getMinY, :43-44)")
    func yDomainAnchorsAtZeroForPositiveData() {
        let domain = ChartAxisScale.yDomain(for: model(Self.weightPoints))

        // `minY >= 0.0 -> 0.0`; `maxY.round(minY)` with base 10 leaves 100 as it is. This is why
        // Android draws this data as a shallow slope rather than a steep one: the domain is
        // 0…100, and only the x axis was wrong on iOS.
        #expect(domain == 0 ... 100)
    }

    @Test("the y maximum is rounded up on a base derived from the larger magnitude (:50-57)")
    func yDomainRoundsTheMaximumUp() {
        // max 127, base 10^(floor(log10(127)) - 1) = 10 -> ceil(12.7) * 10 = 130.
        let domain = ChartAxisScale.yDomain(
            for: model([
                ChartPoint(xEpochDay: 20678, y: 100),
                ChartPoint(xEpochDay: 20682, y: 127)
            ])
        )

        #expect(domain == 0 ... 130)
    }

    @Test("the y range spans both series (LineCartesianLayer.kt:885-898)")
    func yDomainCoversBothSeries() {
        // max 131, base 10 -> ceil(13.1) * 10 = 140.
        let domain = ChartAxisScale.yDomain(
            for: model(
                [ChartPoint(xEpochDay: 20678, y: 128), ChartPoint(xEpochDay: 20682, y: 131)],
                secondaryPoints: [
                    ChartPoint(xEpochDay: 20678, y: 82),
                    ChartPoint(xEpochDay: 20682, y: 79)
                ]
            )
        )

        #expect(domain == 0 ... 140)
    }

    @Test("all-zero data gets the 0…1 range Vico gives it (:44, :48)")
    func yDomainForAllZeroes() {
        let domain = ChartAxisScale.yDomain(
            for: model([
                ChartPoint(xEpochDay: 20678, y: 0),
                ChartPoint(xEpochDay: 20682, y: 0)
            ])
        )

        #expect(domain == 0 ... 1)
    }

    @Test("wholly negative data ends at zero (auto.getMaxY, :49)")
    func yDomainForNegativeData() {
        // min -5, base 10^(floor(log10(5)) - 1) = 0.1 -> -ceil(50) * 0.1 = -5.
        let domain = ChartAxisScale.yDomain(
            for: model([
                ChartPoint(xEpochDay: 20678, y: -5),
                ChartPoint(xEpochDay: 20682, y: -1)
            ])
        )

        #expect(domain == -5 ... 0)
    }

    @Test("data straddling zero keeps both signs (:44, :50)")
    func yDomainForMixedSigns() {
        // min -12, max 5; base 10^(floor(log10(12)) - 1) = 1 for both.
        let domain = ChartAxisScale.yDomain(
            for: model([
                ChartPoint(xEpochDay: 20678, y: -12),
                ChartPoint(xEpochDay: 20682, y: 5)
            ])
        )

        #expect(domain == -12 ... 5)
    }

    @Test("a flat non-zero series still gets a drawable range")
    func yDomainForFlatSeries() {
        let domain = ChartAxisScale.yDomain(
            for: model([
                ChartPoint(xEpochDay: 20678, y: 70),
                ChartPoint(xEpochDay: 20682, y: 70)
            ])
        )

        #expect(domain == 0 ... 70)
    }

    @Test("positive data under 10 rounds on a sub-1 base (mmol/L glucose, :53-57)")
    func yDomainForPositiveSubOneBase() throws {
        // Every other unit in the app rounds on a base of 10 — kg ~ 70…100, mmHg ~ 60…180,
        // mg/dL ~ 70…180. Glucose in mmol/L is the one series that lives under 10, where
        // `base = 10^(floor(log10(max)) - 1)` is 0.1, and the only row that exercised that base
        // was the *negative* branch (`yDomainForNegativeData`). This is the positive twin, added
        // before the glucose chart lands rather than after.
        let domain = try #require(
            ChartAxisScale.yDomain(
                for: model([
                    ChartPoint(xEpochDay: 20678, y: 4.2),
                    ChartPoint(xEpochDay: 20682, y: 9.75)
                ])
            )
        )

        // Non-negative data starts at 0 (`:44`), and 9.75 rounds up one tenth: ceil(97.5) * 0.1.
        #expect(domain.lowerBound == 0)
        #expect(abs(domain.upperBound - 9.8) < Self.axisTolerance)

        // A flat series on the same base. `ceil(magnitude / 0.1) * 0.1` returns
        // 5.600000000000001 in `Double`, so the bound is compared with a tolerance rather than
        // for equality — the rounding base is a tenth, and a tenth has no exact binary form.
        let flat = try #require(
            ChartAxisScale.yDomain(
                for: model([
                    ChartPoint(xEpochDay: 20678, y: 5.6),
                    ChartPoint(xEpochDay: 20682, y: 5.6)
                ])
            )
        )

        #expect(flat.lowerBound == 0)
        #expect(abs(flat.upperBound - 5.6) < Self.axisTolerance)
    }

    /// Tighter than the 0.1 rounding base, so it cannot hide a bound that landed on the wrong
    /// tenth, and looser than the binary error of a tenth.
    private static let axisTolerance: Float = 0.0001

    // MARK: - axis marks

    @Test("few points label every day that has data")
    func xAxisValuesLabelEveryPoint() {
        #expect(ChartAxisScale.xAxisValues(for: model(Self.weightPoints)) == [20678, 20682, 20688])
    }

    @Test("many points thin down to at most four labels, keeping the first and the last")
    func xAxisValuesThin() {
        let points = (0 ..< 30).map { ChartPoint(xEpochDay: 20660 + $0, y: Float(70 + $0)) }

        let values = ChartAxisScale.xAxisValues(for: model(points))

        #expect(values.count == 4)
        #expect(values.first == 20660)
        #expect(values.last == 20689)
        #expect(values == values.sorted())
    }

    @Test("axis marks come from both series and never repeat a day")
    func xAxisValuesAreDistinctAcrossSeries() {
        let values = ChartAxisScale.xAxisValues(
            for: model(
                [ChartPoint(xEpochDay: 20678, y: 128), ChartPoint(xEpochDay: 20682, y: 124)],
                secondaryPoints: [
                    ChartPoint(xEpochDay: 20678, y: 82),
                    ChartPoint(xEpochDay: 20682, y: 79)
                ]
            )
        )

        #expect(values == [20678, 20682])
    }

    @Test("no points, no marks")
    func xAxisValuesWithoutPoints() {
        #expect(ChartAxisScale.xAxisValues(for: model([])).isEmpty)
    }
}
