// The one bridge from a GRDB `ValueObservation` to the `AsyncThrowingStream` that stands in for a
// Room `Flow`. Every DAO in this package observes through it, so the semantics below are decided
// once rather than re-derived — identically, and then eventually not identically — per DAO.
//
// There is nothing to port from Kotlin here: Room generates the flow, and this is what that
// generated flow does.

import GRDB

/// Wraps a GRDB observation in the conflated, throwing stream a ported `Flow` is.
///
/// Throwing, because the `Flow` it ports throws. Room's `@Query`-backed flow re-runs the query on
/// every invalidation and lets a failure propagate to the collector; a stream that quietly ended
/// instead would hide a disk or corruption error behind an empty screen, which is a divergence
/// rather than parity. A failed observation finishes the stream `throwing:` that error, so the
/// caller decides what an unreadable database looks like.
///
/// `.bufferingNewest(1)`, because Room conflates. `CoroutinesRoom.createFlow` pushes invalidations
/// through a conflated channel, so a slow collector is handed the *current* value, never a queue of
/// superseded ones. `AsyncThrowingStream` defaults to `.unbounded`, which would replay every
/// intermediate value — the opposite behaviour, and stale by definition.
func conflatedStream<Value: Sendable>(
    _ values: AsyncValueObservation<Value>
) -> AsyncThrowingStream<Value, any Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let task = Task {
            do {
                for try await value in values {
                    continuation.yield(value)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        // A consumer that stops reading — a screen that goes away, a cancelled task — must stop
        // the observation too, or it keeps re-querying for nobody.
        continuation.onTermination = { _ in task.cancel() }
    }
}
