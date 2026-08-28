// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailScreen.kt:68-159` — the Route, the three content states and the
// confirmation. The six sections live in `MedicationDetailSections.swift`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `TopAppBar`                  → `.navigationTitle(_:)` on the shell's stack; the back arrow is
//                                  the stack's own, which pops the very path `Navigator.pop()`
//                                  mutates (`WeightEditorScreen.swift` records the ruling, and it
//                                  is why `medication_detail_title` needs no `editor_back` twin
//                                  here).
//   `Column(verticalScroll)`     → `ScrollView` + `VStack`.
//   `CircularProgressIndicator`  → `ProgressView()`.
//   `AlertDialog`                → `.salusConfirmDialog(isPresented:…)`.
//
// No `Scaffold` twin: the app shell owns the one navigation stack and its insets.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`MedicationDetailScreen.kt:68-84`).
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
                    // `MedicationDetailScreen.kt:82` — editing is an action on the detail, and the
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

/// The stateless detail (`MedicationDetailScreen.kt:86-159`).
struct MedicationDetailScreen: View {
    let state: MedicationDetailUiState
    let onEvent: (MedicationDetailEvent) -> Void
    let onEdit: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            .navigationTitle(MedicationsStrings.detailTitle)
            // `MedicationDetailScreen.kt:149-158`. The confirm and dismiss labels are the shared
            // `salus_delete` / `salus_cancel`, exactly as Kotlin reaches into `core.ui`'s strings
            // rather than the feature's own.
            .salusConfirmDialog(
                isPresented: isDeleteConfirmPresented,
                title: MedicationsStrings.deleteTitle(state.medication?.name ?? ""),
                message: MedicationsStrings.deleteMessage,
                confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
                dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
            )
    }

    /// The three content states (`MedicationDetailScreen.kt:111-146`).
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let medication = state.medication {
            detail(of: medication)
        } else {
            // `MedicationDetailScreen.kt:114-121` — the medication is gone (deleted from here, or
            // from the list while this screen was up) and the screen says so rather than drawing a
            // blank.
            Text(MedicationsStrings.detailMissing)
                .font(SalusTypography.bodyLarge.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(SalusSpacing.xl)
        }
    }

    /// `MedicationDetailScreen.kt:123-145` — the sections, in the Kotlin order.
    private func detail(of medication: Medication) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                MedicationDetailHeader(medication: medication)
                MedicationRemindersCard(enabled: medication.remindersEnabled) { enabled in
                    onEvent(.remindersToggled(enabled))
                }
                MedicationDetailsSection(medication: medication, schedules: state.schedules)
                // `MedicationDetailScreen.kt:136-138` — the whole section, not an empty one.
                if state.showSupply {
                    MedicationSupplySection(medication: medication)
                }
                MedicationHistorySection(history: state.history)
                MedicationDetailActions(onEdit: onEdit) { onEvent(.deleteClicked) }
            }
            // `MedicationDetailScreen.kt:144` — the trailing spacer.
            .padding(.bottom, SalusSpacing.lg)
        }
    }

    /// `MedicationDetailScreen.kt:149` — `state.showDeleteConfirm && state.medication != null`, so
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

/// `MedicationDetailScreen.kt:379-424`.
private enum PreviewData {
    static let metformin = Medication(
        id: "m1",
        name: "Metformin",
        form: .tablet,
        strengthValue: 500.0,
        strengthUnit: "mg",
        instructions: "Take after meals",
        stockCount: 8.0,
        stockThreshold: 10.0,
        startDateEpochDay: 20600,
        endDateEpochDay: nil,
        isActive: true
    )

    static let schedule = MedicationSchedule(
        id: "s1",
        medicationId: "m1",
        recurrence: .daily,
        daysOfWeekMask: 0,
        intervalDays: nil,
        anchorDateEpochDay: 20600,
        timeOfDayMinutes: 9 * 60,
        doseAmount: 1.0,
        isActive: true
    )

    static let history = [
        IntakeHistoryItem(epochDay: 20680, minuteOfDay: 9 * 60, status: .taken, doseAmount: 1.0),
        IntakeHistoryItem(epochDay: 20679, minuteOfDay: 9 * 60, status: .missed, doseAmount: 1.0)
    ]
}

#Preview("Medication detail") {
    NavigationStack {
        MedicationDetailScreen(
            state: MedicationDetailUiState(
                isLoading: false,
                medication: PreviewData.metformin,
                schedules: [PreviewData.schedule],
                history: PreviewData.history
            ),
            onEvent: { _ in },
            onEdit: {}
        )
    }
}

// No Kotlin twin: the branches the Kotlin preview does not exercise — reminders off, stock
// tracking off (so no supply section) and nothing recorded yet.
#Preview("Medication detail — silenced, no supply") {
    NavigationStack {
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
                schedules: []
            ),
            onEvent: { _ in },
            onEdit: {}
        )
    }
}

#Preview("Medication detail — missing") {
    NavigationStack {
        MedicationDetailScreen(
            state: MedicationDetailUiState(isLoading: false),
            onEvent: { _ in },
            onEdit: {}
        )
    }
}
