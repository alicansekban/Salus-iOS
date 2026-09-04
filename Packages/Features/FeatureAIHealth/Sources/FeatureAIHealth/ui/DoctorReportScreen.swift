// Ported from `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// DoctorReportScreen.kt`.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded (see `AiSummaryScreen.swift`):
//   `TopAppBar` + `navigationIcon` (back) → `.navigationTitle(_:)` + the stack's own back button.
//   `SingleChoiceSegmentedButtonRow` + `SegmentedButton` → `Picker(selection:)` with an empty label with
//     `.pickerStyle(.segmented)`.
//   `CircularProgressIndicator` → `ProgressView()`.
//   `SalusEmptyState` → the same component, with the SF Symbol twin of each Material icon.
//   `Column(verticalScroll(rememberScrollState()))` → `ScrollView` + `VStack`.
//
// The in-app preview is Task 7's: the state and the open/close lifecycle shipped in Task 6, and
// this task fills the full-screen cover with the PDFKit renderer (`DoctorReportPreviewScreen`).

import SalusAI
import SalusDesignSystem
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`DoctorReportScreen.kt:83-100`).
///
/// The module comes from the environment, exactly as `koinViewModel()` reaches Koin's graph — see
/// `AiHealthModule.swift` for what the composition root injects.
public struct DoctorReportRoute: View {
    @Environment(\.aiHealthModule) private var module
    @State private var viewModel: DoctorReportViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                DoctorReportScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(AiHealthStrings.doctorReportTitle)
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeDoctorReportViewModel()
        }
    }
}

