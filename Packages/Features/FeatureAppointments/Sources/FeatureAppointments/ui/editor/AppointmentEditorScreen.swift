// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/editor/AppointmentEditorScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `TopAppBar`                  → `.navigationTitle(_:)` + `.toolbar { }` on the shell's stack;
//                                  the back arrow is the stack's own, which pops the very path
//                                  `Navigator.pop()` mutates (`WeightEditorScreen.swift` records
//                                  the ruling), so `onBack` has no parameter here.
//   `OutlinedTextField`          → `TextField(…).textFieldStyle(.roundedBorder)`.
//   `isError` + `supportingText` → the error line under the field, in the `error` role.
//   `OutlinedButton` + `DatePickerDialog` / `TimePickerDialog`
//                                → `SalusDateField` / `SalusTimeField`, which are the button and
//                                  its picker in one view (see those files' header comments).
//   `FilterChip`                 → `SalusFilterChip`.
//   `Button` / `OutlinedButton`  → `.borderedProminent` / `.bordered`.
//   `AlertDialog`                → `.salusConfirmDialog(isPresented:…)`.
//   `Intent(ACTION_INSERT)`      → a `.sheet` over `CalendarEventEditSheet` — divergence (e).
//
// Two layout notes:
//
//   * The date and time rows draw their pickers with `.labelsHidden()`. Kotlin's two half-width
//     `OutlinedButton`s show the *value* and nothing else, and a `DatePicker` label in half a row
//     would push the wheel off the edge. The title is still what VoiceOver reads — `labelsHidden`
//     hides the label from the eye only.
//   * A new appointment starts with no time, so `SalusTimeField` is handed the seed its wheel opens
//     at — `seedMinuteOfDay: 9 * 60`, Kotlin's `initialHour = … ?: 9`
//     (`AppointmentEditorScreen.kt:368-369`). Seeding the *wheel* is not choosing a time: until the
//     user turns it, `minuteOfDay` stays nil and `appointments_missing_datetime` still fires, which
//     is what Kotlin's Cancel button does.

import SalusCommon
import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel, wires it to the shell, and presents what the effect asks for
/// (`AppointmentEditorScreen.kt:64-95`).
public struct AppointmentEditorRoute: View {
    private let appointmentId: String?

    @Environment(\.appointmentsModule) private var module
    @State private var viewModel: AppointmentEditorViewModel?

    #if canImport(EventKitUI)
        /// The draft the effect last handed over, or nil while no sheet is up.
        @State private var calendarDraft: CalendarEventDraft?
    #endif

    public init(appointmentId: String?) {
        self.appointmentId = appointmentId
    }

