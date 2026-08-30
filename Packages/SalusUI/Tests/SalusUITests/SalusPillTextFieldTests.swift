// The decisions behind `SalusPillTextField`, pinned without rendering it — the same arrangement
// `SalusOptionRowTests` and `SalusDateFieldTests` use.
//
// The interesting one is the error stroke. Kotlin's pill clears all four `TextFieldDefaults`
// indicator colours (`SalusPillTextField.kt:79-88`), so `isError` there only reddens the supporting
// text; the iOS twin draws the capsule itself, which is why it also draws the stroke
// `VitalsEditorField` established (`VitalsEditorField.swift:59-67`). Both halves are pinned here.

import SalusDesignSystem
import SwiftUI
import Testing

@testable import SalusUI

@Suite("SalusPillTextFieldStyle")
struct SalusPillTextFieldTests {
    private let colors = SalusTheme.resolve(systemIsDark: false).colorScheme

    /// `SalusPillTextField.kt:90` — the supporting row exists only when there is something to say,
    /// so the pill never changes height for an empty one.
    @Test("supporting text is drawn only when it is there, and an empty string is not text")
    func supportingTextIsDrawnOnlyWhenPresent() {
        #expect(SalusPillTextFieldStyle.showsSupportingText("50 ile 250 cm arasında bir değer girin."))
        #expect(!SalusPillTextFieldStyle.showsSupportingText(nil))
        #expect(!SalusPillTextFieldStyle.showsSupportingText(""))
    }

    /// `SalusPillTextField.kt:94-98` — `if (isError) error else onSurfaceVariant`.
    @Test("the supporting text reddens while the field is rejected")
    func supportingTextColorFollowsTheErrorFlag() {
        #expect(SalusPillTextFieldStyle.supportingTextColor(isError: true, colors: colors) == colors.error)
        #expect(
            SalusPillTextFieldStyle.supportingTextColor(isError: false, colors: colors)
                == colors.onSurfaceVariant
        )
    }

    /// The iOS-only half: a hand-drawn capsule has no indicator to redden, so the rejected field is
    /// outlined instead — the `VitalsEditorField` stroke, kept optional so a healthy field costs no
    /// layer.
    @Test("only a rejected field is stroked")
    func onlyARejectedFieldIsStroked() {
        #expect(SalusPillTextFieldStyle.stroke(isError: true, colors: colors) == colors.error)
        #expect(SalusPillTextFieldStyle.stroke(isError: false, colors: colors) == nil)
    }

    /// `SalusPillTextField.kt:41` — `singleLine = true` by default; the health-notes field is the
    /// one caller that passes `false`, and a multi-line field grows rather than scrolling sideways.
    @Test("a single-line field is capped at one line, a multi-line one grows")
    func lineLimitFollowsTheSingleLineFlag() {
        #expect(SalusPillTextFieldStyle.lineLimit(isSingleLine: true) == 1 ... 1)
        #expect(SalusPillTextFieldStyle.lineLimit(isSingleLine: false).upperBound > 1)
    }

    /// The init's argument list: two required, the rest defaulted exactly as Kotlin defaults them
    /// (`SalusPillTextField.kt:35-46`). The error flag round-trips, which is what the profile
    /// editor's height field reads back.
    @Test("the field is built from a binding and a placeholder, with every other knob defaulted")
    @MainActor
    func theFieldTakesItsArguments() {
        let rejected = SalusPillTextField(
            text: .constant("300"),
            placeholder: "Örn: 170",
            suffix: "cm",
            isError: true,
            supportingText: "50 ile 250 cm arasında bir değer girin.",
            keyboard: .decimal
        )
        let plain = SalusPillTextField(text: .constant(""), placeholder: "Örn: Ayşe")

        #expect(rejected.isError)
        #expect(rejected.suffix == "cm")
        #expect(!plain.isError)
        #expect(plain.suffix == nil)
        #expect(plain.supportingText == nil)
        #expect(plain.isSingleLine)
    }

    /// `autoCorrectEnabled` is set independently of capitalization on Android
    /// (`ProfileScreen.kt:113` sets it `false` while asking for `Words`), so it is its own argument
    /// here rather than something inferred — a caller that wants `.words` *with* autocorrect can
    /// say so, and the coupling is not invisible at the call site.
    @Test("autocorrect is its own knob, on by default and independent of capitalization")
    @MainActor
    func autocorrectIsIndependentOfCapitalization() {
        let name = SalusPillTextField(
            text: .constant("Ayşe"),
            placeholder: "Örn: Ayşe",
            capitalization: .words,
            autocorrects: false
        )
        let notes = SalusPillTextField(
            text: .constant(""),
            placeholder: "Örn: Penisilin alerjisi",
            isSingleLine: false,
            capitalization: .sentences
        )

        #expect(!name.autocorrects)
        #expect(name.capitalization == .words)
        // The default, which is what the multi-line notes field keeps.
        #expect(notes.autocorrects)
        #expect(notes.capitalization == .sentences)
    }
}
