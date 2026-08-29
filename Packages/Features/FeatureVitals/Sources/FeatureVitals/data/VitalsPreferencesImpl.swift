// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// data/VitalsPreferencesImpl.kt`.
//
// Both halves of **recorded divergence (b)** land here; ``VitalsPreferences`` reasons them out and
// this file does not repeat it.
//
// The preference store stays behind this type: nothing in `domain/` or `ui/` imports
// `SalusSettings`, so the Android-verbatim `glucose_unit` key is named in exactly one place on this
// side of the port — `SettingsKeys`.

import SalusModel
import SalusSettings

/// The only implementation of ``VitalsPreferences`` (`VitalsPreferencesImpl.kt:10-20`).
///
/// A `final class` rather than a struct, matching the Kotlin: it is one long-lived collaborator the
/// composition root holds, not a value anything copies. Its single stored property is an immutable
/// `Sendable` reference, so the protocol's `Sendable` conformance is checked rather than promised.
final class VitalsPreferencesImpl: VitalsPreferences {
    private let dataSource: SalusPreferencesDataSource

    init(dataSource: SalusPreferencesDataSource) {
        self.dataSource = dataSource
    }

    /// `VitalsPreferencesImpl.kt:14-15` — the whole `UserSettings` narrowed to the one field this
    /// feature reads, `distinctUntilChanged`.
    ///
    /// **The dedupe is load-bearing and is Kotlin's**, which is where this parts company with
    /// `CycleReminderSettingsImpl`: `DefaultsValueStream` is distinct-by-content over the *whole*
    /// `UserSettings`, so changing the theme — or any other setting — publishes a new value whose
    /// glucose unit is the one before it. Without the narrowing's own dedupe every such change
    /// would re-run the glucose branch of the vitals screen, which recomputes a converted series
    /// and a chart for a unit that did not move.
    ///
    /// Rebuilt as an `AsyncStream` rather than mapped in place: `AsyncStream.map` answers an
    /// `AsyncMapSequence`, and the protocol promises the concrete type. `.bufferingNewest(1)` is
    /// the conflation `DefaultsValueStream` already applies to the source, restated because
    /// rebuilding the stream is what mapping it costs.
    var glucoseUnit: AsyncStream<GlucoseUnit> {
        let settings = dataSource.userSettings
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                var previous: GlucoseUnit?
                for await value in settings {
                    guard value.glucoseUnit != previous else { continue }
                    previous = value.glucoseUnit
                    continuation.yield(value.glucoseUnit)
                }
                continuation.finish()
            }
            // A consumer that stops reading must stop the underlying subscription too.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `VitalsPreferencesImpl.kt:17-19`.
    func setGlucoseUnit(_ unit: GlucoseUnit) {
        dataSource.setGlucoseUnit(unit)
    }
}
