// Ported from `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/
// TrendsScreen.kt`.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded:
//   `TopAppBar` + `navigationIcon` (back) → `.navigationTitle(_:)` + the stack's own back button
//     (see `AiSummaryScreen.swift:4-9` for the settled reasoning — `onBack` has no parameter
//     here).
//   `FilterChip` row (ranges) → `SalusSegmentedTabs` over `TrendsRange` (M15 divergence (b),
//     spec §9); disabled while the body is locked.
//   `CircularProgressIndicator` → `ProgressView()`.
//   `SalusEmptyState` → the same component, with the SF Symbol twin of each Material icon.
//
// No `Scaffold` twin and no `NavigationStack`: the shell owns the one stack, its insets and the
// tab bar, and a feature never writes `.toolbar(…, for: .tabBar)` (`CLAUDE.md`).

import SalusDesignSystem
import SalusModel
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
            // `data != .locked` is the disabled condition: a free user's every range answers the
            // same locked body, so a tab that reacted would be pretending to do something
            // (`TrendsScreen.kt:88-92`).
            RangeFilter(
                selected: state.range,
                enabled: state.data != .locked
            ) { onEvent(.rangeSelected($0)) }

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
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (`AppointmentDetailScreen.swift`).
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
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
            LockedBody(state: state, onUpgrade: { onEvent(.upgradeClicked) })

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
                if let timeOfDay = ready.timeOfDay {
                    TimeOfDayCard(breakdown: timeOfDay, glucoseUnit: state.glucoseUnit)
                }
                if let overlay = ready.overlay {
                    MetricOverlayCard(overlay: overlay, glucoseUnit: state.glucoseUnit)
                }
                if let doseWeeks = ready.doseWeeks {
                    DoseWeeksCard(weeks: doseWeeks, glucoseUnit: state.glucoseUnit)
                }
                if let summaries = ready.summaries {
                    MetricSummaryCard(summaries: summaries, glucoseUnit: state.glucoseUnit)
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension VitalType {
    /// `VitalType.metricLabelRes()` (`TrendsScreen.kt:896-902`).
    var metricLabel: String {
        switch self {
        case .bloodPressure: TrendsStrings.metricBloodPressure
        case .bloodGlucose: TrendsStrings.metricGlucose
        // Never picked by the time-of-day analysis: when you step on the scale says nothing about
        // your weight. Mapped anyway so the switch stays exhaustive without an else.
        case .weight: TrendsStrings.metricWeight
        }
    }

    /// `VitalType.unitLabelRes(glucoseUnit)` (`TrendsScreen.kt:905-912`) — glucose is the one
    /// metric whose unit the user picks; the other two have exactly one.
    func unitLabel(_ glucoseUnit: GlucoseUnit) -> String {
        switch self {
        case .bloodPressure: TrendsStrings.unitBloodPressure

        case .bloodGlucose:
            switch glucoseUnit {
            case .mgDl: TrendsStrings.unitGlucose
            case .mmolL: TrendsStrings.unitGlucoseMmol
            }

        case .weight: TrendsStrings.unitWeight
        }
    }
}

/// The free user's whole screen: the real card stack drawn over invented records, put out of
/// reach, with the paywall sitting on top of it (`TrendsScreen.kt:752-808`).
///
/// It shows the *shape* of what a subscription buys without handing over one readable number.
/// The records behind it are made up (`sampleTrendsReady`), so there is nothing of the user's to
/// leak in the first place — the lock is about not making a free user read numbers that are not
/// theirs and calling them a preview.
///
/// Three separate things put the backdrop out of reach, because the obvious one does not work
/// everywhere: `.blur(radius: 16)` is the pretty one — unlike Android's `Modifier.blur`, a silent
/// no-op below API 31, SwiftUI's blur draws on every iOS 17 platform, so it is a finish here
/// rather than the guard (`D-M11-b`). The scrim is the guard, kept at `Color.background.opacity(0.6)`
/// for visual depth and Android parity. And touches are swallowed with `.allowsHitTesting(false)`
/// on the sample stack, so it cannot be scrolled or panned; the upgrade button lives in its own
/// layer with `.allowsHitTesting(true)` and is the only thing on this body anyone can reach
/// (`D-M11-a`).
struct LockedBody: View {
    let state: TrendsUiState
    let onUpgrade: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ZStack {
            // The entitled body's own `ReadyBody`, over `sampleTrendsReady`'s invented records.
            // Deliberately the real composables and not a picture of them: a mock-up would start
            // drifting away from the screen it is advertising the first time one of the cards
            // changed. Sharing the stack itself is what makes that guarantee hold for a card
            // *added* rather than changed.
            ReadyBody(state: state, ready: sampleTrendsReady())
                // Applied before the stack's own scroll and padding, so the chain reaching the
                // column is the one it always was: the backdrop is unreachable by touch and
                // blurred as a whole rather than card by card.
                .allowsHitTesting(false)
                .blur(radius: LockedBody.blurRadius)

            // Drawn as its own layer rather than as the stack's background: a background would
            // sit *behind* the cards, and this has to sit in front of them.
            theme.colorScheme.background
                .opacity(LockedBody.scrimOpacity)

            LockedCallout(onUpgrade: onUpgrade)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `LOCKED_BLUR_RADIUS` (`TrendsScreen.kt:1027`) — how far the sample stack is blurred.
    ///
    /// A radius of its own rather than a `SalusSpacing` value: this is a blur radius, not a
    /// distance between two things, and borrowing a layout token for it would make both harder to
    /// change. It is also the one part of the lock that Android cannot draw below API 31 — here
    /// it draws everywhere (`D-M11-b`).
    private static let blurRadius: CGFloat = 16

    /// The scrim over the sample stack (`TrendsScreen.kt` — `BLURRED_SCRIM_ALPHA`).
    ///
    /// Kept for visual depth and Android parity even though the blur already destroys the glyphs.
    private static let scrimOpacity = 0.6
}

/// The window selector (`TrendsScreen.kt:189-203`).
///
/// On the locked body `enabled` is false, which is a real disabled state — dimmed, not selectable,
/// announced as unavailable. It used to swallow the touches instead, so the tabs looked exactly as
/// live as they will once the subscription is: that reads as broken rather than as locked, because a
/// control that looks tappable and answers nothing is a bug to everyone who tries it. The paywall
/// card under the tabs is what explains the state; the selector only has to stop claiming it is
/// live (`SalusSegmentedTabs.kt:65-70`).
private struct RangeFilter: View {
    let selected: TrendsRange
    let enabled: Bool
    let onSelect: (TrendsRange) -> Void

    var body: some View {
        SalusSegmentedTabs(
            options: TrendsRange.allCases,
            selected: selected,
            enabled: enabled,
            label: { range in
                switch range {
                case .month: TrendsStrings.rangeMonth
                case .quarter: TrendsStrings.rangeQuarter
                case .halfYear: TrendsStrings.rangeHalfYear
                case .year: TrendsStrings.rangeYear
                }
            },
            onSelected: onSelect
        )
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}

// MARK: - Preview

// The 8-palette fan-out over the ready body (`TrendsScreen.kt:408-424`).
#Preview("Ready") {
    SalusPreviewPalettes {
        TrendsScreen(
            state: TrendsUiState(
                isLoading: false,
                hasLoaded: true,
                data: .ready(sampleTrendsReady())
            ),
            onEvent: { _ in }
        )
    }
}
