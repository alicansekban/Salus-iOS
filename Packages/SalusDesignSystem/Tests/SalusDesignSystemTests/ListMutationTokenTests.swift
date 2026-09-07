// The §10 motion suite lives in `SalusDesignTokensTests.swift`; the list-mutation tokens
// added 2026-09-07 moved here so the original file stays under the 500-line lint limit.

import SalusDesignSystem
import Testing

@Suite("List mutation motion (§10)")
struct ListMutationTokenTests {
    @Test("list mutation is 300 ms on the push/pop curve (§10)")
    func listMutation() {
        #expect(SalusMotion.listMutationDurationSeconds == 0.3)
        #expect(SalusMotion.allTokens["listMutationDuration"] == .durationSeconds(0.3))
    }
}
