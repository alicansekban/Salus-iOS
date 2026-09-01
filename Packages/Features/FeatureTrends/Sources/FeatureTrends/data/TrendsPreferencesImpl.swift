// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/data/TrendsPreferencesImpl.kt`.

import SalusModel
import SalusSettings

/// The only file in this feature that knows the preferences store exists
/// (`TrendsPreferencesImpl.kt:17-26`).
///
/// The narrowing carries its own dedupe because `DefaultsValueStream` is distinct-by-content over
/// the *whole* `UserSettings`: changing the theme — or any other setting — publishes a new value
/// whose glucose unit is the one before it, and without the dedupe every such change would redraw
/// a chart for a unit that did not move.
public struct TrendsPreferencesImpl: TrendsPreferences {
    private let dataSource: SalusPreferencesDataSource

    public init(dataSource: SalusPreferencesDataSource) {
        self.dataSource = dataSource
    }

    /// `TrendsPreferencesImpl.kt:20-25` — the whole `UserSettings` narrowed to the one field this
    /// feature reads, `distinctUntilChanged`.
    ///
    /// Rebuilt as an `AsyncStream` rather than mapped in place: `AsyncStream.map` answers an
    /// `AsyncMapSequence`, and the protocol promises the concrete type. `.bufferingNewest(1)`
    /// restates the conflation `DefaultsValueStream` already applies to the source.
    public var glucoseUnit: AsyncStream<GlucoseUnit> {
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
}
