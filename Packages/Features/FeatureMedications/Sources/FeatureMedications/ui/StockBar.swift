// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/MedicationFormatting.kt:133-147` (`object StockBar`), added by Android M15.
//
// Its own file rather than a member of `MedicationFormatting.swift` for that file's reason: the
// formatting helpers stay reachable from the reminder handler, which draws nothing, and a
// `SalusProgressBar.Tone` arrives with `SalusUI`.
//
// Kotlin's `Float` is a `Double` here, because `SalusProgressBar` takes a `Double` — the same
// widening every ported progress value in this port makes.

import SalusUI

/// The one stock rule, shared by the list card and the detail screen so the two bars can never
/// disagree (`MedicationFormatting.kt:133-138`).
///
/// A full bar is three thresholds' worth of stock — the threshold is the point the user chose to be
/// warned at, so it is what the scale is built from rather than an invented maximum. There is no bar
/// at all without a threshold: nil means the user never said what "low" is, which is why both
/// members take a non-optional one and the caller returns early instead.
enum StockBar {
    /// A third of the bar is one threshold, and the bar stops at full
    /// (`MedicationFormatting.kt:139-141`).
    static func fill(remaining: Double, threshold: Double) -> Double {
        min(1.0, remaining / (StockBarDefaults.thresholds * threshold))
    }

    /// `MedicationFormatting.kt:143-144`.
    static func tone(remaining: Double, threshold: Double) -> SalusProgressBar.Tone {
        remaining <= threshold ? .rose : .primary
    }
}

/// Kotlin's `private const val STOCK_BAR_THRESHOLDS` (`MedicationFormatting.kt:146`). A scale
/// factor, not a design token — Android keeps it beside the rule too.
private enum StockBarDefaults {
    static let thresholds = 3.0
}
