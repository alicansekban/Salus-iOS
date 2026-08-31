// Ported from `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// AiSummaryScreen.kt`.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded:
//   `TopAppBar` + `navigationIcon` (back) → `.navigationTitle(_:)` + the stack's own back button.
//     Compose has no chrome and must draw one; SwiftUI's `NavigationStack` already provides it,
//     and it pops the very `NavigationPath` the Navigator's `pop()` mutates, so the two ways back
//     stay one behaviour. `onBack` therefore has no parameter here, and `ai_summary_back` stays in
//     the catalog for parity.
//   `SingleChoiceSegmentedButtonRow` + `SegmentedButton` → `Picker("", selection:)` with
//     `.pickerStyle(.segmented)`.
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

/// Owns the ViewModel and wires it to the shell (`AiSummaryScreen.kt:31-40`).
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
                AiSummaryScreen(state: viewModel.state, onEvent: viewModel.onEvent)
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

/// The stateless summary screen (`AiSummaryScreen.kt:42-118`).
struct AiSummaryScreen: View {
    let state: AiSummaryUiState
    let onEvent: (AiSummaryEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            PeriodSelector(selected: state.period) { onEvent(.periodSelected($0)) }

            switch state.result {
            case .loading:
                LoadingBody()

            case let .content(text, fromCache):
                SummaryBody(text: text, fromCache: fromCache)

            case .insufficientData:
                MessageBody(
                    systemImage: "info.circle",
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
            // An unconfigured build offers no retry — the button would fail identically every
            // time — and never mentions the connection, which is not what is wrong.
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
    }
}

/// The WEEKLY/MONTHLY segmented control (`AiSummaryScreen.kt:120-141`).
private struct PeriodSelector: View {
    let selected: SummaryPeriod
    let onSelect: (SummaryPeriod) -> Void

    var body: some View {
        Picker("", selection: Binding(
            get: { selected },
            set: { onSelect($0) }
        )) {
            Text(verbatim: AiHealthStrings.periodWeekly).tag(SummaryPeriod.weekly)
            Text(verbatim: AiHealthStrings.periodMonthly).tag(SummaryPeriod.monthly)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}

/// The centered spinner (`AiSummaryScreen.kt:143-160`).
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

/// The summary itself, with the disclaimer as a line of our own underneath
/// (`AiSummaryScreen.kt:162-205`).
///
/// `:core:ai` already appends a disclaimer sentence to the text before caching it, but that one
/// is produced by the same pipeline as the summary. This line is a UI guarantee that does not
/// depend on it: it is a resource string, so it is there even if a cached row somehow is not.
private struct SummaryBody: View {
    let text: String
    let fromCache: Bool

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                SalusCard {
                    Text(verbatim: text)
                        .font(SalusTypography.bodyLarge.font)
                        .tracking(SalusTypography.bodyLarge.tracking)
                }
                .frame(maxWidth: .infinity)

                if fromCache {
                    Text(verbatim: AiHealthStrings.fromCache)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }

                Text(verbatim: AiHealthStrings.disclaimer)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .padding(.bottom, SalusSpacing.xl)
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
    }
}

/// The centered empty-state block (`AiSummaryScreen.kt:207-225`).
private struct MessageBody: View {
    let systemImage: String
    let title: String
    let message: String
    let actionLabel: String?
    let onAction: (() -> Void)?

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
        SalusEmptyState(
            systemImage: systemImage,
            title: title,
            message: message,
            actionLabel: actionLabel,
            onAction: onAction
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SalusSpacing.lg)
    }
}

// MARK: - Previews

#Preview("Content") {
    AiSummaryScreen(
        state: AiSummaryUiState(
            period: .weekly,
            result: .content(
                text: "Bu hafta tansiyonun genel olarak dengeli seyretti ve ilaçlarını düzenli aldın.",
                fromCache: false
            )
        ),
        onEvent: { _ in }
    )
}

#Preview("Premium required") {
    AiSummaryScreen(
        state: AiSummaryUiState(period: .monthly, result: .premiumRequired),
        onEvent: { _ in }
    )
}
