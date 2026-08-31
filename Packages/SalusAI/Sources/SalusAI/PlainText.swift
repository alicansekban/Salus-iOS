// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/PlainText.kt`.

import Foundation

/// Strips the markdown a model emits even when the prompt asks for plain text.
///
/// Nothing downstream renders markdown: the summary screen draws the string in a `Text` and the
/// doctor report draws it onto a PDF canvas, so `**Blood pressure**` reaches the reader with the
/// asterisks still in it. The instruction to write plain text is in the system prompt, but a
/// prompt is a request and this is the guarantee — a model that slips must not put syntax in
/// front of a user, or in front of their doctor.
///
/// Only markers are removed; no word is ever dropped. A list item keeps its shape as a real
/// bullet rather than losing it, because the shape is what makes the sections readable.
extension String {
    func asPlainText() -> String {
        split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in String(line).stripBlockMarkers().stripInlineMarkers().trimmingTrailingWhitespace }
            .joined(separator: "\n")
            // Blank leading/trailing lines only: a plain `trim()` would also eat the indentation
            // of a nested list item that happens to be the first line.
            .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
    }
}

/// Rewrites what a line *is*: a heading loses its hashes, a list item trades its `-`/`*`/`+`
/// for a bullet. Handled before `stripInlineMarkers` so a leading `*` is understood as a list
/// marker rather than an unpaired emphasis marker.
extension String {
    private func stripBlockMarkers() -> String {
        let indent = String(prefix { $0 == " " || $0 == "\t" })
        let body = String(dropFirst(indent.count))
        if body.range(of: headingPattern, options: .regularExpression) != nil {
            return indent + String(body.drop(while: { $0 == "#" })).trimmingLeadingWhitespace
        }
        if body.range(of: bulletPattern, options: .regularExpression) != nil {
            return indent + "• " + String(body.dropFirst()).trimmingLeadingWhitespace
        }
        return self
    }

    /// Removes emphasis and code markers, keeping the text they wrapped.
    private func stripInlineMarkers() -> String {
        emphasisPatterns.reduce(self) { text, pattern in
            text.replacingOccurrences(
                of: pattern,
                with: "$1",
                options: .regularExpression
            )
        }
    }
}

/// `#`, `##`, … followed by text. A bare `#` with no text is left alone — it is not a heading.
private let headingPattern = "^#{1,6}\\s+.*"

/// `-`, `*` or `+` used as a list marker: the marker, a space, then something.
private let bulletPattern = "^[-*+]\\s+\\S.*"

/// Paired markers only, and never across a line break: an asterisk standing alone in a sentence
/// is content, not syntax, and must survive.
private let emphasisPatterns = [
    "\\*\\*(.+?)\\*\\*",
    "__(.+?)__",
    "\\*(.+?)\\*",
    "`(.+?)`"
]

extension String {
    /// The trailing whitespace of a line, trimmed. `trimEnd()` in Kotlin.
    private var trimmingTrailingWhitespace: String {
        String(reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    }

    /// The leading whitespace of a line, trimmed. `trimStart()` in Kotlin.
    private var trimmingLeadingWhitespace: String {
        String(drop(while: { $0 == " " || $0 == "\t" }))
    }
}
