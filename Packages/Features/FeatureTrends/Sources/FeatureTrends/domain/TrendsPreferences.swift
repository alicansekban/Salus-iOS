// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/domain/TrendsPreferences.kt`.

import SalusModel

/// Feature-facing abstraction over the global user preferences the trends screen needs
/// (`TrendsPreferences.kt:11-19`).
///
/// Read-only, and one field wide: this screen shows numbers, it never changes how they are
/// stored. The unit is a *display* choice — glucose stays canonical mg/dL through the reader,
/// the analyses and `TrendsData`, and is converted once at the UI edge — so nothing behind this
/// interface ever sees it.
public protocol TrendsPreferences: Sendable {
    /// `TrendsPreferences.kt:15` — the stored unit, then every later one.
    var glucoseUnit: AsyncStream<GlucoseUnit> { get }
}
