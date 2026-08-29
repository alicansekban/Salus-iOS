// Covers `LatestOfAll.swift`'s three widenings of `latestOfBoth`. No Android twin, for
// `LatestOfBothTests`' reason: Kotlin's `combine` overloads are library code with their own tests,
// and these exist because Swift ships none of them.
//
// Each arity gets the same three cases, because each is a separate nesting and a mis-wired one
// would still compile: nothing reaches the consumer until every source has a value, a change on any
// source emits the current tuple with the values in argument order, and the first failure on any
// source fails the combined stream. The ordering guarantee is not re-tested here — every layer is
// `latestOfBoth`, whose own suite pins it.

import Testing

@testable import SalusCommon

/// The stand-in for a source failure, as in `LatestOfBothTests`: a local error keeps the cases from
/// borrowing a feature's vocabulary.
private enum StreamFailure: Error {
    case unreadable
}

@Suite("latestOfThree / latestOfFour / latestOfFive")
struct LatestOfAllTests {
    // MARK: - Three

    @Test("latestOfThree emits nothing until every source has a value")
    func latestOfThreeEmitsNothingUntilEverySourceHasAValue() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let third = AsyncThrowingStream<Int, any Error>.makeStream()
        let combined = latestOfThree(first.stream, second.stream, third.stream)

        // The third source never produces a value, so the two that do pair with nothing.
        first.continuation.yield(1)
        second.continuation.yield(2)
        first.continuation.finish()
        second.continuation.finish()
        third.continuation.finish()

