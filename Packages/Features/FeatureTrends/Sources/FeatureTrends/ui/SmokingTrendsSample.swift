// Ported from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/TrendsSample.kt`
// (`previewSmokingQuit`, `previewSmokingReduce`, `previewSmokingNotEnoughData`).
//
// Hand-written insights for the section's previews, in the same spirit as `sampleTrendsReady`: every
// number is fixed, there is no clock and no random source, and they stand in for the calculator's
// output rather than for the records it would be computed from.

import SalusSmoking

/// A QUIT plan with a month behind it: triggers, a heatmap, two attempts and their quit days.
func previewSmokingQuit() -> SmokingInsights {
    SmokingInsights(
        hasEnoughData: true,
        triggers: [
            TriggerShare(trigger: .coffee, count: 34, permille: 340),
            TriggerShare(trigger: .stress, count: 27, permille: 270),
            TriggerShare(trigger: .afterMeal, count: 19, permille: 190),
            TriggerShare(trigger: .social, count: 12, permille: 120),
            TriggerShare(trigger: .boredom, count: 8, permille: 80)
        ],
        heatmap: previewHeatmap,
        busiestBand: .h14_16,
        busiestBandPermille: 260,
        reductionWeekly: [],
        attemptDurations: [
            AttemptDuration(attemptId: "a1", durationMs: 9 * previewDayMs),
            AttemptDuration(attemptId: "a2", durationMs: 23 * previewDayMs)
        ],
        quitMarkerEpochDays: [previewFirstDay + 6, previewFirstDay + 18]
    )
}

/// A REDUCE plan: the reduction curve joins the cards, and no attempt is compared.
func previewSmokingReduce() -> SmokingInsights {
    SmokingInsights(
        hasEnoughData: true,
        triggers: [
            TriggerShare(trigger: .stress, count: 21, permille: 420),
            TriggerShare(trigger: .coffee, count: 17, permille: 340),
            TriggerShare(trigger: .other, count: 12, permille: 240)
        ],
        heatmap: previewHeatmap,
        busiestBand: .h18_22,
        busiestBandPermille: 310,
        reductionWeekly: [18, 16, nil, 12, 9, 7],
        attemptDurations: [],
        quitMarkerEpochDays: []
    )
}

/// Fewer than seven days of entries: the section is one empty state.
func previewSmokingNotEnoughData() -> SmokingInsights {
    SmokingInsights(
        hasEnoughData: false,
        triggers: [],
        heatmap: Array(repeating: Array(repeating: 0, count: 7), count: 7),
        busiestBand: nil,
        busiestBandPermille: 0,
        reductionWeekly: [],
        attemptDurations: [],
        quitMarkerEpochDays: []
    )
}

private let previewDayMs: Int64 = 86_400_000

/// The same fixed day `sampleTrendsReady`'s axis starts on, so the quit markers land inside the
/// overlay the Trends preview draws.
private let previewFirstDay: Int64 = 20671

/// Seven hour bands by seven weekdays, weighted to the afternoons and the weekend evenings.
private let previewHeatmap: [[Int]] = [
    [1, 0, 2, 1, 0, 0, 0],
    [2, 1, 1, 2, 1, 0, 1],
    [3, 2, 2, 3, 2, 1, 1],
    [5, 4, 6, 5, 4, 3, 2],
    [3, 3, 2, 4, 3, 2, 3],
    [2, 3, 3, 2, 4, 6, 5],
    [0, 1, 0, 1, 2, 3, 2]
]
