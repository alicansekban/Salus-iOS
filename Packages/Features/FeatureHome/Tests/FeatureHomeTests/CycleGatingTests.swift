// Ported 1:1 from `feature/home/src/test/kotlin/com/alicansekban/salus/feature/home/domain/
// CycleGatingTest.kt` — all six cases, by name, in the Kotlin order.
//
// Two mechanical differences from the Kotlin, both forced by the type system:
//   `assertSame(snapshot, …)` becomes `==`. Kotlin's `assertSame` proves the function returned the
//   *same object*; `CycleSnapshot` is a Swift struct, so there is no reference identity to assert —
//   value equality is the closest the type allows, and it is what the rule is really about (the
//   snapshot passes through unchanged, not a rebuilt one).
//   `assertNull(…)` becomes `== nil`.

import SalusModel
import Testing

@testable import FeatureHome

@Suite("Cycle gating")
struct CycleGatingTests {
    /// `CycleGatingTest.kt:14-18`.
    private static let snapshot = CycleSnapshot(
        cycleDay: 12,
        isPeriodOpen: false,
        averageCycleLengthDays: 28
    )

    /// `CycleGatingTest.kt:20-28`.
    private static func profile(sex: Sex?) -> Profile {
        Profile(
            id: "p",
            displayName: "A",
            birthDate: nil,
            sex: sex,
            heightCm: nil,
            healthNotes: nil,
            isDefault: true
        )
    }

    @Test("male profile hides the cycle")
    func maleProfileHidesTheCycle() {
        #expect(cycleForProfile(cycle: Self.snapshot, profile: Self.profile(sex: .male)) == nil)
    }

    @Test("female profile keeps the cycle")
    func femaleProfileKeepsTheCycle() {
        #expect(cycleForProfile(cycle: Self.snapshot, profile: Self.profile(sex: .female)) == Self.snapshot)
    }

    @Test("other sex keeps the cycle")
    func otherSexKeepsTheCycle() {
        #expect(cycleForProfile(cycle: Self.snapshot, profile: Self.profile(sex: .other)) == Self.snapshot)
    }

    @Test("null sex keeps the cycle")
    func nullSexKeepsTheCycle() {
        #expect(cycleForProfile(cycle: Self.snapshot, profile: Self.profile(sex: nil)) == Self.snapshot)
    }

    @Test("null profile hides the cycle")
    func nullProfileHidesTheCycle() {
        #expect(cycleForProfile(cycle: Self.snapshot, profile: nil) == nil)
    }

    @Test("null cycle stays null for a female profile")
    func nullCycleStaysNullForAFemaleProfile() {
        #expect(cycleForProfile(cycle: nil, profile: Self.profile(sex: .female)) == nil)
    }
}
