// Ported from `feature/cycle/src/main/kotlin/com/alicansekban/salus/feature/cycle/
// ui/calendar/CycleScreen.kt:377-534` — the opt-in reminder card, its two option rows, and the two
// popups they open.
//
// Material → SwiftUI:
//   `Switch(checked:onCheckedChange:)`   → `Toggle(_:isOn:)` over a get/set `Binding`, the same
//                                          shape `MedicationDetailSections.swift:122` uses.
//   `AlertDialog` + `RadioButton` list   → `.confirmationDialog`, one button per option
//                                          (iOS-M6 ruling 4).
//   `AlertDialog` + `TimePicker`         → `.sheet` with a wheel `DatePicker` (ruling 4).
//   `TextButton`                         → `Button` + `.buttonStyle(.plain)`, tinted with the
//                                          feature accent.
//
// TWO THINGS THE PLATFORM CHANGES, both ruling 4's own consequences and neither a behaviour
// difference:
//
// 1. **The lead-day popup shows no radio buttons.** Kotlin draws a `selectableGroup` whose current
//    row is checked; an action sheet has no selection affordance and cannot be given one. The
//    current value is not lost — the card's own row above it reads it out (`leadDaysLabel`), which
//    is where the user was looking when they tapped.
// 2. **Choosing an option also reports a dismissal.** `.confirmationDialog` writes `false` into its
//    `isPresented` binding as it closes, so the setter fires `reminderDialogDismissed` alongside
//    the option's own `reminderLeadDaysSelected`. Both are idempotent closes on the ViewModel
//    (`CycleViewModel.swift`'s `reminderDialogDismissed` / `closeDialogAndSync`), and the same
//    "any dismissal reports itself" wiring already ships in `MedicationsScreen.swift:94-104`.
//
// The time wheel is pinned to GMT and seeded with `minuteOfDay × 60`, exactly as
// `SalusUI/SalusTimeField.swift` does and for its reason: `DatePicker` speaks `Date`, this state
// speaks a minute-of-day integer, and pinning the zone bridges the two without constructing a
// `Calendar` — which `CLAUDE.md` allows in three files, none of them this one. The user still sees
// their own locale's clock in the wheel.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Opt-in period-start reminder: toggle + lead-day and time-of-day options
/// (`CycleScreen.kt:377-423`).
struct CycleReminderCard: View {
    let state: CycleUiState
    let onEvent: (CycleEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: CycleStrings.reminderTitle)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    Text(verbatim: subtitle)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                // `Modifier.weight(1f)` (`CycleScreen.kt:382`).
                .frame(maxWidth: .infinity, alignment: .leading)

                // The label is given and then hidden rather than omitted: `Toggle("")` would
                // announce an unnamed switch, where Compose's `Switch` inherits the row's text.
                Toggle(CycleStrings.reminderTitle, isOn: isOn)
                    .labelsHidden()
                    // `Spacer(width = sm)` (`CycleScreen.kt:399`).
                    .padding(.leading, SalusSpacing.sm)
            }

            // `CycleScreen.kt:405-421`.
            if state.reminderEnabled {
                Spacer()
                    .frame(height: SalusSpacing.sm)
                CycleReminderOptionRow(
                    label: CycleStrings.reminderLeadLabel,
                    value: leadDaysLabel(state.reminderLeadDays)
                ) {
                    onEvent(.reminderDialogRequested(.leadDays))
                }
                CycleReminderOptionRow(
                    label: CycleStrings.reminderTimeLabel,
                    value: formatMinuteOfDay(state.reminderMinuteOfDay)
                ) {
                    onEvent(.reminderDialogRequested(.time))
                }
            }
        }
    }

    /// `cycle_reminder_needs_data` while the toggle is on but nothing can fire yet, otherwise
    /// `cycle_reminder_desc` (`CycleScreen.kt:388-394`).
    private var subtitle: String {
        state.reminderEnabled && !state.reminderHasUsablePrediction
            ? CycleStrings.reminderNeedsData
            : CycleStrings.reminderDescription
    }

    /// The switch draws what the settings last emitted, never a local copy.
    ///
    /// The setter is a closure literal rather than `onEvent` passed straight through: `Binding`'s
    /// setter is `@isolated(any) @Sendable`, and only a literal written here picks up this view's
    /// main-actor isolation (`MedicationDetailSections.swift:145`).
    private var isOn: Binding<Bool> {
        Binding(get: { state.reminderEnabled }, set: { onEvent(.reminderToggled($0)) })
    }
}

