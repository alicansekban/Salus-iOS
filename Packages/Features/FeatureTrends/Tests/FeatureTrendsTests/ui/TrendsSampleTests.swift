// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/TrendsSampleTest.kt`.

import SalusModel
import Testing

@testable import FeatureTrends

/// Guards the backdrop the locked body draws.
///
/// Two things can go wrong with sample data and neither shows up as a crash. It can start
/// changing between calls, which makes the paywall's backdrop flicker on every recomposition and
/// reads as a broken screen rather than a locked one. Or it can lose a section, which turns the
/// locked copy — which names four cards — into a promise the screen does not keep.
@Suite("TrendsSample")
struct TrendsSampleTests {
    @Test("two calls produce equal data")
    func twoCallsProduceEqualData() {
        // Structural equality all the way down: the analyses are value types and the lists are
        // plain arrays, so an equal result here means nothing was drawn from a clock or a random
        // source on the way. The two operands are deliberately identical — that is the whole
        // point of the test.
        // swiftlint:disable:next identical_operands
        #expect(sampleTrendsReady() == sampleTrendsReady())
    }

    @Test("every section is filled in")
    func everySectionIsFilledIn() {
        let sample = sampleTrendsReady()

        #expect(sample.timeOfDay != nil, "The time-of-day card would be missing.")
        #expect(sample.overlay != nil, "The overlay card would be missing.")
        #expect(sample.doseWeeks != nil, "The dose-week card would be missing.")
        #expect(sample.summaries != nil, "The summary card would be missing.")
    }

    @Test("no filled section is empty")
    func noFilledSectionIsEmpty() {
        let sample = sampleTrendsReady()

        // A non-nil model holding an empty list draws a card with an empty chart in it, which is
        // the one thing a locked preview must not show.
        #expect(sample.timeOfDay?.parts.isEmpty == false)
        #expect(sample.doseWeeks?.isEmpty == false)
        #expect(sample.summaries?.items.isEmpty == false)
    }

    @Test("the overlay carries more than one metric")
    func overlayCarriesMoreThanOneMetric() {
        // One metric laid over itself is not an overlay, so a single series would make the card
        // show something the real analysis never produces.
        #expect((sampleTrendsReady().overlay?.series.count ?? 0) > 1)
    }

    @Test("every week's share is a percentage")
    func everyWeeksShareIsAPercentage() {
        let weeks = sampleTrendsReady().doseWeeks ?? []

        for week in weeks {
            guard let percent = week.takenPercent else { continue }
            #expect(
                (0 ... 100).contains(percent),
                "Week \(week.startEpochDay) reports \(percent)%, which is not a share."
            )
        }

        // A week without a share is legitimate — nothing was written down that week — but a
        // sample where every week is like that would leave the chart with no bars at all.
        #expect(weeks.contains { $0.takenPercent != nil })
    }

    @Test("no week reports more doses taken than recorded")
    func noWeekReportsMoreDosesTakenThanRecorded() {
        for week in sampleTrendsReady().doseWeeks ?? [] {
            #expect(
                week.takenDoses <= week.loggedDoses,
                "Week \(week.startEpochDay) marks \(week.takenDoses) of \(week.loggedDoses)."
            )
        }
    }
}
