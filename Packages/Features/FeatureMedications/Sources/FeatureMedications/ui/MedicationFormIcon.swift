// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/MedicationFormatting.kt:23-33` (`MedicationForm.icon()`), in its M15 shape.
//
// It is its own file rather than a fourth helper in `MedicationFormatting.swift` for the reason
// that file's header gives: the formatting helpers must stay reachable from the reminder handler,
// which draws nothing, and a form-to-SF-Symbol table is a drawing decision. It is not private to
// `MedicationCard` either, because Kotlin's comment is the requirement — shared by the list card,
// the detail hero and the editor's form grid, so the three never drift apart.
//
// **M15 GAVE EVERY FORM ITS OWN GLYPH.** The editor's grid shows all eight at once, where the three
// repeated pills the pre-M15 table drew made the tiles unreadable (`MedicationFormatting.kt:20-22`).
// The Material pairs map onto the SF Symbols that stand for the same idea, and the one pair that
// carries meaning by weight rather than by shape keeps it: Kotlin's `Icons.Filled.Medication` /
// `Icons.Outlined.Medication` for tablet and capsule become `pills.fill` / `pills`.
//
// A `String`, not an `Image`: SF Symbols are named, so nothing here has to import SwiftUI and the
// table stays a value a test could read.

import SalusModel

extension MedicationForm {
    /// The SF Symbol that stands for this form (`MedicationFormatting.kt:23-33`).
    ///
    /// The cases are in the repo's alphabetical order (`.swiftformat`'s `sortSwitchCases`) rather
    /// than Kotlin's; the eight arms and what they answer are the same.
    var systemImage: String {
        switch self {
        // `Icons.Outlined.Medication` — the outlined twin of the tablet's filled pill.
        case .capsule: "pills"
        // `Icons.Filled.Spa`.
        case .cream: "leaf.fill"
        // `Icons.Filled.WaterDrop`.
        case .drop: "drop.fill"
        // `Icons.Filled.Air`.
        case .inhaler: "wind"
        // `Icons.Filled.Vaccines`.
        case .injection: "syringe"
        // `Icons.Filled.MoreHoriz`.
        case .other: "ellipsis"
        // `Icons.Outlined.LocalDrink`.
        case .syrup: "cup.and.saucer"
        // `Icons.Filled.Medication`.
        case .tablet: "pills.fill"
        }
    }
}
