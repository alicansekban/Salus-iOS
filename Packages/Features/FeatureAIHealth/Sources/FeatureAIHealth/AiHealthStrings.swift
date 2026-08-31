// The twin of `feature/aihealth/src/main/res/values/strings.xml` (Turkish, the source language)
// and `feature/aihealth/src/main/res/values-en/strings.xml` — the `ai_summary_*` keys and
// `ai_language_code`, name and text verbatim, resolved against this package's own bundle exactly
// as `R.string` resolves against `:feature:aihealth`.
//
// THE DOCTOR-REPORT KEYS ARE NOT HERE, and that is the milestone split: `doctor_report_*` belongs
// to Task 6 of iOS-M10, which ships the report screen. This catalog carries only what this task's
// summary screen reads, so the key-set pin below is 20 where the Android XML is 44. When Task 6
// lands, the keys and the pin grow together in the same commit.
//
// `ai_language_code` is the one key that is not user-visible: it is the language the model answers
// in, resolved by the resource system rather than derived from a locale by hand, so whatever
// qualifier the framework picks for the strings the user is reading is the one it picks here and
// the two can never disagree. It maps onto `AiLanguage`; any unrecognised value falls back to TR.
//
// PLACEHOLDER MAPPING, the one place the port is not byte-for-byte. None of the `ai_summary_*`
// keys carries a specifier, so there is no `%1$s`→`%1$@` / `%1$d`→`%1$lld` rewrite to record here
// — the mapping is the standing one from `CLAUDE.md`, applied the day a key with a placeholder
// arrives.
//
// TOOLCHAIN NOTE, and it costs an hour to rediscover: a `.xcstrings` catalog is compiled into
// `.lproj/Localizable.strings` by **Xcode's** build system only. Command-line `swift build` /
// `swift test` copies the catalog into the resource bundle verbatim, so a lookup under
// `swift test` finds no table and `String(localized:)` returns the key. That is why the tests
// assert against the FILE, never against a resolved string; the end-to-end check is the simulator
// run.

import Foundation

/// The strings `:feature:aihealth` owns.
public enum AiHealthStrings {
    // MARK: - The summary screen (19)

    public static var summaryTitle: String { localized(.summaryTitle) }
    public static var summaryBack: String { localized(.summaryBack) }

    public static var periodWeekly: String { localized(.periodWeekly) }
    public static var periodMonthly: String { localized(.periodMonthly) }

    public static var loading: String { localized(.loading) }
    public static var fromCache: String { localized(.fromCache) }
    public static var disclaimer: String { localized(.disclaimer) }

    public static var insufficientTitle: String { localized(.insufficientTitle) }
    public static var insufficientMessage: String { localized(.insufficientMessage) }

    public static var premiumTitle: String { localized(.premiumTitle) }
    public static var premiumMessage: String { localized(.premiumMessage) }
    public static var premiumAction: String { localized(.premiumAction) }

    public static var dailyLimitTitle: String { localized(.dailyLimitTitle) }
    public static var dailyLimitMessage: String { localized(.dailyLimitMessage) }

    public static var errorTitle: String { localized(.errorTitle) }
    public static var errorMessage: String { localized(.errorMessage) }
    public static var retry: String { localized(.retry) }

    public static var unavailableTitle: String { localized(.unavailableTitle) }
    public static var unavailableMessage: String { localized(.unavailableMessage) }

    // MARK: - The model language (1)

    /// The language the model answers in, resolved by the resource system (`ai_language_code`).
    /// NOT user-visible.
    public static var languageCode: String { localized(.languageCode) }

    // MARK: - Keys

    /// The catalog keys, named once. Internal so the parity test can prove every accessor asks for
    /// a key the catalog really carries — a typo here would otherwise ship the key as the label.
    enum Key: String, CaseIterable {
        // The summary screen (19).
        case summaryTitle = "ai_summary_title"
        case summaryBack = "ai_summary_back"
        case periodWeekly = "ai_summary_period_weekly"
        case periodMonthly = "ai_summary_period_monthly"
        case loading = "ai_summary_loading"
        case fromCache = "ai_summary_from_cache"
        case disclaimer = "ai_summary_disclaimer"
        case insufficientTitle = "ai_summary_insufficient_title"
        case insufficientMessage = "ai_summary_insufficient_message"
        case premiumTitle = "ai_summary_premium_title"
        case premiumMessage = "ai_summary_premium_message"
        case premiumAction = "ai_summary_premium_action"
        case dailyLimitTitle = "ai_summary_daily_limit_title"
        case dailyLimitMessage = "ai_summary_daily_limit_message"
        case errorTitle = "ai_summary_error_title"
        case errorMessage = "ai_summary_error_message"
        case retry = "ai_summary_retry"
        case unavailableTitle = "ai_summary_unavailable_title"
        case unavailableMessage = "ai_summary_unavailable_message"

        /// The model language (1).
        case languageCode = "ai_language_code"
    }

    private static func localized(_ key: Key) -> String {
        String(localized: String.LocalizationValue(key.rawValue), bundle: .module)
    }
}
