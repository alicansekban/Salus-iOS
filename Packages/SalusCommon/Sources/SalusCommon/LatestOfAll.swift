// The three- four- and five-source widenings of `LatestOfBoth.swift`'s combinator — the twins of
// `kotlinx.coroutines.flow.combine(a, b, c) { … }` and its wider overloads.
//
// Same reason as `latestOfBoth`, and no Kotlin counterpart file for the same reason: Kotlin gets
// every arity from the coroutines library, Swift ships none of them, and no general-purpose
// async-algorithms package may be added because `CLAUDE.md`'s dependency allowlist is closed.
// iOS-M7's home dashboard is what needs the wider arities.
//
// Each arity is the one below it combined with one more source, so the hard part is written once
// and all three inherit `latestOfBoth`'s semantics unchanged:
//  - nothing is emitted until **every** source has produced a value;
//  - after that a value from any source emits, carrying the others' latest;
//  - the first failure on any source fails the combined stream;
//  - and the "emit under the lock" ordering `LatestOfBoth.swift` documents holds at every layer, so
//    tuples reach the consumer in the order they were formed rather than the order their
//    transforms happened to finish.
//
// The tuple is in argument order, and these take no `transform`: a caller that wants one maps the
// tuple with `mapped`, and a caller that only wants the latest of each destructures it. That keeps
// the three signatures free of a closure whose argument count is the one thing that varies.

/// Emits `(first, second, third)` whenever any source produces a value and all three have produced
/// at least one.
public func latestOfThree<First: Sendable, Second: Sendable, Third: Sendable>(
    _ first: AsyncThrowingStream<First, any Error>,
    _ second: AsyncThrowingStream<Second, any Error>,
    _ third: AsyncThrowingStream<Third, any Error>
) -> AsyncThrowingStream<(First, Second, Third), any Error> {
    latestOfBoth(latestOfBoth(first, second) { ($0, $1) }, third) { pair, latestThird in
        (pair.0, pair.1, latestThird)
    }
}

/// Emits `(first, second, third, fourth)` whenever any source produces a value and all four have
/// produced at least one.
public func latestOfFour<First: Sendable, Second: Sendable, Third: Sendable, Fourth: Sendable>(
    _ first: AsyncThrowingStream<First, any Error>,
    _ second: AsyncThrowingStream<Second, any Error>,
    _ third: AsyncThrowingStream<Third, any Error>,
    _ fourth: AsyncThrowingStream<Fourth, any Error>
) -> AsyncThrowingStream<(First, Second, Third, Fourth), any Error> {
    latestOfBoth(latestOfThree(first, second, third), fourth) { triple, latestFourth in
        (triple.0, triple.1, triple.2, latestFourth)
    }
}

/// Emits `(first, second, third, fourth, fifth)` whenever any source produces a value and all five
/// have produced at least one.
public func latestOfFive<
    First: Sendable,
    Second: Sendable,
    Third: Sendable,
    Fourth: Sendable,
    Fifth: Sendable
>(
    _ first: AsyncThrowingStream<First, any Error>,
    _ second: AsyncThrowingStream<Second, any Error>,
    _ third: AsyncThrowingStream<Third, any Error>,
    _ fourth: AsyncThrowingStream<Fourth, any Error>,
    _ fifth: AsyncThrowingStream<Fifth, any Error>
) -> AsyncThrowingStream<(First, Second, Third, Fourth, Fifth), any Error> {
    latestOfBoth(latestOfFour(first, second, third, fourth), fifth) { quad, latestFifth in
        (quad.0, quad.1, quad.2, quad.3, latestFifth)
    }
}
