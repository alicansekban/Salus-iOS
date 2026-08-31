import SalusAI
import SalusModel
import Testing

// Tests pin down the `FakeAiClient` test-double's own behaviour, the shared fake later tasks use:
// queued results return in order, `isConfigured` propagates, and prompts are recorded.

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

    @Test("generate reports an error when no result is queued")
    func generateReportsNoQueuedResultError() async {
        let client = FakeAiClient(queuedResults: [], isConfigured: true)

        #expect(await client.generate(prompt("x")) == .error("no queued result"))
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

        // This fake has no short-circuit like the real client: it records what it is asked,
        // leaving the "unconfigured -> unavailable" decision purely behavioural.
        #expect(client.prompts == [promptSent])
    }

    private func prompt(_ user: String) -> AiPrompt {
        AiPrompt(system: "system", user: user)
    }
}
