// The time-of-day twin of `SalusDateField`, ported from the picker Kotlin builds by hand in
// `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/ui/editor/
// AppointmentEditorScreen.kt:264-297, 362-394`: an `OutlinedButton` showing the formatted time,
// which opens a `TimePickerDialog` whose OK button hands back
// `timePickerState.hour * MINUTES_PER_HOUR + timePickerState.minute`. SwiftUI's `DatePicker` *is*
// that button plus its picker, so the dialog, its two buttons and `rememberTimePickerState` all
// disappear into one view, exactly as they do in `SalusDateField`.
//
// The binding uses the same GMT pin as `SalusDateField`, for the same reason: `DatePicker` speaks
// `Date`, this state speaks a minute-of-day integer, and bridging the two is a calendar operation
// that `CLAUDE.md` allows in exactly two places, neither of them here. Pinned to GMT, the `Date`
// handed in is `minuteOfDay × 60` — whose GMT clock reading *is* the selected time — and the `Date`
// handed back is divided by the same constant. No `Calendar` is constructed, the device's zone
// cannot shift the reading by an hour, and the user still sees their own locale's clock in the wheel.

import SwiftUI

/// Editor time row: a labelled wheel when a time is set, `placeholder` before the first pick.
public struct SalusTimeField: View {
    private let title: String
    private let minuteOfDay: Int?
    private let placeholder: String
    private let onChange: (Int) -> Void

    /// - Parameters:
    ///   - title: the row's label, shown beside the wheel.
    ///   - minuteOfDay: minutes since local midnight, `0 ..< 1440`; `nil` before the first pick.
    ///   - placeholder: what the row reads while `minuteOfDay` is `nil`
    ///     (`AppointmentEditorScreen.kt:283` — `appointments_select_time`).
    public init(
        title: String,
        minuteOfDay: Int?,
        placeholder: String,
        onChange: @escaping (Int) -> Void
    ) {
        self.title = title
        self.minuteOfDay = minuteOfDay
        self.placeholder = placeholder
        self.onChange = onChange
    }

    public var body: some View {
        if let minuteOfDay {
            DatePicker(
                title,
                selection: selection(for: minuteOfDay),
                displayedComponents: .hourAndMinute
            )
            .environment(\.timeZone, .gmt)
        } else {
            // Kotlin's button shows the same string for the same reason
            // (`AppointmentEditorScreen.kt:281-286`).
            Text(placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selection(for minuteOfDay: Int) -> Binding<Date> {
        Binding(
            get: { SalusTimeFieldBinding.date(minuteOfDay: minuteOfDay) },
            set: { picked in onChange(SalusTimeFieldBinding.minuteOfDay(from: picked)) }
        )
    }
}

/// The `minuteOfDay` ↔ `Date` arithmetic behind ``SalusTimeField``, lifted out of the view so it
/// can be tested without SwiftUI.
enum SalusTimeFieldBinding {
    /// The unit `Date` counts, against the minutes Kotlin counts
    /// (`AppointmentEditorScreen.kt:377` — `hour * MINUTES_PER_HOUR + minute`).
    private static let secondsPerMinute = 60
    /// Kotlin never spells this out because `TimePicker` cannot leave the day; the GMT pin can,
    /// so the wrap is explicit here.
    private static let minutesPerDay = 1440

    /// The GMT instant whose clock reading is `minuteOfDay`.
    static func date(minuteOfDay: Int) -> Date {
        Date(timeIntervalSince1970: Double(minuteOfDay * secondsPerMinute))
    }

    /// The clock reading of `date` in GMT, as minutes since midnight — always `0 ..< 1440`.
    static func minuteOfDay(from date: Date) -> Int {
        let minutes = Int((date.timeIntervalSince1970 / Double(secondsPerMinute)).rounded(.down))
        // Swift's `%` keeps the sign of the dividend, and a wheel seeded before the epoch would
        // otherwise report a negative minute, which is not a time of day.
        return ((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay
    }
}

#Preview("Editor time field") {
    Form {
        SalusTimeField(
            title: "Time",
            minuteOfDay: 14 * 60 + 30,
            placeholder: "Select time",
            onChange: { _ in }
        )
        SalusTimeField(title: "Time", minuteOfDay: nil, placeholder: "Select time", onChange: { _ in })
    }
}
