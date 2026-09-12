// Ported from `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// DoctorReportScreen.kt` in its M15 shape.
//
// Material → SwiftUI, per the mapping table iOS-M2 Task 3 recorded (see `AiSummaryScreen.swift`):
//   `TopAppBar` + `navigationIcon` (back) → `.navigationTitle(_:)` + the stack's own back button.
//   `SingleChoiceSegmentedButtonRow` + `SegmentedButton` → `SalusSegmentedTabs`.
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

/// Owns the ViewModel and wires it to the shell (`DoctorReportScreen.kt:43-61`).
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

/// The stateless doctor report screen (`DoctorReportScreen.kt:70-159`).
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
                    content: state.content,
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
                    systemImage: "sparkles",
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
        // `#if os(iOS)` because `fullScreenCover` and the inline title are both iOS-only API
        // while every feature package also builds for the macOS test host
        // (`AppointmentDetailScreen.swift`).
        #if os(iOS)
            // The cover is presented only while a finished report is on screen: the URL says
            // where the PDF is, and `.ready` on the result is what says there is one. The file
            // itself is the preview screen's business, so it is not bound here.
            .fullScreenCover(isPresented: previewBinding) {
                if case let .ready(url) = state.preview, case .ready = state.result {
                    DoctorReportPreviewScreen(
                        url: url,
                        onClose: { onEvent(.previewDismissed) }
                    )
                }
            }
            // LAST in the chain, the house rule for a pushed screen (CLAUDE.md, Design system
            // rules): SwiftFormat indents whatever follows an `#endif` one level deeper.
            .navigationBarTitleDisplayMode(.inline)
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

/// The WEEKLY/MONTHLY segmented control (`DoctorReportScreen.kt:98-107`).
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

/// The centered spinner (`DoctorReportScreen.kt:120-121`, `AiHealthStateBodies.kt:31-55`).
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

/// The centered empty-state block (`DoctorReportScreen.kt`, `AiHealthStateBodies.kt:57-98`).
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

/// The finished report (`DoctorReportSections.kt:69-143`).
///
/// A missing narrative is stated plainly rather than hidden: the user is about to hand this file
/// to a doctor, so what is and is not in it has to be visible before they send it. That is also
/// what the checklist under the preview is for — it names the document's sections and how many
/// records went into each, so "complete" is something the user can see rather than trust.
///
/// Three actions, and none of them stands in for another: sharing sends the document out of the
/// app, previewing keeps it inside, and regenerating replaces it. Preview sits between the other
/// two rather than ahead of Share so that the action the user came for stays the primary one.
private struct ReadyBody: View {
    let pdfFile: URL
    let narrativeIncluded: Bool
    let content: ReportContent?
    let onPreview: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                ReadyCard(
                    narrativeIncluded: narrativeIncluded,
                    metrics: content?.metrics
                )

                VStack(alignment: .leading, spacing: 0) {
                    SalusSectionHeader(title: AiHealthStrings.doctorReportPreviewSection) {
                        // The shared header action, so "Büyüt" is a 44 pt target rather than a
                        // bare-`Text` hit shape inside the slot's frame.
                        SalusSectionHeaderAction(
                            title: AiHealthStrings.doctorReportPreviewExpand,
                            action: onPreview
                        )
                    }
                    PreviewCard(onPreview: onPreview)
                }

                VStack(alignment: .leading, spacing: 0) {
                    SalusSectionHeader(title: AiHealthStrings.doctorReportIncludesTitle)
                    IncludedSections(
                        content: content,
                        narrativeIncluded: narrativeIncluded
                    )
                }

                VStack(spacing: SalusSpacing.sm) {
                    // Android composes the share here in `DoctorReportScreen.kt` and hands the
                    // system an `ACTION_SEND` chooser; iOS owns the same sheet through `ShareLink`,
                    // which wears a large primary `SalusButton` as its label (the deleted
                    // `SalusPillLabel`'s spot).
                    ShareLink(item: pdfFile) {
                        SalusButton(AiHealthStrings.doctorReportShare, systemImage: "square.and.arrow.up", action: {})
                    }
                    .buttonStyle(.plain)
                    SalusButton(AiHealthStrings.doctorReportPreview, variant: .secondary, action: onPreview)
                    SalusButton(AiHealthStrings.doctorReportRegenerate, variant: .outlined, action: onRegenerate)
                }

