// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// domain/repository/VitalsPreferences.kt`.
//
// **Recorded divergence (b)**, the same one `CycleReminderSettings.swift` reasons out, for the same
// store underneath:
//
//  1. `glucoseUnit` is a non-throwing `AsyncStream`, not `AsyncThrowingStream`. Android's DataStore
//     `Flow` can fail on an IO error; the iOS side reads `UserDefaults` through `SalusSettings`'
//     `DefaultsValueStream`, which cannot.
//  2. `setGlucoseUnit` is synchronous. Kotlin's is `suspend` because DataStore's `edit` is;
//     `UserDefaults.set` is not, and the whole `SalusPreferencesDataSource` surface already is.
//
// Note what is *not* a divergence: unlike `CycleReminderSettings`, this stream **drops equal
// consecutive units** — Kotlin has an explicit `distinctUntilChanged` here
// (`VitalsPreferencesImpl.kt:14-15`) and the cycle twin deliberately has none.

import SalusModel

/// The unit blood glucose is *displayed* in, as the feature's domain sees it
/// (`VitalsPreferences.kt:7-12`).
///
/// It is a preference rather than a per-reading field: storage is always mg/dL, and this decides
/// only how a stored reading is written out. The glucose editor's segmented control is the one
/// place it is chosen — there is no toggle on the list screen and none in Settings — so the editor
/// writes it app-wide.
public protocol VitalsPreferences: Sendable {
    /// `VitalsPreferences.kt:9` — the stored unit, then every later one, with equal consecutive
    /// values dropped.
    var glucoseUnit: AsyncStream<GlucoseUnit> { get }

    /// `VitalsPreferences.kt:11`.
    func setGlucoseUnit(_ unit: GlucoseUnit)
}
