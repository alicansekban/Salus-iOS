// Ported from `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// AiSummaryScreen.kt` in its M15 shape.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded:
//   `TopAppBar` + `navigationIcon` (back) → `.navigationTitle(_:)` + the stack's own back button.
//     Compose has no chrome and must draw one; SwiftUI's `NavigationStack` already provides it,
//     and it pops the very `NavigationPath` the Navigator's `pop()` mutates, so the two ways back
//     stay one behaviour. `onBack` therefore has no parameter here.
//   `SingleChoiceSegmentedButtonRow` + `SegmentedButton` → `SalusSegmentedTabs` (M15 divergence
//     (b), spec §9 — the native `Picker(.segmented)` paints from a process-wide appearance proxy
//     and cannot follow the per-palette pill).
//   `CircularProgressIndicator` → `ProgressView()`.
//   `SalusEmptyState` → the same component, with the SF Symbol twin of each Material icon.
//   `Column(verticalScroll(rememberScrollState()))` → `ScrollView` + `VStack`.
//
// No `Scaffold` twin and no `NavigationStack`: the shell owns the one stack, its insets and the
// tab bar, and a feature never writes `.toolbar(…, for: .tabBar)` (`CLAUDE.md`).

import SalusAI
import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`AiSummaryScreen.kt:41-55`).
///
/// The module comes from the environment, exactly as `koinViewModel()` reaches Koin's graph — see
/// `AiHealthModule.swift` for what the composition root injects.
public struct AiSummaryRoute: View {
    @Environment(\.aiHealthModule) private var module
    @State private var viewModel: AiSummaryViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                // The report is this feature's own destination, so the summary pushes it directly
                // through the module's navigator rather than asking the shell for a cross-feature
                // hop — the twin of `AiSummaryRoute` reaching `koinInject<Navigator>()` and calling
                // `navigator.navigate(DoctorReportKey)` (`AiSummaryScreen.kt:44,53`).
                AiSummaryScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onOpenReport: { module?.navigator.navigate(DoctorReportKey()) }
                )
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(AiHealthStrings.summaryTitle)
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeAiSummaryViewModel()
        }
    }
}

/// The stateless summary screen (`AiSummaryScreen.kt:69-160`).
struct AiSummaryScreen: View {
    let state: AiSummaryUiState
    let onEvent: (AiSummaryEvent) -> Void

    /// The report is this feature's own destination, so the summary pushes it directly rather
    /// than asking the shell for a cross-feature hop (`AiSummaryScreen.kt:53`).
    let onOpenReport: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            PeriodSelector(selected: state.period) { onEvent(.periodSelected($0)) }

            switch state.result {
            case .loading:
                LoadingBody()

            case let .content(text, fromCache, metrics):
                SummaryBody(text: text, fromCache: fromCache, metrics: metrics)

            case .insufficientData:
                MessageBody(
                    systemImage: "sparkles",
                    title: AiHealthStrings.insufficientTitle,
                    message: AiHealthStrings.insufficientMessage
                )

            case .premiumRequired:
                MessageBody(
                    systemImage: "lock",
                    title: AiHealthStrings.premiumTitle,
                    message: AiHealthStrings.premiumMessage,
                    actionLabel: AiHealthStrings.premiumAction,
                    onAction: { onEvent(.upgradeClicked) }
                )

            case .dailyLimit:
                MessageBody(
                    systemImage: "arrow.clockwise",
                    title: AiHealthStrings.dailyLimitTitle,
                    message: AiHealthStrings.dailyLimitMessage
                )

            // Every line here is ours; the repository's raw failure text never reaches the UI.
            case let .error(reason):
                switch reason {
                case .error:
                    MessageBody(
                        systemImage: "exclamationmark.triangle",
                        title: AiHealthStrings.errorTitle,
                        message: AiHealthStrings.errorMessage,
                        actionLabel: AiHealthStrings.retry,
                        onAction: { onEvent(.retryClicked) }
                    )

                case .unavailable:
                    MessageBody(
                        systemImage: "info.circle",
                        title: AiHealthStrings.unavailableTitle,
                        message: AiHealthStrings.unavailableMessage
                    )
                }
            }

