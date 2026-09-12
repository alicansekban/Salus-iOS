// The decisions behind `SalusCard`, pinned without rendering it — the shape the component suites
// set: the view is only a `#Preview` build, and everything it decides lives in a plain helper
// beside it.
//
// The Kotlin twin (`SalusCard.kt:103-147` in its M15 shape) makes the accessibility role a
// property of the *two* optional knobs together: a `selected` card is a radio item
// (`Modifier.selectable(role = Role.RadioButton)`, `SalusCard.kt:117`), while a card that is only
// clickable takes the button role (`Surface(onClick = …)`, `SalusCard.kt:123-134`). Each row of the
// trait table is derived from that mapping and pinned here so a future edit cannot silently turn a
// picked plan card into an unnamed button.

import SwiftUI
import Testing

@testable import SalusUI

@Suite("SalusCard")
struct SalusCardTests {
    /// `SalusCard.kt:117` — `selectable(selected = selected, role = Role.RadioButton)`, which
    /// publishes `.isSelected` while picked. A `nil` `selected` (the plain card) has no radio role.
    @Test("a selected card exposes the isSelected trait; a nil selected does not")
    func selectedExposesTheSelectedTrait() {
        #expect(
            SalusCardAccessibility.traits(selected: true, onTap: {}).contains(.isSelected)
        )
        #expect(
            !SalusCardAccessibility.traits(selected: nil, onTap: {}).contains(.isSelected)
        )
    }

    /// `SalusCard.kt:123-134` — a clickable card takes the button role (`Surface(onClick = …)`).
    /// The role exists only when there is something to tap: a card with `onTap == nil` carries no
    /// button trait, whatever the other knobs say. This is what keeps a non-interactive card out of
    /// VoiceOver's focus order.
    @Test("the isButton trait is present only when onTap is not nil")
    func buttonTraitTracksTheTapHandler() {
        #expect(
            SalusCardAccessibility.traits(selected: nil, onTap: {}).contains(.isButton)
        )
        #expect(
            !SalusCardAccessibility.traits(selected: nil, onTap: nil).contains(.isButton)
        )
    }
}
