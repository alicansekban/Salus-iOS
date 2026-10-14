// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/analysis/SmokingTrendsTest.kt`.

import Foundation
import SalusSmoking
import Testing

@testable import FeatureTrends

/// The step between the smoking insights and the Trends screen: whether the section exists at all
/// and whether it has enough behind it to show figures. The figures themselves are
/// `SmokingInsightsCalculator`'s, tested in `SalusSmoking`.
@Suite("SmokingTrends")
struct SmokingTrendsTests {
    private let zone = TimeZone.gmt

    @Test("no plan means no section")
    func noPlanMeansNoSection() {
        let trends = smokingTrendsOrNull(
            smokingInput(plan: nil, events: eventsOnConsecutiveDays(10)),
            nowMs: smokingNowMs,
            zone: zone
        )

        #expect(trends == nil)
    }

    @Test("six distinct days are not enough data and seven are")
    func sixDaysAreNotEnoughAndSevenAre() {
        let six = smokingTrendsOrNull(smokingInput(events: eventsOnConsecutiveDays(6)), nowMs: smokingNowMs, zone: zone)
        let seven = smokingTrendsOrNull(
            smokingInput(events: eventsOnConsecutiveDays(7)),
            nowMs: smokingNowMs,
            zone: zone
        )

        #expect(six?.hasEnoughData == false)
        #expect(seven?.hasEnoughData == true)
    }

    @Test("a plan with no events is a section that is not yet enough")
    func planWithNoEventsIsNotYetEnough() {
        let trends = smokingTrendsOrNull(smokingInput(), nowMs: smokingNowMs, zone: zone)

        #expect(trends?.hasEnoughData == false)
        #expect(trends?.busiestBand == nil)
    }

    @Test("the figures of the insights are carried over")
    func theFiguresOfTheInsightsAreCarriedOver() {
        let trends = smokingTrendsOrNull(
            smokingInput(
                attempts: [
                    smokingAttempt("a1", startDay: smokingToday - 40, endDay: smokingToday - 20),
                    smokingAttempt("a2", startDay: smokingToday - 20)
                ],
                events: eventsOnConsecutiveDays(8)
            ),
            nowMs: smokingNowMs,
            zone: zone
        )

        // Every event is at 15:00, so the whole heatmap weight sits in one band.
        #expect(trends?.busiestBand == .h14_16)
        #expect(trends?.busiestBandPermille == 1000)
        #expect(trends?.quitMarkerEpochDays == [smokingToday - 40, smokingToday - 20])
        #expect(trends?.attemptDurations.count == 2)
        #expect(trends?.heatmap.count == HourBand.allCases.count)
    }

    @Test("the reduction history exists only for a reduce plan")
    func reductionHistoryExistsOnlyForAReducePlan() {
        let quit = smokingTrendsOrNull(
            smokingInput(plan: smokingPlan(mode: .quit), events: eventsOnConsecutiveDays(8, smoked: true)),
            nowMs: smokingNowMs,
            zone: zone
        )
        let reduce = smokingTrendsOrNull(
            smokingInput(plan: smokingPlan(mode: .reduce), events: eventsOnConsecutiveDays(8, smoked: true)),
            nowMs: smokingNowMs,
            zone: zone
        )

        #expect(quit?.reductionWeekly.isEmpty == true)
        #expect(reduce?.reductionWeekly.isEmpty == false)
    }
}
