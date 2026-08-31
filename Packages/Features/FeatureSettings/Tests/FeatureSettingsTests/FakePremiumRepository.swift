// A ``PremiumRepository`` a test can flip between `PremiumStatus` values, for `MoreViewModelTests`
// (T7). The real `PremiumRepositoryImpl` reads the store; the fake is the only way a ViewModel test
// exercises the entitled branches (`.premium`/`.gracePeriod`) without a store.
//
// `@unchecked Sendable` over a lock rather than an actor for the same reason
// `FakeSettingsPreferences.swift` is: the protocol's stream is not `@MainActor`-isolated.

import Foundation
import SalusPremium

/// A ``PremiumRepository`` whose status a test sets and re-emits on demand.
final class FakePremiumRepository: PremiumRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var value: PremiumStatus
    private var continuations: [UUID: AsyncStream<PremiumStatus>.Continuation] = [:]

    init(value: PremiumStatus = .free) {
        self.value = value
    }

    var status: AsyncStream<PremiumStatus> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = value
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    func refresh() async {}

    /// Flips the value and pushes it to every open stream.
    func setValue(_ newValue: PremiumStatus) {
        lock.lock()
        value = newValue
        let pending = Array(continuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(newValue)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
