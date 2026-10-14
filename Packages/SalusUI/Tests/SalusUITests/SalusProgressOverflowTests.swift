import Testing

@testable import SalusUI

/// Design review R2 (iOS-M17 Task 8): over a limit the ring and the bar stay full in their own
/// colour and the excess is drawn as a neutral lap. This pins the one number both shapes share —
/// how much of the track/circumference the lap covers.
@Suite("SalusProgressOverflow")
struct SalusProgressOverflowTests {
    @Test("no overflow draws no lap")
    func zeroIsNoLap() {
        #expect(SalusProgressOverflow.fraction(forPermille: 0) == 0)
    }

    @Test("a negative value is treated as no overflow")
    func negativeIsNoLap() {
        #expect(SalusProgressOverflow.fraction(forPermille: -250) == 0)
    }

    @Test("permille maps to a fraction of the track")
    func permilleMapsToFraction() {
        #expect(SalusProgressOverflow.fraction(forPermille: 200) == 0.2)
        #expect(SalusProgressOverflow.fraction(forPermille: 500) == 0.5)
        #expect(SalusProgressOverflow.fraction(forPermille: 1000) == 1)
    }

    @Test("more than a full lap is capped at one")
    func cappedAtOneLap() {
        #expect(SalusProgressOverflow.fraction(forPermille: 1700) == 1)
    }

    @MainActor
    @Test("the ring and the bar take overflow without changing their default clamp")
    func existingCallSitesAreUnchanged() {
        // The defaulted parameter is what keeps every existing call site compiling; the clamp the
        // M14 plan added stays where it was.
        #expect(SalusProgressRing.clamped(1.5) == 1)
        _ = SalusProgressRing(progress: 0.5, label: "1/2")
        _ = SalusProgressBar(progress: 0.5)
        _ = SalusProgressRing(progress: 1, label: "12", overflowPermille: 200)
        _ = SalusProgressBar(progress: 1, overflowPermille: 200)
    }
}
