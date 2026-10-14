// Koin's `getAll<SmokingChangeListener>()` has no counterpart without a container; this is the
// registry the composition root hands to the store. Listeners are read on every write, not
// captured at construction, so one registered later (the reminder resync, plan Task 17) is still
// told and no use case changes.

import Foundation

public final class SmokingChangeListeners: @unchecked Sendable {
    private let lock = NSLock()
    private var listeners: [any SmokingChangeListener] = []

    public init() {}

    public func add(_ listener: any SmokingChangeListener) {
        lock.withLock { listeners.append(listener) }
    }

    /// Tells every listener, outside the lock: a listener that registers another, or writes again,
    /// must not deadlock on it.
    func notifyAll() {
        let current = lock.withLock { listeners }
        for listener in current {
            listener.smokingDataChanged()
        }
    }
}
