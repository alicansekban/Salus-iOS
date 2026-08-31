// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/ui/
// DoctorReportUiState.kt`.

import Foundation
import SalusAI

/// Everything the doctor report screen can be showing below the period selector.
///
/// One member per outcome `DoctorReportRepository` can answer, plus `idle` — which the repository
/// has no equivalent for because it is the state *before* anything is asked. That state is the
/// whole reason this screen does not generate on open: a report may cost an AI call, and a feature
/// that spends one for merely visiting the screen would be spending the user's daily quota on
/// curiosity.
public enum DoctorReportResult: Equatable, Sendable {
    /// Nothing requested yet. The screen offers the button and no more.
    case idle

    case generating

    /// - Parameters:
    ///   - pdfFile: the written document, shareable through the app's share sheet.
    ///   - narrativeIncluded: false when the AI section was skipped, which the screen says out
    ///     loud — the user is about to forward this to a doctor and should know what is in it.
    case ready(pdfFile: URL, narrativeIncluded: Bool)

    /// Not entitled. The only state that offers the paywall; the report is premium in full.
    case premiumRequired

    /// Not one record in the period — there is nothing to tabulate.
    case insufficientData

    /// The document could not be written.
    ///
    /// Carries no message on purpose: the repository's text is the underlying platform failure,
    /// untranslated and kept for the log, so every line the user reads here is ours.
    case failed
}

/// The in-app preview of a finished report, which covers the screen while it is open.
///
/// It exists so the report can be read before it leaves the device. Generating a PDF the user can
/// only inspect by sending it to some other app makes the third party the first reader of a
/// document full of their health data; with a preview, the file reaches another app only on the
/// tap that shares it.
///
/// This task ships the state and the open/close lifecycle; the page-by-page renderer that fills
/// `ready` is Task 7's, so `ready` carries the file URL rather than rendered pages.
public enum DoctorReportPreview: Equatable, Sendable {
    /// No preview. The report screen itself is what is showing.
    case hidden

    /// The file is being opened.
    case opening

    /// The file is open and ready to be read.
    case ready(url: URL)

    /// The document could not be opened.
    case failed
}

/// The selected period is held next to `result` rather than inside it, so the segmented control
/// keeps its selection while the next report is generated.
///
/// `preview` is a third axis rather than a member of `result` for the mirror reason: the preview
/// is only ever open over a `DoctorReportResult.ready`, and folding it in would make the file and
/// the narrative note something every preview state had to carry a copy of.
public struct DoctorReportUiState: Equatable, Sendable {
    public var period: SummaryPeriod
    public var result: DoctorReportResult
    public var preview: DoctorReportPreview

    public init(
        period: SummaryPeriod = .weekly,
        result: DoctorReportResult = .idle,
        preview: DoctorReportPreview = .hidden
    ) {
        self.period = period
        self.result = result
        self.preview = preview
    }
}

/// User intents on the doctor report screen.
public enum DoctorReportEvent: Equatable, Sendable {
    case periodSelected(SummaryPeriod)

    /// The generate/regenerate/retry button — all three ask for exactly the same thing.
    case generateClicked

    case upgradeClicked

    /// Open the finished report in the app. Ignored unless there is one to open.
    case previewClicked

    /// The preview's close button and the system back gesture, which mean the same thing.
    case previewDismissed
}
