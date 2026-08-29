// Ported 1:1 from the fixtures of `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/
// cycle/domain/usecase/CyclePredictorTest.kt` (`CyclePredictorTest.kt:22-42`).
//
// Kotlin keeps both builders private to the test class; Swift's test suites are structs, so they
// live at file scope here and every case in the table reads the same fixture.

import Foundation
import SalusModel

@testable import FeatureCycle

/// `CyclePredictorTest.kt:22` — one fixed instant for every record, so nothing in a case depends
/// on when the suite runs.
let cycleTestCreatedAt = Date(timeIntervalSince1970: 1_750_000_000)

/// Builds completed 5-day period records from the given start dates
/// (`CyclePredictorTest.kt:24-35`).
func periods(starts: [LocalDate]) -> [CyclePeriod] {
    starts.enumerated().map { index, start in
        CyclePeriod(
            id: "period-\(index)",
            startDate: start,
            endDate: start.plusDays(4),
            flowPeak: nil,
            note: nil,
            createdAt: cycleTestCreatedAt
        )
    }
}

/// Start dates produced by walking the given cycle lengths from `first`
/// (`CyclePredictorTest.kt:37-42`).
func startsFromLengths(first: LocalDate, lengths: [Int]) -> [LocalDate] {
    var starts = [first]
    var current = first
    for length in lengths {
        current = current.plusDays(length)
        starts.append(current)
    }
    return starts
}
