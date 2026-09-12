// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/EditorDateField.kt`.

import SalusUI
import SwiftUI

/// The editors' date row (`EditorDateField.kt:9-25`).
///
/// `SalusUI` owns the field and its picker; this wrapper only binds the module's own placeholder,
/// so all three editors keep one call site to change.
struct EditorDateField: View {
    let dateEpochDay: Int?
    let onDateSelected: (Int) -> Void

    var body: some View {
        SalusDateField(
            title: VitalsStrings.selectDate,
            epochDay: dateEpochDay,
            placeholder: VitalsStrings.selectDate,
            // Where the wheel opens before a day is set, Kotlin's `initialSelectedDateMillis`
            // slot. The ViewModel fills `dateEpochDay` at init on a new entry and from the loaded
            // entry otherwise, so the fallback only stands in for the window before a loaded entry
            // arrives — and seeding the wheel records nothing until it is turned.
            seedEpochDay: dateEpochDay ?? 0,
            onChange: onDateSelected
        )
    }
}
