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
            // Every later appearance — the pop-back from the weight editor above all — reopens the
            // window with a fresh `until`. This is Android's `WhileSubscribed(5_000)` re-subscribe
            // (`VitalsViewModel.kt:87-90`) restarting `flatMapLatest` (`VitalsViewModel.kt:51-53`);
            // without it an entry saved just now sits past the window's fixed `until` and never
            // shows up. See `VitalsViewModel.restartHistoryObservation()`.
            viewModel.restartHistoryObservation()
        }
    }

    /// `VitalsScreen.kt:74-80`. M2 owns one editor key; M7 adds the other two arms here.
    private func openEditor(_ type: VitalType, entryId: String?) {
        // TODO(M7): drop the `type == .weight` half — blood pressure and glucose silently no-op
        // here because their editor keys do not exist yet (`VitalsScreen.kt:74-80` navigates all
        // three). M7 replaces this guard with the three-way switch.
        guard let module, type == .weight else { return }
        module.navigator.navigate(WeightEditorKey(entryId: entryId))
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
                header
                typeSelector
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `VitalsScreen.kt:144-151`. TODO(M7): drop the condition — the FAB is hidden for the
            // other two types only because their editor keys do not exist yet, so `onAddEntry` has
            // nothing to push. M7 removes this `if` rather than adding a branch.
            if state.selectedType == .weight {
                SalusFab(systemImage: "plus", contentDescription: VitalsStrings.addEntry) {
                    onAddEntry(state.selectedType)
                }
                .padding(SalusSpacing.lg)
            }
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

    /// `VitalsScreen.kt:102-115`. The trends action is deliberately ungated: a free user reaches
    /// the screen and meets its own lock.
    private var header: some View {
        SalusScreenHeader(title: VitalsStrings.title) {
            Button(action: onOpenTrends) {
                Label(VitalsStrings.openTrends, systemImage: "chart.line.uptrend.xyaxis")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(theme.colorScheme.onBackground)
            }
        }
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
                Text(type.vitalsLabel).tag(type)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }

    /// `VitalsScreen.kt:124-141`.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.entries.isEmpty {
            SalusEmptyState(
                systemImage: "heart.text.square",
                title: emptyTitle,
                accent: theme.extendedColors.vitals,
                actionLabel: VitalsStrings.addEntry,
                onAction: { onAddEntry(state.selectedType) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            entryList
        }
    }

    /// `VitalsScreen.kt:184-246`.
    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SalusSpacing.md) {
                Text(headerText)
                    .font(SalusTypography.headlineSmall.font)
                    .foregroundStyle(theme.colorScheme.onBackground)

                rangeSelector

                if let chart = state.chart {
                    SalusCard(contentPadding: SalusSpacing.md) {
                        SalusLineChart(
                            model: chart,
                            lineColor: theme.extendedColors.vitals.accent,
                            // The latest-value summary doubles as the chart's spoken description.
                            contentDescription: headerText
                        )
                        .frame(height: chartHeight)
                    }
                }

                ForEach(state.entries) { entry in
                    VitalsRow(
                        entry: entry,
                        onTap: { onEditEntry(entry) },
                        onDelete: { onEvent(.deleteRequested(entry.id)) }
                    )
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.top, SalusSpacing.sm)
            // Keeps the last row scrollable above the floating action button
            // (`VitalsScreen.kt:385-386`).
            .padding(.bottom, fabClearance)
        }
    }

    /// `VitalsScreen.kt:207-217` — a row of `FilterChip`s, which carries no label either.
    private var rangeSelector: some View {
        Picker(
            selection: Binding(
                get: { state.selectedRange },
                set: { onEvent(.rangeSelected($0)) }
            )
        ) {
            ForEach(ChartRange.allCases, id: \.self) { range in
                Text(range.vitalsLabel).tag(range)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// `VitalsScreen.kt:248-277`.
    private var headerText: String {
        switch state.selectedType {
        case .weight:
            state.latestKilograms.map { VitalsStrings.latestWeight(formatKg($0)) } ?? VitalsStrings.empty

        case .bloodPressure:
            state.latestBloodPressure.map { VitalsStrings.latestBloodPressure(formatBloodPressure($0)) }
                ?? VitalsStrings.emptyBloodPressure

        case .bloodGlucose:
            state.latestGlucose.map { VitalsStrings.latestGlucose(formatGlucose($0.value, unit: $0.unit)) }
                ?? VitalsStrings.emptyGlucose
        }
    }

    /// `VitalsScreen.kt:279-284`.
    private var emptyTitle: String {
        switch state.selectedType {
        case .weight: VitalsStrings.empty
        case .bloodPressure: VitalsStrings.emptyBloodPressure
        case .bloodGlucose: VitalsStrings.emptyGlucose
        }
    }
}

/// One row of the list (`VitalsScreen.kt:286-331`).
///
/// **Why this is not `SalusCard(onTap:)` with the trash button inside it.** That is what Compose
/// does — `SalusCard(onClick = onClick)` with an `IconButton` in its content — and it works there
/// because Compose dispatches a tap to the innermost clickable. `SalusCard(onTap:)` on iOS is
/// `Button(action: onTap) { surface }` (`SalusCard.swift:33-34`), so the trash button would sit
/// **inside another Button's label**, where SwiftUI's default styles treat it as decoration and
/// route the tap to the outer button: the row would open the editor and `deleteRequested` would
/// never fire.
///
/// So the outer `Button` is gone. The card is the plain, non-interactive `SalusCard`, "open" is a
/// tap gesture on the text column, and the trash stays a real `Button` — and the two tap targets
/// are **disjoint by layout**, not merely ordered by dispatch rules: the column is a sibling of the
/// button in the `HStack`, so no tap can reach both and there is nothing left to swallow anything.
/// The gesture route costs the row its automatic button semantics, so they are added back by hand
/// below; VoiceOver still reaches both actions, the row's own and the trash button's.
private struct VitalsRow: View {
    let entry: VitalsListItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard {
            HStack(alignment: .center, spacing: SalusSpacing.sm) {
                details
                    // The column already fills every point the trash button does not, and
                    // `contentShape` makes the empty space beside a short value tappable too.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    // A tap gesture is invisible to VoiceOver, where Compose's `Card(onClick =)`
                    // is announced as a button. `.combine` reads the row's lines as one element,
                    // the trait announces it as activatable, and the action is what a double tap
                    // runs — the three together are what the outer `Button` used to provide.
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, onTap)

                // A sibling of the column, not a descendant of any Button: this is the whole fix.
                Button(action: onDelete) {
                    Label(VitalsStrings.delete, systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(theme.colorScheme.error)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// `VitalsScreen.kt:296-320`.
    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.headline)
                .font(SalusTypography.titleMedium.font)
                .foregroundStyle(theme.colorScheme.onSurface)
            Text(entry.measuredAt.formatted(pattern: rowDatePattern))
                .font(SalusTypography.bodyMedium.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            if let supporting = entry.supportingText {
                Text(supporting)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            if let note = entry.note {
                Text(note)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

// MARK: - Formatting

/// `VitalsScreen.kt:333-338`.
extension VitalsListItem {
    var headline: String {
        switch self {
        case let .weight(item): formatKg(item.kilograms)
        case let .bloodPressure(item): formatBloodPressure(item)
        case let .glucose(item): formatGlucose(item.value, unit: item.unit)
        }
    }

    /// `VitalsScreen.kt:340-345`.
    var supportingText: String? {
        switch self {
        case .weight: nil
        case let .bloodPressure(item): item.pulse.map(VitalsStrings.pulseValue)
        case let .glucose(item): item.measurementContext?.vitalsLabel
        }
    }
}

/// `VitalsScreen.kt:353-357`.
extension VitalType {
    var vitalsLabel: String {
        switch self {
        case .weight: VitalsStrings.typeWeight
        case .bloodPressure: VitalsStrings.typeBloodPressure
        case .bloodGlucose: VitalsStrings.typeGlucose
        }
    }
}

/// `VitalsScreen.kt:359-364`.
extension MeasurementContext {
    var vitalsLabel: String {
        switch self {
        case .fasting: VitalsStrings.contextFasting
        case .postMeal: VitalsStrings.contextPostMeal
        case .bedtime: VitalsStrings.contextBedtime
        case .random: VitalsStrings.contextRandom
        }
    }
}

/// `VitalsScreen.kt:366-371`.
extension ChartRange {
    var vitalsLabel: String {
        switch self {
        case .week: VitalsStrings.rangeWeek
        case .month: VitalsStrings.rangeMonth
        case .quarter: VitalsStrings.rangeQuarter
        case .year: VitalsStrings.rangeYear
        }
    }
}

/// `VitalsScreen.kt:373-374`. `Locale.current` is Android's `Locale.getDefault()`, so a Turkish
/// device reads "72,5 kg" on both platforms.
func formatKg(_ kilograms: Double) -> String {
    String(format: "%.1f kg", locale: .current, kilograms)
}

/// `VitalsScreen.kt:376-377`.
func formatBloodPressure(_ item: VitalsListItem.BloodPressure) -> String {
    String(format: "%lld/%lld mmHg", locale: .current, item.systolic, item.diastolic)
}

/// `VitalsScreen.kt:379-382`.
func formatGlucose(_ value: Double, unit: GlucoseUnit) -> String {
    switch unit {
    case .mgDl: String(format: "%.0f mg/dL", locale: .current, value)
    case .mmolL: String(format: "%.1f mmol/L", locale: .current, value)
    }
}

/// `VitalsScreen.kt:293`.
private let rowDatePattern = "d MMM yyyy, HH:mm"
/// `VitalsScreen.kt:384`.
private let chartHeight: CGFloat = 220
/// `VitalsScreen.kt:386`.
private let fabClearance: CGFloat = 88

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
