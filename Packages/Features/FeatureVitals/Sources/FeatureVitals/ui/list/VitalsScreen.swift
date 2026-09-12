// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsScreen.kt` — the route and the screen's shape. The list's own pieces live beside
// it: `VitalsListSections.swift`, `VitalsChartCard.swift`, `VitalsRow.swift`,
// `VitalsFormatting.swift`.
//
// Material → SwiftUI, M15 shapes:
//   `SalusSegmentedTabs(options:selected:label:)` → the same component (spec §3.3). The M2
//                               `Picker(.segmented)` mapping is **reversed** here, which is the
//                               spec's own instruction for every use Android draws as
//                               `SalusSegmentedTabs`.
//   `SalusFab(icon:)`         → `SalusUI.SalusFab`, unchanged.
//   `AlertDialog`             → `.salusConfirmDialog(isPresented:…)`.
//
// **The trends action moved out of the navigation bar.** Task 5 left it as a `ToolbarItem` beside
// the shell's bell and avatar, with a note that Android M15 had moved it. Android's M15 screen puts
// it in the chart section header's trailing slot (`VitalsScreen.kt:201-212`), so it is there now —
// the bar carries only the shell's own three controls, and QA §5.2.7 / §6's "third trailing
// control" risk closes with it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`VitalsScreen.kt:70-93`).
///
/// - Parameter onOpenTrends: trends belong to another feature, whose navigation key this one cannot
///   see, so the shell fills the callback in (`VitalsNavigation.kt:24-28`, spec §4).
public struct VitalsRoute: View {
    private let onOpenTrends: () -> Void

    @Environment(\.vitalsModule) private var module
    /// The in-app language pick the shell publishes (`RootView+Locale.swift`). The chart's axis
    /// labels are built in the ViewModel, which has no environment of its own, so the route is
    /// where the two meet — `Locale.current` there would be the device's language, not the pick.
    @Environment(\.locale) private var locale
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
                let created = module.makeVitalsViewModel()
                created.setLocale(locale)
                viewModel = created
                return
            }
            viewModel.setLocale(locale)
            // Every later appearance — the pop-back from one of the three editors above all —
            // reopens the window with a fresh `until`. This is Android's `WhileSubscribed(5_000)`
            // re-subscribe (`VitalsViewModel.kt:89-92`) restarting `flatMapLatest`
            // (`VitalsViewModel.kt:53-54`); without it an entry saved just now sits past the
            // window's fixed `until` and never shows up. See
            // `VitalsViewModel.restartHistoryObservation()`.
            viewModel.restartHistoryObservation()
        }
        // A language switch re-identifies the tabs, so this route is normally rebuilt with it; the
        // observer is what keeps the chart honest if it ever is not (the pick can also change while
        // the route is alive, from the settings screen inside the same tab).
        .onChange(of: locale) { _, picked in
            viewModel?.setLocale(picked)
        }
    }

    /// `VitalsScreen.kt:78-84` — one key per `VitalType`, exhaustive on both platforms.
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

/// The stateless list (`VitalsScreen.kt:95-175`).
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
                typeTabs
                VitalsListContent(
                    state: state,
                    onEvent: onEvent,
                    onAddEntry: onAddEntry,
                    onEditEntry: onEditEntry,
                    onOpenTrends: onOpenTrends
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `VitalsScreen.kt:153-162` — unconditional, for every type, and it opens the editor
            // of the type the tabs have selected.
            SalusFab(systemImage: "plus", contentDescription: VitalsStrings.addEntry) {
                onAddEntry(state.selectedType)
            }
            .padding(SalusSpacing.lg)
        }
        .background(theme.colorScheme.background)
        // The screen title, which the shell's root toolbar draws in the navigation bar's principal
        // slot (`RootNavigationStack`). Kept although Android M15 deleted `vitals_title`: iOS needs
        // it for the back button of everything this root pushes, and for what VoiceOver reads —
        // a recorded divergence, not a missed deletion.
        .navigationTitle(Text(verbatim: VitalsStrings.title))
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
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard — the shape
        // `AboutScreen` has carried since M8.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// `VitalsScreen.kt:111-124` — the same segment control the Appointments tabs use: three equal
    /// segments, one per vital.
    ///
    /// The latest reading it used to carry now heads the chart card, and the range filter lives
    /// inside that card, so the screen's two selectors no longer read as the same control twice.
    private var typeTabs: some View {
        SalusSegmentedTabs(
            options: VitalType.allCases,
            selected: state.selectedType,
            label: \.vitalsLabel,
            onSelected: { onEvent(.typeSelected($0)) }
        )
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.md)
    }
}

// MARK: - Previews

/// `PreviewState` (`VitalsScreen.kt:377-432`).
private enum VitalsPreviewData {
    static let state = VitalsUiState(
        isLoading: false,
        selectedType: .weight,
        entries: [
            .weight(
                VitalsListItem.Weight(
                    id: "w1",
                    measuredAt: LocalDateTime(
                        date: LocalDate(year: 2026, month: 9, day: 10),
                        minuteOfDay: 9 * 60 + 41
                    ),
                    kilograms: 78.7,
                    note: nil,
                    delta: 0.4,
                    trend: .stable
                )
            ),
            .weight(
                VitalsListItem.Weight(
                    id: "w2",
                    measuredAt: LocalDateTime(
                        date: LocalDate(year: 2026, month: 9, day: 6),
                        minuteOfDay: 8 * 60 + 30
                    ),
                    kilograms: 78.3,
                    note: "After breakfast",
                    delta: -5.2,
                    trend: .falling
                )
            ),
            .weight(
                VitalsListItem.Weight(
                    id: "w3",
                    measuredAt: LocalDateTime(
                        date: LocalDate(year: 2026, month: 9, day: 1),
                        minuteOfDay: 8 * 60 + 10
                    ),
                    kilograms: 83.5,
                    note: nil
                )
            )
        ],
        chart: ChartUiModel(
            points: [
                ChartPoint(xEpochDay: 20697, y: 83.5),
                ChartPoint(xEpochDay: 20702, y: 78.3),
                ChartPoint(xEpochDay: 20706, y: 78.7)
            ],
            xLabel: { LocalDate(epochDay: $0).formatted(pattern: "d MMM", locale: Locale(identifier: "tr")) },
            yLabel: { String(format: "%.1f", locale: Locale(identifier: "tr"), Double($0)) }
        ),
        latestKilograms: 78.7
    )
}

#Preview("Vitals list") {
    SalusPreviewPalettes {
        VitalsScreen(
            state: VitalsPreviewData.state,
            onEvent: { _ in },
            onAddEntry: { _ in },
            onEditEntry: { _ in },
            onOpenTrends: {}
        )
    }
}

#Preview("Vitals list — empty") {
    SalusPreviewPalettes {
        VitalsScreen(
            state: VitalsUiState(isLoading: false),
            onEvent: { _ in },
            onAddEntry: { _ in },
            onEditEntry: { _ in },
            onOpenTrends: {}
        )
    }
}

#Preview("Vitals list — xxxLarge") {
    VitalsScreen(
        state: VitalsPreviewData.state,
        onEvent: { _ in },
        onAddEntry: { _ in },
        onEditEntry: { _ in },
        onOpenTrends: {}
    )
    .dynamicTypeSize(.xxxLarge)
}