            if case .content = state.result {
                SummaryActions(
                    onShareAsPdf: onOpenReport,
                    onRefresh: { onEvent(.retryClicked) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        .toolbar {
            // `.primaryAction`, not `.topBarTrailing` (spec §2.2): the trailing slot by its iOS
            // spelling, and `ToolbarItemPlacement.topBarTrailing` is iOS-only API that every
            // feature package also compiles against the macOS host.
            ToolbarItem(placement: .primaryAction) {
                SalusIconButton(
                    systemImage: "square.and.arrow.up",
                    accessibilityLabel: AiHealthStrings.openReport,
                    action: onOpenReport
                )
            }
        }
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (`AppointmentDetailScreen.swift`).
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// The WEEKLY/MONTHLY segmented control (`AiSummaryScreen.kt:89-98`).
private struct PeriodSelector: View {
    let selected: SummaryPeriod
    let onSelect: (SummaryPeriod) -> Void

    var body: some View {
        SalusSegmentedTabs(
            options: [SummaryPeriod.weekly, .monthly],
            selected: selected,
            label: { period in
                switch period {
                case .weekly: AiHealthStrings.periodWeekly
                case .monthly: AiHealthStrings.periodMonthly
                }
            },
            onSelected: onSelect
        )
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}

/// The centered spinner (`AiHealthStateBodies.kt:31-55`).
private struct LoadingBody: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.lg) {
            ProgressView()
            Text(verbatim: AiHealthStrings.loading)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SalusSpacing.lg)
    }
}

/// The centered empty-state block (`AiHealthStateBodies.kt:57-98`).
private struct MessageBody: View {
    let systemImage: String
    let title: String
    let message: String
    let actionLabel: String?
    let onAction: (() -> Void)?

    @Environment(\.salusTheme) private var theme

    init(
        systemImage: String,
        title: String,
        message: String,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.onAction = onAction
    }

    var body: some View {
        // `fillMaxSize` before `verticalScroll` with `Arrangement.Center`
        // (`AiHealthStateBodies.kt:65-69,87`): `GeometryReader` supplies the full height the tabs
        // left, the two expanding spacers push a short block to the middle of it (mid-screen on a
        // tall device), and a long one — a large font scale, a wordy message, a message plus a
        // button — grows past it and scrolls instead of being clipped.
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: SalusSpacing.lg) {
                    Spacer(minLength: 0)
                    SalusEmptyState(
                        systemImage: systemImage,
                        title: title,
                        message: message,
                        accent: theme.extendedColors.trends,
                        actionLabel: actionLabel,
                        onAction: onAction
                    )
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The model's prose split into the lines the screen dots (`AiSummarySections.kt:212-223`).
///
/// A bullet character the model wrote itself is stripped: the dot is the screen's, and a line
/// that arrived as "- Tansiyonun…" would otherwise carry two. The trailing disclaimer `:core:ai`
/// appends before caching is dropped for the same reason — this screen states it once, in its own
/// resource string, and a dotted copy of the same sentence directly above it reads as a mistake.
extension String {
    fileprivate func summaryParagraphs() -> [String] {
        split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { line in
                var trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "-*•"))
                trimmed = trimmed.trimmingCharacters(in: .whitespaces)
                return trimmed
            }
            .filter { !$0.isEmpty && !isAIDisclaimer($0) }
    }

    /// The two sentences `disclaimerFor` can produce — matched, never restated
    /// (`AiSummarySections.kt:225-226`).
    private func isAIDisclaimer(_ line: String) -> Bool {
        line == Self.trDisclaimer || line == Self.enDisclaimer
    }

    private static let trDisclaimer = "Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."
    private static let enDisclaimer = "This report is for informational purposes only and is not medical advice."
}

// MARK: - The summary body

/// The summary itself, with the disclaimer as a line of our own underneath
/// (`AiSummarySections.kt:46-109`).
///
/// `:core:ai` already appends a disclaimer sentence to the text before caching it, but that one
/// is produced by the same pipeline as the summary. This line is a UI guarantee that does not
/// depend on it: it is a resource string, so it is there even if a cached row somehow is not.
private struct SummaryBody: View {
    let text: String
    let fromCache: Bool
    let metrics: AiSummaryMetrics?

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                SalusCard(tone: .accent) {
                    HStack(spacing: SalusSpacing.md) {
                        SalusIconBadge(
                            systemImage: "sparkles",
                            accent: theme.extendedColors.trends
                        )
                        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                            Text(verbatim: AiHealthStrings.bannerTitle)
                                .font(SalusTypography.titleLarge.font)
                                .tracking(SalusTypography.titleLarge.tracking)
                            SalusStatusChip(
                                label: fromCache
                                    ? AiHealthStrings.stateCached
                                    : AiHealthStrings.stateFresh
                            )
                        }
                    }

                    if let metrics {
                        MetricsRow(metrics: metrics)
                            .padding(.top, SalusSpacing.lg)
                    }
                }
                .frame(maxWidth: .infinity)

                SummaryParagraphs(text: text)

                SalusDisclaimer(AiHealthStrings.disclaimer)
                    .padding(.bottom, SalusSpacing.md)
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The period's three headline figures (`AiSummarySections.kt:111-146`).
///
/// A missing figure drops its tile rather than printing a zero, and a period with none of them
/// drops the row entirely — which the caller handles by not composing it, because
/// `AiSummaryMetrics` is `nil` then.
private struct MetricsRow: View {
    let metrics: AiSummaryMetrics

    var body: some View {
        HStack(alignment: .top, spacing: SalusSpacing.md) {
            if let bloodPressure = metrics.averageBloodPressure {
                SalusMetricTile(
                    overline: AiHealthStrings.metricBloodPressure,
                    value: bloodPressure
                )
                .frame(maxWidth: .infinity)
            }
            if let percent = metrics.recordedDosePercent {
                SalusMetricTile(
                    overline: AiHealthStrings.metricDoses,
                    value: AiHealthStrings.metricDosesValue(percent),
                    progress: Double(percent) / 100
                )
                .frame(maxWidth: .infinity)
            }
            if let pulse = metrics.averagePulse {
                SalusMetricTile(
                    overline: AiHealthStrings.metricPulse,
                    value: "\(pulse)"
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The summary text, one dotted row per line the model wrote (`AiSummarySections.kt:148-175`).
private struct SummaryParagraphs: View {
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            ForEach(Array(text.summaryParagraphs().enumerated()), id: \.offset) { _, paragraph in
                HStack(alignment: .top, spacing: SalusSpacing.md) {
                    Circle()
                        .fill(theme.colorScheme.primary)
                        .frame(width: SummaryParagraphs.bulletSize, height: SummaryParagraphs.bulletSize)
                        .padding(.top, SummaryParagraphs.bulletTopPadding)
                        .accessibilityHidden(true)
                    Text(verbatim: paragraph)
                        .font(SalusTypography.bodyMedium.font)
                        .tracking(SalusTypography.bodyMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `BulletSize` (`AiSummarySections.kt:229`) — the screen's dot, small enough to read as
    /// punctuation in front of a line of prose.
    private static let bulletSize: CGFloat = 6
    /// The bullet's top alignment relative to the first line of text (`AiSummarySections.kt:160`).
    private static let bulletTopPadding: CGFloat = SalusSpacing.sm
}

/// The pair of actions under the body: out of the app as a document, or one more model call
/// (`AiSummarySections.kt:177-210`).
///
/// Pinned below the scrolling content rather than placed at the end of it, so the way to a
/// shareable PDF is on screen however long the text runs. They belong to a finished summary and
/// appear with one: there is nothing to update or export while the request is still in flight,
/// or when the answer is a wall.
private struct SummaryActions: View {
    let onShareAsPdf: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: SalusSpacing.sm) {
            SalusButton(AiHealthStrings.sharePdf, systemImage: "square.and.arrow.up", action: onShareAsPdf)
            SalusButton(AiHealthStrings.refresh, variant: .secondary, action: onRefresh)
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.top, SalusSpacing.md)
        .padding(.bottom, SalusSpacing.lg)
    }
}

// MARK: - Previews

// The 8-palette fan-out (`AiSummaryScreen.kt:174-196`).
#Preview("Content") {
    SalusPreviewPalettes {
        AiSummaryScreen(
            state: AiSummaryUiState(
                period: .weekly,
                result: .content(
                    text: "Bu hafta tansiyonun genel olarak dengeli seyretti.\n"
                        + "İlaç dozlarının neredeyse tamamını kaydettin.\n"
                        + "Nabız ortalaman haftanın ikinci yarısında biraz düştü.",
                    fromCache: false,
                    metrics: AiSummaryMetrics(
                        averageBloodPressure: "128/82",
                        recordedDosePercent: 92,
                        averagePulse: 72
                    )
                )
            ),
            onEvent: { _ in },
            onOpenReport: {}
        )
        .dynamicTypeSize(.xxxLarge)
    }
}

#Preview("Loading") {
    SalusPreviewPalettes {
        AiSummaryScreen(state: AiSummaryUiState(result: .loading), onEvent: { _ in }, onOpenReport: {})
    }
}

#Preview("Premium required") {
    SalusPreviewPalettes {
        AiSummaryScreen(
            state: AiSummaryUiState(period: .monthly, result: .premiumRequired),
            onEvent: { _ in },
            onOpenReport: {}
        )
    }
}
