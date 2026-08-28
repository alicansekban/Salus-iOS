// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/MedicationFormatting.kt:24-34` (`MedicationForm.labelRes()`).
//
// The second of the two helpers `MedicationFormatting.swift`'s header defers to the screens that
// draw them, and it lands for the same reason `MedicationFormIcon.swift` did: the formatting file
// must stay reachable from the reminder handler, which draws nothing and resolves no label.
//
// It is its own file rather than a second member of `MedicationFormIcon.swift` so the two tables
// stay one decision each — and because Kotlin's `labelRes()` is shared by the detail header
// (iOS-M5 Task 11) and the editor's form picker (Task 12), which is exactly why it is not private
// to either screen.
//
// A resolved `String`, not a key: a Swift accessor on ``MedicationsStrings`` already *is* the
// resolved string, so there is nothing for a `stringResource` call site to do with a raw value.

import SalusModel

extension MedicationForm {
    /// This form's display name (`MedicationFormatting.kt:24-34`).
    ///
    /// The cases are in the repo's alphabetical order (`.swiftformat`'s `sortSwitchCases`) rather
    /// than Kotlin's declaration order; the eight arms and what they answer are the same.
    var label: String {
        switch self {
        case .capsule: MedicationsStrings.formCapsule
        case .cream: MedicationsStrings.formCream
        case .drop: MedicationsStrings.formDrop
        case .inhaler: MedicationsStrings.formInhaler
        case .injection: MedicationsStrings.formInjection
        case .other: MedicationsStrings.formOther
        case .syrup: MedicationsStrings.formSyrup
        case .tablet: MedicationsStrings.formTablet
        }
    }
}
