// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/editor/MedicationEditorScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `TopAppBar`                  → `.navigationTitle(_:)` + `.toolbar { }` on the shell's stack;
//                                  the back arrow is the stack's own, which pops the very path
//                                  `Navigator.pop()` mutates. That is why `editor_back` has no
//                                  reader here (divergence (h)), and `editor_confirm` /
//                                  `editor_cancel` have none either: the two dialogs they label
//                                  are `DatePickerDialog` and the time `AlertDialog`, and
//                                  `SalusDateField` / `SalusTimeField` are the button and its
//                                  picker in one view, with no OK button to name.
//   `OutlinedTextField`          → `TextField(…).textFieldStyle(.roundedBorder)`.
//   `FilterChip` rows            → `ChipFlowLayout` of `SalusFilterChip`s. Kotlin chunks its chips
//                                  three to a row to avoid a `FlowRow` dependency
//                                  (`MedicationEditorScreen.kt:303`); the iOS layout wraps on
//                                  measured width, which is what that comment settles for.
//   `OutlinedButton` + `DatePickerDialog` / `TimePicker`
//                                → `SalusDateField` / `SalusTimeField`.
//   `AlertDialog`                → `.salusConfirmDialog(isPresented:…)`.
//
// `isError` has no `TextField` twin, so it is not spelled per field: the banner at the top of the
// form is the one error surface, and it already names which of the five things is wrong. Kotlin
// draws both — a red field *and* the banner — and dropping the redundant half is the only visual
// difference in the port.
//
// The 12 items of the body are Kotlin's, in Kotlin's order; the sections themselves live in
// `MedicationEditorSections.swift` and `DoseTimesSection.swift`, split out under the 500-line rule.

import SalusDesignSystem
import SalusReminder
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`MedicationEditorScreen.kt:66-79`).
///
/// One callback, and it is the one hop a pop cannot make: the post-save warning's "Fix" opens
/// Reminder health, which belongs to `:feature:settings`, and features never depend on each other
/// (spec §4). Everything else out of this screen is a pop, which `Navigator` already carries.
public struct MedicationEditorRoute: View {
    private let medicationId: String?
    private let onOpenReminderHealth: () -> Void

    @Environment(\.medicationsModule) private var module
    @State private var viewModel: MedicationEditorViewModel?

    public init(medicationId: String?, onOpenReminderHealth: @escaping () -> Void) {
        self.medicationId = medicationId
        self.onOpenReminderHealth = onOpenReminderHealth
    }

