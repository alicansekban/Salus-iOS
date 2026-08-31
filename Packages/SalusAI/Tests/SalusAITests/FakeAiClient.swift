import Foundation
import SalusAI

/// A test double for `AiClient` that queues canned results and records every prompt it receives.
///
/// This is the shared fake later tasks use wherever a repository needs an `AiClient`:
/// it lets a test drive a screen through predetermined outcomes while asserting on the exact
/// prompts that were sent. Its own behaviour — queue ordering, `isConfigured` propagation and
/// prompt recording — is what this task's tests pin down.
///
/// All mutation is serialised on a private dispatch queue. `generate` never actually suspends —
/// it returns the queued result immediately — so the synchronous critical section is safe to run
/// inside the `async` method, which Swift's `NSLock` API disallows from an async context.
final class FakeAiClient: AiClient, @unchecked Sendable {
    /// Results returned in queue order; `generate` removes and returns one per call.
    private var queuedResults: [AiResult]
    /// Whether this fake reports itself as configured. Configurable per test.
    var isConfigured: Bool
    /// Every prompt handed to `generate`, in call order.
    private var recordedPrompts: [AiPrompt]
    /// Serialises all mutation.
    private let queue = DispatchQueue(label: "com.salus.FakeAiClient")

    init(queuedResults: [AiResult] = [], isConfigured: Bool = true) {
        self.queuedResults = queuedResults
        self.isConfigured = isConfigured
        recordedPrompts = []
    }

    func generate(_ prompt: AiPrompt) async -> AiResult {
        queue.sync {
            recordedPrompts.append(prompt)
            if queuedResults.isEmpty {
                return .error("no queued result")
            }
            return queuedResults.removeFirst()
        }
    }

    /// The prompts recorded so far, in call order.
    var prompts: [AiPrompt] {
        queue.sync { recordedPrompts }
    }

    /// Whether any queued results remain.
    var hasRemainingResults: Bool {
        queue.sync { !queuedResults.isEmpty }
    }
}
