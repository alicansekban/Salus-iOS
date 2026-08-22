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
///    observed below. The data sources *also* call `publish()` by hand after each of their own
///    writes, because the notification only covers `UserDefaults`: the app-lock flag lives in the
///    Keychain and posts nothing at all, and a stream that depended on a platform notification
///    for its correctness would be one SDK change away from going silent. Both paths end in the
///    same recompute, so a doubled wake-up costs a read, not a duplicate element.
///  * **Distinct by content.** `DataStore.data` does not re-emit an unchanged file, so writing
///    the value that is already stored wakes nobody. The per-subscriber `lastSent` below is that
///    rule; it is per subscriber rather than global so a late collector still gets its first
///    value even when nothing has changed since the previous one arrived.
///  * **Backpressure that keeps the newest.** `.bufferingNewest(1)`: settings are state, not
///    events, so a slow consumer should see the current value, never a queue of stale ones.
///  * **One emission per logical write.** `DataStore.edit` is one transaction however many keys
///    it touches. `UserDefaults` posts `didChangeNotification` *synchronously, from inside
///    `set`*, so a two-key write publishes the half-written state in between. `batched(_:)` is
///    that missing transaction — see its own comment.
///
/// `@unchecked Sendable` is earned, not assumed: every access to the two dictionaries goes
/// through `lock`, the batch depth through `batchLock`, and `read` is `@Sendable`.
final class DefaultsValueStream<Value: Equatable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    private var lastSent: [UUID: Value] = [:]
    private let read: @Sendable () -> Value
    private let defaults: UserDefaults

    /// Guards `batchDepth` alone, and is never held across anything but a few instructions.
    /// A second lock rather than reusing `lock`: the notification that `batched(_:)` has to
    /// swallow is delivered *synchronously on the batching thread*, so a single non-recursive
    /// lock held for the duration of a batch would deadlock against itself the moment
    /// `UserDefaults.set` posted.
    private let batchLock = NSLock()
    private var batchDepth = 0

    /// - Parameters:
    ///   - defaults: the store to observe. Scoping the observer to this instance is exact —
    ///     `didChangeNotification` names the `UserDefaults` object it came from, suites included.
    ///   - read: recomputes the whole value from storage. Called under `lock`, so it must not
    ///     call back into this type.
    init(defaults: UserDefaults, read: @escaping @Sendable () -> Value) {
        self.defaults = defaults
        self.read = read
    }

    /// A new subscription, carrying the current value as its first element.
    func makeStream() -> AsyncStream<Value> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))

        // `NSObjectProtocol` is not `Sendable`, but the token is only ever handed back to
        // `NotificationCenter`, which is.
        nonisolated(unsafe) let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
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

    /// Runs `body` as one logical write: nothing is published while it is in flight, and exactly
    /// one `publish()` follows it.
    ///
    /// The iOS stand-in for `DataStore.edit`'s atomicity *towards readers*
    /// (`AiUsageDataSource.kt:106-114`). Without it, `recordCall`'s two `set` calls each post
    /// `didChangeNotification` synchronously and the observer publishes the state between them —
    /// on a day rollover that is tomorrow's date carrying today's spent count, which
    /// `AiUsage.callsOn` reads as an exhausted quota on a fresh day.
    ///
    /// Suppression is per object, not per thread, so a concurrent write on another thread can
    /// have its own publish swallowed. Nothing is lost by it: `publish()` recomputes from
    /// storage, and the depth is dropped *before* the trailing publish, so any write that landed
    /// during the batch is either included in that recompute or publishes for itself afterwards.
    func batched(_ body: () -> Void) {
        batchLock.lock()
        batchDepth += 1
        batchLock.unlock()

        defer {
            batchLock.lock()
            batchDepth -= 1
            batchLock.unlock()

            publish()
        }

        body()
    }

    /// Recomputes the value and hands it to every subscriber that has not already seen it.
    ///
    /// Called after each write and on every `UserDefaults` change notification.
    func publish() {
        batchLock.lock()
        let suppressed = batchDepth > 0
        batchLock.unlock()
        guard !suppressed else { return }

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
