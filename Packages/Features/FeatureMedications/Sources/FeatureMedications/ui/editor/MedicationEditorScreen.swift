// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/editor/MedicationEditorScreen.kt` in its M15 shape.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `SalusTopBar.Pushed(title:subtitle:actions:)`
//                                → `.navigationTitle(_:)` + `ToolbarItem(placement:
//                                  .primaryAction)` on the shell's stack; the back arrow is the
//                                  stack's own, which pops the very path `Navigator.pop()` mutates.
//                                  That is why `editor_back` had no reader here and is gone with the
//                                  M15 sweep (divergence (h)). Kotlin's `TextButton` action is a
//                                  plain `Button` tinted `primary` (spec §2.2), and **the subtitle
//                                  the pushed bar carries moves into the content's first row**, the
//                                  rule spec §2.2 states for every pushed screen.
//   `SalusCard` sections         → the same component, one `View` per card.
//   `SalusInfoNote`              → the same component; the error banner is Kotlin's, tone and all.
//   `OutlinedButton` + `DatePickerDialog` / `TimePicker`
//                                → `SalusDateField` / `SalusTimeField`, the button and its picker in
//                                  one view. `editor_confirm` / `editor_cancel` therefore have no
//                                  reader — they name dialog buttons that do not exist here.
//   `AlertDialog`                → `.salusConfirmDialog(isPresented:…)`.
//
// The five cards are Kotlin's, in Kotlin's order; they live in `MedicationEditorSections.swift`,
// `MedicationFormGrid.swift`, `DoseTimesSection.swift` and `MedicationStockCard.swift`, split out
// under the 500-line rule.
//
// **THE DELETE ACTION LEFT THE TOOLBAR.** Until M15 the editor carried a trash `ToolbarItem` for a
// saved medication; Kotlin's M15 top bar has only "Kaydet" and puts "İlacı Sil" at the foot of the
// form (`MedicationEditorScreen.kt:96-104`, `:139-148`). This follows, so the one conditional
// toolbar item this screen had is gone and the trailing slot is constant.
//
// **`.primaryAction`, not `.topBarTrailing`.** Spec §2.2 names the trailing slot by its iOS
// spelling; `ToolbarItemPlacement.topBarTrailing` is iOS-only API and every feature package also
// builds for the macOS host so `swift test` can run (CLAUDE.md, the `.macOS(.v14)` concession).
// `.primaryAction` resolves to exactly that slot on iOS, compiles on both, and is what every other
// feature in the tree already writes (`VitalsScreen.swift:142`, `AppointmentEditorScreen.swift:164`).
// The one `topBarTrailing` in the tree is the shell's own root toolbar, which is already inside an
// `#if os(iOS)`.

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

/// The stateless editor (`MedicationEditorScreen.kt:80-191`).
struct MedicationEditorScreen: View {
    let state: MedicationEditorUiState
    let onEvent: (MedicationEditorEvent) -> Void

