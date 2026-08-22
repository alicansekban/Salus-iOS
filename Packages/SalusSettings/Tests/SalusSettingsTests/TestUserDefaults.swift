import Foundation
import Testing

/// A throwaway `UserDefaults` suite, one per test, wiped when the test's instance goes away.
///
/// The Android tests get their isolation from JUnit's `TemporaryFolder`
/// (`AiUsageDataSourceTest.kt:28-29`); a named suite is the `UserDefaults` twin. The name carries
/// a fresh UUID so tests running in parallel — Swift Testing's default — cannot see each other's
/// writes, and `removePersistentDomain` in `deinit` keeps the plist off the developer's machine.
///
/// A class rather than a struct on purpose: `deinit` is the only teardown hook a value type has
/// no equivalent for, and it fires whether the test passed, failed or threw.
final class TestUserDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init() throws {
        let suiteName = "salus-test-\(UUID().uuidString)"
        self.suiteName = suiteName
        defaults = try #require(
            UserDefaults(suiteName: suiteName),
            "UserDefaults refused the suite name \(suiteName)"
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

extension AsyncStream {
    /// The stream's current value — the twin of Kotlin's `flow.first()`
    /// (`AiUsageDataSourceTest.kt:166`).
    ///
    /// Both data sources emit the stored value as soon as a consumer arrives, so this awaits a
    /// real element instead of sleeping; leaving the loop terminates the stream, exactly as
    /// `first()` cancels its collector.
    func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}

/// Records every element a stream emits, so a test can assert the whole *sequence* instead of
/// whatever happened to be in the buffer.
///
/// Why this exists: the streams under test buffer `.bufferingNewest(1)`. A test that pulls
/// elements with its own iterator is only inside `next()` for an instant, so a duplicate emitted
/// while it was between calls lands in the one-slot buffer and is overwritten by the next
/// element — which makes "it does not re-emit equal values" pass whether the store dedupes or
/// not. A dedicated consumer task that sits *in* `next()` is handed each yield directly, so what
/// it collected is the emission sequence rather than a sample of it.
///
/// `wait(forAtLeast:)` is the only synchronisation — no sleeps, no polling. It suspends until the
/// consumer has recorded that many elements, then gives the cooperative pool two scheduling
/// rounds so the consumer is parked in `next()` again before the test's next write. That last
/// part is best effort: if the consumer has not re-parked, a spurious duplicate can still be
/// swallowed by the buffer and the test *passes* where it should have failed. It cannot fail
/// spuriously, because nothing but a real emission ever appends to the array.
final class StreamRecorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value] = []
    private var waiter: (threshold: Int, continuation: CheckedContinuation<Void, Never>)?
    /// Optional only so it can be assigned after `self` is fully initialised, which is what lets
    /// the task capture the recorder weakly.
    private var consumer: Task<Void, Never>?

    init(_ stream: AsyncStream<Value>) {
        consumer = Task { [weak self] in
            for await value in stream {
                self?.record(value)
            }
            self?.streamFinished()
        }
    }

    deinit {
        consumer?.cancel()
    }

    /// Everything received so far, in order.
    var recorded: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    /// Suspends until at least `count` elements have been recorded.
    func wait(forAtLeast count: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if values.count >= count {
                lock.unlock()
                continuation.resume()
                return
            }
            waiter = (count, continuation)
            lock.unlock()
        }
        // Let the consumer get back into `next()` before the caller writes again.
        await Task.yield()
        await Task.yield()
    }

    private func record(_ value: Value) {
        lock.lock()
        values.append(value)
        let due = waiter.map { values.count >= $0.threshold } ?? false
        let resumed = due ? waiter?.continuation : nil
        if due {
            waiter = nil
        }
        lock.unlock()

        resumed?.resume()
    }

    /// Releases a waiter that can never be satisfied, so a broken stream fails the test instead
    /// of hanging it.
    private func streamFinished() {
        lock.lock()
        let resumed = waiter?.continuation
        waiter = nil
        lock.unlock()

        resumed?.resume()
    }
}
