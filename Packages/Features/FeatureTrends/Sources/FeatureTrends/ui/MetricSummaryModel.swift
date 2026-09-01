// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/MetricSummaryModel.kt`.

import Foundation
import SalusModel

/// Which sentence a row's change is written with (`MetricSummaryModel.kt:20-45`).
///
/// The three cases are separated here, in a tested function, rather than by a chain of null
/// checks inside the view, because they are the part of this card that can be made false: "no
/// earlier records" and "did not move" are different facts, and a card that wrote the second
/// where the first was true would be inventing a comparison out of an absence.
enum SummaryChange: Equatable, Sendable {
    /// The metric was never measured in the earlier window, so there is nothing to compare.
    case noPreviousRecords

    /// There was an earlier average, but it cannot be divided by.
    ///
    /// Only reachable for an average of exactly zero, which none of these metrics can really
    /// take — kept as its own case because the analysis is total and answers `nil` for it, and
    /// folding it into `noPreviousRecords` would tell the reader something that was not true.
    case notComputable

    /// The average moved by `magnitudePercent`, in `direction`.
    ///
    /// The magnitude is unsigned and already rounded to what the card writes, and the direction
    /// is derived from that same rounded number. That order matters: deciding the wording from
    /// the raw value would let a move of 0.04% be announced as a rise of 0.0%.
    case moved(direction: SummaryChangeDirection, magnitudePercent: Double)
}

/// Which way a measured change went. `flat` is a change too small to write down, not an absence
/// (`MetricSummaryModel.kt:48`).
enum SummaryChangeDirection: Equatable, Sendable {
    case up
    case down
    case flat
}

/// One row of the summary card, in canonical units (`MetricSummaryModel.kt:57-65`).
///
/// The numbers stay stored values — glucose in mg/dL whatever the reader chose — because the
/// conversion belongs to `MetricDisplay` at the very last step. Converting here would put a
/// display setting inside a mapping that is meant to be about wording.
struct MetricSummaryRow: Equatable, Sendable {
    let type: VitalType
    let count: Int
    let average: Double
    let min: Double
    let max: Double
    let trend: Trend
    let change: SummaryChange
}

/// Turns the metric summaries into the rows the card draws (`MetricSummaryModel.kt:78-91`).
///
/// The whole UI edge of this analysis, and a plain function rather than a block inside the view
/// so that its rules are covered by unit tests instead of by looking at a device — the same shape
/// `barChartModelOf`, `overlayChartModelOf` and `doseWeeksChartModelOf` have.
///
/// It decides two things and nothing else: which of the three sentences a row's change is
/// written with, and the number that sentence carries. Everything else it copies through, so a
/// row and the summary it came from can never disagree about a metric's own statistics.
func metricSummaryRowsOf(summaries: MetricSummaries) -> [MetricSummaryRow] {
    summaries.items.map { summary in
        MetricSummaryRow(
            type: summary.type,
            count: summary.current.count,
            average: summary.current.average,
            min: summary.current.min,
            max: summary.current.max,
            trend: summary.current.trend,
            change: changeOf(summary)
        )
    }
}

private func changeOf(_ summary: MetricSummary) -> SummaryChange {
    guard let percent = summary.changePercent else {
        return summary.previous == nil ? .noPreviousRecords : .notComputable
    }

    let magnitude = abs(percent).roundedToWrittenPrecision()
    let direction: SummaryChangeDirection = {
        // Rounded first on purpose: a move the card would write as "0.0%" is not a move it can
        // honestly announce a direction for.
        if magnitude == 0.0 {
            return .flat
        }
        return percent > 0.0 ? .up : .down
    }()
    return .moved(direction: direction, magnitudePercent: magnitude)
}

/// Rounded to the decimals the card writes, so the wording and the number cannot disagree
/// (`MetricSummaryModel.kt:112-113`).
extension Double {
    fileprivate func roundedToWrittenPrecision() -> Double {
        (self * changeScale).rounded() / changeScale
    }
}

/// One decimal on a percentage change, which is what `changeScale` is the power of ten for
/// (`MetricSummaryModel.kt:122`).
///
/// A whole percent would round a move of 1.4% and one of 0.6% to numbers a reader would compare
/// as if they were exact; a second decimal would suggest a precision a handful of readings does
/// not have.
let changeDecimals = 1

private let changeScale = 10.0
