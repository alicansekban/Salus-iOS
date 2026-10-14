import Testing

@testable import SalusUI

/// `ChartUiModel.markers` (iOS-M17 Task 8, spec §7 — the quit date drawn on a vitals chart): a
/// marker is only drawn when its day falls inside the span the chart plots, because Swift Charts
/// would otherwise widen the domain to reach it and the chart would no longer be the data.
@Suite("ChartMarker")
struct ChartMarkerTests {
    private func model(markers: [ChartMarker]) -> ChartUiModel {
        ChartUiModel(
            points: [
                ChartPoint(xEpochDay: 20680, y: 70),
                ChartPoint(xEpochDay: 20690, y: 72)
            ],
            xLabel: { String($0) },
            markers: markers
        )
    }

    @Test("the markers default to none, so every existing call site is unchanged")
    func defaultsToNone() {
        let plain = ChartUiModel(points: [], xLabel: { String($0) })
        #expect(plain.markers.isEmpty)
    }

    @Test("a marker inside the plotted days is kept")
    func insideIsKept() {
        let marker = ChartMarker(xEpochDay: 20685, label: "Quit")
        #expect(ChartAxisScale.visibleMarkers(for: model(markers: [marker])) == [marker])
    }

    @Test("markers on the first and last plotted day are kept (the range is inclusive)")
    func edgesAreKept() {
        let first = ChartMarker(xEpochDay: 20680, label: "A")
        let last = ChartMarker(xEpochDay: 20690, label: "B")
        #expect(ChartAxisScale.visibleMarkers(for: model(markers: [first, last])) == [first, last])
    }

    @Test("markers before the first or after the last day are dropped")
    func outsideIsDropped() {
        let before = ChartMarker(xEpochDay: 20679, label: "Before")
        let after = ChartMarker(xEpochDay: 20691, label: "After")
        let inside = ChartMarker(xEpochDay: 20682, label: "In")
        let visible = ChartAxisScale.visibleMarkers(for: model(markers: [before, inside, after]))
        #expect(visible == [inside])
    }

    @Test("a chart with no points draws no marker at all")
    func emptyChartDrawsNone() {
        let empty = ChartUiModel(
            points: [],
            xLabel: { String($0) },
            markers: [ChartMarker(xEpochDay: 20685, label: "Quit")]
        )
        #expect(ChartAxisScale.visibleMarkers(for: empty).isEmpty)
    }

    @Test("markers never widen the x domain")
    func markersDoNotWidenTheDomain() {
        let far = ChartMarker(xEpochDay: 25000, label: "Far")
        #expect(ChartAxisScale.xDomain(for: model(markers: [far])) == 20680 ... 20690)
    }
}

/// `MultiSeriesChartUiModel.markers` (iOS-M17 Task 18 — the Trends overlay is a multi-series chart, so
/// the quit day needs the same labelled guideline `ChartUiModel` already has; Android twin
/// `MultiSeriesMarkersTest`). The plotted span is every series together, because a day between
/// two series' own ranges still has a place on the shared x axis.
@Suite("MultiSeriesChartMarker")
struct MultiSeriesChartMarkerTests {
    private func model(markers: [ChartMarker], second: [Int] = [20682, 20688]) -> MultiSeriesChartUiModel {
        MultiSeriesChartUiModel(
            series: [
                ChartSeries(
                    points: [ChartPoint(xEpochDay: 20684, y: 0), ChartPoint(xEpochDay: 20686, y: 1)],
                    role: .primary
                ),
                ChartSeries(points: second.map { ChartPoint(xEpochDay: $0, y: 0.5) }, role: .secondary)
            ],
            xLabel: { String($0) },
            markers: markers
        )
    }

    @Test("the markers default to none, so every existing call site is unchanged")
    func defaultsToNone() {
        let plain = MultiSeriesChartUiModel(series: [], xLabel: { String($0) })
        #expect(plain.markers.isEmpty)
    }

    @Test("a marker inside the span of all series together is kept, even between two readings")
    func insideTheCombinedSpanIsKept() {
        // 20687 is past the primary line's last point but inside the secondary line's span.
        let marker = ChartMarker(xEpochDay: 20687, label: "Quit")
        #expect(ChartAxisScale.visibleMarkers(for: model(markers: [marker])) == [marker])
    }

    @Test("markers on the first and last plotted day are kept (the range is inclusive)")
    func edgesAreKept() {
        let first = ChartMarker(xEpochDay: 20682, label: "A")
        let last = ChartMarker(xEpochDay: 20688, label: "B")
        #expect(ChartAxisScale.visibleMarkers(for: model(markers: [first, last])) == [first, last])
    }

    @Test("markers before the first or after the last plotted day are dropped")
    func outsideIsDropped() {
        let before = ChartMarker(xEpochDay: 20681, label: "Before")
        let after = ChartMarker(xEpochDay: 20689, label: "After")
        let inside = ChartMarker(xEpochDay: 20685, label: "In")
        #expect(ChartAxisScale.visibleMarkers(for: model(markers: [before, inside, after])) == [inside])
    }

    @Test("a chart with no points draws no marker at all")
    func emptyChartDrawsNone() {
        let empty = MultiSeriesChartUiModel(
            series: [ChartSeries(points: [], role: .primary)],
            xLabel: { String($0) },
            markers: [ChartMarker(xEpochDay: 20685, label: "Quit")]
        )
        #expect(ChartAxisScale.visibleMarkers(for: empty).isEmpty)
    }
}