    @Environment(\.salusTheme) var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            .navigationTitle(Text(verbatim: title))
            // `MedicationEditorScreen.kt:96-104` — the one trailing action M15 leaves in the bar.
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { onEvent(.saveClicked) } label: {
                        Text(verbatim: MedicationsStrings.editorSave)
                    }
                    .tint(theme.colorScheme.primary)
                }
            }
            // `MedicationEditorScreen.kt:170-180`. The confirm label is the shared `salus_delete`,
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
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard
        // (`docs/ios-feature-template.md`, and the shape `AboutScreen` has carried since M8).
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
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

    /// `MedicationEditorScreen.kt:107` — Kotlin returns before the form while the medication is
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

    /// The scrolling body — the subtitle row, the error note and the five cards
    /// (`MedicationEditorScreen.kt:107-151`).
    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                // Spec §2.2: the subtitle Kotlin hangs under the pushed title moves into the
                // content's first row, because the system navigation bar has no subtitle slot.
                Text(verbatim: subtitle)
                    .font(SalusTypography.bodyMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)

                // `MedicationEditorScreen.kt:118-124`.
                if let error = state.error {
                    SalusInfoNote(
                        text: Self.message(of: error),
                        systemImage: "exclamationmark.triangle",
                        tone: .warning
                    )
                }

                MedicationBasicsCard(state: state, onEvent: onEvent)
                MedicationEditorPlanCard(state: state, onEvent: onEvent)
                MedicationDatesCard(state: state, onEvent: onEvent)
                // `MedicationEditorScreen.kt:129-135` — an as-needed medication has no clock time to
                // build, so there is no list of them to build either.
                if state.recurrence != .asNeeded {
                    MedicationDoseTimesCard(state: state, onEvent: onEvent)
                }
                MedicationStockCard(state: state, onEvent: onEvent)

                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
            // `Spacer(height = xl)` after the last action (`MedicationEditorScreen.kt:150`).
            .padding(.bottom, SalusSpacing.xl)
        }
        // Divergence: iOS-only, with no line in `MedicationEditorScreen.kt` behind it. Every numeric
        // field here is `.decimalPad` / `.numberPad`, and neither pad draws a return key, so the
        // keyboard has no "Done" to press — where Compose's number IMEs still carry the
        // `ImeAction.Next` / `ImeAction.Done` the Kotlin fields declare. The two lines below give the
        // keyboard the two ways down the platform expects: a tap, and a drag over the form. Both
        // belong on the `ScrollView` itself; the file comment on `salusDismissesKeyboardOnTap()`
        // records the layouts that were measured and do nothing.
        .salusDismissesKeyboardOnTap()
        .scrollDismissesKeyboard(.interactively)
    }

    /// `MedicationEditorScreen.kt:139-148` — save, then delete for a medication that has one.
    private var actions: some View {
        VStack(spacing: SalusSpacing.md) {
            SalusButton(MedicationsStrings.editorSave) { onEvent(.saveClicked) }
            if !state.isNew {
                SalusButton(MedicationsStrings.detailDeleteMedication, variant: .destructive) {
                    onEvent(.deleteClicked)
                }
            }
        }
        // `Spacer(height = sm)` before the block (`MedicationEditorScreen.kt:138`).
        .padding(.top, SalusSpacing.sm)
    }

    /// `editor_title_new` / `editor_title_edit` (`MedicationEditorScreen.kt:90-92`).
    private var title: String {
        state.isNew ? MedicationsStrings.editorTitleNew : MedicationsStrings.editorTitleEdit
    }

    /// `editor_subtitle_new` / `editor_subtitle_edit` (`MedicationEditorScreen.kt:93-95`).
    private var subtitle: String {
        state.isNew ? MedicationsStrings.editorSubtitleNew : MedicationsStrings.editorSubtitleEdit
    }

    /// `EditorError.messageRes()` (`MedicationEditorScreen.kt:223-229`) — the five errors and their
    /// five strings.
    private static func message(of error: EditorError) -> String {
        switch error {
        case .emptyName: MedicationsStrings.editorErrorEmptyName
        case .endBeforeStart: MedicationsStrings.editorErrorEndBeforeStart
        case .invalidInterval: MedicationsStrings.editorErrorInvalidInterval
        case .noDaysSelected: MedicationsStrings.editorErrorNoDays
        case .noDoseTimes: MedicationsStrings.editorErrorNoTimes
        }
    }
}

// MARK: - Previews

/// `MedicationEditorScreen.kt:236-262`.
private enum PreviewData {
    static let existing = MedicationEditorUiState(
        isLoading: false,
        isNew: false,
        name: "Metformin",
        form: .tablet,
        strengthValueInput: "500",
        strengthUnitInput: "mg",
        instructions: "Yemeklerden sonra",
        stockCountInput: "30",
        stockThresholdInput: "10",
        startDateEpochDay: 20600,
        recurrence: .daily,
        doseTimes: [
            DoseTimeUi(existingScheduleId: "s1", minuteOfDay: 9 * 60, amountInput: "1"),
            DoseTimeUi(existingScheduleId: "s2", minuteOfDay: 21 * 60, amountInput: "0.5")
        ]
    )
}

#Preview("Medication editor — existing") {
    SalusPreviewPalettes {
        MedicationEditorScreen(state: PreviewData.existing, onEvent: { _ in })
    }
}

// No Kotlin twin: the branches the Kotlin preview does not exercise — a new medication with the
// stock card collapsed, and a weekly plan whose day chips are drawn.
#Preview("Medication editor — new, weekly") {
    SalusPreviewPalettes {
        MedicationEditorScreen(
            state: MedicationEditorUiState(
                isLoading: false,
                startDateEpochDay: 20680,
                recurrence: .daysOfWeek,
                daysOfWeekMask: 0b1010101,
                doseTimes: [DoseTimeUi(existingScheduleId: nil, minuteOfDay: 8 * 60, amountInput: "1")]
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Medication editor — interval, error") {
    SalusPreviewPalettes {
        MedicationEditorScreen(
            state: MedicationEditorUiState(
                isLoading: false,
                startDateEpochDay: 20680,
                recurrence: .intervalDays,
                intervalDaysInput: "0",
                doseTimes: [DoseTimeUi(existingScheduleId: nil, minuteOfDay: 8 * 60, amountInput: "1")],
                error: .invalidInterval
            ),
            onEvent: { _ in }
        )
    }
}

#Preview("Medication editor — saved, alarms blocked") {
    SalusPreviewPalettes {
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

#Preview("Medication editor — xxxLarge") {
    MedicationEditorScreen(state: PreviewData.existing, onEvent: { _ in })
        .dynamicTypeSize(.xxxLarge)
}
