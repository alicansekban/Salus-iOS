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
