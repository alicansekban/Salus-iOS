// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailScreen.kt:52-178` — the Route, the toolbar, the three content states,
// the two bottom actions and the confirmation. The sections live in
// `MedicationDetailSections.swift`, `MedicationSupplyCard.swift` and `MedicationHistoryCard.swift`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `SalusTopBar.Pushed(title:actions:)` → `.navigationTitle(_:)` + `ToolbarItem(placement:
//                                          .primaryAction)` on the shell's stack; the back arrow is
//                                          the stack's own, which pops the very path
//                                          `Navigator.pop()` mutates (`WeightEditorScreen.swift`
//                                          records the ruling). Kotlin's `TextButton` action is a
//                                          plain `Button` tinted `primary` (spec §2.2).
//   `Column(verticalScroll)`             → `ScrollView` + `VStack`.
//   `CircularProgressIndicator`          → `ProgressView()`.
//   `AlertDialog`                        → `.salusConfirmDialog(isPresented:…)`.
//
// No `Scaffold` twin: the app shell owns the one navigation stack and its insets.
//
// **`.primaryAction`, not `.topBarTrailing`.** Spec §2.2 names the trailing slot by its iOS
// spelling; `ToolbarItemPlacement.topBarTrailing` is iOS-only API and every feature package also
// builds for the macOS host so `swift test` can run (CLAUDE.md, the `.macOS(.v14)` concession).
// `.primaryAction` resolves to exactly that slot on iOS, compiles on both, and is what every other
// feature in the tree already writes (`VitalsScreen.swift:142`, `AppointmentEditorScreen.swift:164`).
// The one `topBarTrailing` in the tree is the shell's own root toolbar, which is already inside an
// `#if os(iOS)`.
//
// **THE "AKTİF TAKİP" CHIP IS A CONDITIONAL TOOLBAR ITEM, and the `if` is inside the item's
// builder rather than around it** — the shape `MedicationsScreen` settled in Task 5 and the reason
// it gave: `ToolbarContentBuilder` identifies items by position, and toolbar content that appears
// and disappears has a history of not being inserted or removed on a live state change. An item
// that always exists and draws nothing when there is nothing to say has no identity to lose.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`MedicationDetailScreen.kt:52-67`).
public struct MedicationDetailRoute: View {
    private let medicationId: String

    @Environment(\.medicationsModule) private var module
    @State private var viewModel: MedicationDetailViewModel?

    public init(medicationId: String) {
        self.medicationId = medicationId
    }

    public var body: some View {
        Group {
            if let viewModel {
                MedicationDetailScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    // `MedicationDetailScreen.kt:65` — editing is an action on the detail, and the
                    // key it pushes is this feature's own, so no shell callback is involved.
                    onEdit: { module?.navigator.navigate(MedicationEditorKey(id: medicationId)) }
                )
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeMedicationDetailViewModel(medicationId)
        }
    }
}

/// The stateless detail (`MedicationDetailScreen.kt:74-178`).
struct MedicationDetailScreen: View {
    let state: MedicationDetailUiState
    let onEvent: (MedicationDetailEvent) -> Void
    let onEdit: () -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            .navigationTitle(Text(verbatim: MedicationsStrings.detailTitle))
            // `MedicationDetailScreen.kt:83-100` — the chip, then the edit action.
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if state.medication?.isActive == true {
                        SalusStatusChip(label: MedicationsStrings.detailActiveTracking, status: .accent)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    // No `.tint` of its own: the shell tints the whole `TabView` `primary`
                    // (`RootView.swift`), and a toolbar action inherits it. One shape for every
                    // pushed screen's text action (CLAUDE.md, Design system rules).
                    Button(action: onEdit) {
                        Text(verbatim: MedicationsStrings.detailEdit)
                    }
                }
            }
            // `MedicationDetailScreen.kt:165-175`. The confirm and dismiss labels are the shared
            // `salus_delete` / `salus_cancel`, exactly as Kotlin reaches into `core.ui`'s strings
            // rather than the feature's own.
            .salusConfirmDialog(
                isPresented: isDeleteConfirmPresented,
                title: MedicationsStrings.deleteTitle(state.medication?.name ?? ""),
                message: MedicationsStrings.deleteMessage,
                confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
                dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
            )
        // LAST in the chain, and `#if os(iOS)` because both modifiers are iOS-only API while
        // every feature package also builds for the macOS test host (`docs/ios-feature-template.md`).
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The three content states (`MedicationDetailScreen.kt:103-162`).
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let medication = state.medication {
            detail(of: medication)
        } else {
            // `MedicationDetailScreen.kt:106-115` — the medication is gone (deleted from here, or
            // from the list while this screen was up) and the screen says so rather than drawing a
            // blank.
            Text(verbatim: MedicationsStrings.detailMissing)
                .font(SalusTypography.bodyLarge.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(SalusSpacing.xl)
        }
    }

    /// `MedicationDetailScreen.kt:116-161` — the sections, in the Kotlin order.
    private func detail(of medication: Medication) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                MedicationDetailHero(medication: medication)
                MedicationRemindersRow(enabled: medication.remindersEnabled) { enabled in
                    onEvent(.remindersToggled(enabled))
                }
                MedicationPlanCard(medication: medication, schedules: state.schedules)
                // `MedicationDetailScreen.kt:135-140` — the whole card, not an empty one.
                if state.showSupply {
                    MedicationSupplyCard(medication: medication, daysOfSupply: state.daysOfSupply)
                }
                MedicationHistoryCard(history: state.history, todayEpochDay: state.todayEpochDay)
                actions
            }
            .padding(.horizontal, SalusSpacing.lg)
            // `Spacer(height = xl)` after the last action (`MedicationDetailScreen.kt:160`).
            .padding(.bottom, SalusSpacing.xl)
        }
    }

    /// `MedicationDetailScreen.kt:145-159` — record the dose that is due, then delete.
    private var actions: some View {
        VStack(spacing: SalusSpacing.md) {
            if let dose = state.pendingDose {
                SalusButton(
                    MedicationsStrings.detailRecordNow(time: formatTime(minuteOfDay: dose.minuteOfDay, locale: locale))
                ) { onEvent(.takeDoseClicked(dose)) }
            }
            SalusButton(MedicationsStrings.detailDeleteMedication, variant: .destructive) {
                onEvent(.deleteClicked)
            }
        }
        // `Spacer(height = sm)` before the block (`MedicationDetailScreen.kt:144`): the actions sit
        // one step further from the card above them than the cards sit from each other.
        .padding(.top, SalusSpacing.sm)
    }

    /// `MedicationDetailScreen.kt:165` — `state.showDeleteConfirm && state.medication != null`, so
    /// the dialog disappears with the medication rather than naming a title that is no longer
    /// there.
    ///
    /// SwiftUI's alert takes a `Binding<Bool>`, so the setter reports the system-driven dismissals
    /// (a swipe, the hardware back gesture) back as `deleteDismissed` — the same shape the list
    /// screen uses.
    private var isDeleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { state.showDeleteConfirm && state.medication != nil },
            set: { isPresented in
                guard !isPresented else { return }
                onEvent(.deleteDismissed)
            }
        )
    }
}

