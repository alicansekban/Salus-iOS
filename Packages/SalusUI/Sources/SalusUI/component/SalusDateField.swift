// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/editor/EditorDateField.kt`, and moved here from `FeatureVitals` in iOS-M4 (recorded
// divergence (c)) so Appointments can use the same row rather than grow a second one.
//
// Compose has no date field, so Kotlin builds one: an `OutlinedButton` showing the formatted date,
// which opens a `DatePickerDialog` whose OK button hands back `selectedDateMillis / MILLIS_PER_DAY`.
// SwiftUI ships `DatePicker`, which *is* that button plus its picker, so the dialog, its two
// buttons, `rememberDatePickerState` and `MILLIS_PER_DAY` all disappear into one view — the same
// collapse `SalusTimeField` documents, and the two rows draw the same three faces:
//
//   * nothing picked yet → the button, which is Kotlin's `OutlinedButton` showing
//     `vitals_select_date` / `appointments_select_date` (`EditorDateField.kt:35-44`);
//   * tapped → the wheel, seeded at `seedEpochDay` where Kotlin passes
//     `initialSelectedDateMillis = dateEpochDay?.let { it * MILLIS_PER_DAY }`
//     (`EditorDateField.kt:47-49`) and lets Material open on the current month when that is null;
//   * moved → `onChange`, which is Kotlin's OK button. **The tap alone commits nothing**: a state
//     that stays nil is Kotlin's Cancel, which is why the seed lives on the wheel and never in the
//     callback.
//   * a value arrives → the field binds to it directly, and the seed is never consulted again.
//
// The binding is the other interesting part. `DatePicker` speaks `Date`, this state speaks
// `epochDay`, and turning one into the other is a calendar operation — which `CLAUDE.md` allows in
// exactly two places, neither of them here. So the picker is pinned to GMT instead: the `Date` it is
// handed is `epochDay × 86 400`, whose GMT components *are* the selected day, and the `Date` it
// hands back is divided by the same constant. No `Calendar` is constructed, the device's zone
// cannot shift the day by one, and the user still sees their own locale and calendar in the wheel.

import SalusModel
import SwiftUI

/// Shared editor date row (`EditorDateField.kt:24-73`): a labelled wheel when a day is set,
/// a `placeholder` button that opens the seeded wheel before the first pick.
public struct SalusDateField: View {
    private let title: String
    private let epochDay: Int?
    private let placeholder: String
    private let seedEpochDay: Int
    private let onChange: (Int) -> Void

    /// Whether the placeholder button has been tapped. Presentation state, not editor state: the
    /// twin of `showDatePicker` in `EditorDateField.kt:32`, which Compose also keeps in the row
    /// rather than in the ViewModel.
    @State private var isPicking = false
    /// What the wheel shows while picking, or nil while it still shows the seed. Every write is a
    /// user gesture, which is what makes it safe to treat as the OK button.
    @State private var draft: Date?

    /// - Parameters:
    ///   - title: the row's label, shown beside the wheel and read by VoiceOver; callers that draw
    ///     the row in a narrow column hide it with `.labelsHidden()`.
    ///   - epochDay: days since 1970-01-01; `nil` before the first pick.
    ///   - placeholder: what the row reads while `epochDay` is `nil` (`EditorDateField.kt:41-43`).
    ///   - seedEpochDay: where the wheel opens when nothing is picked yet — the slot Kotlin fills
    ///     with `initialSelectedDateMillis` (`EditorDateField.kt:48`). Required, and deliberately
    ///     without a default: a wheel has to start somewhere, and only the caller knows where.
    public init(
        title: String,
        epochDay: Int?,
        placeholder: String,
        seedEpochDay: Int,
        onChange: @escaping (Int) -> Void
    ) {
        self.title = title
        self.epochDay = epochDay
        self.placeholder = placeholder
        self.seedEpochDay = seedEpochDay
        self.onChange = onChange
    }

