// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsScreen.kt:102-115`, `:124-141`, `:184-246`, `:286-382` — the screen header, the
// loading/empty/list content, one row, and the value formatters they share.
//
// Split out of `VitalsScreen.swift` in iOS-M7, the way `MedicationDetailSections.swift` was split
// out of `MedicationDetailScreen.swift` and for the same reason: the screen file stays the
// screen's shape, and neither file approaches the 500-line limit once the second and third vital
// types land. Kotlin keeps all of it in one file because a `private @Composable` is invisible
// outside it; Swift has no per-file privacy for a `View` used from another file, so these are
// internal types rather than private computed properties. Nothing outside this package can name
// them — the package exports the Route and nothing else.
//
// This is a move, not a rewrite: every view below draws exactly what the M2 screen drew, and the
// only change of substance is that `header` and `content` now take the state they read as
// parameters rather than closing over `VitalsScreen`'s stored properties.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// `VitalsScreen.kt:102-115`. The trends action is deliberately ungated: a free user reaches
/// the screen and meets its own lock.
struct VitalsListHeader: View {
    let onOpenTrends: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusScreenHeader(title: VitalsStrings.title) {
            Button(action: onOpenTrends) {
                Label(VitalsStrings.openTrends, systemImage: "chart.line.uptrend.xyaxis")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(theme.colorScheme.onBackground)
            }
        }
    }
}

/// `VitalsScreen.kt:124-141` — the loading spinner, the empty state, or the list.
///
/// The M2 `content` property carried an `@ViewBuilder`; a `View`'s own `body` is already one.
struct VitalsListContent: View {
    let state: VitalsUiState
    let onEvent: (VitalsEvent) -> Void
    let onAddEntry: (VitalType) -> Void
    let onEditEntry: (VitalsListItem) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
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
                Text(verbatim: headerText)
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
                Text(verbatim: range.vitalsLabel).tag(range)
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
            Text(verbatim: entry.headline)
                .font(SalusTypography.titleMedium.font)
                .foregroundStyle(theme.colorScheme.onSurface)
            Text(verbatim: entry.measuredAt.formatted(pattern: rowDatePattern))
                .font(SalusTypography.bodyMedium.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            if let supporting = entry.supportingText {
                Text(verbatim: supporting)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            if let note = entry.note {
                Text(verbatim: note)
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
