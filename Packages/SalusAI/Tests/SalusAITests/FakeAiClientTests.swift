import SalusAI
import SalusModel
import Testing

// Tests pin down the `FakeAiClient` test-double's own behaviour, the shared fake later tasks use:
// queued results return in order, `isConfigured` propagates, prompts are recorded, the unconfigured
// short-circuit mirrors `FirebaseAiClient`, and a dry queue falls back to `defaultResult`.

@Suite("FakeAiClient")
struct FakeAiClientTests {
    @Test("queued results are returned in order")
    func queuedResultsAreReturnedInOrder() async {
        let client = FakeAiClient(
            queuedResults: [.success("first"), .success("second"), .error("third")],
            isConfigured: true
        )

        #expect(await client.generate(prompt("a")) == .success("first"))
        #expect(await client.generate(prompt("b")) == .success("second"))
        #expect(await client.generate(prompt("c")) == .error("third"))
        #expect(!client.hasRemainingResults)
    }

    @Test("result queue can be drained fully")
    func resultQueueCanBeDrainedFully() async {
        let client = FakeAiClient(queuedResults: [.success("only")], isConfigured: true)

        #expect(await client.generate(prompt("x")) == .success("only"))
        #expect(!client.hasRemainingResults)
    }

    @Test("empty queue falls back to the default success result")
    func emptyQueueFallsBackToDefaultResult() async {
        let client = FakeAiClient(queuedResults: [], isConfigured: true)

        // Android's `defaultResult` answers a dry queue instead of erroring; `enqueue` keeps the
        // queue mutable so a later call can still supply a specific answer.
        #expect(await client.generate(prompt("x")) == .success("fake summary"))
    }

    @Test("customised defaultResult is used once the queue runs dry")
    func customisedDefaultResultIsUsedWhenQueueRunsDry() async {
        let client = FakeAiClient(queuedResults: [.success("first")], isConfigured: true)
        client.defaultResult = .error("dry")

        #expect(await client.generate(prompt("a")) == .success("first"))
        #expect(!client.hasRemainingResults)
        #expect(await client.generate(prompt("b")) == .error("dry"))
        #expect(client.prompts.count == 2)
    }

    @Test("enqueue appends results to the back of the queue")
    func enqueueAppendsToTheBackOfTheQueue() async {
        let client = FakeAiClient(queuedResults: [.success("initial")], isConfigured: true)

        client.enqueue(.success("one"), .error("two"))

        #expect(await client.generate(prompt("a")) == .success("initial"))
        #expect(await client.generate(prompt("b")) == .success("one"))
        #expect(await client.generate(prompt("c")) == .error("two"))
        #expect(!client.hasRemainingResults)
    }

    @Test("isConfigured is controllable per instance")
    func isConfiguredIsControllablePerInstance() {
        #expect(FakeAiClient(queuedResults: [], isConfigured: true).isConfigured)
        #expect(!FakeAiClient(queuedResults: [], isConfigured: false).isConfigured)
    }

    @Test("prompt list records exactly the sent prompts in order")
    func promptListRecordsExactlyTheSentPromptsInOrder() async {
        let client = FakeAiClient(queuedResults: [.success(""), .success("")], isConfigured: true)
        let first = prompt("hello")
        let second = prompt("doctor report")

        _ = await client.generate(first)
        _ = await client.generate(second)

        #expect(client.prompts == [first, second])
    }

    @Test("prompt list also records prompts on unconfigured calls")
    func promptListRecordsPromptsEvenWhenUnconfigured() async {
        let client = FakeAiClient(queuedResults: [], isConfigured: false)
        let promptSent = prompt("still sent")

        _ = await client.generate(promptSent)

        // Every prompt is recorded, including the ones answered with `.unavailable` (Android
        // doc: "including the ones answered with AiResult.Unavailable").
        #expect(client.prompts == [promptSent])
    }

    @Test("unconfigured client returns unavailable without consuming the queue")
    func unconfiguredClientReturnsUnavailableWithoutConsumingQueue() async {
        let client = FakeAiClient(queuedResults: [.success("kept"), .success("kept")], isConfigured: false)

        #expect(await client.generate(prompt("a")) == .unavailable)
        #expect(await client.generate(prompt("b")) == .unavailable)

        // The short-circuit mirrors `FirebaseAiClient`: neither call spent a queued result.
        #expect(client.hasRemainingResults)
    }

    private func prompt(_ user: String) -> AiPrompt {
        AiPrompt(system: "system", user: user)
    }
}