// MARK: - Previews

/// `MedicationDetailScreen.kt:180-248`.
private enum PreviewData {
    static let today = 20700

    static let metformin = Medication(
        id: "m1",
        name: "Metformin",
        form: .tablet,
        strengthValue: 500.0,
        strengthUnit: "mg",
        instructions: "Yemeklerden sonra",
        stockCount: 8.0,
        stockThreshold: 10.0,
        startDateEpochDay: 20600,
        endDateEpochDay: nil,
        isActive: true
    )

    static let schedules = [
        MedicationSchedule(
            id: "s1",
            medicationId: "m1",
            recurrence: .daily,
            daysOfWeekMask: 0,
            intervalDays: nil,
            anchorDateEpochDay: 20600,
            timeOfDayMinutes: 9 * 60,
            doseAmount: 1.0,
            isActive: true
        ),
        MedicationSchedule(
            id: "s2",
            medicationId: "m1",
            recurrence: .daily,
            daysOfWeekMask: 0,
            intervalDays: nil,
            anchorDateEpochDay: 20600,
            timeOfDayMinutes: 21 * 60,
            doseAmount: 1.0,
            isActive: true
        )
    ]

    static let history = [
        IntakeHistoryItem(epochDay: today, minuteOfDay: 9 * 60, status: .taken, doseAmount: 1.0),
        IntakeHistoryItem(epochDay: today - 1, minuteOfDay: 21 * 60, status: .skipped, doseAmount: 1.0),
        IntakeHistoryItem(epochDay: today - 2, minuteOfDay: 9 * 60, status: .missed, doseAmount: 1.0)
    ]

    static let loaded = MedicationDetailUiState(
        isLoading: false,
        medication: metformin,
        schedules: schedules,
        history: history,
        daysOfSupply: 4,
        pendingDose: PendingDose(scheduleId: "s2", epochDay: today, minuteOfDay: 21 * 60),
        todayEpochDay: today
    )
}

#Preview("Medication detail") {
    SalusPreviewPalettes {
        MedicationDetailScreen(state: PreviewData.loaded, onEvent: { _ in }, onEdit: {})
    }
}

// No Kotlin twin: the branches the Kotlin preview does not exercise — reminders off, stock tracking
// off (so no supply card) and nothing recorded yet.
#Preview("Medication detail — silenced, no supply") {
    SalusPreviewPalettes {
        MedicationDetailScreen(
            state: MedicationDetailUiState(
                isLoading: false,
                medication: Medication(
                    id: "m2",
                    name: "İnsülin",
                    form: .injection,
                    strengthValue: nil,
                    strengthUnit: nil,
                    instructions: nil,
                    stockCount: nil,
                    stockThreshold: nil,
                    startDateEpochDay: 20600,
                    endDateEpochDay: nil,
                    isActive: true,
                    remindersEnabled: false
                ),
                schedules: [],
                todayEpochDay: PreviewData.today
            ),
            onEvent: { _ in },
            onEdit: {}
        )
    }
}

#Preview("Medication detail — missing") {
    SalusPreviewPalettes {
        MedicationDetailScreen(state: MedicationDetailUiState(isLoading: false), onEvent: { _ in }, onEdit: {})
    }
}

#Preview("Medication detail — xxxLarge") {
    MedicationDetailScreen(state: PreviewData.loaded, onEvent: { _ in }, onEdit: {})
        .dynamicTypeSize(.xxxLarge)
}
