import Testing

@testable import SalusDesignSystem

// Motion-token pinning tests, split out of `SalusDesignTokensTests.swift` so the design-token
// file stays under the `file_length` warning (500). The suite name and contents are unchanged;
// `swift test --filter MotionTokenTests` still picks them up.

@Suite("Motion (§10, §11)")
struct MotionTokenTests {
    @Test("motion constants match design-tokens.md §10")
    func motionConstants() {
        #expect(SalusMotion.pushPopDurationSeconds == 0.4)
        #expect(SalusMotion.pushPopEasing == SalusTimingCurve(0.4, 0.0, 0.2, 1.0))
        #expect(SalusMotion.parallaxDivisor == 4)
        #expect(SalusMotion.enterZIndexPush == 1)
        #expect(SalusMotion.enterZIndexPop == -1)
    }

    @Test("tab-root transition is an instant swap and no screen resizes")
    func instantTabSwap() {
        #expect(SalusMotion.allTokens["tabRootTransition"] == SalusMotionToken.noTransition)
        #expect(SalusMotion.allTokens["sizeTransform"] == SalusMotionToken.noSizeTransform)
    }

    @Test("entrance tokens match design-tokens.md §11")
    func entranceTokens() {
        #expect(SalusMotion.entranceDurationSeconds == 0.45)
        #expect(SalusMotion.feedbackDurationSeconds == 0.15)
        #expect(SalusMotion.stateChangeDurationSeconds == 0.3)
        #expect(SalusMotion.emphasizedEasing == SalusTimingCurve(0.2, 0.0, 0.0, 1.0))
        #expect(SalusMotion.entranceStaggerStepSeconds == 0.04)
        #expect(SalusMotion.entranceStaggerCapIndex == 5)
        #expect(SalusMotion.entranceTokens.count == 6)
    }
}