/// A label on the left, its current value in the feature accent on the right
/// (`CycleScreen.kt:425-446`).
struct CycleReminderOptionRow: View {
    let label: String
    let value: String
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 0) {
                Text(verbatim: label)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    // `Modifier.weight(1f)` (`CycleScreen.kt:438`).
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: value)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.extendedColors.cycle.accent)
            }
            // `defaultMinSize(minHeight = SalusTouchTarget.min)` + `padding(vertical = sm)`
            // (`CycleScreen.kt:430`, `:432`).
            .padding(.vertical, SalusSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: SalusTouchTarget.min)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - The two popups

extension View {
    /// `ReminderDialogs(state:onEvent:)` (`CycleScreen.kt:448-521`), which Compose emits as a
    /// sibling of the scroll area and SwiftUI attaches as a modifier.
    func cycleReminderDialogs(state: CycleUiState, onEvent: @escaping (CycleEvent) -> Void) -> some View {
        modifier(CycleReminderDialogs(state: state, onEvent: onEvent))
    }
}

/// The lead-day action sheet and the time sheet, both driven by `state.activeReminderDialog`.
struct CycleReminderDialogs: ViewModifier {
    let state: CycleUiState
    let onEvent: (CycleEvent) -> Void

    func body(content: Content) -> some View {
        content
            // `CycleScreen.kt:452-486`.
            .confirmationDialog(
                CycleStrings.reminderLeadLabel,
                isPresented: isPresented(.leadDays),
                titleVisibility: .visible
            ) {
                ForEach(minReminderLeadDays ... maxReminderLeadDays, id: \.self) { days in
                    Button(leadDaysLabel(days)) { onEvent(.reminderLeadDaysSelected(days)) }
                }
                // Kotlin's `confirmButton`, which only cancels (`CycleScreen.kt:481-485`).
                Button(CycleStrings.reminderCancel, role: .cancel) {
                    onEvent(.reminderDialogDismissed)
                }
            }
            // `CycleScreen.kt:488-517`.
            .sheet(isPresented: isPresented(.time)) {
                CycleReminderTimeSheet(
                    minuteOfDay: state.reminderMinuteOfDay,
                    onConfirm: { minuteOfDay in onEvent(.reminderTimeSelected(minuteOfDay)) },
                    onCancel: { onEvent(.reminderDialogDismissed) }
                )
            }
    }

    /// `onDismissRequest = { onEvent(ReminderDialogDismissed) }` (`CycleScreen.kt:453`, `:495`):
    /// the popup is open exactly while the state says so, and every system-driven close — a swipe,
    /// a tap outside — reports itself as a dismissal.
    private func isPresented(_ dialog: CycleReminderDialog) -> Binding<Bool> {
        Binding(
            get: { state.activeReminderDialog == dialog },
            set: { isPresented in
                guard !isPresented else { return }
                onEvent(.reminderDialogDismissed)
            }
        )
    }
}

/// The time wheel and its two buttons (`CycleScreen.kt:489-516`).
struct CycleReminderTimeSheet: View {
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void

    /// What the wheel currently reads. Seeded once from the stored minute, exactly as
    /// `rememberTimePickerState(initialHour:initialMinute:)` seeds Kotlin's picker
    /// (`CycleScreen.kt:489-493`) — the sheet's content view is built afresh on each presentation,
    /// so the seed is re-read every time it opens.
    @State private var picked: Date

