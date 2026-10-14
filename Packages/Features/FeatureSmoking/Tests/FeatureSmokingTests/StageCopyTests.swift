// Ported from `StageCopyTest.kt`.

import SalusSmoking
import Testing

@testable import FeatureSmoking

@Suite("StageCopy")
struct StageCopyTests {
    @Test("every catalog stage has a title and a statement")
    func everyStageHasWords() {
        for stage in HealthStage.catalog {
            #expect(StageCopy.title(of: stage.id) != nil, "title of \(stage.id)")
            #expect(StageCopy.statement(of: stage.id) != nil, "statement of \(stage.id)")
        }
    }

    @Test("every stage has its own title")
    func everyStageHasItsOwnTitle() {
        let titles = HealthStage.catalog.map { StageCopy.title(of: $0.id) }
        #expect(Set(titles).count == titles.count, "two stages share a title string")
    }

    @Test("an id outside the catalog has no copy")
    func unknownIdHasNoCopy() {
        #expect(StageCopy.title(of: "h_9mo") == nil)
        #expect(StageCopy.statement(of: "h_9mo") == nil)
    }

    // MARK: - Timeline additions (Task 13)

    @Test("the threshold is the words before the title's separator")
    func thresholdIsTheTitleBeforeTheSeparator() {
        #expect(StageCopy.thresholdLabel(of: "20 dakika · Nabız ve tansiyon") == "20 dakika")
        #expect(StageCopy.thresholdLabel(of: "1 year · Coronary heart disease risk") == "1 year")
        // A title with no separator is its own threshold rather than an empty header figure.
        #expect(StageCopy.thresholdLabel(of: "Nabız") == "Nabız")
    }

    @Test("a stage's threshold comes from its own title")
    func stageThresholdFollowsItsTitle() throws {
        for stage in HealthStage.catalog {
            let title = try #require(StageCopy.title(of: stage.id))
            #expect(StageCopy.threshold(of: stage.id) == StageCopy.thresholdLabel(of: title))
        }
        #expect(StageCopy.threshold(of: "h_9mo") == nil)
    }

    @Test("each source has its own chip label and its own attribution")
    func eachSourceHasItsOwnWords() {
        #expect(StageCopy.sourceLabel(of: .who) != StageCopy.sourceLabel(of: .nhs))
        #expect(StageCopy.attribution(of: .who) != StageCopy.attribution(of: .nhs))
    }
}
