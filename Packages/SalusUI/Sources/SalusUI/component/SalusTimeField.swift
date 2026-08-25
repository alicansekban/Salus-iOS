// The time-of-day twin of `SalusDateField`, ported from the picker Kotlin builds by hand in
// `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/ui/editor/
// AppointmentEditorScreen.kt:264-297, 362-394`: an `OutlinedButton` showing the formatted time,
// which opens a `TimePickerDialog` whose OK button hands back
// `timePickerState.hour * MINUTES_PER_HOUR + timePickerState.minute`. SwiftUI's `DatePicker` *is*
// that button plus its picker, so the dialog and its two buttons disappear into one control:
//
//   * nothing picked yet → the button, which is Kotlin's `OutlinedButton` showing
//     `appointments_select_time`;
//   * tapped → the wheel, seeded at `seedMinuteOfDay` exactly as
//     `rememberTimePickerState(initialHour = initialMinuteOfDay?.div(60) ?: 9, …)` seeds the dialog
//     (`AppointmentEditorScreen.kt:367-370`);
//   * moved → `onChange`, which is Kotlin's OK button. **The tap alone commits nothing**: a state
//     that stays nil is Kotlin's Cancel, and the form's "pick a date and time" error still fires,
//     which is the whole reason the seed lives on the wheel and not in the callback.
//   * a value arrives → the field binds to it directly, and the seed is never consulted again.
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
    private let seedMinuteOfDay: Int
    private let onChange: (Int) -> Void

    /// Whether the placeholder button has been tapped. Presentation state, not editor state: the
    /// twin of `showTimePicker` in `AppointmentEditorScreen.kt:105`, which Compose also keeps in the
    /// screen rather than in the ViewModel.
    @State private var isPicking = false
    /// What the wheel shows while picking, or nil while it still shows the seed. Every write is a
    /// user gesture, which is what makes it safe to treat as the OK button.
    @State private var draft: Date?

    /// - Parameters:
    ///   - title: the row's label, read by VoiceOver; callers that draw the row in a narrow column
    ///     hide it with `.labelsHidden()`.
    ///   - minuteOfDay: minutes since local midnight, `0 ..< 1440`; `nil` before the first pick.
    ///   - placeholder: what the row reads while `minuteOfDay` is `nil`
    ///     (`AppointmentEditorScreen.kt:283` — `appointments_select_time`).
    ///   - seedMinuteOfDay: where the wheel opens when nothing is picked yet — Kotlin's
    ///     `initialHour = … ?: 9` (`AppointmentEditorScreen.kt:368-369`). Required, and deliberately
    ///     without a default: a wheel has to start somewhere, and only the caller knows where.
    public init(
        title: String,
        minuteOfDay: Int?,
        placeholder: String,
        seedMinuteOfDay: Int,
        onChange: @escaping (Int) -> Void
    ) {
        self.title = title
        self.minuteOfDay = minuteOfDay
        self.placeholder = placeholder
        self.seedMinuteOfDay = seedMinuteOfDay
        self.onChange = onChange
    }

    public var body: some View {
        switch SalusTimeFieldState.displayMode(
            minuteOfDay: minuteOfDay,
            isPicking: isPicking,
            seedMinuteOfDay: seedMinuteOfDay
        ) {
        case .placeholder:
            // Kotlin's `OutlinedButton { Text(appointments_select_time) }`
            // (`AppointmentEditorScreen.kt:281-286`). Opening the picker is all it does.
            Button(placeholder) { isPicking = true }
                .buttonStyle(.bordered)

        case let .picker(seed):
            DatePicker(title, selection: draftSelection(seededAt: seed), displayedComponents: .hourAndMinute)
                .environment(\.timeZone, .gmt)
                // The OK button (`AppointmentEditorScreen.kt:373-380`): the value leaves this view
                // when the wheel moves, and never merely because it was opened.
                .onChange(of: draft) { _, picked in
                    guard let picked else { return }
                    onChange(SalusTimeFieldBinding.minuteOfDay(from: picked))
                }

        case let .bound(minuteOfDay):
            DatePicker(title, selection: selection(for: minuteOfDay), displayedComponents: .hourAndMinute)
                .environment(\.timeZone, .gmt)
        }
    }

    /// The wheel before it has been moved: it shows the seed, and the first turn is what records a
    /// choice.
    private func draftSelection(seededAt seed: Int) -> Binding<Date> {
        Binding(
            get: { draft ?? SalusTimeFieldBinding.date(minuteOfDay: seed) },
            set: { picked in draft = picked }
        )
    }

    private func selection(for minuteOfDay: Int) -> Binding<Date> {
        Binding(
            get: { SalusTimeFieldBinding.date(minuteOfDay: minuteOfDay) },
            set: { picked in onChange(SalusTimeFieldBinding.minuteOfDay(from: picked)) }
        )
    }
}

/// Which of ``SalusTimeField``'s three faces to draw, lifted out of the view so the decision can be
/// tested without SwiftUI.
enum SalusTimeFieldState {
    enum DisplayMode: Equatable {
        /// Nothing picked and the picker not open: Kotlin's closed dialog behind its button.
        case placeholder
        /// The open dialog, its wheel at `seed`.
        case picker(seed: Int)
        /// A time has been chosen; the field is the wheel, bound to it.
        case bound(minuteOfDay: Int)
    }

    /// A chosen time always wins: once the editor holds one, reopening the picker is meaningless,
    /// which is why `isPicking` is only ever consulted while `minuteOfDay` is nil.
    static func displayMode(minuteOfDay: Int?, isPicking: Bool, seedMinuteOfDay: Int) -> DisplayMode {
        if let minuteOfDay {
            return .bound(minuteOfDay: minuteOfDay)
        }
        return isPicking ? .picker(seed: seedMinuteOfDay) : .placeholder
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
            seedMinuteOfDay: 9 * 60,
            onChange: { _ in }
        )
        SalusTimeField(
            title: "Time",
            minuteOfDay: nil,
            placeholder: "Select time",
            seedMinuteOfDay: 9 * 60,
            onChange: { _ in }
        )
    }
}
