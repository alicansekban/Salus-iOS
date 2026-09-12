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

    /// Spec §3.5 / divergence (g): the entrance plays **once per view instance**. `TabView` keeps
    /// a tab's root alive, so returning to a tab re-runs `onAppear` on a view that has already
    /// arrived — and replaying the fade there reads as the screen reloading. The played flag is
    /// `@State` on the modifier and this is the ladder it gates.
    @Test("a first appearance animates after its stagger delay", arguments: [0, 2, 9])
    func firstAppearanceAnimates(_ index: Int) {
        let step = SalusEntrance.progress(for: index, played: false)

        #expect(step.animates)
        #expect(step.delay == SalusEntrance.delaySeconds(index: index))
        #expect(step.target == 1)
    }

    @Test("a second appearance animates nothing", arguments: [0, 2, 9])
    func secondAppearanceAnimatesNothing(_ index: Int) {
        let step = SalusEntrance.progress(for: index, played: true)

        #expect(step.animates == false)
        #expect(step.delay == nil)
        // Still settled, not hidden: a view that has played is drawn where it landed.
        #expect(step.target == 1)
    }
}
