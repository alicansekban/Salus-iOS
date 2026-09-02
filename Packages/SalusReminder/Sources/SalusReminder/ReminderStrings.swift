// The twin of `core/reminder/src/main/res/values/strings.xml` (Turkish, the source language) and
// `core/reminder/src/main/res/values-en/strings.xml`, resolved against this package's own bundle
// exactly as `R.string` resolves against `:core:reminder`.
//
// One key, and one is the whole module surface: the engine bakes every other piece of copy from the
// handler that owns the occurrence (`ReminderNotificationContent`), so the only sentence the engine
// itself has to write is the label on the button that silences a fired reminder without resolving
// it — Android's `alarm_dismiss`, appended to the alarm's actions in `AlarmService.kt:87` and drawn
// under them in `AlarmScreen.kt:153`.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under `swift test`
// finds no table and `String(localized:)` returns the key. The real app build
// (`scripts/build-app.sh`, xcodebuild) does compile it, which is where the translations appear.
// That is why `ReminderStringsTests` asserts against the FILE and never against a resolved string;
// the end-to-end check is the simulator run.

import Foundation
import SalusCommon

/// The strings `:core:reminder` owns.
public enum ReminderStrings {
    /// `alarm_dismiss` — "Kapat" / "Dismiss". The label on the answer that silences a fired
    /// reminder and leaves the occurrence unresolved (``ReminderActionIds/dismiss``).
    public static var alarmDismiss: String { localized(.alarmDismiss) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case alarmDismiss = "alarm_dismiss"
    }

    private static func localized(_ key: Key) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
