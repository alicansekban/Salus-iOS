// The five Kotlin cases from
// `salus-android/core/common/src/test/kotlin/com/alicansekban/salus/core/common/ReviewPromptPolicyTest.kt`,
// ported one for one. Milliseconds throughout, because that is the unit the stamp is stored in.

import Testing

@testable import SalusCommon

@Suite("ReviewPromptPolicy")
struct ReviewPromptPolicyTests {
    private let now: Int64 = 1_700_000_000_000
    private let day: Int64 = 24 * 60 * 60 * 1000

    @Test("two opens and never asked is too early")
    func belowThreshold() {
        #expect(!ReviewPromptPolicy.shouldRequest(openCount: 2, lastRequestedEpochMs: nil, nowEpochMs: now))
    }

    @Test("the third open with no earlier request asks")
    func atThreshold() {
        #expect(ReviewPromptPolicy.shouldRequest(openCount: 3, lastRequestedEpochMs: nil, nowEpochMs: now))
    }

    @Test("thirteen days after the last request is inside the cooldown")
    func insideCooldown() {
        #expect(!ReviewPromptPolicy.shouldRequest(openCount: 3, lastRequestedEpochMs: now - 13 * day, nowEpochMs: now))
    }

    @Test("exactly fourteen days after the last request asks again")
    func atCooldownBoundary() {
        #expect(ReviewPromptPolicy.shouldRequest(openCount: 3, lastRequestedEpochMs: now - 14 * day, nowEpochMs: now))
    }

    @Test("a request made just now blocks regardless of the count")
    func justRequested() {
        #expect(!ReviewPromptPolicy.shouldRequest(openCount: 100, lastRequestedEpochMs: now, nowEpochMs: now))
    }

    @Test("the constants are the Android values")
    func constants() {
        #expect(ReviewPromptPolicy.minOpens == 3)
        #expect(ReviewPromptPolicy.cooldownMs == 14 * day)
    }
}
