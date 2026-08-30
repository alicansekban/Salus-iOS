// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsScreen.kt`.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded:
//   `SingleChoiceSegmentedButtonRow` (types) → `Picker(…).pickerStyle(.segmented)`.
//   `FilterChip` row (ranges)                → `Picker(…).pickerStyle(.segmented)`. There is no
//                                              chip spec in `design-tokens.md`, so no
//                                              `SalusFilterChip` is invented for one call site.
//   `LazyColumn`                             → `ScrollView` + `LazyVStack`.
//   `CircularProgressIndicator`              → `ProgressView()`.
//   `IconButton`                             → `Button` with a `Label`, icons as SF Symbols.
//   `AlertDialog`                            → `.salusConfirmDialog(isPresented:…)`.
//
// The list's own pieces — the screen header, the loading/empty/list content, the rows and the
// value formatters (`VitalsScreen.kt:102-115`, `:124-141`, `:184-246`, `:286-382`) — live in
// `VitalsListSections.swift`, split off in iOS-M7 the way `MedicationDetailSections.swift` was
// split out of `MedicationDetailScreen.swift`. This file keeps the route and the screen's shape.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`VitalsScreen.kt:66-89`).
///
/// - Parameter onOpenTrends: trends belong to another feature, whose navigation key this one cannot
///   see, so the shell fills the callback in (`VitalsNavigation.kt:24-28`, spec §4).
public struct VitalsRoute: View {
    private let onOpenTrends: () -> Void

    @Environment(\.vitalsModule) private var module
    @State private var viewModel: VitalsViewModel?

    public init(onOpenTrends: @escaping () -> Void) {
        self.onOpenTrends = onOpenTrends
    }

    public var body: some View {
        Group {
            if let viewModel {
                VitalsScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onAddEntry: { type in openEditor(type, entryId: nil) },
                    onEditEntry: { item in openEditor(item.vitalType, entryId: item.id) },
                    onOpenTrends: onOpenTrends
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let module else { return }
            guard let viewModel else {
                // First appearance: `init` opens the first history window. The ViewModel is owned
                // for the lifetime of the route and is never recreated below.
                viewModel = module.makeVitalsViewModel()
                return
            }
            // Every later appearance — the pop-back from one of the three editors above all —
            // reopens the window with a fresh `until`. This is Android's `WhileSubscribed(5_000)`
            // re-subscribe (`VitalsViewModel.kt:87-90`) restarting `flatMapLatest`
            // (`VitalsViewModel.kt:51-53`); without it an entry saved just now sits past the
            // window's fixed `until` and never shows up. See
            // `VitalsViewModel.restartHistoryObservation()`.
            viewModel.restartHistoryObservation()
        }
    }

    /// `VitalsScreen.kt:74-80` — one key per `VitalType`, exhaustive on both platforms.
    private func openEditor(_ type: VitalType, entryId: String?) {
        guard let module else { return }
        switch type {
        case .weight:
            module.navigator.navigate(WeightEditorKey(entryId: entryId))

        case .bloodPressure:
            module.navigator.navigate(BloodPressureEditorKey(entryId: entryId))

        case .bloodGlucose:
            module.navigator.navigate(GlucoseEditorKey(entryId: entryId))
        }
    }
}

/// The stateless list (`VitalsScreen.kt:91-164`).
struct VitalsScreen: View {
    let state: VitalsUiState
    let onEvent: (VitalsEvent) -> Void
    let onAddEntry: (VitalType) -> Void
    let onEditEntry: (VitalsListItem) -> Void
    let onOpenTrends: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                VitalsListHeader(onOpenTrends: onOpenTrends)
                typeSelector
                VitalsListContent(
                    state: state,
                    onEvent: onEvent,
                    onAddEntry: onAddEntry,
                    onEditEntry: onEditEntry
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `VitalsScreen.kt:144-151` — unconditional, for every type.
            SalusFab(systemImage: "plus", contentDescription: VitalsStrings.addEntry) {
                onAddEntry(state.selectedType)
            }
            .padding(SalusSpacing.lg)
        }
        .background(theme.colorScheme.background)
        .salusConfirmDialog(
            isPresented: Binding(
                get: { state.pendingDeleteId != nil },
                set: { isPresented in
                    guard !isPresented else { return }
                    onEvent(.deleteDismissed)
                }
            ),
            title: VitalsStrings.deleteTitle,
            message: VitalsStrings.deleteMessage,
            confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
            dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
        )
    }

    /// `VitalsScreen.kt:166-182`.
    ///
    /// The label is empty because Kotlin's `SingleChoiceSegmentedButtonRow` has none, and inventing
    /// one would mean inventing user-facing copy the string catalog does not carry.
    private var typeSelector: some View {
        Picker(
            selection: Binding(
                get: { state.selectedType },
                set: { onEvent(.typeSelected($0)) }
            )
        ) {
            ForEach(VitalType.allCases, id: \.self) { type in
                Text(verbatim: type.vitalsLabel).tag(type)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}

#Preview("Vitals list") {
    VitalsScreen(
        state: VitalsUiState(
            isLoading: false,
            entries: [
                .weight(
                    VitalsListItem.Weight(
                        id: "w1",
                        measuredAt: LocalDateTime(
                            date: LocalDate(year: 2026, month: 8, day: 17),
                            minuteOfDay: 9 * 60 + 41
                        ),
                        kilograms: 72.5,
                        note: nil
                    )
                ),
                .weight(
                    VitalsListItem.Weight(
                        id: "w2",
                        measuredAt: LocalDateTime(
                            date: LocalDate(year: 2026, month: 8, day: 15),
                            minuteOfDay: 8 * 60 + 30
                        ),
                        kilograms: 72.9,
                        note: "After breakfast"
                    )
                )
            ],
            latestKilograms: 72.5
        ),
        onEvent: { _ in },
        onAddEntry: { _ in },
        onEditEntry: { _ in },
        onOpenTrends: {}
    )
}

#Preview("Vitals list — empty") {
    VitalsScreen(
        state: VitalsUiState(isLoading: false),
        onEvent: { _ in },
        onAddEntry: { _ in },
        onEditEntry: { _ in },
        onOpenTrends: {}
    )
}
