// The Swift twin of the anonymous `object : TodayRepository` over a `MutableStateFlow<TodayOverview>`
// that `HomeViewModelTest.kt:57-59` declares inline.
//
// Kotlin gets replay-the-current-value for free: a `MutableStateFlow` hands every new collector the
// value it holds before it hands out any update. Swift's `AsyncThrowingStream` has no such
// behaviour, so the fake keeps the current overview under a lock and yields it to each new
// subscription at registration time. That replay is what makes ``HomeViewModel/restartObservation()``
// testable at all: a restart opens a *second* subscription, and without the replay it would wait for
// a mutation that the test never makes.
//
// The lock discipline is `FakeCycleRepository`'s, including its correction: the mutation happens
// under the lock, the observers are copied out under the same lock, and the yields happen after it
// is released — a continuation's `onTermination` takes the same lock, so publishing while holding it
// is a latent deadlock. The same residual window `FakeCycleRepository` documents applies here (a
// mutation landing between registration and the seed's yield leaves the collector one value stale
// under `bufferingNewest(1)`), and no test in this target can reach it: every case registers its
// observation — by constructing the ViewModel — before it mutates.

import Foundation

@testable import FeatureHome

/// An in-memory ``TodayRepository`` (`HomeViewModelTest.kt:57-59`).
///
/// `@unchecked Sendable` for `FakeCycleRepository`'s reason: the state is mutable, and the lock is
/// what makes the promise true.
final class FakeTodayRepository: TodayRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var overview: TodayOverview
    private var observers: [UUID: @Sendable (TodayOverview) -> Void] = [:]

    init(_ overview: TodayOverview) {
        self.overview = overview
    }

    /// The twin of reading `overview.value` (`HomeViewModelTest.kt:127`).
    var current: TodayOverview {
        lock.withLock { overview }
    }

    /// The twin of assigning to `overview.value` (`HomeViewModelTest.kt:127-129`).
    func set(_ newValue: TodayOverview) {
        let publishers = lock.withLock { () -> [@Sendable (TodayOverview) -> Void] in
            overview = newValue
            return Array(observers.values)
        }
        for publish in publishers {
            publish(newValue)
        }
    }

    /// `HomeViewModelTest.kt:58` — the current overview, then every later one.
    func observeTodayOverview() -> AsyncThrowingStream<TodayOverview, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            let snapshot = lock.withLock { () -> TodayOverview in
                observers[token] = { snapshot in continuation.yield(snapshot) }
                return overview
            }
            // Outside the lock, like every other publish in this file.
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }
}
