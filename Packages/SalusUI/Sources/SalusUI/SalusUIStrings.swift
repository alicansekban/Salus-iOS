// The twin of `core/ui/src/main/res/values/strings.xml` (Turkish, the source language) and
// `core/ui/src/main/res/values-en/strings.xml`.
//
// Three strings live in `:core:ui` rather than in a feature because every screen that deletes
// something needs them: the undo action `UndoableDelete` attaches to its snackbar
// (`UndoableDelete.kt:26`), and the confirm/dismiss pair every `SalusConfirmDialog` site passes
// (`VitalsScreen.kt:158-159`, `WeightEditorScreen.kt:143-144`, and six more). They are resolved
// against this package's own bundle, exactly as `R.string` resolves against `:core:ui`'s.
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

/// The shared strings `SalusUI` owns.
public enum SalusUIStrings {
    /// `salus_undo` — "Geri al" / "Undo".
    public static var undo: String { localized(Key.undo) }
    /// `salus_cancel` — "Vazgeç" / "Cancel".
    public static var cancel: String { localized(Key.cancel) }
    /// `salus_delete` — "Sil" / "Delete".
    public static var delete: String { localized(Key.delete) }

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key {
        static let undo = "salus_undo"
        static let cancel = "salus_cancel"
        static let delete = "salus_delete"

        /// Every key this type reads, for the test that compares them with the catalog's.
        static let all: Set<String> = [undo, cancel, delete]
    }

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }
}
