// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// TrendsScreen.kt`.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded:
//   `TopAppBar` + `navigationIcon` (back) → `.navigationTitle(_:)` + the stack's own back button
//     (see `AiSummaryScreen.swift:4-9` for the settled reasoning — `onBack` has no parameter
//     here, and `trends_back` stays in the catalog for Android parity).
//   `FilterChip` row (ranges) → `Picker("", selection:)` with `.pickerStyle(.segmented)`. Vitals
//     maps its `ChartRange` chips the same way, so the two range selectors stay one look.
//   `CircularProgressIndicator` → `ProgressView()`.
//   `SalusEmptyState` → the same component, with the SF Symbol twin of each Material icon.
//
// No `Scaffold` twin and no `NavigationStack`: the shell owns the one stack, its insets and the
// tab bar, and a feature never writes `.toolbar(…, for: .tabBar)` (`CLAUDE.md`).

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`TrendsScreen.kt:87-100`).
///
/// The module comes from the environment, exactly as `koinViewModel()` reaches Koin's graph — see
/// `TrendsModule.swift` for what the composition root injects.
public struct TrendsRoute: View {
    @Environment(\.trendsModule) private var module
    @State private var viewModel: TrendsViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                TrendsScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(TrendsStrings.title)
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeTrendsViewModel()
        }
    }
}

/// The stateless screen (`TrendsScreen.kt:104-164`).
struct TrendsScreen: View {
    let state: TrendsUiState
    let onEvent: (TrendsEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            RangeFilter(selected: state.range) { onEvent(.rangeSelected($0)) }

            // Only the first load gets the whole body: until it answers there is nothing on
            // screen worth keeping, and `data` still holds the locked default that an entitled
            // user must never see a frame of (`TrendsScreen.kt:140-145`). A range switch is the
            // one place a later load must not blank the screen — see the opacity below, which is
            // the reload dim Android applies (`TrendsScreen.kt:152-162`).
            if !state.hasLoaded, state.isLoading {
                bodySpacer
            } else {
                // Every load keeps the body it is replacing and dims it while the next window
                // is being read. Task 1 ships the empty `Ready` shell that draws no cards — the
                // four analyses arrive with later tasks.
                TrendsBody(state: state, onEvent: onEvent)
                    .opacity(state.isLoading ? TrendsScreen.reloadingAlpha : TrendsScreen.opaque)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
    }

    private var bodySpacer: some View {
        VStack {
            Spacer()
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `RELOADING_ALPHA` (`TrendsScreen.kt:1109`) — how far the previous body is dimmed while the
    /// next window is being read.
    private static let reloadingAlpha = 0.4

    /// `OPAQUE` (`TrendsScreen.kt:1112`) — nothing in flight, nothing dimmed.
    private static let opaque = 1.0
}

/// One body per `TrendsData` member (`TrendsScreen.kt:172-220`).
///
/// Task 1's `Ready` body is an empty scrolling column; the four cards land with their analyses
/// in later tasks, and the locked body is Android's `LockedCallout` until Task 6 fills it with
/// the sample-data backdrop.
struct TrendsBody: View {
    let state: TrendsUiState
    let onEvent: (TrendsEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        switch state.data {
        case .locked:
            LockedBody(onUpgrade: { onEvent(.upgradeClicked) })

        case .empty:
            SalusEmptyState(
                systemImage: "chart.line.uptrend.xyaxis",
                title: TrendsStrings.emptyTitle,
                message: TrendsStrings.emptyMessage,
                accent: theme.extendedColors.trends
            )

        case .failed:
            SalusEmptyState(
                systemImage: "exclamationmark.triangle",
                title: TrendsStrings.errorTitle,
                message: TrendsStrings.errorMessage,
                accent: theme.extendedColors.trends,
                actionLabel: TrendsStrings.errorAction,
                onAction: { onEvent(.retryClicked) }
            )

        case let .ready(ready):
            ReadyBody(state: state, ready: ready)
        }
    }
}

/// The scrollable column a `.ready` answer draws its cards into (`TrendsScreen.kt:234-250`).
///
/// Task 1 ships the empty shell — every analysis field is `nil`, so no card is built. Each later
/// task adds the card its own field feeds, exactly as Android's `TrendsCardStack` maps a `let`
/// per field (`TrendsScreen.kt:245-248`).
struct ReadyBody: View {
    let state: TrendsUiState
    let ready: TrendsReady

    var body: some View {
        ScrollView {
            VStack(spacing: SalusSpacing.md) {
                // Task 2 adds:   ready.timeOfDay.map { TimeOfDayCard($0, unit: …) }
                // Task 3 adds:   ready.overlay.map { MetricOverlayCard($0, unit: …) }
                // Task 4 adds:   ready.doseWeeks.map { DoseWeeksCard($0, unit: …) }
                // Task 5 adds:   ready.summaries.map { MetricSummaryCard($0, unit: …) }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The free user's whole screen: the paywall callout card (`TrendsScreen.kt:842-871`).
///
/// Task 6 replaces this plain callout with the real sample-data stack behind a blur and scrim;
/// until then the locked body is the one card this screen has to sell.
struct LockedBody: View {
    let onUpgrade: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack {
            Spacer()
            SalusCard(contentPadding: SalusSpacing.lg) {
                Text(verbatim: TrendsStrings.lockedTitle)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer().frame(height: SalusSpacing.sm)
                Text(verbatim: TrendsStrings.lockedMessage)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                Spacer().frame(height: SalusSpacing.lg)
                SalusPillButton(text: TrendsStrings.lockedAction, action: onUpgrade)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SalusSpacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The range-selector segmented control (`TrendsScreen.kt:729-750`, Android's
/// `TrendsRangeFilter`).
private struct RangeFilter: View {
    let selected: TrendsRange
    let onSelect: (TrendsRange) -> Void

    var body: some View {
        Picker("", selection: Binding(
            get: { selected },
            set: { onSelect($0) }
        )) {
            Text(verbatim: TrendsStrings.rangeMonth).tag(TrendsRange.month)
            Text(verbatim: TrendsStrings.rangeQuarter).tag(TrendsRange.quarter)
            Text(verbatim: TrendsStrings.rangeHalfYear).tag(TrendsRange.halfYear)
            Text(verbatim: TrendsStrings.rangeYear).tag(TrendsRange.year)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}
