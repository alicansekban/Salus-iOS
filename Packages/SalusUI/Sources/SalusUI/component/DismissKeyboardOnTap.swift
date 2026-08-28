// No Android twin, and that is the point: this is an iOS-only affordance the port owes the
// platform, not a ported component.
//
// Compose gives every `TextField` an IME action — `ImeAction.Next` / `ImeAction.Done`
// (`MedicationEditorScreen.kt:138,154,163,186,197,233`) — and Android's number and decimal IMEs
// still draw that key, so a Compose editor always has a labelled way down from the keyboard.
// UIKit's `.numberPad` and `.decimalPad` draw no return key at all, so a screen whose numeric
// fields use them leaves the user with a keyboard and nothing to press. Tapping outside the field
// is what iOS users reach for, and SwiftUI does not do it for free.
//
// **Three implementations were measured on a booted simulator before this one was kept**, because
// the two that read better on the page do nothing at all and fail exactly like a clean build:
//
//   1. `background(Color.clear.contentShape(Rectangle()).onTapGesture { … })` — the layer renders
//      and never receives a touch, whether it is put behind the `ScrollView` or behind the padded
//      stack inside it. SwiftUI does not offer a tap to `background` content here. The same layer
//      moved to `overlay` fires on the first try, which is how we know the layer itself is fine
//      and the z-order is what decides it — but an overlay swallows every chip and field under it,
//      so it is not a candidate.
//   2. `contentShape(Rectangle()).onTapGesture { … }` on the scroll content, and a plain
//      `onTapGesture` on the `ScrollView` itself — neither fires on empty space.
//   3. `simultaneousGesture(TapGesture())` on the `ScrollView` — the one that works, and what
//      this modifier is.
//
// The cost of (3) is the thing to know before reusing it: a simultaneous gesture sees *every* tap
// in the scroll view, including the tap that moves focus from one text field to the next, so that
// tap resigns the old responder on its way to the new one. Nothing is swallowed — the chip, the
// date field, the button and the text field under the finger all still receive their own tap,
// which is what `simultaneousGesture` means — but a focus move between two fields does ask the
// keyboard to go down and come straight back up.

import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

extension View {
    /// Ends text editing — closing the keyboard — when the user taps inside this view.
    ///
    /// Apply it to an editor's `ScrollView`, alongside `.scrollDismissesKeyboard(.interactively)`:
    /// the two cover the two gestures a user tries, a tap and a drag down over the form.
    ///
    /// Nothing is swallowed. The gesture runs *simultaneously* with whatever is under the finger,
    /// so text fields, `SalusFilterChip`s, `SalusDateField` / `SalusTimeField`, toggles and buttons
    /// keep their taps exactly as before. Read the file comment above before reaching for a
    /// tidier-looking `background` or `onTapGesture` instead: both were measured, and both are
    /// inert here.
    ///
    /// **Manual check** (this package has no view-test harness, and the effect is a UIKit
    /// responder-chain side effect with no value to read back): open the medication editor, focus
    /// the strength field so the `.decimalPad` — which has no return key — comes up, then confirm
    /// that (1) tapping the empty space beside a chip row closes it, (2) a recurrence chip, the
    /// date field and the save button still react to a single tap, and (3) tapping straight from
    /// one text field into another leaves the second field focused.
    @MainActor
    public func salusDismissesKeyboardOnTap() -> some View {
        simultaneousGesture(TapGesture().onEnded { salusEndEditing() })
    }
}

/// Asks whoever is first responder to resign it, which is what closes the keyboard.
///
/// UIKit-only and guarded, because `swift test` builds `SalusUI` on a macOS host (see the
/// `.macOS(.v14)` concession in `Package.swift`) where there is no `UIApplication` and no
/// keyboard to close; there the body compiles away to nothing.
@MainActor
private func salusEndEditing() {
    #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    #endif
}