        var emitted = 0
        for try await _ in combined {
            emitted += 1
        }
        #expect(emitted == 0)
    }

    @Test("latestOfThree emits the latest tuple, in argument order, on every change")
    func latestOfThreeEmitsTheLatestTupleInArgumentOrderOnEveryChange() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let third = AsyncThrowingStream<Int, any Error>.makeStream()
        var iterator = latestOfThree(first.stream, second.stream, third.stream).makeAsyncIterator()

        first.continuation.yield(1)
        second.continuation.yield(2)
        third.continuation.yield(3)
        let opened = try await iterator.next()
        #expect(opened.map { [$0.0, $0.1, $0.2] } == [1, 2, 3])

        // A change on one source re-emits with the others' latest, and only that slot moves.
        second.continuation.yield(20)
        let changed = try await iterator.next()
        #expect(changed.map { [$0.0, $0.1, $0.2] } == [1, 20, 3])
    }

    @Test("latestOfThree propagates the first error")
    func latestOfThreePropagatesTheFirstError() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let third = AsyncThrowingStream<Int, any Error>.makeStream()
        let combined = latestOfThree(first.stream, second.stream, third.stream)

        first.continuation.yield(1)
        third.continuation.finish(throwing: StreamFailure.unreadable)
        first.continuation.finish()
        second.continuation.finish()

        await #expect(throws: StreamFailure.unreadable) {
            for try await _ in combined {}
        }
    }

    // MARK: - Four

    @Test("latestOfFour emits nothing until every source has a value")
    func latestOfFourEmitsNothingUntilEverySourceHasAValue() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let third = AsyncThrowingStream<Int, any Error>.makeStream()
        let fourth = AsyncThrowingStream<Int, any Error>.makeStream()
        let combined = latestOfFour(first.stream, second.stream, third.stream, fourth.stream)

        first.continuation.yield(1)
        second.continuation.yield(2)
        third.continuation.yield(3)
        first.continuation.finish()
        second.continuation.finish()
        third.continuation.finish()
        fourth.continuation.finish()

        var emitted = 0
        for try await _ in combined {
            emitted += 1
        }
        #expect(emitted == 0)
    }

    @Test("latestOfFour emits the latest tuple, in argument order, on every change")
    func latestOfFourEmitsTheLatestTupleInArgumentOrderOnEveryChange() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let third = AsyncThrowingStream<Int, any Error>.makeStream()
        let fourth = AsyncThrowingStream<Int, any Error>.makeStream()
        var iterator = latestOfFour(first.stream, second.stream, third.stream, fourth.stream)
            .makeAsyncIterator()

        first.continuation.yield(1)
        second.continuation.yield(2)
        third.continuation.yield(3)
        fourth.continuation.yield(4)
        let opened = try await iterator.next()
        #expect(opened.map { [$0.0, $0.1, $0.2, $0.3] } == [1, 2, 3, 4])

        third.continuation.yield(30)
        let changed = try await iterator.next()
        #expect(changed.map { [$0.0, $0.1, $0.2, $0.3] } == [1, 2, 30, 4])
    }

    @Test("latestOfFour propagates the first error")
    func latestOfFourPropagatesTheFirstError() async throws {
        let first = AsyncThrowingStream<Int, any Error>.makeStream()
        let second = AsyncThrowingStream<Int, any Error>.makeStream()
        let third = AsyncThrowingStream<Int, any Error>.makeStream()
        let fourth = AsyncThrowingStream<Int, any Error>.makeStream()
        let combined = latestOfFour(first.stream, second.stream, third.stream, fourth.stream)

        first.continuation.yield(1)
        fourth.continuation.finish(throwing: StreamFailure.unreadable)
        first.continuation.finish()
        second.continuation.finish()
        third.continuation.finish()

        await #expect(throws: StreamFailure.unreadable) {
            for try await _ in combined {}
        }
    }

    // MARK: - Five

    @Test("latestOfFive emits nothing until every source has a value")
    func latestOfFiveEmitsNothingUntilEverySourceHasAValue() async throws {
        let sources = IntSources()
        let combined = latestOfFive(
            sources.first.stream,
            sources.second.stream,
            sources.third.stream,
            sources.fourth.stream,
            sources.fifth.stream
        )

        sources.first.continuation.yield(1)
        sources.second.continuation.yield(2)
        sources.third.continuation.yield(3)
        sources.fourth.continuation.yield(4)
        sources.finishAll()

        var emitted = 0
        for try await _ in combined {
            emitted += 1
        }
        #expect(emitted == 0)
    }

    @Test("latestOfFive emits the latest tuple, in argument order, on every change")
    func latestOfFiveEmitsTheLatestTupleInArgumentOrderOnEveryChange() async throws {
        let sources = IntSources()
        var iterator = latestOfFive(
            sources.first.stream,
            sources.second.stream,
            sources.third.stream,
            sources.fourth.stream,
            sources.fifth.stream
        ).makeAsyncIterator()

        sources.first.continuation.yield(1)
        sources.second.continuation.yield(2)
        sources.third.continuation.yield(3)
        sources.fourth.continuation.yield(4)
        sources.fifth.continuation.yield(5)
        let opened = try await iterator.next()
        #expect(opened.map { [$0.0, $0.1, $0.2, $0.3, $0.4] } == [1, 2, 3, 4, 5])

        sources.fifth.continuation.yield(50)
        let changed = try await iterator.next()
        #expect(changed.map { [$0.0, $0.1, $0.2, $0.3, $0.4] } == [1, 2, 3, 4, 50])
    }

    @Test("latestOfFive propagates the first error")
    func latestOfFivePropagatesTheFirstError() async throws {
        let sources = IntSources()
        let combined = latestOfFive(
            sources.first.stream,
            sources.second.stream,
            sources.third.stream,
            sources.fourth.stream,
            sources.fifth.stream
        )

        sources.first.continuation.yield(1)
        sources.second.continuation.finish(throwing: StreamFailure.unreadable)
        sources.first.continuation.finish()
        sources.third.continuation.finish()
        sources.fourth.continuation.finish()
        sources.fifth.continuation.finish()

        await #expect(throws: StreamFailure.unreadable) {
            for try await _ in combined {}
        }
    }
}

/// Five hand-made streams. The three- and four-source cases build theirs inline, but five pairs of
/// `let`s repeated three times is where the noise starts to hide the assertion.
private struct IntSources {
    let first = AsyncThrowingStream<Int, any Error>.makeStream()
    let second = AsyncThrowingStream<Int, any Error>.makeStream()
    let third = AsyncThrowingStream<Int, any Error>.makeStream()
    let fourth = AsyncThrowingStream<Int, any Error>.makeStream()
    let fifth = AsyncThrowingStream<Int, any Error>.makeStream()

    func finishAll() {
        first.continuation.finish()
        second.continuation.finish()
        third.continuation.finish()
        fourth.continuation.finish()
        fifth.continuation.finish()
    }
}
