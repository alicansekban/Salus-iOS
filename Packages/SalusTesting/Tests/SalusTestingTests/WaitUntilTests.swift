// The helper itself: it has to outlast background work that takes real time, which a fixed number of
// main-actor yields does not (the yields can all be spent before a loaded pool thread gets a turn).

import Foundation
import SalusTesting
import Testing

@MainActor
@Suite("waitUntil", .timeLimit(.minutes(1)))
struct WaitUntilTests {
    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var raised = false
        var value: Bool { lock.withLock { raised } }
        func raise() {
            lock.withLock { raised = true }
        }
    }

    @Test("it waits for background work that takes real time")
    func outlastsSlowBackgroundWork() async {
        let flag = Flag()
        Task.detached {
            try? await Task.sleep(for: .milliseconds(200))
            flag.raise()
        }

        await waitUntil("the slow work") { flag.value }

        #expect(flag.value)
    }

    @Test("it returns at once when the condition already holds")
    func returnsImmediately() async {
        let start = ContinuousClock.now

        await waitUntil("nothing") { true }

        #expect(ContinuousClock.now - start < .seconds(1))
    }
}