    public var body: some View {
        Group {
            switch SalusDateFieldState.displayMode(
                epochDay: epochDay,
                isPicking: isPicking,
                seedEpochDay: seedEpochDay
            ) {
            case .placeholder:
                // Kotlin's `OutlinedButton { Text(vitals_select_date) }`
                // (`EditorDateField.kt:35-44`). Opening the picker is all it does.
                Button(placeholder) { isPicking = true }
                    .buttonStyle(.bordered)

            case let .picker(seed):
                DatePicker(title, selection: draftSelection(seededAt: seed), displayedComponents: .date)
                    .environment(\.timeZone, .gmt)
                    // The OK button (`EditorDateField.kt:52-61`): the value leaves this view when
                    // the wheel moves, and never merely because it was opened.
                    .onChange(of: draft) { _, picked in
                        guard let picked else { return }
                        onChange(SalusDateFieldBinding.epochDay(from: picked))
                    }

            case let .bound(epochDay):
                DatePicker(title, selection: selection(for: epochDay), displayedComponents: .date)
                    .environment(\.timeZone, .gmt)
            }
        }
        // A caller that clears the day is starting over, so the picker closes and its draft goes
        // with it: without this, the next tap would resume at the day the last picker left behind
        // instead of at the seed.
        .onChange(of: epochDay) { _, value in
            guard SalusDateFieldState.clearsPicker(whenValueBecomes: value) else { return }
            isPicking = false
            draft = nil
        }
    }

    /// The wheel before it has been moved: it shows the seed, and the first turn is what records a
    /// choice.
    private func draftSelection(seededAt seed: Int) -> Binding<Date> {
        Binding(
            get: { draft ?? SalusDateFieldBinding.date(epochDay: seed) },
            set: { picked in draft = picked }
        )
    }

    private func selection(for epochDay: Int) -> Binding<Date> {
        Binding(
            get: { SalusDateFieldBinding.date(epochDay: epochDay) },
            set: { picked in onChange(SalusDateFieldBinding.epochDay(from: picked)) }
        )
    }
}

/// Which of ``SalusDateField``'s three faces to draw, lifted out of the view so the decision can be
/// tested without SwiftUI — the twin of ``SalusTimeFieldState``.
enum SalusDateFieldState {
    enum DisplayMode: Equatable {
        /// Nothing picked and the picker not open: Kotlin's closed dialog behind its button.
        case placeholder
        /// The open dialog, its wheel at `seed`.
        case picker(seed: Int)
        /// A day has been chosen; the field is the wheel, bound to it.
        case bound(epochDay: Int)
    }

    /// A chosen day always wins: once the editor holds one, reopening the picker is meaningless,
    /// which is why `isPicking` is only ever consulted while `epochDay` is nil.
    static func displayMode(epochDay: Int?, isPicking: Bool, seedEpochDay: Int) -> DisplayMode {
        if let epochDay {
            return .bound(epochDay: epochDay)
        }
        return isPicking ? .picker(seed: seedEpochDay) : .placeholder
    }

    /// Whether a change in the bound day must close the picker and drop its draft. Only a cleared
    /// field does: a day that merely changed is drawn by the bound wheel anyway.
    static func clearsPicker(whenValueBecomes epochDay: Int?) -> Bool {
        epochDay == nil
    }
}

/// The `epochDay` ↔ `Date` arithmetic behind ``SalusDateField``, lifted out of the view so it can
/// be tested without SwiftUI.
enum SalusDateFieldBinding {
    /// The unit `Date` counts, against the days Kotlin counts
    /// (`EditorDateField.kt:22, 29, 35` — `MILLIS_PER_DAY`).
    private static let secondsPerDay = 86400

    /// The GMT instant at midnight on `epochDay`.
    static func date(epochDay: Int) -> Date {
        Date(timeIntervalSince1970: Double(epochDay * secondsPerDay))
    }

    /// The GMT day `date` falls in, as days since 1970-01-01.
    static func epochDay(from date: Date) -> Int {
        // Floored, not truncated: integer division toward zero would put every instant on
        // 1969-12-31 on day 0.
        Int((date.timeIntervalSince1970 / Double(secondsPerDay)).rounded(.down))
    }
}

#Preview("Editor date field") {
    Form {
        SalusDateField(
            title: "Date",
            epochDay: LocalDate(year: 2026, month: 8, day: 17).epochDay,
            placeholder: "Select date",
            seedEpochDay: LocalDate(year: 2026, month: 8, day: 17).epochDay,
            onChange: { _ in }
        )
        SalusDateField(
            title: "Date",
            epochDay: nil,
            placeholder: "Select date",
            seedEpochDay: LocalDate(year: 2026, month: 8, day: 17).epochDay,
            onChange: { _ in }
        )
    }
}
