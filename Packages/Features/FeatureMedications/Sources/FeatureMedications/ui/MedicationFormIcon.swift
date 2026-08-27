// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/MedicationFormatting.kt:18-22` (`MedicationForm.icon()`).
//
// It is its own file rather than a fourth helper in `MedicationFormatting.swift` for the reason
// that file's header gives: the formatting helpers must stay reachable from the reminder handler,
// which draws nothing, and a form-to-SF-Symbol table is a drawing decision. It is not private to
// `MedicationCard` either, because Kotlin's comment is the requirement — "shared by the list card
// and the detail header so the two never drift apart" — and the detail header arrives in iOS-M5
// Task 11.
//
// A `String`, not an `Image`: SF Symbols are named, so nothing here has to import SwiftUI and the
// table stays a value a test could read. The three Material icons map to the three symbols the
// system ships for the same idea — `Vaccines` → `syringe`, `WaterDrop` → `drop`, `Medication` →
// `pills`.

import SalusModel

extension MedicationForm {
    /// The SF Symbol that stands for this form (`MedicationFormatting.kt:18-22`).
    ///
    /// The cases are in the repo's alphabetical order (`.swiftformat`'s `sortSwitchCases`) rather
    /// than Kotlin's; the three arms and what they answer are the same.
    var systemImage: String {
        switch self {
        case .drop, .syrup: "drop"
        case .injection: "syringe"
        default: "pills"
        }
    }
}
