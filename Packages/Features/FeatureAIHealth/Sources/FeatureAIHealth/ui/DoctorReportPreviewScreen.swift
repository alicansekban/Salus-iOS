// The in-app PDF preview — Task 7 of iOS-M10, the iOS-specific addition that Android's
// `PdfRenderer` does differently (divergence `D-M10-a`).
//
// Android renders the report page-by-page with `PdfRenderer` and its `ReportDocument` /
// `ReportDocumentOpener` / `reportPageBitmapSize` infrastructure; iOS has PDFKit, which opens the
// whole document in one `PDFView` and manages the file descriptor itself. That infrastructure is
// deliberately **not** ported: the ViewModel carries only the file URL, and `PDFView` opens it.
//
// The whole file sits behind `#if canImport(UIKit)` because it wraps a `UIView` (`PDFView` is a
// `UIView` on iOS and an `NSView` on macOS), and the package's host build (`swift test`) runs on
// macOS — the guard keeps the UIKit-backed `UIViewRepresentable` out of a build that has no UIKit.

#if canImport(UIKit)

    import PDFKit
    import SwiftUI

    /// The full-screen in-app preview of a finished doctor report.
    ///
    /// Presented as a `.fullScreenCover` from `DoctorReportScreen` when the ViewModel's preview
    /// state is `.ready(url:)`. It hosts a `PDFView` that auto-scales the document, a close button
    /// that dismisses it, and a `ShareLink` that hands the file to the system share sheet — the
    /// same file the report screen's Share button offers, reachable here without leaving the app.
    public struct DoctorReportPreviewScreen: View {
        private let url: URL
        private let onClose: () -> Void

        public init(url: URL, onClose: @escaping () -> Void) {
            self.url = url
            self.onClose = onClose
        }

        public var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: AiHealthStrings.doctorReportPreviewTitle)
                        .font(.headline)
                    Spacer()
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(AiHealthStrings.doctorReportShare)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                    }
                    .accessibilityLabel(AiHealthStrings.doctorReportPreviewClose)
                }
                .padding()

                PDFViewRepresentable(url: url)
            }
        }
    }

    /// A `UIViewRepresentable` that hosts a `PDFView` and loads the document at `url`.
    ///
    /// `autoScales` is set so the first page fits the view and the user can zoom and scroll from
    /// there. The document is opened by PDFKit, which owns the file descriptor — nothing here
    /// opens or closes a handle.
    ///
    /// `PDFView.document` is main-actor isolated, and `makeUIView` is documented to run on the
    /// main thread, so the mutation is wrapped in `MainActor.assumeIsolated` — the Swift 6 spelling
    /// of "this is already on the main actor, trust me". The struct itself stays nonisolated
    /// because `UIViewRepresentable`'s requirements are nonisolated in this SDK.
    private struct PDFViewRepresentable: UIViewRepresentable {
        let url: URL

        func makeUIView(context: Context) -> PDFView {
            MainActor.assumeIsolated {
                let view = PDFView()
                view.autoScales = true
                view.document = PDFDocument(url: url)
                return view
            }
        }

        func updateUIView(_ uiView: PDFView, context: Context) {
            // The document is fixed for the lifetime of the preview; nothing to update.
        }
    }

#endif // canImport(UIKit)
