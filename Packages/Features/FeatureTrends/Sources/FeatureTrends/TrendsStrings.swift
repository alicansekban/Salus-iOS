// The twin of `feature/trends/src/main/res/values/strings.xml` (Turkish, the source language) and
// `feature/trends/src/main/res/values-en/strings.xml` — the `trends_*` keys name and text verbatim,
// resolved against this package's own bundle exactly as `R.string` resolves against
// `:feature:trends`.
//
// Task 1 ships the skeleton's keys (title, back, the four ranges, the locked/empty/error bodies);
// the four cards' keys arrive with the analysis tasks that draw them (Task 2's time-of-day, Task
// 3's overlay, Task 4's dose weeks, Task 5's summaries). Each task extends this enum, the catalog
// and the key-set pin together.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. None of Task 1's keys carries a
// specifier, so there is no `%1$s`→`%1$@` / `%1$d`→`%1$lld` rewrite to record here — the mapping is
// the standing one from `CLAUDE.md`, applied the day a key with a placeholder arrives.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. That is why the tests
// assert against the FILE, never against a resolved string; the end-to-end check is the simulator
// run, which `scripts/build-app.sh` builds for.

import Foundation

/// The strings `:feature:trends` owns.
public enum TrendsStrings {
    public static var title: String { localized(.title) }
    public static var back: String { localized(.back) }

    public static var rangeMonth: String { localized(.rangeMonth) }
    public static var rangeQuarter: String { localized(.rangeQuarter) }
    public static var rangeHalfYear: String { localized(.rangeHalfYear) }
    public static var rangeYear: String { localized(.rangeYear) }

    public static var lockedTitle: String { localized(.lockedTitle) }
    public static var lockedMessage: String { localized(.lockedMessage) }
    public static var lockedAction: String { localized(.lockedAction) }

    public static var emptyTitle: String { localized(.emptyTitle) }
    public static var emptyMessage: String { localized(.emptyMessage) }

    public static var errorTitle: String { localized(.errorTitle) }
    public static var errorMessage: String { localized(.errorMessage) }
    public static var errorAction: String { localized(.errorAction) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        case title = "trends_title"
        case back = "trends_back"

        case rangeMonth = "trends_range_month"
        case rangeQuarter = "trends_range_quarter"
        case rangeHalfYear = "trends_range_half_year"
        case rangeYear = "trends_range_year"

        case lockedTitle = "trends_locked_title"
        case lockedMessage = "trends_locked_message"
        case lockedAction = "trends_locked_action"

        case emptyTitle = "trends_empty_title"
        case emptyMessage = "trends_empty_message"

        case errorTitle = "trends_error_title"
        case errorMessage = "trends_error_message"
        case errorAction = "trends_error_action"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .module)
    }
}
