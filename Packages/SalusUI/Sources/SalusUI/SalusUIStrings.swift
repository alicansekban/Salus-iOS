// The twin of `core/ui/src/main/res/values/strings.xml` (Turkish, the source language) and
// `core/ui/src/main/res/values-en/strings.xml`.
//
// Three strings live in `:core:ui` rather than in a feature because every screen that deletes
// something needs them: the undo action `UndoableDelete` attaches to its snackbar
// (`UndoableDelete.kt:26`), and the confirm/dismiss pair every `SalusConfirmDialog` site passes
// (`VitalsScreen.kt:158-159`, `WeightEditorScreen.kt:143-144`, and six more). They are resolved
// against this package's own bundle, exactly as `R.string` resolves against `:core:ui`'s.
//
// The M15 primitives added four more for the same reason — they are spoken by components, not by
// screens, so no feature could own them: the sheet header's close button and the stepper's two
// buttons plus the state it announces while its number is still only a suggestion.
//
// M16 added two more, and they are the clearest case yet: the root toolbar's bell and avatar are
// drawn by the SHELL for all five tab roots (`SalusRootToolbar.swift`), so no feature owns them
// either, and Android keeps them in `:core:ui` for the same reason
// (`core/ui/src/main/res/values/strings.xml:11-12`).
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
//
// That is why the tests below the catalog assert against the FILE — key set, both locales,
// Android-verbatim values, and that these accessors ask for keys the catalog actually has — and
// never against a resolved string. The end-to-end check is the simulator run (iOS-M2 Task 7).

import Foundation
import SalusCommon

/// The shared strings `SalusUI` owns.
public enum SalusUIStrings {
    /// `salus_undo` — "Geri al" / "Undo".
    public static var undo: String { localized(Key.undo) }
    /// `salus_cancel` — "Vazgeç" / "Cancel".
    public static var cancel: String { localized(Key.cancel) }
    /// `salus_delete` — "Sil" / "Delete".
    public static var delete: String { localized(Key.delete) }
    /// `salus_sheet_close` — "Kapat" / "Close". The sheet header's close button
    /// (`SalusBottomSheet.kt:98`).
    public static var sheetClose: String { localized(Key.sheetClose) }
    /// `salus_stepper_decrease` — "Azalt" / "Decrease" (`SalusStepperField.kt:175`).
    public static var stepperDecrease: String { localized(Key.stepperDecrease) }
    /// `salus_stepper_increase` — "Artır" / "Increase" (`SalusStepperField.kt:271`).
    public static var stepperIncrease: String { localized(Key.stepperIncrease) }
    /// `salus_stepper_suggested` — "Önerilen değer" / "Suggested value". The state a stepper
    /// announces while the number on screen is only a suggestion (`SalusStepperField.kt:188`).
    public static var stepperSuggested: String { localized(Key.stepperSuggested) }
    /// `salus_topbar_bell_cd` — "Hatırlatıcı sağlığı" / "Reminder health". The root toolbar's bell
    /// (`SalusTopBar.kt:163`).
    public static var topBarBell: String { localized(Key.topBarBell) }
    /// `salus_topbar_profile_cd` — "Profil" / "Profile". The root toolbar's avatar
    /// (`SalusTopBar.kt:182`).
    public static var topBarProfile: String { localized(Key.topBarProfile) }

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key {
        static let undo = "salus_undo"
        static let cancel = "salus_cancel"
        static let delete = "salus_delete"
        static let sheetClose = "salus_sheet_close"
        static let stepperDecrease = "salus_stepper_decrease"
        static let stepperIncrease = "salus_stepper_increase"
        static let stepperSuggested = "salus_stepper_suggested"
        static let topBarBell = "salus_topbar_bell_cd"
        static let topBarProfile = "salus_topbar_profile_cd"

        /// Every key this type reads, for the test that compares them with the catalog's.
        static let all: Set<String> = [
            undo,
            cancel,
            delete,
            sheetClose,
            stepperDecrease,
            stepperIncrease,
            stepperSuggested,
            topBarBell,
            topBarProfile
        ]
    }

    private static func localized(_ key: String) -> String {
        SalusLocalization.string(key, bundle: .module)
    }
}
