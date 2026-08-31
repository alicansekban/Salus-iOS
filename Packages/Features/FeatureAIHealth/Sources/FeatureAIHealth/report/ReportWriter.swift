// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/report/
// ReportWriter.kt`.

import Foundation

/// The roles text can take on the page. A surface maps each one onto a concrete font.
enum ReportTextStyle: Sendable {
    case title
    case section
    case body
    case columnHeader
    case footer
}

/// Where the ink goes — the only part of the report that needs a graphics stack.
///
/// It exists because `UIGraphicsPDFRenderer` has no unit-test story at all: it is backed by
/// native calls that a host build cannot run, so any layout rule expressed directly against it is
/// untestable by construction. Everything that decides *where a line lands and when a page breaks*
/// lives above this interface and is asserted through a recording double; below it there is
/// nothing left but delegation.
protocol ReportSurface {
    func startPage(pageNumber: Int)

    /// - Parameter baselineY: distance from the top of the page to the text baseline.
    func drawText(_ text: String, x: Float, baselineY: Float, style: ReportTextStyle)

    /// Rendered width of `text`, for wrapping.
    func widthOf(_ text: String, style: ReportTextStyle) -> Float

    func finishPage()
}

/// Lays `ReportBlock`s out top-down on A4 pages, breaking to a new page whenever the next line
/// would cross `CONTENT_BOTTOM`.
///
/// **The disclaimer is drawn on the footer of every page, never once at the end.** A doctor
/// report gets pages torn off, photographed and forwarded one at a time, so a page that left the
/// document without it would stand alone as an unqualified medical claim. That is a property of
/// this class rather than a rule each section has to remember: `closePage` is the only path that
/// finishes a page, and it draws the footer first.
final class ReportWriter {
    private let surface: any ReportSurface
    private let footer: String

    private var pageOpen = false
    private var cursorY: Float = 0

    /// Pages started so far, which is also the page number of the open one.
    private(set) var pageCount = 0

    init(surface: any ReportSurface, footer: String) {
        self.surface = surface
        self.footer = footer
    }

    func draw(_ blocks: [ReportBlock]) {
        for block in blocks {
            switch block {
            case let .title(text):
                line(text, style: .title, leading: titleLeading)
            case let .section(heading):
                section(heading)
            case let .body(text):
                body(text)
            case .gap:
                gap(bodyLeading)
            case let .table(heading, columns, weights, rows):
                table(heading: heading, columns: columns, weights: weights, rows: rows)
            }
        }
        finish()
    }

    private func section(_ heading: String) {
        gap()
        line(heading, style: .section, leading: sectionLeading)
    }

    private func body(_ text: String) {
        // Wrapped rather than clipped: a narrative line is model output of unbounded length, and
        // a sentence cut off mid-word in a medical document is worse than a taller page.
        for wrapped in wrap(text) {
            line(wrapped, style: .body, leading: bodyLeading)
        }
    }

    private func gap(_ height: Float = sectionSpacing) {
        require(height)
        cursorY += height
    }

    /// A heading, a column header and the data rows. The column header is redrawn after a page
    /// break, so a table that spans pages never leaves a page of bare numbers behind.
    private func table(heading: String, columns: [String], weights: [Float], rows: [[String]]) {
        // A heading over nothing reads as "measured, and got no result". `reportBlocksOf` never
        // emits an empty table, but the writer should not depend on that to stay honest.
        if rows.isEmpty {
            return
        }

        // The heading, its column header and the first row are reserved as one block, so a
        // heading can never be the last line of a page with its table stranded on the next. The
        // nested `require` calls below are then satisfied by this reservation and do not break.
        require(sectionSpacing + sectionLeading + bodyLeading * 2)
        section(heading)
        let offsets = columnOffsets(weights)
        var pageOfHeader = -1
        for cells in rows {
            // Two lines of room, so a column header is never the last thing on a page.
            require(bodyLeading * 2)
            if pageCount != pageOfHeader {
                self.cells(columns, style: .columnHeader, offsets: offsets)
                pageOfHeader = pageCount
            }
            self.cells(cells, style: .body, offsets: offsets)
        }
        gap()
    }

    /// Closes the last page. Nothing may be drawn afterwards.
    private func finish() {
        // A document with no page at all is not a valid PDF; only reachable for an empty list.
        if !pageOpen {
            newPage()
        }
        closePage()
    }

    private func line(_ text: String, style: ReportTextStyle, leading: Float) {
        require(leading)
        surface.drawText(text, x: margin, baselineY: cursorY, style: style)
        cursorY += leading
    }

    private func cells(_ values: [String], style: ReportTextStyle, offsets: [Float]) {
        require(bodyLeading)
        for (index, cell) in values.enumerated() {
            surface.drawText(cell, x: margin + offsets[index], baselineY: cursorY, style: style)
        }
        cursorY += bodyLeading
    }

    /// Guarantees `height` of room below the cursor, breaking the page when there is not.
    private func require(_ height: Float) {
        if !pageOpen {
            newPage()
        } else if cursorY + height > contentBottom {
            closePage()
            newPage()
        }
    }

    private func newPage() {
        pageCount += 1
        surface.startPage(pageNumber: pageCount)
        pageOpen = true
        cursorY = margin + titleLeading
    }

    private func closePage() {
        if !pageOpen {
            return
        }
        surface.drawText(footer, x: margin, baselineY: footerBaseline, style: .footer)
        surface.finishPage()
        pageOpen = false
    }

    private func wrap(_ text: String) -> [String] {
        if surface.widthOf(text, style: .body) <= usableWidth {
            return [text]
        }

        var wrapped: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            let candidate = current.isEmpty ? String(word) : "\(current) \(word)"
            if surface.widthOf(candidate, style: .body) <= usableWidth {
                current = candidate
            } else {
                // A single word wider than the page still gets its own line: breaking inside a
                // word would be worse than one line that runs long.
                if !current.isEmpty {
                    wrapped.append(current)
                }
                current = String(word)
            }
        }
        if !current.isEmpty {
            wrapped.append(current)
        }
        return wrapped
    }

    private func columnOffsets(_ weights: [Float]) -> [Float] {
        var offset: Float = 0
        return weights.map { weight in
            let current = offset
            offset += weight * usableWidth
            return current
        }
    }
}

/// A4 at 72 dpi, which is the unit `UIGraphicsPDFRenderer`'s page rectangle takes.
let pageWidth: Float = 595
let pageHeight: Float = 842

private let margin: Float = 40
private let usableWidth = pageWidth - 2 * margin

/// Floor for body content: everything below it belongs to the footer disclaimer.
private let contentBottom = pageHeight - 56
private let footerBaseline = pageHeight - 28

private let titleLeading: Float = 26
private let sectionLeading: Float = 18
private let bodyLeading: Float = 14
private let sectionSpacing: Float = 10