    public var body: some View {
        Group {
            if let viewModel {
                editor(driving: viewModel)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeAppointmentEditorViewModel(appointmentId)
        }
    }

    /// The `LaunchedEffect { viewModel.effects.collect { … } }` of `AppointmentEditorScreen.kt:70-88`,
    /// spelled for an `@Observable`: the effect is a property, so `.onChange` is the collector.
    ///
    /// Compiled with the sheet only where a calendar editor exists to present, exactly as the
    /// button that produces the effect is.
    @ViewBuilder
    private func editor(driving viewModel: AppointmentEditorViewModel) -> some View {
        AppointmentEditorScreen(state: viewModel.state, onEvent: viewModel.onEvent)
        #if canImport(EventKitUI)
            .onChange(of: viewModel.pendingEffect) { _, effect in
                // Fires on the clear as well as on the set, so the nil edge is dropped before the
                // queue is drained.
                guard effect != nil, let pending = viewModel.consumeEffect() else { return }
                switch pending {
                case let .addToCalendar(draft):
                    calendarDraft = draft
                }
            }
            .sheet(isPresented: isPresentingCalendar) { calendarSheet }
        #endif
    }

    #if canImport(EventKitUI)
        private var isPresentingCalendar: Binding<Bool> {
            Binding(
                get: { calendarDraft != nil },
                set: { isPresented in
                    guard !isPresented else { return }
                    calendarDraft = nil
                }
            )
        }

        @ViewBuilder
        private var calendarSheet: some View {
            if let calendarDraft {
                CalendarEventEditSheet(draft: calendarDraft, onDismiss: dismissCalendarSheet)
                    .ignoresSafeArea()
            }
        }

        /// The draft state is captured rather than `self`, so the callback is `@Sendable` and the
        /// coordinator's main-actor hop is a compiler fact instead of a promise in a comment.
        private var dismissCalendarSheet: @MainActor @Sendable () -> Void {
            let draft = $calendarDraft
            return { draft.wrappedValue = nil }
        }
    #endif
}

/// The stateless editor (`AppointmentEditorScreen.kt:97-256`).
struct AppointmentEditorScreen: View {
    let state: AppointmentEditorUiState
    let onEvent: (AppointmentEditorEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                titleField
                doctorField
                locationField
                dateTimeSection
                reminderOffsetsSection
                notesField
                #if canImport(EventKitUI)
                    // `AppointmentEditorScreen.kt:211-220` — proposing a calendar event is an
                    // action on an appointment that exists.
                    if !state.isNew {
                        addToCalendarButton
                    }
                #endif
                saveButton
            }
            .padding(SalusSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .navigationTitle(state.isNew ? AppointmentsStrings.newTitle : AppointmentsStrings.editTitle)
        .toolbar {
            // `AppointmentEditorScreen.kt:128-137` — the delete action exists only for an
            // appointment that has been saved.
            if !state.isNew {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEvent(.deleteClicked)
                    } label: {
                        Label(AppointmentsStrings.delete, systemImage: "trash")
                    }
                }
            }
        }
        .salusConfirmDialog(
            isPresented: Binding(
                get: { state.showDeleteConfirm },
                set: { isPresented in
                    guard !isPresented else { return }
                    onEvent(.deleteDismissed)
                }
            ),
            title: AppointmentsStrings.deleteTitle(state.titleText),
            message: AppointmentsStrings.deleteMessage,
            confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
            dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
        )
    }

    /// `AppointmentEditorScreen.kt:145-163`.
    private var titleField: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            TextField(
                AppointmentsStrings.titleLabel,
                text: Binding(get: { state.titleText }, set: { onEvent(.titleChanged($0)) })
            )
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .textInputAutocapitalization(.words)
            #endif
            if state.showMissingTitle {
                errorText(AppointmentsStrings.missingTitle)
            }
        }
    }

    /// `AppointmentEditorScreen.kt:165-180`.
    private var doctorField: some View {
        TextField(
            AppointmentsStrings.doctorLabel,
            text: Binding(get: { state.doctorText }, set: { onEvent(.doctorChanged($0)) })
        )
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
            .textInputAutocapitalization(.words)
            // `semantics { contentType = ContentType.PersonFullName }`
            // (`AppointmentEditorScreen.kt:176-178`): one of only two fields in the app with a real
            // autofill category — the rest are medical free text no provider has an entry for.
            .textContentType(.name)
        #endif
    }

    /// `AppointmentEditorScreen.kt:182-192`.
    private var locationField: some View {
        TextField(
            AppointmentsStrings.locationLabel,
            text: Binding(get: { state.locationText }, set: { onEvent(.locationChanged($0)) })
        )
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
            .textInputAutocapitalization(.words)
        #endif
    }

    /// `AppointmentEditorScreen.kt:258-300` — the two pickers side by side, the error beneath.
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            HStack(spacing: SalusSpacing.sm) {
                SalusDateField(
                    title: AppointmentsStrings.selectDate,
                    epochDay: state.dateEpochDay,
                    placeholder: AppointmentsStrings.selectDate
                ) { onEvent(.dateSelected($0)) }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)

                SalusTimeField(
                    title: AppointmentsStrings.selectTime,
                    minuteOfDay: state.minuteOfDay,
                    placeholder: AppointmentsStrings.selectTime,
                    // `rememberTimePickerState(initialHour = initialMinuteOfDay?.div(60) ?: 9, …)`
                    // (`AppointmentEditorScreen.kt:367-370`).
                    seedMinuteOfDay: Self.seedMinuteOfDay
                ) { onEvent(.timeSelected($0)) }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if state.showMissingDateTime {
                errorText(AppointmentsStrings.missingDatetime)
            }
        }
    }

    /// `AppointmentEditorScreen.kt:302-323`. The group label is a plain `titleSmall` `Text`, not
    /// `SalusSectionHeader`: that component is the `titleLarge` screen-section title the detail
    /// uses, where this is the small label Kotlin writes inline above the chip row — with no colour
    /// override, so it takes `onSurface` like every other `Text` on the screen.
    private var reminderOffsetsSection: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            Text(AppointmentsStrings.remindersLabel)
                .font(SalusTypography.titleSmall.font)
                .tracking(SalusTypography.titleSmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            HStack(spacing: SalusSpacing.sm) {
                ForEach(ReminderOffsets.options, id: \.self) { offsetMinutes in
                    SalusFilterChip(
                        label: offsetLabel(offsetMinutes),
                        isSelected: state.selectedOffsets.contains(offsetMinutes)
                    ) { onEvent(.reminderOffsetToggled(offsetMinutes)) }
                }
            }
        }
    }

    /// `AppointmentEditorScreen.kt:202-209`.
    private var notesField: some View {
        TextField(
            AppointmentsStrings.notesLabel,
            text: Binding(get: { state.notesText }, set: { onEvent(.notesChanged($0)) }),
            axis: .vertical
        )
        .textFieldStyle(.roundedBorder)
        // `minLines = 2` (`AppointmentEditorScreen.kt:207`); the upper bound is SwiftUI's way of
        // saying the field grows with the text instead of scrolling from the second line.
        .lineLimit(2 ... 6)
        #if os(iOS)
            .textInputAutocapitalization(.sentences)
        #endif
    }

    #if canImport(EventKitUI)
        /// `AppointmentEditorScreen.kt:212-219`.
        private var addToCalendarButton: some View {
            Button {
                onEvent(.addToCalendarClicked)
            } label: {
                Text(AppointmentsStrings.addToCalendar)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(state.dateEpochDay == nil || state.minuteOfDay == nil)
        }
    #endif

    /// `AppointmentEditorScreen.kt:222-228`.
    private var saveButton: some View {
        Button {
            onEvent(.saveClicked)
        } label: {
            Text(AppointmentsStrings.save)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(state.isSaving)
    }

    /// The `supportingText` / error line both error messages are drawn as
    /// (`AppointmentEditorScreen.kt:150-154, 293-298`).
    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(SalusTypography.bodySmall.font)
            .foregroundStyle(theme.colorScheme.error)
    }

    /// `AppointmentEditorScreen.kt:368-369` — where the time wheel opens when nothing is set yet.
    /// Where it *opens*, not what it reports: nothing is chosen until the wheel is turned.
    private static let seedMinuteOfDay = 9 * 60
}

// MARK: - Previews

#Preview("Appointment editor — new") {
    NavigationStack {
        AppointmentEditorScreen(
            state: AppointmentEditorUiState(
                dateEpochDay: LocalDate(year: 2026, month: 8, day: 18).epochDay,
                selectedOffsets: [ReminderOffsets.oneDay]
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Appointment editor — existing") {
    NavigationStack {
        AppointmentEditorScreen(
            state: AppointmentEditorUiState(
                isNew: false,
                titleText: "Annual check-up",
                doctorText: "Dr. Lee",
                locationText: "City Clinic, Room 204",
                notesText: "Bring the last blood test results.",
                dateEpochDay: LocalDate(year: 2026, month: 8, day: 18).epochDay,
                minuteOfDay: 10 * 60,
                selectedOffsets: [ReminderOffsets.oneHour, ReminderOffsets.oneDay]
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Appointment editor — errors") {
    NavigationStack {
        AppointmentEditorScreen(
            state: AppointmentEditorUiState(showMissingTitle: true, showMissingDateTime: true),
            onEvent: { _ in }
        )
    }
}
