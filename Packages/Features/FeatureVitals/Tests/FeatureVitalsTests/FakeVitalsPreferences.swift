// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// FakeVitalsPreferences.kt`.
//
// Kotlin backs the fake with one `MutableStateFlow<GlucoseUnit>` and exposes it as the interface's
// `glucoseUnit` flow. Swift has no `StateFlow`, so the current unit lives behind a lock and every
// live observation is a callback fired on each change — `FakeCycleReminderSettings`' shape,
// including its correction: the lock is taken to apply the change and copy out the observers, then
// RELEASED, and only then is the new value published. Publishing under the lock would let a
// collector's `onTermination` reach back in.
//
// `setGlucoseUnit` is synchronous rather than `suspend`, and `glucoseUnit` is a non-throwing
// `AsyncStream`, because `VitalsPreferences` is — the two halves of recorded divergence (b),
// reasoned out in `CycleReminderSettings.swift` and restated in `VitalsPreferences.swift`.

import Foundation
import SalusModel

@testable import FeatureVitals

/// An in-memory `VitalsPreferences` for tests that must not reach `UserDefaults`
/// (`FakeVitalsPreferences.kt:8-21`).
///
/// `@unchecked Sendable` for `FakeVitalsRepository`'s reason: the state is mutable, and the lock is
/// what makes the promise true.
final class FakeVitalsPreferences: VitalsPreferences, @unchecked Sendable {
    private let lock = NSLock()
    private var unit: GlucoseUnit
    private var observers: [UUID: @Sendable (GlucoseUnit) -> Void] = [:]

    /// `FakeVitalsPreferences.kt:8-10` — the same default as `UserSettings.glucoseUnit`.
    init(initialUnit: GlucoseUnit = .mgDl) {
        unit = initialUnit
    }

    /// `FakeVitalsPreferences.kt:20` — the twin of reading `MutableStateFlow.value`.
    func currentUnit() -> GlucoseUnit {
        lock.withLock { unit }
    }

    /// `FakeVitalsPreferences.kt:14` — replays what the fake holds right now, then every later
    /// unit, exactly as a `MutableStateFlow` collector sees it.
    var glucoseUnit: AsyncStream<GlucoseUnit> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            let snapshot = lock.withLock {
                observers[token] = { unit in continuation.yield(unit) }
                return unit
            }
            // Outside the lock, like every other publish in this file.
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = observers.removeValue(forKey: token) }
            }
        }
    }

    /// `FakeVitalsPreferences.kt:16-18`. A `MutableStateFlow` drops an assignment equal to the
    /// value it already holds, and so does this — the fake therefore honours the same
    /// "equal consecutive units are dropped" contract `VitalsPreferencesImpl` does.
    func setGlucoseUnit(_ unit: GlucoseUnit) {
        let publishers = lock.withLock { () -> [@Sendable (GlucoseUnit) -> Void] in
            guard unit != self.unit else { return [] }
            self.unit = unit
            return Array(observers.values)
        }
        for publish in publishers {
            publish(unit)
        }
    }
}
