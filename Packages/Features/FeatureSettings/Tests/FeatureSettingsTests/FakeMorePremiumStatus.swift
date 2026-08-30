// A ``MorePremiumStatus`` a test can flip from `.free` to `.entitled`, for `MoreViewModelTests`
// (T4). The production stand-in `FreeOnlyMorePremiumStatus` always emits `.free`; the fake is the
// only way a ViewModel test exercises the entitled branch before iOS-M9.
//
// `@unchecked Sendable` over a lock rather than an actor for the same reason
// `FakeSettingsPreferences.swift` is: the protocol's stream is not `@MainActor`-isolated.

import Foundation

@testable import FeatureSettings

/// A ``MorePremiumStatus`` whose value a test sets and re-emits on demand.
final class FakeMorePremiumStatus: MorePremiumStatus, @unchecked Sendable {
    private let lock = NSLock()
    private var value: MorePremiumStatusValue
    private var continuations: [UUID: AsyncStream<MorePremiumStatusValue>.Continuation] = [:]

    init(value: MorePremiumStatusValue = .free) {
        self.value = value
    }

    var status: AsyncStream<MorePremiumStatusValue> {
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

    /// Flips the value and pushes it to every open stream.
    func setValue(_ newValue: MorePremiumStatusValue) {
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
