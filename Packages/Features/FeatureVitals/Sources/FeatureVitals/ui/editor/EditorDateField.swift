// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/EditorDateField.kt`.
//
// Compose has no date field, so Kotlin builds one: an `OutlinedButton` showing the formatted date,
// which opens a `DatePickerDialog` whose OK button hands back `selectedDateMillis / MILLIS_PER_DAY`.
// SwiftUI ships `DatePicker`, which *is* that button plus its picker, so the dialog, its two
// buttons, `rememberDatePickerState` and `MILLIS_PER_DAY` all disappear into one view.
//
// The binding is the interesting part. `DatePicker` speaks `Date`, this state speaks `epochDay`,
// and turning one into the other is a calendar operation — which `CLAUDE.md` allows in exactly two
// places, neither of them here. So the picker is pinned to GMT instead: the `Date` it is handed is
// `epochDay × 86 400`, whose GMT components *are* the selected day, and the `Date` it hands back is
// divided by the same constant. No `Calendar` is constructed, the device's zone cannot shift the
// day by one, and the user still sees their own locale and calendar in the wheel.

import SalusModel
import SwiftUI

/// Shared editor date row (`EditorDateField.kt:24-73`).
struct EditorDateField: View {
    let dateEpochDay: Int?
    let onDateSelected: (Int) -> Void

    var body: some View {
        if let dateEpochDay {
            DatePicker(
                VitalsStrings.selectDate,
                selection: selection(for: dateEpochDay),
                displayedComponents: .date
            )
            .environment(\.timeZone, .gmt)
        } else {
            // The one frame before an existing entry has loaded. Kotlin's button shows the same
            // string for the same reason (`EditorDateField.kt:41-43`).
            Text(VitalsStrings.selectDate)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selection(for epochDay: Int) -> Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: Double(epochDay) * secondsPerDay) },
            set: { picked in
                onDateSelected(Int((picked.timeIntervalSince1970 / secondsPerDay).rounded(.down)))
            }
        )
    }
}

/// `EditorDateField.kt:22` — `MILLIS_PER_DAY`, in the unit `Date` counts.
private let secondsPerDay: Double = 86400

#Preview("Editor date field") {
    Form {
        EditorDateField(dateEpochDay: LocalDate(year: 2026, month: 8, day: 17).epochDay) { _ in }
        EditorDateField(dateEpochDay: nil) { _ in }
    }
}
