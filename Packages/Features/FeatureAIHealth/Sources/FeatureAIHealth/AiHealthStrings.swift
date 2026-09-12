// The twin of `feature/aihealth/src/main/res/values/strings.xml` (Turkish, the source language)
// and `feature/aihealth/src/main/res/values-en/strings.xml` — the `ai_summary_*` keys and
// `ai_language_code`, name and text verbatim, resolved against this package's own bundle exactly
// as `R.string` resolves against `:feature:aihealth`.
//
// The `doctor_report_*` keys arrived with Task 6 of iOS-M10, which ships the report screen, so
// the key-set pin below is 47 — the full Android XML.
//
// `ai_language_code` is the one key that is not user-visible: it is the language the model answers
// in, resolved by the resource system rather than derived from a locale by hand, so whatever
// qualifier the framework picks for the strings the user is reading is the one it picks here and
// the two can never disagree. It maps onto `AiLanguage`; any unrecognised value falls back to TR.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. None of the `ai_summary_*`
// keys carries a specifier, so there is no `%1$s`→`%1$@` / `%1$d`→`%1$lld` rewrite to record here
// — the mapping is the standing one from `CLAUDE.md`, applied the day a key with a placeholder
// arrives.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. That is why the tests
// assert against the FILE, never against a resolved string; the end-to-end check is the simulator
// run.

import Foundation
import SalusCommon

/// The strings `:feature:aihealth` owns.
public enum AiHealthStrings {
    // MARK: - The summary screen (19 → 21 with the M15 additions and removals)

    public static var summaryTitle: String { localized(.summaryTitle) }

    public static var periodWeekly: String { localized(.periodWeekly) }
    public static var periodMonthly: String { localized(.periodMonthly) }

    /// `ai_summary_banner_title` — the accent banner over the three metric tiles.
    public static var bannerTitle: String { localized(.bannerTitle) }
    /// `ai_summary_state_fresh` / `ai_summary_state_cached` — where the text came from.
    public static var stateFresh: String { localized(.stateFresh) }
    public static var stateCached: String { localized(.stateCached) }

    public static var loading: String { localized(.loading) }
    public static var disclaimer: String { localized(.disclaimer) }

    /// `ai_summary_open_report` — the toolbar share button's accessibility label, which opens the
    /// doctor report.
    public static var openReport: String { localized(.openReport) }

    /// `ai_summary_metric_bp` — overline "ORT. TANSİYON".
    public static var metricBloodPressure: String { localized(.metricBloodPressure) }
    /// `ai_summary_metric_doses` — overline "KAYDEDİLEN DOZ".
    public static var metricDoses: String { localized(.metricDoses) }
    /// `ai_summary_metric_doses_value` — the recorded-dose share as `%` + number.
    public static func metricDosesValue(_ percent: Int) -> String {
        String(format: localized(.metricDosesValue), percent)
    }
    /// `ai_summary_metric_pulse` — overline "ORT. NABIZ".
    public static var metricPulse: String { localized(.metricPulse) }

    /// `ai_summary_share_pdf` — the primary action under a finished summary.
    public static var sharePdf: String { localized(.sharePdf) }
    /// `ai_summary_refresh` — the secondary action that asks for a new summary.
    public static var refresh: String { localized(.refresh) }

    public static var insufficientTitle: String { localized(.insufficientTitle) }
    public static var insufficientMessage: String { localized(.insufficientMessage) }

    public static var premiumTitle: String { localized(.premiumTitle) }
    public static var premiumMessage: String { localized(.premiumMessage) }
    public static var premiumAction: String { localized(.premiumAction) }

    public static var dailyLimitTitle: String { localized(.dailyLimitTitle) }
    public static var dailyLimitMessage: String { localized(.dailyLimitMessage) }

    public static var errorTitle: String { localized(.errorTitle) }
    public static var errorMessage: String { localized(.errorMessage) }
    public static var retry: String { localized(.retry) }

    public static var unavailableTitle: String { localized(.unavailableTitle) }
    public static var unavailableMessage: String { localized(.unavailableMessage) }