    @Environment(\.salusTheme) private var theme

    init(minuteOfDay: Int, onConfirm: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _picked = State(initialValue: CycleReminderTime.date(minuteOfDay: minuteOfDay))
    }

    var body: some View {
        VStack(spacing: SalusSpacing.lg) {
            // Kotlin's `title` slot (`CycleScreen.kt:496`).
            Text(verbatim: CycleStrings.reminderTimeLabel)
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)

            DatePicker(
                CycleStrings.reminderTimeLabel,
                selection: $picked,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .environment(\.timeZone, .gmt)
            #if os(iOS)
                // `TimePicker` (`CycleScreen.kt:497`) is a wheel; the compact field SwiftUI would
                // otherwise draw inside a sheet is a second popup on top of this one.
                .datePickerStyle(.wheel)
            #endif

            HStack(spacing: SalusSpacing.lg) {
                // `dismissButton` (`CycleScreen.kt:511-515`).
                textButton(CycleStrings.reminderCancel, action: onCancel)
                // `confirmButton` (`CycleScreen.kt:498-510`).
                textButton(CycleStrings.reminderTimeConfirm) {
                    onConfirm(CycleReminderTime.minuteOfDay(from: picked))
                }
            }
        }
        .padding(SalusSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.colorScheme.background)
        #if os(iOS)
            .presentationDetents([.medium])
        #endif
    }

    /// Material's `TextButton`: the label, in the accent, over the 48-pt touch target.
    private func textButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.extendedColors.cycle.accent)
                .padding(.horizontal, SalusSpacing.lg)
                .frame(minHeight: SalusTouchTarget.min)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// The `minuteOfDay` ↔ `Date` arithmetic the wheel needs, with no `Calendar` in it — see this
/// file's header, and `SalusUI/SalusTimeField.swift`'s `SalusTimeFieldBinding`, which is the same
/// pair of functions kept internal to its own package.
enum CycleReminderTime {
    private static let secondsPerMinute = 60
    private static let minutesPerDay = 1440

    /// The GMT instant whose clock reading is `minuteOfDay`.
    static func date(minuteOfDay: Int) -> Date {
        Date(timeIntervalSince1970: Double(minuteOfDay * secondsPerMinute))
    }

    /// The clock reading of `date` in GMT, as minutes since midnight — always `0 ..< 1440`, which
    /// is Kotlin's `timeState.hour * 60 + timeState.minute` (`CycleScreen.kt:504`).
    static func minuteOfDay(from date: Date) -> Int {
        let minutes = Int((date.timeIntervalSince1970 / Double(secondsPerMinute)).rounded(.down))
        // Swift's `%` keeps the sign of the dividend, and a wheel dragged before the epoch would
        // otherwise report a negative minute, which is not a time of day.
        return ((minutes % minutesPerDay) + minutesPerDay) % minutesPerDay
    }
}

// MARK: - Labels and constants

/// `leadDaysLabel(days)` (`CycleScreen.kt:523-528`) — 0 is the predicted day itself.
private func leadDaysLabel(_ days: Int) -> String {
    days == 0 ? CycleStrings.reminderLeadSameDay : CycleStrings.reminderLeadDaysBefore(days)
}

/// `formatMinuteOfDay(minuteOfDay)` (`CycleScreen.kt:530-534`) — 24-hour, always, on both
/// platforms: this is the time the reminder fires, not a clock the user reads their own way.
private func formatMinuteOfDay(_ minuteOfDay: Int) -> String {
    String(format: "%02d:%02d", minuteOfDay / minutesPerHour, minuteOfDay % minutesPerHour)
}

/// `MIN_REMINDER_LEAD_DAYS` (`CycleScreen.kt:543`).
private let minReminderLeadDays = 0
/// `MAX_REMINDER_LEAD_DAYS` (`CycleScreen.kt:544`).
private let maxReminderLeadDays = 3
private let minutesPerHour = 60
