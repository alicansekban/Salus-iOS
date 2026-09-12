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

    /// §11's behaviour contract: a reduced entrance is opacity only. The offset is the half a
    /// renderless test can hold, and the half that was wrong — the modifier drove the travel
    /// from `progress` in both branches, so Reduce Motion still slid 24 pt.
    @Test(
        "Reduce Motion removes the travel at every progress",
        arguments: [0, 0.25, 0.5, 1] as [CGFloat]
    )
    func reducedMotionNeverTravels(_ progress: CGFloat) {
        #expect(SalusEntrance.offset(progress: progress, reduceMotion: true) == 0)
    }

    @Test("the full entrance starts one travel up and settles at zero")
    func fullEntranceTravels() {
        #expect(SalusEntrance.offset(progress: 0, reduceMotion: false) == SalusEntrance.travel)
        #expect(SalusEntrance.offset(progress: 0.5, reduceMotion: false) == SalusEntrance.travel / 2)
        #expect(SalusEntrance.offset(progress: 1, reduceMotion: false) == 0)
    }
}
