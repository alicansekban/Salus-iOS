import Foundation
import SalusDesignSystem
import Testing
@testable import SalusUI

/// The §11 stagger ladder — `salusStaggerDelay` in `SalusEnter.kt:64-65`, in seconds.
/// One step per index, floored at zero and capped so a long Home column still arrives in
/// one gesture instead of dribbling in.
@Suite("SalusEntrance")
struct SalusEntranceTests {
    @Test("zero and negative indices start immediately", arguments: [0, -3])
    func floor(_ index: Int) {
        #expect(SalusEntrance.delaySeconds(index: index) == 0)
    }

    @Test("each index adds one stagger step", arguments: [(1, 0.04), (3, 0.12), (5, 0.2)])
    func steps(_ index: Int, _ expected: TimeInterval) {
        #expect(SalusEntrance.delaySeconds(index: index) == expected)
    }

    @Test("delays stop growing at the cap", arguments: [6, 100])
    func cap(_ index: Int) {
        #expect(SalusEntrance.delaySeconds(index: index) == 0.2)
    }
}
