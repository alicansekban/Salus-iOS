// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/MetricSummaryModelTest.kt`.

import SalusModel
import Testing

@testable import FeatureTrends

/// The UI edge of the metric summary: which of the three change sentences a row is written with,
/// and the number that sentence carries (`MetricSummaryModelTest.kt`).
///
/// This is where a true analysis can still be written down as a false claim, so the cases are
/// pinned here rather than checked by looking at a device. A metric that was never measured
/// before did not "stay the same"; a move too small to write down is not a rise of nothing; and
/// the number the sentence carries has to be the number the direction was decided from.
@Suite("MetricSummaryModel")
struct MetricSummaryModelTests {
    @Test("a metric absent from the earlier window is written as having nothing to compare")
    func metricAbsentFromEarlierWindowHasNothingToCompare() {
        let rows = metricSummaryRowsOf(summaries: summaries(summary(previous: nil, changePercent: nil)))

        #expect(rows.single().change == .noPreviousRecords)
    }

    @Test("an earlier average that cannot be divided by is its own case")
    func earlierAverageThatCannotBeDividedIsItsOwnCase() {
        // The analysis answers a nil change for an earlier average of zero. It is not the same
        // thing as having no earlier records, and the card may not say it is.
        let rows = metricSummaryRowsOf(
            summaries: summaries(summary(previous: stats(average: 0.0), changePercent: nil))
        )

        #expect(rows.single().change == .notComputable)
    }

    @Test("a rise carries its direction and its unsigned magnitude")
    func riseCarriesDirectionAndUnsignedMagnitude() {
        let rows = metricSummaryRowsOf(summaries: summaries(summary(changePercent: 8.24)))

        #expect(rows.single().change == .moved(direction: .up, magnitudePercent: 8.2))
    }

    @Test("a fall keeps its direction and loses its sign")
    func fallKeepsDirectionAndLosesSign() {
        // The sign lives in the sentence, not in the number, so a minus written in front of a
        // number the sentence already calls a fall would read as a double negative.
        let rows = metricSummaryRowsOf(summaries: summaries(summary(changePercent: -12.35)))

        let change = rows.single().change
        guard case let .moved(direction, magnitudePercent) = change else {
            Issue.record("expected a moved change, got \(change)")
            return
        }
        #expect(direction == .down)
        #expect(abs(magnitudePercent - 12.4) < tolerance)
    }

    @Test("a move too small to write down is flat rather than a rise of nothing")
    func moveTooSmallToWriteDownIsFlat() {
        // 0.04% rounds to 0.0 at the precision this card writes, and "up 0.0%" is a sentence
        // that contradicts its own number.
        let rows = metricSummaryRowsOf(summaries: summaries(summary(changePercent: 0.04)))

        #expect(rows.single().change == .moved(direction: .flat, magnitudePercent: 0.0))
    }

    @Test("a small fall is flat for the same reason a small rise is")
    func smallFallIsFlat() {
        let rows = metricSummaryRowsOf(summaries: summaries(summary(changePercent: -0.02)))

        #expect(rows.single().change == .moved(direction: .flat, magnitudePercent: 0.0))
    }

    @Test("a row carries its metric's own statistics unchanged")
    func rowCarriesItsMetricsOwnStatisticsUnchanged() {
        // Copied through rather than recomputed: a row and the summary it came from must not be
        // able to disagree about what was measured.
        let summary = MetricSummary(
            type: .bloodGlucose,
            current: MetricStats(
                count: 9,
                average: 118.5,
                min: 92.0,
                max: 164.0,
                trend: .falling
            ),
            previous: nil,
            changePercent: nil
        )

        let row = metricSummaryRowsOf(summaries: MetricSummaries(items: [summary])).single()

        #expect(row.type == .bloodGlucose)
        #expect(row.count == 9)
        #expect(abs(row.average - 118.5) < tolerance)
        #expect(abs(row.min - 92.0) < tolerance)
        #expect(abs(row.max - 164.0) < tolerance)
        #expect(row.trend == .falling)
    }

    @Test("rows keep the order the analysis produced")
    func rowsKeepTheOrderTheAnalysisProduced() {
        let rows = metricSummaryRowsOf(
            summaries: MetricSummaries(items: [
                summary(type: .weight),
                summary(type: .bloodGlucose)
            ])
        )

        #expect(rows.map(\.type) == [VitalType.weight, VitalType.bloodGlucose])
    }

    // MARK: - Fixtures

    private func summaries(_ summary: MetricSummary) -> MetricSummaries {
        MetricSummaries(items: [summary])
    }

    private func summary(
        type: VitalType = .weight,
        previous: MetricStats? = defaultStats,
        changePercent: Double? = nil
    ) -> MetricSummary {
        MetricSummary(
            type: type,
            current: defaultStats,
            previous: previous,
            changePercent: changePercent
        )
    }

    private func stats(average: Double = 72.0) -> MetricStats {
        MetricStats(
            count: 4,
            average: average,
            min: average,
            max: average,
            trend: .stable
        )
    }
}

private let defaultStats = MetricStats(
    count: 4,
    average: 72.0,
    min: 72.0,
    max: 72.0,
    trend: .stable
)

private let tolerance = 0.0001

extension Collection {
    fileprivate func single() -> Element {
        precondition(count == 1, "expected exactly one element, found \(count)")
        // swiftlint:disable:next force_unwrapping
        return first!
    }
}