                SalusDisclaimer(AiHealthStrings.doctorReportDisclaimer)
                    .padding(.bottom, SalusSpacing.xl)
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The "Raporun Hazır" accent card with the three metric tiles (`DoctorReportSections.kt:146-192`).
private struct ReadyCard: View {
    let narrativeIncluded: Bool
    let metrics: AiSummaryMetrics?

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(tone: .accent) {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(
                    systemImage: "checkmark",
                    accent: theme.extendedColors.trends
                )
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: AiHealthStrings.doctorReportReadyTitle)
                        .font(SalusTypography.titleLarge.font)
                        .tracking(SalusTypography.titleLarge.tracking)
                    SalusStatusChip(label: AiHealthStrings.doctorReportPdfChip)
                }
            }

            Text(verbatim: narrativeIncluded
                ? AiHealthStrings.doctorReportReadyMessage
                : AiHealthStrings.doctorReportReadyWithoutNarrative)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .padding(.top, SalusSpacing.md)

            if let metrics {
                ReportMetrics(metrics: metrics)
                    .padding(.top, SalusSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The period's three headline figures, on the same rule as the summary: no figure, no tile
/// (`DoctorReportSections.kt:194-224`).
private struct ReportMetrics: View {
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

/// The document opened in place, one tap away (`DoctorReportSections.kt:226-260`).
private struct PreviewCard: View {
    let onPreview: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(onTap: onPreview) {
            HStack(spacing: SalusSpacing.md) {
                SalusIconBadge(
                    systemImage: "list.bullet",
                    accent: theme.extendedColors.trends
                )
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    Text(verbatim: AiHealthStrings.doctorReportPreviewTitle)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                    Text(verbatim: AiHealthStrings.doctorReportPreviewHint)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// What went into the document, section by section (`DoctorReportSections.kt:262-299`).
///
/// A count of zero leaves the row unchecked rather than hiding it: the section is in the PDF
/// either way. `content` is nil when the period's snapshot could not be read — the rows still
/// stand, carrying no counts rather than invented ones.
private struct IncludedSections: View {
    let content: ReportContent?
    let narrativeIncluded: Bool

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                if let content {
                    ForEach(content.sections, id: \.section) { summary in
                        SalusCheckRow(
                            title: sectionLabel(summary.section),
                            trailing: "\(summary.recordCount)",
                            // A count of zero leaves the row unchecked (`DoctorReportSections.kt:289`).
                            checked: summary.recordCount > 0
                        )
                    }
                } else {
                    ForEach(ReportSection.allCases, id: \.self) { section in
                        SalusCheckRow(title: sectionLabel(section))
                    }
                }
                SalusCheckRow(
                    title: AiHealthStrings.doctorReportSectionNarrative,
                    // The report states whether the narrative is in the PDF and checks the row only
                    // when it is (`DoctorReportSections.kt:293-296`).
                    checked: narrativeIncluded
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `ReportSection.labelRes` (`DoctorReportSections.kt:424-430`).
    private func sectionLabel(_ section: ReportSection) -> String {
        switch section {
        case .bloodPressure: AiHealthStrings.doctorReportSectionBloodPressure
        case .glucose: AiHealthStrings.doctorReportSectionGlucose
        case .weight: AiHealthStrings.doctorReportSectionWeight
        case .medications: AiHealthStrings.doctorReportSectionMedications
        }
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
            result: .ready(pdfFile: URL(fileURLWithPath: "salus-report.pdf"), narrativeIncluded: true),
            content: ReportContent(
                metrics: AiSummaryMetrics(
                    averageBloodPressure: "128/82",
                    recordedDosePercent: 92,
                    averagePulse: 72
                ),
                sections: [
                    ReportSectionSummary(section: .bloodPressure, recordCount: 14),
                    ReportSectionSummary(section: .glucose, recordCount: 0),
                    ReportSectionSummary(section: .weight, recordCount: 4),
                    ReportSectionSummary(section: .medications, recordCount: 21)
                ]
            )
        ),
        onEvent: { _ in }
    )
}
