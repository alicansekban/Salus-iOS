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
}
