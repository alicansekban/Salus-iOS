import Testing

@testable import SalusAI

// Ported 1:1 from Android
// `core/ai/src/test/kotlin/com/alicansekban/salus/core/ai/PlainTextTest.kt`.
//
// The cases here are taken from real model output: asked for plain text in Turkish, the model
// still answered with `**bold**` section labels and `-` list markers.

@Suite("PlainText (Android parity)")
struct PlainTextTests {
    @Test("bold markers are removed and the words they wrapped are kept")
    func boldMarkersAreRemovedAndTheWordsTheyWrappedAreKept() {
        #expect(
            "**Kan Basıncı:** ortalama 126.1 mmHg".asPlainText()
                == "Kan Basıncı: ortalama 126.1 mmHg"
        )
        #expect("__vurgu burada__".asPlainText() == "vurgu burada")
        #expect("*italik*".asPlainText() == "italik")
        #expect("`kod`".asPlainText() == "kod")
    }

    @Test("list markers become bullets")
    func listMarkersBecomeBullets() {
        #expect(
            "- **Kan Şekeri:** 3 ölçüm\n* **Kilo:** 4 ölçüm".asPlainText()
                == "• Kan Şekeri: 3 ölçüm\n• Kilo: 4 ölçüm"
        )
    }

    @Test("heading marks are removed but the heading text stays")
    func headingMarksAreRemovedButTheHeadingTextStays() {
        #expect("## Son 7 Günün Özeti".asPlainText() == "Son 7 Günün Özeti")
    }

    @Test("an unpaired asterisk in a sentence is content and survives")
    func anUnpairedAsteriskInASentenceIsContentAndSurvives() {
        // Nothing is ever dropped: a lone marker means the model was writing prose, not syntax.
        #expect("2 * 3 değeri".asPlainText() == "2 * 3 değeri")
        #expect("yıldız * burada".asPlainText() == "yıldız * burada")
    }

    @Test("emphasis is not matched across a line break")
    func emphasisIsNotMatchedAcrossALineBreak() {
        // A greedy match here would swallow the newline and glue two paragraphs together.
        #expect("*ilk satır\nikinci satır*".asPlainText() == "*ilk satır\nikinci satır*")
    }

    @Test("plain text passes through unchanged apart from trailing space")
    func plainTextPassesThroughUnchangedApartFromTrailingSpace() {
        let text = "Kaydedilen 7 dozun 6 tanesi alındı olarak işaretlendi (%85).\n\nİkinci paragraf."
        #expect("\(text)   ".asPlainText() == text)
    }

    @Test("indentation of a nested list item is preserved")
    func indentationOfANestedListItemIsPreserved() {
        #expect("  - alt madde".asPlainText() == "  • alt madde")
    }
}
