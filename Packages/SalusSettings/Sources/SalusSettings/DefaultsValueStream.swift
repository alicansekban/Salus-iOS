import Foundation

/// The `AsyncStream` machinery both data sources need, factored out because getting it wrong
/// twice is worse than naming it once.
///
/// It is the iOS twin of Kotlin's `DataStore.data.map { … }`
/// (`SalusPreferencesDataSource.kt:20`, `AiUsageDataSource.kt:82`), which gives four properties
/// for free that `UserDefaults` gives none of:
///
///  * **A current value on subscribe.** A new collector of `DataStore.data` receives what is
///    stored right now, not the next change. So does every stream made here.
///  * **An emission on every change.** `UserDefaults` posts `didChangeNotification`, which is
///    observed below — but a suite's notification is not reliably posted on every platform, so
///    the data sources also call `publish()` by hand after each of their own writes. Both paths
///    end in the same recompute, so a doubled wake-up costs a read, not a duplicate element.
///  * **Distinct by content.** `DataStore.data` does not re-emit an unchanged file, so writing
///    the value that is already stored wakes nobody. The per-subscriber `lastSent` below is that
///    rule; it is per subscriber rather than global so a late collector still gets its first
///    value even when nothing has changed since the previous one arrived.
///  * **Backpressure that keeps the newest.** `.bufferingNewest(1)`: settings are state, not
///    events, so a slow consumer should see the current value, never a queue of stale ones.
///
/// `@unchecked Sendable` is earned, not assumed: every access to the two dictionaries goes
/// through `lock`, and `read` is `@Sendable`.
final class DefaultsValueStream<Value: Equatable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var lastSent: [UUID: Value] = [:]
    private let read: @Sendable () -> Value

    /// - Parameter read: recomputes the whole value from storage. Called under `lock`, so it must
    ///   not call back into this type.
    init(read: @escaping @Sendable () -> Value) {
        self.read = read
    }

    /// A new subscription, carrying the current value as its first element.
    func makeStream() -> AsyncStream<Value> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))

        // `NSObjectProtocol` is not `Sendable`, but the token is only ever handed back to
        // `NotificationCenter`, which is. `object: nil` rather than the specific `UserDefaults`
        // instance because a suite does not always name itself as the notification's object; a
        // wake-up caused by someone else's suite recomputes our value, finds it unchanged, and
        // emits nothing.
        nonisolated(unsafe) let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.publish()
        }

        continuation.onTermination = { [weak self] _ in
            NotificationCenter.default.removeObserver(observer)
            self?.forget(id)
        }

        lock.lock()
        continuations[id] = continuation
        let current = read()
        lastSent[id] = current
        continuation.yield(current)
        lock.unlock()

        return stream
    }

    /// Recomputes the value and hands it to every subscriber that has not already seen it.
    ///
    /// Called after each write and on every `UserDefaults` change notification.
    func publish() {
        lock.lock()
        defer { lock.unlock() }

        let value = read()
        for (id, continuation) in continuations where lastSent[id] != value {
            lastSent[id] = value
            continuation.yield(value)
        }
    }

    private func forget(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        continuations[id] = nil
        lastSent[id] = nil
    }
}

extension UserDefaults {
    /// `preferences[key] ?: fallback` for a boolean.
    ///
    /// `bool(forKey:)` answers `false` for a key that was never written, which happens to be the
    /// right answer for all four boolean settings — but only by coincidence, and the coincidence
    /// would break the day a default flips. `object(forKey:)` is what actually distinguishes
    /// "absent" from "stored false", so both readers go through it.
    func storedBool(forKey key: String, default fallback: Bool) -> Bool {
        object(forKey: key) == nil ? fallback : bool(forKey: key)
    }

    /// `preferences[key] ?: fallback` for an integer.
    ///
    /// Here the distinction is load-bearing: `integer(forKey:)` answers 0 for an absent key, so a
    /// user who has never opened the settings screen would read `cycleReminderMinuteOfDay == 0`
    /// and be reminded at midnight instead of at 09:00
    /// (`SalusPreferencesDataSource.kt:30-31`).
    func storedInt(forKey key: String, default fallback: Int) -> Int {
        object(forKey: key) == nil ? fallback : integer(forKey: key)
    }
}
