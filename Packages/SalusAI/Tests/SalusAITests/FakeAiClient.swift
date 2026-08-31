import Foundation
import SalusAI

/// A test double for `AiClient` that queues canned results and records every prompt it receives.
///
/// This is the shared fake later tasks use wherever a repository needs an `AiClient`:
/// it lets a test drive a screen through predetermined outcomes while asserting on the exact
/// prompts that were sent. Its own behaviour — queue ordering, `isConfigured` propagation,
/// `defaultResult` fallback and prompt recording — is what this task's tests pin down.
///
/// Ported 1:1 from Android
/// `core/ai/src/test/kotlin/com/alicansekban/salus/core/ai/FakeAiClient.kt`.
///
/// All mutation is serialised on a private dispatch queue. `generate` never actually suspends —
/// it returns the queued result immediately — so the synchronous critical section is safe to run
/// inside the `async` method, which Swift's `NSLock` API disallows from an async context.
final class FakeAiClient: AiClient, @unchecked Sendable {
    /// Results returned in FIFO order; `generate` removes and returns one per call. Once the queue
    /// runs dry, `defaultResult` is returned. An unconfigured client answers `.unavailable` without
    /// spending a result, exactly as the real `FirebaseAiClient` does.
    private var queuedResults: [AiResult]
    /// Whether this fake reports itself as configured. Configurable per instance, mirroring
    /// Android's constructor parameter (default `true`).
    var isConfigured: Bool
    /// Every prompt handed to `generate`, in call order.
    private var recordedPrompts: [AiPrompt]
    /// Serialises all mutation.
    private let queue = DispatchQueue(label: "com.salus.FakeAiClient")

    /// Answer used once the queue runs dry. Mirrors Android's `defaultResult` (default
    /// `.success("fake summary")`), so a test that does not care about the answer does not have to
    /// enqueue one.
    var defaultResult: AiResult = .success("fake summary")

    init(queuedResults: [AiResult] = [], isConfigured: Bool = true) {
        self.queuedResults = queuedResults
        self.isConfigured = isConfigured
        recordedPrompts = []
    }

    func generate(_ prompt: AiPrompt) async -> AiResult {
        queue.sync {
            recordedPrompts.append(prompt)
            // Mirrors FirebaseAiClient: an unconfigured client answers without spending a result.
            if !isConfigured {
                return .unavailable
            }
            return queuedResults.isEmpty ? defaultResult : queuedResults.removeFirst()
        }
    }

    /// Queues `results` to be returned by the next `generate` calls, in the given order. The twin
    /// of Android's `enqueue(vararg results: AiResult)`.
    func enqueue(_ results: AiResult...) {
        queue.sync {
            queuedResults.append(contentsOf: results)
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