    // MARK: - The doctor report screen (24 → 28 with the M15 additions and removals)

    public static var doctorReportTitle: String { localized(.doctorReportTitle) }

    public static var doctorReportIdleTitle: String { localized(.doctorReportIdleTitle) }
    public static var doctorReportIdleMessage: String { localized(.doctorReportIdleMessage) }
    public static var doctorReportGenerate: String { localized(.doctorReportGenerate) }

    public static var doctorReportGenerating: String { localized(.doctorReportGenerating) }

    public static var doctorReportReadyTitle: String { localized(.doctorReportReadyTitle) }
    public static var doctorReportReadyMessage: String { localized(.doctorReportReadyMessage) }
    public static var doctorReportReadyWithoutNarrative: String { localized(.doctorReportReadyWithoutNarrative) }
    public static var doctorReportShare: String { localized(.doctorReportShare) }
    public static var doctorReportPreview: String { localized(.doctorReportPreview) }
    public static var doctorReportRegenerate: String { localized(.doctorReportRegenerate) }
    public static var doctorReportDisclaimer: String { localized(.doctorReportDisclaimer) }

    /// `doctor_report_pdf_chip` — the neutral chip on the ready card.
    public static var doctorReportPdfChip: String { localized(.doctorReportPdfChip) }
    /// `doctor_report_preview_section` — the overline above the BELGE ÖNİZLEME section.
    public static var doctorReportPreviewSection: String { localized(.doctorReportPreviewSection) }
    /// `doctor_report_preview_expand` — the section's trailing "Büyüt" action.
    public static var doctorReportPreviewExpand: String { localized(.doctorReportPreviewExpand) }
    /// `doctor_report_preview_hint` — the preview card's supporting line.
    public static var doctorReportPreviewHint: String { localized(.doctorReportPreviewHint) }

    /// `doctor_report_includes_title` — the overline above the RAPORA DAHİL EDİLENLER list.
    public static var doctorReportIncludesTitle: String { localized(.doctorReportIncludesTitle) }

    /// `doctor_report_section_*` — the checklist row labels.
    public static var doctorReportSectionBloodPressure: String { localized(.sectionBloodPressure) }
    public static var doctorReportSectionGlucose: String { localized(.sectionGlucose) }
    public static var doctorReportSectionWeight: String { localized(.sectionWeight) }
    public static var doctorReportSectionMedications: String { localized(.sectionMedications) }
    public static var doctorReportSectionNarrative: String { localized(.sectionNarrative) }

    public static var doctorReportPreviewTitle: String { localized(.doctorReportPreviewTitle) }
    public static var doctorReportPreviewLoading: String { localized(.doctorReportPreviewLoading) }
    public static var doctorReportPreviewPage: String { localized(.doctorReportPreviewPage) }
    public static var doctorReportPreviewErrorTitle: String { localized(.doctorReportPreviewErrorTitle) }
    public static var doctorReportPreviewErrorMessage: String { localized(.doctorReportPreviewErrorMessage) }

    public static var doctorReportPremiumTitle: String { localized(.doctorReportPremiumTitle) }
    public static var doctorReportPremiumMessage: String { localized(.doctorReportPremiumMessage) }
    public static var doctorReportPremiumAction: String { localized(.doctorReportPremiumAction) }

    public static var doctorReportInsufficientTitle: String { localized(.doctorReportInsufficientTitle) }
    public static var doctorReportInsufficientMessage: String { localized(.doctorReportInsufficientMessage) }

    public static var doctorReportErrorTitle: String { localized(.doctorReportErrorTitle) }
    public static var doctorReportErrorMessage: String { localized(.doctorReportErrorMessage) }
    public static var doctorReportRetry: String { localized(.doctorReportRetry) }

    // MARK: - The model language (1)

