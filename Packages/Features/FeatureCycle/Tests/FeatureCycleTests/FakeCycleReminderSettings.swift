// Ported 1:1 from `feature/cycle/src/test/kotlin/com/alicansekban/salus/feature/cycle/
// FakeCycleReminderSettings.kt`.
//
// Kotlin backs the fake with one `MutableStateFlow<CycleReminderConfig>` and exposes it as the
// interface's `config` flow; the three setters are `update { it.copy(...) }`. Swift has no
// `StateFlow`, so the current value lives behind a lock and every live observation is a callback
// fired on each mutation — `FakeCycleRepository`'s shape, including its correction: the lock is
// taken to apply the change and copy out the observers, then RELEASED, and only then is the new
// value yielded. Publishing under the lock would let a collector's `onTermination` reach back in.
//
// The setters are synchronous rather than `suspend`, because `CycleReminderSettings` is, and
// `config` is a non-throwing `AsyncStream` for the same reason — the two halves of recorded
// divergence (b), reasoned out in `CycleReminderSettings.swift`.

import Foundation

@testable import FeatureCycle

/// An in-memory `CycleReminderSettings` for tests that must not reach `UserDefaults`
/// (`FakeCycleReminderSettings.kt:9-32`).
///
/// `@unchecked Sendable` for `FakeCycleRepository`'s reason: the state is mutable, and the lock is
/// what makes the promise true.
final class FakeCycleReminderSettings: CycleReminderSettings, @unchecked Sendable {
    private let lock = NSLock()
    private var value: CycleReminderConfig
    private var observers: [UUID: @Sendable (CycleReminderConfig) -> Void] = [:]

    /// `FakeCycleReminderSettings.kt:10-14` — the same default triple: off, one day of lead, 09:00.
    init(
        initial: CycleReminderConfig = CycleReminderConfig(
            enabled: false,
            leadDays: 1,
            minuteOfDay: 9 * 60
        )
    ) {
        value = initial
    }

    /// The twin of reading `configFlow.value` (`FakeCycleReminderSettings.kt:17`).
    var currentConfig: CycleReminderConfig {
        lock.withLock { value }
    }

    /// `FakeCycleReminderSettings.kt:19` — replays what the fake holds right now, then every
    /// later value, exactly as a `MutableStateFlow` collector sees it.
    var config: AsyncStream<CycleReminderConfig> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            let snapshot = lock.withLock {
                observers[token] = { config in continuation.yield(config) }
                return value
            }
            // Outside the lock, like every other publish in this file.
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// `FakeCycleReminderSettings.kt:21-23`.
    func setEnabled(_ enabled: Bool) {
        mutate { config in
            CycleReminderConfig(
                enabled: enabled,
                leadDays: config.leadDays,
                minuteOfDay: config.minuteOfDay
            )
        }
    }

    /// `FakeCycleReminderSettings.kt:25-27`.
    func setLeadDays(_ days: Int) {
        mutate { config in
            CycleReminderConfig(
                enabled: config.enabled,
                leadDays: days,
                minuteOfDay: config.minuteOfDay
            )
        }
    }

    /// `FakeCycleReminderSettings.kt:29-31`.
    func setMinuteOfDay(_ minuteOfDay: Int) {
        mutate { config in
            CycleReminderConfig(
                enabled: config.enabled,
                leadDays: config.leadDays,
                minuteOfDay: minuteOfDay
            )
        }
    }

    /// The twin of `MutableStateFlow.update`, minus the deadlock a collector could otherwise
    /// reach back into: mutate under the lock, publish after releasing it.
    private func mutate(_ change: (CycleReminderConfig) -> CycleReminderConfig) {
        let (snapshot, publishers) = lock
            .withLock { () -> (CycleReminderConfig, [@Sendable (CycleReminderConfig) -> Void]) in
                value = change(value)
                return (value, Array(observers.values))
            }
        for publish in publishers {
            publish(snapshot)
        }
    }
}