    public var body: some View {
        Group {
            if let viewModel {
                MedicationEditorScreen(state: viewModel.state) { event in
                    deliverEffects(of: viewModel, after: event)
                }
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeMedicationEditorViewModel(medicationId)
        }
    }

    /// The collector for Kotlin's `Channel<MedicationEditorEffect>`, drained right after the event
    /// that could have filled it rather than from an `.onChange(of:)` (the `MoreRoute` shape).
    ///
    /// The reason is this screen's own: the hop out of here is a pop *and* a push, and the ViewModel
    /// deliberately does neither for "Fix" — a pop of its own would tear this Route down mid-flight
    /// and the push would be lost with it. So the shell does both halves, in that order, and this
    /// drain is what reaches it. Every effect is appended from `onEvent`, so draining immediately
    /// after the event is both complete and ordered.
    @MainActor
    private func deliverEffects(of viewModel: MedicationEditorViewModel, after event: MedicationEditorEvent) {
        viewModel.onEvent(event)
        for effect in viewModel.consumeEffects() {
            switch effect {
            case .openReminderHealth:
                onOpenReminderHealth()
            }
        }
    }
}

/// The stateless editor (`MedicationEditorScreen.kt:81-256`).
struct MedicationEditorScreen: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    @Environment(\.salusTheme) var theme
    @Environment(\.locale) var locale

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            .navigationTitle(
                state.isNew ? MedicationsStrings.editorTitleNew : MedicationsStrings.editorTitleEdit
            )
            .toolbar {
                // `MedicationEditorScreen.kt:103-113` — the delete action exists only for a
                // medication that has been saved.
                if !state.isNew {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            onEvent(.deleteClicked)
                        } label: {
                            Label(MedicationsStrings.editorDelete, systemImage: "trash")
                        }
                    }
                }
                // `MedicationEditorScreen.kt:114-116`.
                ToolbarItem(placement: .primaryAction) {
                    Button(MedicationsStrings.editorSave) { onEvent(.saveClicked) }
                }
            }
            // `MedicationEditorScreen.kt:243-255`. The confirm label is the shared `salus_delete`,
            // exactly as Kotlin reaches into `core.ui`'s string rather than the feature's own.
            .salusConfirmDialog(
                isPresented: isDeleteConfirmPresented,
                title: MedicationsStrings.deleteTitle(state.name),
                message: MedicationsStrings.deleteMessage,
                confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
                dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
            )
            // The post-save warning. The message is the first hard problem's own reason — on iOS
            // there is exactly one hard problem, so `first` is the whole list
            // (`ReminderReadiness.swift`), and `nil` is unreachable while the dialog is presented.
            //
            // `confirmIsDestructive: false`, the same argument Kotlin passes here: "Fix" steers the
            // user to Reminder health, it does not remove anything, so it keeps the plain button
            // rather than the delete tint the dialog's usual caller wants.
            .salusConfirmDialog(
                isPresented: isReminderWarningPresented,
                title: MedicationsStrings.savedRemindersBlockedTitle,
                message: state.reminderWarning?.first?.reason ?? "",
                confirm: SalusDialogAction(label: ReminderStrings.reminderFix) {
                    onEvent(.reminderWarningFixClicked)
                },
                dismiss: SalusDialogAction(label: ReminderStrings.reminderNotNow) {
                    onEvent(.reminderWarningDismissed)
                },
                confirmIsDestructive: false
            )
    }

    /// The warning's binding, the same shape `isDeleteConfirmPresented` has: the setter reports the
    /// system-driven dismissal that follows either button back as `reminderWarningDismissed`, and
    /// the ViewModel answers a warning exactly once, so that second event changes nothing.
    private var isReminderWarningPresented: Binding<Bool> {
        Binding(
            get: { state.reminderWarning?.isEmpty == false },
            set: { isPresented in
                guard !isPresented else { return }
                onEvent(.reminderWarningDismissed)
            }
        )
    }

    /// SwiftUI's alert takes a `Binding<Bool>` where Kotlin writes `if (state.showDeleteConfirm)`,
    /// so the setter reports the system-driven dismissals (a swipe, the hardware back gesture) back
    /// as `deleteDismissed`.
    private var isDeleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { state.showDeleteConfirm },
            set: { isPresented in
                guard !isPresented else { return }
                onEvent(.deleteDismissed)
            }
        )
    }

    /// `MedicationEditorScreen.kt:119` — Kotlin returns before the form while the medication is
    /// still being read, drawing the bar and nothing else. The spinner is what the rest of this
    /// port draws for that same moment (`MedicationsScreen.content`), and it says the screen is
    /// working rather than empty.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            form
        }
    }

    /// The scrolling body — the twelve items of `MedicationEditorScreen.kt:121-241`, in order.
    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                if let error = state.error {
                    errorBanner(error)
                }
                nameField
                formSelector
                strengthRow
                instructionsField
                stockRow
                dateRow
                scheduleSectionLabel
                recurrenceSelector
                recurrenceDetail
                // `MedicationEditorScreen.kt:236-238` — an as-needed medication has no clock time
                // to build, so the builder is not drawn at all.
                if state.recurrence != .asNeeded {
                    DoseTimesSection(state: state, onEvent: onEvent)
                }
                Spacer()
                    .frame(height: SalusSpacing.xl)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SalusSpacing.lg)
        }
        // Divergence: iOS-only, with no line in `MedicationEditorScreen.kt` behind it. Every
        // numeric field here is `.decimalPad` / `.numberPad`, and neither pad draws a return key,
        // so the keyboard has no "Done" to press — where Compose's number IMEs still carry the
        // `ImeAction.Next` / `ImeAction.Done` the Kotlin fields declare. The two lines below give
        // the keyboard the two ways down the platform expects: a tap, and a drag over the form.
        // Both belong on the `ScrollView` itself; the file comment on
        // `salusDismissesKeyboardOnTap()` records the layouts that were measured and do nothing.
        .salusDismissesKeyboardOnTap()
        .scrollDismissesKeyboard(.interactively)
    }

    /// `MedicationEditorScreen.kt:259-273` — the five errors and their five strings.
    private func errorBanner(_ error: EditorError) -> some View {
        let message = switch error {
        case .emptyName: MedicationsStrings.editorErrorEmptyName
        case .endBeforeStart: MedicationsStrings.editorErrorEndBeforeStart
        case .invalidInterval: MedicationsStrings.editorErrorInvalidInterval
        case .noDaysSelected: MedicationsStrings.editorErrorNoDays
        case .noDoseTimes: MedicationsStrings.editorErrorNoTimes
        }
        return Text(verbatim: message)
            .font(SalusTypography.bodyMedium.font)
            .foregroundStyle(theme.colorScheme.error)
    }
}

// MARK: - Previews

#Preview("Medication editor — new") {
    NavigationStack {
        MedicationEditorScreen(
            state: MedicationEditorUiState(
                isLoading: false,
                startDateEpochDay: 20680,
                doseTimes: [DoseTimeUi(existingScheduleId: nil, minuteOfDay: 8 * 60, amountInput: "1")]
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Medication editor — existing, weekly") {
    NavigationStack {
        MedicationEditorScreen(
            state: MedicationEditorUiState(
                isLoading: false,
                isNew: false,
                name: "Iron",
                form: .capsule,
                strengthValueInput: "500",
                strengthUnitInput: "mg",
                stockCountInput: "30",
                stockThresholdInput: "5",
                startDateEpochDay: 20680,
                endDateEpochDay: 20710,
                recurrence: .daysOfWeek,
                daysOfWeekMask: 0b1010101,
                doseTimes: [
                    DoseTimeUi(existingScheduleId: "s1", minuteOfDay: 9 * 60, amountInput: "1"),
                    DoseTimeUi(existingScheduleId: "s2", minuteOfDay: 20 * 60, amountInput: "2")
                ]
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Medication editor — saved, alarms blocked") {
    NavigationStack {
        MedicationEditorScreen(
            state: MedicationEditorUiState(
                isLoading: false,
                name: "Iron",
                startDateEpochDay: 20680,
                doseTimes: [DoseTimeUi(existingScheduleId: nil, minuteOfDay: 8 * 60, amountInput: "1")],
                reminderWarning: [.notificationsOff]
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Medication editor — error") {
    NavigationStack {
        MedicationEditorScreen(
            state: MedicationEditorUiState(
                isLoading: false,
                recurrence: .intervalDays,
                intervalDaysInput: "0",
                error: .invalidInterval
            ),
            onEvent: { _ in }
        )
    }
}
