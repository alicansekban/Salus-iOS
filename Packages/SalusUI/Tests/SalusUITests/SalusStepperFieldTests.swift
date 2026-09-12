// The decisions `SalusStepperField` makes about the text in its field, pinned without rendering it
// — the shape `SalusCardTests` and `SalusTextFieldTests` set.
//
// The Kotlin twin keeps the same three rules in `commit()` and in the field's seed
// (`SalusStepperField.kt:98-100`, `:141-157`): a suggestion is drawn *behind* an empty field and is
// not a value; text `parse` cannot read reverts to what the field showed rather than raising an
// error; and an edit commits exactly once, on submit or on losing focus.

import Testing

@testable import SalusUI

@Suite("SalusStepperField")
struct SalusStepperFieldTests {
    /// `val seed = if (placeholder) "" else formatted` (`SalusStepperField.kt:100`) — the
    /// suggestion never enters the field, so the first keystroke starts a fresh number.
    @Test("a placeholder field opens empty and reports no value")
    func placeholderReportsNoValue() {
        let seed = SalusStepperFieldState.seed(value: "70", placeholder: true)

        #expect(seed.isEmpty)
        #expect(SalusStepperFieldState.hasValue(text: seed) == false)
    }

    /// The same field without the suggestion holds the value itself, and reports one.
    @Test("a field seeded with a value reports one")
    func seededFieldReportsAValue() {
        let seed = SalusStepperFieldState.seed(value: "70", placeholder: false)

        #expect(seed == "70")
        #expect(SalusStepperFieldState.hasValue(text: seed))
    }

    /// `if (parsed == null) { text = seed; return }` (`SalusStepperField.kt:144-150`): there is
    /// nothing for the user to fix in a field that only holds numbers, so unreadable text goes
    /// back to the number the field showed.
    @Test("text the parse closure rejects keeps the last value", arguments: ["abc", "", "  "])
    func rejectedTextKeepsTheLastValue(_ typed: String) {
        let committed = SalusStepperFieldState.committed(
            text: typed,
            seed: "70",
            parse: { Double($0) != nil }
        )

        #expect(committed == "70")
    }

    /// A rejected edit over a *suggestion* reverts to the suggestion's own seed — nothing — so a
    /// field the user never answered does not acquire a value by being tapped.
    @Test("rejected text over a suggestion reverts to no value")
    func rejectedTextOverASuggestionRevertsToNoValue() {
        let committed = SalusStepperFieldState.committed(
            text: "abc",
            seed: SalusStepperFieldState.seed(value: "70", placeholder: true),
            parse: { Double($0) != nil }
        )

        #expect(committed.isEmpty)
        #expect(SalusStepperFieldState.hasValue(text: committed) == false)
    }

    /// `onValueChange(committed)` (`SalusStepperField.kt:152`) — submit hands the typed text on.
    @Test("text the parse closure accepts commits")
    func acceptedTextCommits() {
        let committed = SalusStepperFieldState.committed(
            text: "72.5",
            seed: "70",
            parse: { Double($0) != nil }
        )

        #expect(committed == "72.5")
    }
}
