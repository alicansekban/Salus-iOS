// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/report/
// PdfReportGenerator.kt`.
//
// Android's `android.graphics.pdf.PdfDocument` becomes `UIGraphicsPDFRenderer`. The protocol is
// declared unconditionally so the repository's gating rules can be tested against a fake on a
// plain host; only the UIKit-backed implementation is behind `#if canImport(UIKit)`, because
// `swift test` runs on a macOS host that has no UIKit.

import Foundation
import SalusAI

/// Lays the deterministic doctor report out as a PDF and returns the file it was written to.
///
/// Behind an interface so the repository's gating rules can be tested on a plain host: everything
/// below the interface talks to `UIGraphicsPDFRenderer`, and the gates are what a wrong answer
/// costs a user money for. A test that asserts "the PDF was never produced" needs a double it can
/// ask.
public protocol PdfReportGenerator: Sendable {
    /// Writes the report and returns the file. Throws only for a real I/O failure, which the
    /// repository turns into `ReportOutcome.failed`.
    ///
    /// - Parameters:
    ///   - narrative: the AI section's text, or `nil` when it was skipped — the page then carries
    ///     a localized note in its place rather than silently omitting the section, so the reader
    ///     can tell an absent narrative from one that was never asked for.
    ///   - language: the language every fixed string in the document is rendered in. It is a
    ///     parameter and not the device configuration because the document outlives the session it
    ///     was made in: a file generated in Turkish must still read Turkish after the user switches
    ///     the app to English.
    func generate(
        stats: HealthPeriodStats,
        rows: HealthPeriodRows,
        narrative: String?,
        language: AiLanguage
    ) throws -> URL
}

#if canImport(UIKit)

    import SalusCommon
    import UIKit

    /// Assembles the report and writes it out as a PDF.
    ///
    /// The work is split three ways so that only the last part needs a graphics stack: `reportBlocksOf`
    /// decides what the document says, `ReportWriter` decides where each line lands, and
    /// `PdfReportSurface` puts it on a page. This class is the seam that joins them and owns the file.
    ///
    /// Files go to `cachesDirectory/reports/`: they are shareable through the app's share sheet and
    /// the system may reclaim them whenever it needs the space, which is the right lifetime for a
    /// document the user has already sent on.
    public final class IosPdfReportGenerator: PdfReportGenerator {
        private let clock: any SalusClock

        public init(clock: any SalusClock) {
            self.clock = clock
        }

        public func generate(
            stats: HealthPeriodStats,
            rows: HealthPeriodRows,
            narrative: String?,
            language: AiLanguage
        ) throws -> URL {
            let blocks = reportBlocksOf(
                stats: stats,
                rows: rows,
                narrative: narrative,
                copy: language.reportCopy(),
                // The clock is injected like every other date in the app, never `Date()`, so the
                // header is deterministic under test.
                generatedOn: clock.today()
            )

            let output = try outputFileFor(stats)
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: CGFloat(pageWidth), height: CGFloat(pageHeight))
            )
            try renderer.writePDF(to: output) { context in
                ReportWriter(
                    surface: PdfReportSurface(context),
                    footer: disclaimerFor(language)
                ).draw(blocks)
            }
            return output
        }

        /// `cachesDirectory/reports/salus-report-<start>-<end>.pdf`, replacing any earlier run's file.
        ///
        /// Every other report in the directory is deleted first: each period produces its own file
        /// name, so without a prune the cache accumulates one PDF of health data per period the user
        /// ever exported. Only the report being handed to the share sheet needs to survive.
        private func outputFileFor(_ stats: HealthPeriodStats) throws -> URL {
            let fileManager = FileManager.default
            let caches = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = caches.appendingPathComponent(reportsDirectory, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent(
                "salus-report-\(stats.startEpochDay)-\(stats.endEpochDay).pdf"
            )
            let stale = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for candidate in stale where candidate != file {
                try? fileManager.removeItem(at: candidate)
            }
            return file
        }
    }

    /// `ReportSurface` backed by a `UIGraphicsPDFRenderer.Context`. Delegation only — every decision
    /// was made above it.
    ///
    /// Fonts are built once and reused: a font allocation per drawn string on a report that can run to
    /// hundreds of table rows is pure garbage.
    private final class PdfReportSurface: ReportSurface {
        private let context: UIGraphicsPDFRendererContext
        private let fonts: [ReportTextStyle: UIFont]

        init(_ context: UIGraphicsPDFRendererContext) {
            self.context = context
            fonts = [
                .title: Self.font(size: titleSize, bold: true),
                .section: Self.font(size: sectionSize, bold: true),
                .body: Self.font(size: bodySize, bold: false),
                .columnHeader: Self.font(size: bodySize, bold: true),
                .footer: Self.font(size: footerSize, bold: false)
            ]
        }

        func startPage(pageNumber: Int) {
            context.beginPage()
        }

        func drawText(_ text: String, x: Float, baselineY: Float, style: ReportTextStyle) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font(for: style)
            ]
            (text as NSString).draw(
                at: CGPoint(x: CGFloat(x), y: CGFloat(baselineY)),
                withAttributes: attributes
            )
        }

        func widthOf(_ text: String, style: ReportTextStyle) -> Float {
            Float((text as NSString).size(withAttributes: [.font: font(for: style)]).width)
        }

        func finishPage() {}

        private func font(for style: ReportTextStyle) -> UIFont {
            fonts[style] ?? fonts[.body] ?? Self.font(size: bodySize, bold: false)
        }

        private static func font(size: CGFloat, bold: Bool) -> UIFont {
            let descriptor = UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .body)
                .withSymbolicTraits(bold ? .traitBold : []) ?? UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .body)
            return UIFont(descriptor: descriptor, size: size)
        }
    }

    private let titleSize: CGFloat = 18
    private let sectionSize: CGFloat = 12
    private let bodySize: CGFloat = 10
    private let footerSize: CGFloat = 8

    /// Subdirectory of `cachesDirectory` the reports live in.
    private let reportsDirectory = "reports"

#endif