    /// The language the model answers in, resolved by the resource system (`ai_language_code`).
    /// NOT user-visible.
    public static var languageCode: String { localized(.languageCode) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        // The summary screen (21).
        case summaryTitle = "ai_summary_title"
        case periodWeekly = "ai_summary_period_weekly"
        case periodMonthly = "ai_summary_period_monthly"
        case bannerTitle = "ai_summary_banner_title"
        case stateFresh = "ai_summary_state_fresh"
        case stateCached = "ai_summary_state_cached"
        case loading = "ai_summary_loading"
        case disclaimer = "ai_summary_disclaimer"
        case openReport = "ai_summary_open_report"
        case metricBloodPressure = "ai_summary_metric_bp"
        case metricDoses = "ai_summary_metric_doses"
        case metricDosesValue = "ai_summary_metric_doses_value"
        case metricPulse = "ai_summary_metric_pulse"
        case sharePdf = "ai_summary_share_pdf"
        case refresh = "ai_summary_refresh"
        case insufficientTitle = "ai_summary_insufficient_title"
        case insufficientMessage = "ai_summary_insufficient_message"
        case premiumTitle = "ai_summary_premium_title"
        case premiumMessage = "ai_summary_premium_message"
        case premiumAction = "ai_summary_premium_action"
        case dailyLimitTitle = "ai_summary_daily_limit_title"
        case dailyLimitMessage = "ai_summary_daily_limit_message"
        case errorTitle = "ai_summary_error_title"
        case errorMessage = "ai_summary_error_message"
        case retry = "ai_summary_retry"
        case unavailableTitle = "ai_summary_unavailable_title"
        case unavailableMessage = "ai_summary_unavailable_message"

        // The doctor report screen (28).
        case doctorReportTitle = "doctor_report_title"
        case doctorReportIdleTitle = "doctor_report_idle_title"
        case doctorReportIdleMessage = "doctor_report_idle_message"
        case doctorReportGenerate = "doctor_report_generate"
        case doctorReportGenerating = "doctor_report_generating"
        case doctorReportReadyTitle = "doctor_report_ready_title"
        case doctorReportReadyMessage = "doctor_report_ready_message"
        case doctorReportReadyWithoutNarrative = "doctor_report_ready_without_narrative"
        case doctorReportShare = "doctor_report_share"
        case doctorReportPreview = "doctor_report_preview"
        case doctorReportRegenerate = "doctor_report_regenerate"
        case doctorReportDisclaimer = "doctor_report_disclaimer"
        case doctorReportPdfChip = "doctor_report_pdf_chip"
        case doctorReportPreviewSection = "doctor_report_preview_section"
        case doctorReportPreviewExpand = "doctor_report_preview_expand"
        case doctorReportPreviewHint = "doctor_report_preview_hint"
        case doctorReportIncludesTitle = "doctor_report_includes_title"
        case sectionBloodPressure = "doctor_report_section_blood_pressure"
        case sectionGlucose = "doctor_report_section_glucose"
        case sectionWeight = "doctor_report_section_weight"
        case sectionMedications = "doctor_report_section_medications"
        case sectionNarrative = "doctor_report_section_narrative"
        case doctorReportPreviewTitle = "doctor_report_preview_title"
        case doctorReportPreviewLoading = "doctor_report_preview_loading"
        case doctorReportPreviewPage = "doctor_report_preview_page"
        case doctorReportPreviewErrorTitle = "doctor_report_preview_error_title"
        case doctorReportPreviewErrorMessage = "doctor_report_preview_error_message"
        case doctorReportPremiumTitle = "doctor_report_premium_title"
        case doctorReportPremiumMessage = "doctor_report_premium_message"
        case doctorReportPremiumAction = "doctor_report_premium_action"
        case doctorReportInsufficientTitle = "doctor_report_insufficient_title"
        case doctorReportInsufficientMessage = "doctor_report_insufficient_message"
        case doctorReportErrorTitle = "doctor_report_error_title"
        case doctorReportErrorMessage = "doctor_report_error_message"
        case doctorReportRetry = "doctor_report_retry"

        /// The model language (1).
        case languageCode = "ai_language_code"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