/// The stateless doctor report screen (`DoctorReportScreen.kt:104-188`).
struct DoctorReportScreen: View {
    let state: DoctorReportUiState
    let onEvent: (DoctorReportEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            PeriodSelector(selected: state.period) { onEvent(.periodSelected($0)) }

            switch state.result {
            case .idle:
                MessageBody(
                    systemImage: "list.bullet",
                    title: AiHealthStrings.doctorReportIdleTitle,
                    message: AiHealthStrings.doctorReportIdleMessage,
                    actionLabel: AiHealthStrings.doctorReportGenerate,
                    onAction: { onEvent(.generateClicked) }
                )

            case .generating:
                LoadingBody(message: AiHealthStrings.doctorReportGenerating)

            case let .ready(pdfFile, narrativeIncluded):
                ReadyBody(
                    pdfFile: pdfFile,
                    narrativeIncluded: narrativeIncluded,
                    onPreview: { onEvent(.previewClicked) },
                    onRegenerate: { onEvent(.generateClicked) }
                )

            case .premiumRequired:
                MessageBody(
                    systemImage: "lock",
                    title: AiHealthStrings.doctorReportPremiumTitle,
                    message: AiHealthStrings.doctorReportPremiumMessage,
                    actionLabel: AiHealthStrings.doctorReportPremiumAction,
                    onAction: { onEvent(.upgradeClicked) }
                )

            case .insufficientData:
                MessageBody(
                    systemImage: "info.circle",
                    title: AiHealthStrings.doctorReportInsufficientTitle,
                    message: AiHealthStrings.doctorReportInsufficientMessage
                )

            // Every line here is ours; the repository's platform failure text never reaches the UI.
            case .failed:
                MessageBody(
                    systemImage: "exclamationmark.triangle",
                    title: AiHealthStrings.doctorReportErrorTitle,
                    message: AiHealthStrings.doctorReportErrorMessage,
                    actionLabel: AiHealthStrings.doctorReportRetry,
                    onAction: { onEvent(.generateClicked) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
        #if os(iOS)
            .fullScreenCover(isPresented: previewBinding) {
                if case let .ready(url) = state.preview {
                    DoctorReportPreviewScreen(
                        url: url,
                        onClose: { onEvent(.previewDismissed) }
                    )
                }
            }
        #endif
    }

    /// The preview is presented only while a finished report is on screen and the preview is not
    /// hidden (`DoctorReportScreen.kt:116-124`).
    private var previewBinding: Binding<Bool> {
        Binding(
            get: {
                if case .ready = state.result, state.preview != .hidden {
                    return true
                }
                return false
            },
            set: { showing in
                if !showing {
                    onEvent(.previewDismissed)
                }
            }
        )
    }
}

/// The WEEKLY/MONTHLY segmented control (`DoctorReportScreen.kt:190-212`).
private struct PeriodSelector: View {
    let selected: SummaryPeriod
    let onSelect: (SummaryPeriod) -> Void

    var body: some View {
        // `label: { EmptyView() }`, not `Picker("", …)`: an empty `LocalizedStringKey` is written
        // into the catalog as a bare `""` entry by Xcode's string extraction on every build.
        Picker(selection: Binding(
            get: { selected },
            set: { onSelect($0) }
        )) {
            Text(verbatim: AiHealthStrings.periodWeekly).tag(SummaryPeriod.weekly)
            Text(verbatim: AiHealthStrings.periodMonthly).tag(SummaryPeriod.monthly)
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}

/// The centered spinner (`DoctorReportScreen.kt:214-235`).
private struct LoadingBody: View {
    let message: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.lg) {
            ProgressView()
            Text(verbatim: message)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SalusSpacing.lg)
    }
}

/// The finished report (`DoctorReportScreen.kt:237-309`).
///
/// A missing narrative is stated plainly rather than hidden: the user is about to hand this file
/// to a doctor, so what is and is not in it has to be visible before they send it.
///
/// Three actions, and none of them stands in for another: sharing sends the document out of the
/// app, previewing keeps it inside, and regenerating replaces it. Preview sits between the other
/// two rather than ahead of Share so that the action the user came for stays the primary one,
/// while the way to read the report first is the next thing their eye lands on.
///
/// Share is a `ShareLink` over the file rather than an event: Kotlin shares from the screen too
/// (`Context.shareReport`, `DoctorReportScreen.kt:520-540`, an `ACTION_SEND` chooser with no
/// ViewModel round trip), and `ShareLink` is the system share sheet the preview's toolbar already
/// hands the same file to. Until 2026-09-05 this pill was wired to `.generateClicked` by mistake,
/// so tapping Share silently regenerated the report instead of opening the sheet.
private struct ReadyBody: View {
    let pdfFile: URL
    let narrativeIncluded: Bool
    let onPreview: () -> Void
    let onRegenerate: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                SalusCard {
                    VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                        Text(verbatim: AiHealthStrings.doctorReportReadyTitle)
                            .font(SalusTypography.titleMedium.font)
                            .tracking(SalusTypography.titleMedium.tracking)
                        Text(verbatim: narrativeIncluded
                            ? AiHealthStrings.doctorReportReadyMessage
                            : AiHealthStrings.doctorReportReadyWithoutNarrative)
                            .font(SalusTypography.bodyMedium.font)
                            .tracking(SalusTypography.bodyMedium.tracking)
                            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity)

                ShareLink(item: pdfFile) {
                    SalusPillLabel(
                        text: AiHealthStrings.doctorReportShare,
                        systemImage: "square.and.arrow.up",
                        fillsWidth: true
                    )
                }
                .buttonStyle(.plain)
                SalusPillButton(
                    text: AiHealthStrings.doctorReportPreview,
                    tonal: true,
                    systemImage: "list.bullet",
                    fillsWidth: true,
                    action: onPreview
                )
                SalusPillButton(
                    text: AiHealthStrings.doctorReportRegenerate,
                    tonal: true,
                    fillsWidth: true,
                    action: onRegenerate
                )

                Text(verbatim: AiHealthStrings.doctorReportDisclaimer)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .padding(.bottom, SalusSpacing.xl)
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
    }
}

/// The centered empty-state block (`DoctorReportScreen.kt:495-517`).
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

#Preview("Idle") {
    DoctorReportScreen(
        state: DoctorReportUiState(period: .weekly),
        onEvent: { _ in }
    )
}

#Preview("Ready") {
    DoctorReportScreen(
        state: DoctorReportUiState(
            period: .monthly,
            result: .ready(pdfFile: URL(fileURLWithPath: "salus-report.pdf"), narrativeIncluded: false)
        ),
        onEvent: { _ in }
    )
}
