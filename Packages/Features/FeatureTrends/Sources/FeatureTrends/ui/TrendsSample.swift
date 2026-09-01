// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/TrendsSample.kt`.

import SalusModel

/// The made-up records the locked body draws behind its scrim, and the same data the screen's
/// `Ready` preview renders.
///
/// Every number here is written by hand. There is no `Random`, no `Clock` and no `SalusClock`:
/// two calls have to produce equal values, because a paywall whose backdrop reshuffles itself on
/// every recomposition looks like a screen that is malfunctioning rather than one that is locked.
/// The fixed epoch days are the same choice — the sample's axis says August 2026 forever, which
/// nobody can read through the scrim and which keeps this file free of a time source.
///
/// All four analyses are filled in. The locked copy names four cards, so a backdrop that showed
/// three would be promising something the screen does not draw.
///
/// The values are ordinary, unremarkable readings. They are a texture, not an example of a
/// result: nothing here is meant to be read as a finding, which is also why nothing on the
/// locked body is reachable by VoiceOver.
func sampleTrendsReady() -> TrendsReady {
    TrendsReady(
        timeOfDay: sampleTimeOfDay(),
        overlay: sampleOverlay(),
        doseWeeks: sampleDoseWeeks(),
        summaries: sampleSummaries()
    )
}

/// Blood pressure across all four buckets, so the backdrop's first chart has no gap in it.
private func sampleTimeOfDay() -> TimeOfDayBreakdown {
    TimeOfDayBreakdown(
        type: .bloodPressure,
        parts: [
            DayPartStats(part: .morning, count: 21, primaryAverage: 129.0, secondaryAverage: 84.0),
            DayPartStats(part: .midday, count: 14, primaryAverage: 124.0, secondaryAverage: 81.0),
            DayPartStats(part: .evening, count: 18, primaryAverage: 133.0, secondaryAverage: 87.0),
            DayPartStats(part: .night, count: 6, primaryAverage: 121.0, secondaryAverage: 79.0)
        ]
    )
}

/// Three metrics on the shared scale, five points each.
///
/// The y values are already normalized to 0...1, the way `metricOverlayOf` hands them over: this
/// file stands in for the analysis output, not for the records it was computed from.
private func sampleOverlay() -> MetricOverlay {
    MetricOverlay(
        series: [
            OverlaySeries(
                type: .weight,
                points: [
                    OverlayPoint(xEpochDay: sampleFirstDay, y: 1),
                    OverlayPoint(xEpochDay: sampleFirstDay + 7, y: 0.78),
                    OverlayPoint(xEpochDay: sampleFirstDay + 14, y: 0.55),
                    OverlayPoint(xEpochDay: sampleFirstDay + 21, y: 0.31),
                    OverlayPoint(xEpochDay: sampleFirstDay + 28, y: 0)
                ],
                min: 68.2,
                max: 71.6
            ),
            OverlaySeries(
                type: .bloodPressure,
                points: [
                    OverlayPoint(xEpochDay: sampleFirstDay, y: 0.72),
                    OverlayPoint(xEpochDay: sampleFirstDay + 7, y: 0.41),
                    OverlayPoint(xEpochDay: sampleFirstDay + 14, y: 0.63),
                    OverlayPoint(xEpochDay: sampleFirstDay + 21, y: 0.28),
                    OverlayPoint(xEpochDay: sampleFirstDay + 28, y: 0.46)
                ],
                min: 117.0,
                max: 142.0
            ),
            OverlaySeries(
                type: .bloodGlucose,
                points: [
                    OverlayPoint(xEpochDay: sampleFirstDay, y: 0.34),
                    OverlayPoint(xEpochDay: sampleFirstDay + 7, y: 0.52),
                    OverlayPoint(xEpochDay: sampleFirstDay + 14, y: 0.29),
                    OverlayPoint(xEpochDay: sampleFirstDay + 21, y: 0.66),
                    OverlayPoint(xEpochDay: sampleFirstDay + 28, y: 0.48)
                ],
                min: 92.0,
                max: 128.0
            )
        ]
    )
}

/// Six weeks of dose records.
///
/// One of them logged nothing, so it has no share and therefore no bar — the same shape the real
/// analysis produces, kept here so the backdrop does not imply that every week always has one.
private func sampleDoseWeeks() -> [DoseWeek] {
    [
        DoseWeek(
            startEpochDay: sampleFirstWeek,
            loggedDoses: 14,
            takenDoses: 12,
            takenPercent: 86,
            systolicAverage: 131.0,
            glucoseAverage: 104.0
        ),
        DoseWeek(
            startEpochDay: sampleFirstWeek + daysPerWeek,
            loggedDoses: 14,
            takenDoses: 13,
            takenPercent: 93,
            systolicAverage: 128.0,
            glucoseAverage: 99.0
        ),
        DoseWeek(
            startEpochDay: sampleFirstWeek + 2 * daysPerWeek,
            loggedDoses: 14,
            takenDoses: 14,
            takenPercent: 100,
            systolicAverage: 125.0,
            glucoseAverage: nil
        ),
        // Nothing was written down this week, so there is no share to report and no bar to draw.
        DoseWeek(
            startEpochDay: sampleFirstWeek + 3 * daysPerWeek,
            loggedDoses: 0,
            takenDoses: 0,
            takenPercent: nil,
            systolicAverage: 127.0,
            glucoseAverage: 108.0
        ),
        DoseWeek(
            startEpochDay: sampleFirstWeek + 4 * daysPerWeek,
            loggedDoses: 14,
            takenDoses: 11,
            takenPercent: 79,
            systolicAverage: 130.0,
            glucoseAverage: 111.0
        ),
        DoseWeek(
            startEpochDay: sampleFirstWeek + 5 * daysPerWeek,
            loggedDoses: 14,
            takenDoses: 13,
            takenPercent: 93,
            systolicAverage: 126.0,
            glucoseAverage: 102.0
        )
    ]
}

/// One summary per metric, and one of each change sentence the card can write.
///
/// Weight moved down, blood pressure moved up, and glucose was measured for the first time in
/// this window, which is the case that has nothing to compare against.
private func sampleSummaries() -> MetricSummaries {
    MetricSummaries(
        items: [
            MetricSummary(
                type: .weight,
                current: MetricStats(
                    count: 24,
                    average: 69.8,
                    min: 68.2,
                    max: 71.6,
                    trend: .falling
                ),
                previous: MetricStats(
                    count: 19,
                    average: 71.4,
                    min: 70.1,
                    max: 72.8,
                    trend: .stable
                ),
                changePercent: -2.2409
            ),
            MetricSummary(
                type: .bloodPressure,
                current: MetricStats(
                    count: 59,
                    average: 128.2,
                    min: 117.0,
                    max: 142.0,
                    trend: .rising
                ),
                previous: MetricStats(
                    count: 44,
                    average: 124.6,
                    min: 114.0,
                    max: 139.0,
                    trend: .stable
                ),
                changePercent: 2.8892
            ),
            // Measured for the first time in this window: there is no earlier average to move from.
            MetricSummary(
                type: .bloodGlucose,
                current: MetricStats(
                    count: 31,
                    average: 105.4,
                    min: 92.0,
                    max: 128.0,
                    trend: .stable
                ),
                previous: nil,
                changePercent: nil
            )
        ]
    )
}

/// Monday 2026-08-03: the week the sample's first dose record falls in.
private let sampleFirstWeek = 20668

/// 2026-08-06, so the sample's axis reads like a real month.
private let sampleFirstDay = 20671

/// Weeks are laid out by hand here, so the step is spelled out rather than imported.
private let daysPerWeek = 7
