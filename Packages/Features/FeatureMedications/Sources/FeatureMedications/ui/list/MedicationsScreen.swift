// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsScreen.kt` in its M15 shape.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `LazyVerticalGrid(Fixed(2))` + `contentPadding`  → `ScrollView` + `LazyVGrid(2 flexible columns)`
//                                                      + `.padding`.
//   `GridItemSpan(maxLineSpan)`                      → a full-width row outside the grid, because
//                                                      SwiftUI's `LazyVGrid` has no span: the header
//                                                      and the two content states are siblings of
//                                                      the grid inside one `LazyVStack`, which draws
//                                                      the same column.
//   `CircularProgressIndicator`                      → `ProgressView()`.
//   `Icons.Filled.*`                                 → SF Symbol names.
//   `LocalLocale.current.platformLocale`             → `@Environment(\.locale)`.
//
// The header lives in `MedicationsHeader.swift` and the card in `MedicationCard.swift`: this file is
// the screen's own shape — the grid, the three content states, the FAB and the confirmation.
//
// **NO CLEARANCE CONSTANTS, and no `SalusTopBarDefaults` / `SalusBottomBarDefaults` twin.** Kotlin
// reserves both bars in its `contentPadding` because they float over the root; on iOS the native
// navigation bar and tab bar live in the safe area, so scroll content clears them by itself
// (spec §2.4). The one inset that survives is the FAB's, which does float.
//
// **THE EXTENDED FAB IS AN ICON FAB HERE.** Android draws `SalusExtendedFab(text, icon)` bottom
// centre (`MedicationsScreen.kt:160-168`); `SalusUI.SalusFab` has no extended variant — Task 2's
// brief did not ask for one and this task may not touch `SalusUI` — so the plus disc keeps the
// bottom-trailing placement it has had since M5 and `medications_fab_add` becomes its
// `accessibilityLabel`. Recorded as a deviation in `task-7-report.md`.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`MedicationsScreen.kt:79-91`).
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
                    // Cards open the detail screen; editing is an action on it, not the card's job
                    // (`MedicationsScreen.kt:88`).
                    onOpenMedication: { id in navigate(MedicationDetailKey(id: id)) }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Built once and owned for the lifetime of the route — which is the whole app session,
            // because `TabView` keeps a root alive. That is exactly why the ViewModel re-reads the
            // clock on every emission rather than holding the day it was built on
            // (`MedicationsViewModel.swift`, the M15 critical fix).
            guard viewModel == nil, let module else { return }
            viewModel = module.makeMedicationsViewModel()
        }
    }

    private func navigate(_ key: some Hashable & Sendable) {
        module?.navigator.navigate(key)
    }
}

/// The stateless list (`MedicationsScreen.kt:98-181`).
struct MedicationsScreen: View {
    let state: MedicationsUiState
    let onEvent: (MedicationsEvent) -> Void
    let onAddMedication: () -> Void
    let onOpenMedication: (String) -> Void

    @Environment(\.salusTheme) private var theme

    /// §10: reduce motion keeps the fade and drops the move, on both platforms.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        ZStack(alignment: .bottomTrailing) {
            scroller
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `MedicationsScreen.kt:160-168`, as an icon disc — see this file's header.
            SalusFab(
                systemImage: "plus",
                contentDescription: MedicationsStrings.fabAdd,
                action: onAddMedication
            )
            .padding(SalusSpacing.lg)
        }
        .background(theme.colorScheme.background)
        // The screen title. The shell's root toolbar draws it in the navigation bar's principal
        // slot; `.navigationTitle` is still what names the back button of everything this root
        // pushes, and what VoiceOver reads for the screen. M15 deleted `medications_title` on
        // Android because its custom top bar needed no such label — the ruling that iOS keeps the
        // key is recorded in `MedicationsStrings.swift`.
        .navigationTitle(Text(verbatim: MedicationsStrings.title))
        // `MedicationsScreen.kt:171-180`. The confirm label is the shared `salus_delete`, exactly
        // as Kotlin reaches into `core.ui`'s string rather than the feature's own.
        .salusConfirmDialog(
            isPresented: isDeleteConfirmPresented,
            title: MedicationsStrings.deleteTitle(state.pendingDelete?.name ?? ""),
            message: MedicationsStrings.deleteMessage,
            confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
            dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
        )
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard — the shape
        // `AboutScreen` has carried since M8.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

    /// The one scrolling column: the header, then whichever of the three content states holds
    /// (`MedicationsScreen.kt:104-158`).
    private var scroller: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SalusSpacing.md) {
                MedicationsHeader(state: state)
                content
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.top, SalusSpacing.lg)
            // Keeps the last row of cards scrollable above the floating action button
            // (`MedicationsScreen.kt:112`, `:353`).
            .padding(.bottom, MedicationsScreenDefaults.fabClearance)
        }
    }

    /// `MedicationsScreen.kt:120-157`.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(SalusSpacing.xxl)
        } else if state.medications.isEmpty {
            SalusEmptyState(
                systemImage: "pills",
                title: MedicationsStrings.emptyTitle,
                message: MedicationsStrings.emptyBody,
                accent: theme.extendedColors.medications,
                actionLabel: MedicationsStrings.add,
                onAction: onAddMedication
            )
            .frame(maxWidth: .infinity)
        } else {
            grid
        }
    }

    /// `items(state.medications, key = { it.medication.id })` inside the two-column grid
    /// (`MedicationsScreen.kt:144-156`).
    private var grid: some View {
        LazyVGrid(columns: MedicationsScreenDefaults.columns, alignment: .leading, spacing: SalusSpacing.md) {
            ForEach(state.medications) { item in
                MedicationCard(
                    item: item,
                    onTap: { onOpenMedication(item.medication.id) },
                    onDelete: { onEvent(.deleteRequested(item.medication.id)) },
                    onTakeDose: { dose in onEvent(.takeDoseClicked(dose)) }
                )
                // §10 list mutation: fade + vertical move on add, remove and undo's return.
                // Reduce motion keeps the fade and drops the move (`MedicationsScreen.kt:151-154`).
                .transition(
                    reduceMotion
                        ? SalusMotion.listMutationReducedMotionTransition
                        : SalusMotion.listMutationTransition
                )
            }
        }
        // Every mutation path — delete confirmed, undo's return, an editor save landing — arrives
        // as a state change the container observes, so the animation rides with it wherever it
        // came from.
        .animation(
            reduceMotion
                ? SalusMotion.listMutationReducedMotionAnimation
                : SalusMotion.listMutationAnimation,
            value: state.medications
        )
    }
}

