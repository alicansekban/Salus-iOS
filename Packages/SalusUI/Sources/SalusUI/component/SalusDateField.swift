// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/EditorDateField.kt`, and moved here from `FeatureVitals` in iOS-M4 (recorded
// divergence (c)) so Appointments can use the same row rather than grow a second one.
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

/// Shared editor date row (`EditorDateField.kt:24-73`): a labelled wheel when a day is set,
/// `placeholder` before the first pick.
public struct SalusDateField: View {
    private let title: String
    private let epochDay: Int?
    private let placeholder: String
    private let onChange: (Int) -> Void

    /// - Parameters:
    ///   - title: the row's label, shown beside the wheel.
    ///   - epochDay: days since 1970-01-01; `nil` before the first pick.
    ///   - placeholder: what the row reads while `epochDay` is `nil` (`EditorDateField.kt:41-43`).
    public init(
        title: String,
        epochDay: Int?,
        placeholder: String,
        onChange: @escaping (Int) -> Void
    ) {
        self.title = title
        self.epochDay = epochDay
        self.placeholder = placeholder
        self.onChange = onChange
    }

    public var body: some View {
        if let epochDay {
            DatePicker(
                title,
                selection: selection(for: epochDay),
                displayedComponents: .date
            )
            .environment(\.timeZone, .gmt)
        } else {
            // Before an existing entry has loaded, or before the first pick on a new one. Kotlin's
            // button shows the same string for the same reason (`EditorDateField.kt:41-43`).
            Text(placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selection(for epochDay: Int) -> Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: Double(epochDay) * secondsPerDay) },
            set: { picked in
                onChange(Int((picked.timeIntervalSince1970 / secondsPerDay).rounded(.down)))
            }
        )
    }
}

/// `EditorDateField.kt:22` — `MILLIS_PER_DAY`, in the unit `Date` counts.
private let secondsPerDay: Double = 86400

#Preview("Editor date field") {
    Form {
        SalusDateField(
            title: "Date",
            epochDay: LocalDate(year: 2026, month: 8, day: 17).epochDay,
            placeholder: "Select date",
            onChange: { _ in }
        )
        SalusDateField(title: "Date", epochDay: nil, placeholder: "Select date", onChange: { _ in })
    }
}
