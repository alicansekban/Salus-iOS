// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `LazyColumn` + `contentPadding`      → `ScrollView` + `LazyVStack` + `.padding`.
//   `CircularProgressIndicator`          → `ProgressView()`.
//   `Icons.Filled.*`                     → SF Symbol names.
//   `LocalLocale.current.platformLocale` → `@Environment(\.locale)`.
//
// The card itself lives in `MedicationCard.swift`: this file is the screen's own shape — header,
// the three content states, the FAB and the confirmation — and splitting the row out is what M4 did
// once its screen passed 500 lines.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`MedicationsScreen.kt:69-83`).
///
/// No callback parameters: every destination this screen reaches is this feature's own, so there is
/// no cross-feature move for the shell to fill in.
public struct MedicationsRoute: View {
    @Environment(\.medicationsModule) private var module
    @State private var viewModel: MedicationsViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                MedicationsScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onAddMedication: { navigate(MedicationEditorKey(id: nil)) },
                    // Rows open the detail screen; editing is an action on it, not the row's job
                    // (`MedicationsScreen.kt:80`).
                    onOpenMedication: { id in navigate(MedicationDetailKey(id: id)) }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Built once and owned for the lifetime of the route. The recorded-dose window is read
            // when the ViewModel is built, so a route that outlives midnight keeps yesterday's
            // seven days — the same thing Android's `stateIn` does with the value it holds, and the
            // same refresh on both platforms: re-entering the tab rebuilds it.
            guard viewModel == nil, let module else { return }
            viewModel = module.makeMedicationsViewModel()
        }
    }

    private func navigate(_ key: some Hashable & Sendable) {
        module?.navigator.navigate(key)
    }
}

/// The stateless list (`MedicationsScreen.kt:84-143`).
struct MedicationsScreen: View {
    let state: MedicationsUiState
    let onEvent: (MedicationsEvent) -> Void
    let onAddMedication: () -> Void
    let onOpenMedication: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                SalusScreenHeader(title: MedicationsStrings.title)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `MedicationsScreen.kt:122-129`.
            SalusFab(systemImage: "plus", contentDescription: MedicationsStrings.add, action: onAddMedication)
                .padding(SalusSpacing.lg)
        }
        .background(theme.colorScheme.background)
        // `MedicationsScreen.kt:132-142`. The confirm label is the shared `salus_delete`, exactly
        // as Kotlin reaches into `core.ui`'s string rather than the feature's own.
        .salusConfirmDialog(
            isPresented: isDeleteConfirmPresented,
            title: MedicationsStrings.deleteTitle(state.pendingDelete?.name ?? ""),
            message: MedicationsStrings.deleteMessage,
            confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
            dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
        )
    }

    /// Kotlin writes `state.pendingDelete?.let { … }` — the dialog exists only while there is
    /// something to ask about. SwiftUI's alert takes a `Binding<Bool>` instead, so the optional is
    /// read as "is there one" and the setter reports the system-driven dismissals (a swipe, the
    /// hardware back gesture) back as `deleteDismissed`.
    private var isDeleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { state.pendingDelete != nil },
            set: { isPresented in
                guard !isPresented else { return }
                onEvent(.deleteDismissed)
            }
        )
    }

    /// `MedicationsScreen.kt:88-120`.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.medications.isEmpty {
            SalusEmptyState(
                systemImage: "pills",
                title: MedicationsStrings.emptyTitle,
                message: MedicationsStrings.emptyBody,
                accent: theme.extendedColors.medications,
                actionLabel: MedicationsStrings.add,
                onAction: onAddMedication
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list
        }
    }

    /// `MedicationsScreen.kt:144-168`.
    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SalusSpacing.md) {
                ForEach(state.medications) { item in
                    MedicationCard(
                        item: item,
                        onTap: { onOpenMedication(item.medication.id) },
                        onDelete: { onEvent(.deleteRequested(item.medication.id)) }
                    )
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.top, SalusSpacing.sm)
            // Keeps the last card scrollable above the floating action button
            // (`MedicationsScreen.kt:156`, `:258`).
            .padding(.bottom, fabClearance)
        }
    }
}

/// `MedicationsScreen.kt:258`.
private let fabClearance: CGFloat = 88

// MARK: - Previews

/// The fixture the previews share (`MedicationsScreen.kt:260-306`, which needs only one preview
/// because Compose renders light and dark from a single `@PreviewLightDark`).
///
/// A namespace rather than loose file-scope constants: everything preview-only is then one
/// `private enum` a reader can skip, and nothing here can be mistaken for screen state.
private enum PreviewData {
    /// Kotlin's `Metformin`, with its stock below its threshold so the low-stock chip is drawn.
    static let metformin = MedicationListItem(
        medication: Medication(
            id: "m1",
            name: "Metformin",
            form: .tablet,
            strengthValue: 500.0,
            strengthUnit: "mg",
            instructions: nil,
            stockCount: 8.0,
            stockThreshold: 10.0,
            startDateEpochDay: 20600,
            endDateEpochDay: nil,
            isActive: true
        ),
        schedules: [
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
            )
        ],
        recordedDosePercent: 92
    )

    /// No Kotlin twin: the two branches the Kotlin preview does not exercise — reminders off, and
    /// nothing recorded yet, so the bar is absent rather than 0%.
    static let insulin = MedicationListItem(
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
        recordedDosePercent: nil
    )
}

#Preview("Medications list") {
    MedicationsScreen(
        state: MedicationsUiState(isLoading: false, medications: [PreviewData.metformin, PreviewData.insulin]),
        onEvent: { _ in },
        onAddMedication: {},
        onOpenMedication: { _ in }
    )
}

#Preview("Medications list — empty") {
    MedicationsScreen(
        state: MedicationsUiState(isLoading: false),
        onEvent: { _ in },
        onAddMedication: {},
        onOpenMedication: { _ in }
    )
}
