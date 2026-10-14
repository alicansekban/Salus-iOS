import Testing

@testable import FeatureAIHealth

// Twin of the tobacco case in Android `ReportWriterTest.kt`: the section is drawn as a heading and
// its lines, a line that does not apply is not drawn, and the page still carries the footer.

@Suite("ReportWriter tobacco section")
struct ReportWriterTobaccoTests {
    @Test("the tobacco heading and its present lines are drawn, absent ones are skipped")
    func drawsHeadingAndPresentLinesOnly() {
        let surface = RecordingSurface()

        ReportWriter(surface: surface, footer: "footer").draw([
            .tobaccoUse(
                TobaccoUseBlock(
                    heading: "Tobacco use",
                    status: "Status: reducing",
                    quitDate: nil,
                    duration: nil,
                    slips: nil,
                    dailyAverage: "Daily average: 4.0"
                )
            )
        ])

        #expect(surface.drawn == ["Tobacco use", "Status: reducing", "Daily average: 4.0", "footer"])
        #expect(surface.styles.first == .section)
    }

    @Test("a heading is never left alone at the foot of a page")
    func headingIsNotStrandedAtThePageFoot() {
        let surface = RecordingSurface()
        // Enough body lines to leave the cursor where the heading fits but its first line would not.
        let filler = (0 ..< 49).map { ReportBlock.body("line \($0)") }

        ReportWriter(surface: surface, footer: "footer").draw(
            filler + [
                .tobaccoUse(
                    TobaccoUseBlock(
                        heading: "Tobacco use",
                        status: "Status: reducing",
                        quitDate: nil,
                        duration: nil,
                        slips: nil,
                        dailyAverage: nil
                    )
                )
            ]
        )

        let heading = surface.drawn.firstIndex(of: "Tobacco use")
        let status = surface.drawn.firstIndex(of: "Status: reducing")
        #expect(heading != nil && status != nil)
        // Whatever page the heading landed on, its first line is on the same one: no page footer
        // sits between them.
        if let heading, let status {
            #expect(!surface.drawn[heading ..< status].contains("footer"))
        }
    }
}

private final class RecordingSurface: ReportSurface {
    private(set) var drawn: [String] = []
    private(set) var styles: [ReportTextStyle] = []

    func startPage(pageNumber: Int) {}

    func drawText(_ text: String, x: Float, baselineY: Float, style: ReportTextStyle) {
        drawn.append(text)
        styles.append(style)
    }

    func widthOf(_ text: String, style: ReportTextStyle) -> Float {
        Float(text.count) * 5
    }

    func finishPage() {}
}
