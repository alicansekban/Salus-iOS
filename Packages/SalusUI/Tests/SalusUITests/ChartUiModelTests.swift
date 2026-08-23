import Testing

@testable import SalusUI

/// `ChartUiModel.kt` has no Kotlin test of its own — the model is a data class whose behaviour is
/// its defaults and its structural equality. Those are exactly what a Swift port can get wrong
/// (a `class` instead of a `struct`, a defaulted label that formats differently), so they are
/// pinned here rather than left to the first feature that trips over them.
@Suite("ChartUiModel")
struct ChartUiModelTests {
    @Test("chart points compare by value, not by identity (ChartUiModel.kt:12-15)")
    func chartPointsCompareByValue() {
        let point = ChartPoint(xEpochDay: 20000, y: 70.5)
        let sameValues = ChartPoint(xEpochDay: 20000, y: 70.5)
        let otherDay = ChartPoint(xEpochDay: 20001, y: 70.5)
        let otherValue = ChartPoint(xEpochDay: 20000, y: 70.6)

        #expect(point == sameValues)
        #expect(point != otherDay)
        #expect(point != otherValue)
    }

    @Test("the secondary series defaults to empty (ChartUiModel.kt:27)")
    func secondarySeriesDefaultsToEmpty() {
        let model = ChartUiModel(points: [ChartPoint(xEpochDay: 1, y: 1)], xLabel: { _ in "" })

        #expect(model.secondaryPoints.isEmpty)
    }

    @Test("the y label defaults to the plain number, as Kotlin's Float.toString (ChartUiModel.kt:26)")
    func yLabelDefaultsToPlainNumber() {
        let model = ChartUiModel(points: [], xLabel: { _ in "" })

        // Kotlin: 70.5f.toString() == "70.5", 70f.toString() == "70.0".
        #expect(model.yLabel(70.5) == "70.5")
        #expect(model.yLabel(70) == "70.0")
    }

    @Test("both labels are the caller's, when the caller passes them")
    func labelsAreTheCallers() {
        let model = ChartUiModel(
            points: [],
            xLabel: { "day \($0)" },
            yLabel: { "\($0) kg" },
            secondaryPoints: [ChartPoint(xEpochDay: 2, y: 2)]
        )

        #expect(model.xLabel(7) == "day 7")
        #expect(model.yLabel(3.5) == "3.5 kg")
        #expect(model.secondaryPoints == [ChartPoint(xEpochDay: 2, y: 2)])
    }
}