/// The screen's own measurements. Not design tokens — a column count and a FAB inset.
enum MedicationsScreenDefaults {
    /// `GridCells.Fixed(GRID_COLUMNS)` with `horizontalArrangement = spacedBy(md)`
    /// (`MedicationsScreen.kt:106`, `:114`, `:349`).
    static let columns = [
        GridItem(.flexible(), spacing: SalusSpacing.md, alignment: .top),
        GridItem(.flexible(), spacing: SalusSpacing.md, alignment: .top)
    ]

    /// `FabRow = SalusSpacing.xxl + SalusSpacing.xl` (`MedicationsScreen.kt:353`) — enough for the
    /// last row of cards to clear the floating button.
    static let fabClearance = SalusSpacing.xxl + SalusSpacing.xl
}

// MARK: - Previews

/// The fixture the previews share (`MedicationsPreviewData.kt`).
///
/// A namespace rather than loose file-scope constants: everything preview-only is then one
/// `private enum` a reader can skip, and nothing here can be mistaken for screen state.
private enum PreviewData {
    static let today = 20700

    /// Kotlin's `Metformin`, with its stock below its threshold so the bar draws rose, and a dose
    /// still outstanding this morning so the card offers "Hemen Al".
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
        recordedDosePercent: 92,
        dayStatus: .pending,
        nextDoseMinuteOfDay: 9 * 60,
        dueDose: PendingDose(scheduleId: "s1", epochDay: today, minuteOfDay: 9 * 60)
    )

    /// The branches the first card does not exercise: reminders off, nothing recorded yet (so no
    /// share on the tile), as-needed (so no clock time and no due dose).
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
        recordedDosePercent: nil,
        dayStatus: .asNeeded
    )

    static let loaded = MedicationsUiState(
        isLoading: false,
        medications: [metformin, insulin],
        nextDoseMinuteOfDay: 9 * 60,
        todayEpochDay: today
    )
}

// The eight-panel fan-out every restyled surface gets (spec §7): one render per premium palette in
// both modes, so a palette regression is visible without opening the app.
#Preview("Medications list") {
    SalusPreviewPalettes {
        MedicationsScreen(
            state: PreviewData.loaded,
            onEvent: { _ in },
            onAddMedication: {},
            onOpenMedication: { _ in }
        )
    }
}

#Preview("Medications list — empty") {
    SalusPreviewPalettes {
        MedicationsScreen(
            state: MedicationsUiState(isLoading: false, todayEpochDay: PreviewData.today),
            onEvent: { _ in },
            onAddMedication: {},
            onOpenMedication: { _ in }
        )
    }
}

// The tab root at the largest text size the design is checked against — Kotlin's
// `@Preview(fontScale = 1.3f)` (`MedicationsScreen.kt:368-376`), and the step spec §7 names for iOS.
#Preview("Medications list — xxxLarge") {
    MedicationsScreen(
        state: PreviewData.loaded,
        onEvent: { _ in },
        onAddMedication: {},
        onOpenMedication: { _ in }
    )
    .dynamicTypeSize(.xxxLarge)
}
