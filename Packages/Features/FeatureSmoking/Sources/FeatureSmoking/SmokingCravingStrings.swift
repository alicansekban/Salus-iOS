// The accessors for the keys `:feature:smoking` owns on the craving flow — an extension of
// ``SmokingStrings`` so the enum itself stays inside SwiftLint's 300-line `type_body_length`. The key
// names are in `SmokingStrings.Key`.
//
// The keys are their own enum, ``CravingKey``, beside the accessors: `SmokingStrings.Key` is at
// SwiftLint's 300-line `type_body_length`, which the nested enum counts towards. The parity test
// reads both.
//
// The title ("Canım çekti"), "Sigara içtim", the spoken minutes-and-seconds (``heroMinSec(_:_:)``) and
// the write error are the main screen's and the shell's keys; the flow reads them from there.

import Foundation
import SalusCommon

extension SmokingStrings {
    public static var cravingHeadline: String { localized(.cravingHeadline) }
    public static var cravingPhaseIn: String { localized(.cravingPhaseIn) }
    public static var cravingPhaseHold: String { localized(.cravingPhaseHold) }
    public static var cravingPhaseOut: String { localized(.cravingPhaseOut) }
    public static var cravingChipIn: String { localized(.cravingChipIn) }
    public static var cravingChipHold: String { localized(.cravingChipHold) }
    public static var cravingChipOut: String { localized(.cravingChipOut) }
    public static var cravingLineFocus: String { localized(.cravingLineFocus) }
    public static var cravingPassed: String { localized(.cravingPassed) }
    public static var cravingDoneTitle: String { localized(.cravingDoneTitle) }
    public static var cravingDoneTimer: String { localized(.cravingDoneTimer) }
    public static var cravingDoneSemantics: String { localized(.cravingDoneSemantics) }
    public static var cravingContinue: String { localized(.cravingContinue) }

    /// `smoking_craving_timer_semantics`: the spoken timer, `time` being the minutes and seconds
    /// and `phase` the breath step.
    public static func cravingTimerSemantics(_ time: String, _ phase: String) -> String {
        String(format: localized(.cravingTimerSemantics), locale: .current, time, phase)
    }

    /// `smoking_craving_line_days` / `smoking_craving_line_days_one`: two keys selected in code
    /// (spec §9 (h)), where Android keeps one `<plurals>`.
    public static func cravingLineDays(_ days: Int) -> String {
        String(format: localized(days == 1 ? .cravingLineDaysOne : .cravingLineDays), locale: .current, days)
    }

    /// `smoking_craving_line_saved`: `amount` is the formatted money.
    public static func cravingLineSaved(_ amount: String) -> String {
        String(format: localized(.cravingLineSaved), locale: .current, amount)
    }

    /// `smoking_craving_line_stage`: `title` is the next stage's title.
    public static func cravingLineStage(_ title: String) -> String {
        String(format: localized(.cravingLineStage), locale: .current, title)
    }

    /// `smoking_craving_reason`: the person's own words in curly quotes.
    public static func cravingReason(_ reason: String) -> String {
        String(format: localized(.cravingReason), locale: .current, reason)
    }

    /// `smoking_craving_done_count`: "18. krizi atlattın".
    public static func cravingDoneCount(_ count: Int) -> String {
        String(format: localized(.cravingDoneCount), locale: .current, count)
    }

    // MARK: - Keys

    /// The craving flow's catalog keys, named once. Internal so the parity test can prove every
    /// accessor asks for a key the catalog really carries.
    enum CravingKey: String, CaseIterable {
        case cravingChipHold = "smoking_craving_chip_hold"
        case cravingChipIn = "smoking_craving_chip_in"
        case cravingChipOut = "smoking_craving_chip_out"
        case cravingContinue = "smoking_craving_continue"
        case cravingDoneCount = "smoking_craving_done_count"
        case cravingDoneSemantics = "smoking_craving_done_semantics"
        case cravingDoneTimer = "smoking_craving_done_timer"
        case cravingDoneTitle = "smoking_craving_done_title"
        case cravingHeadline = "smoking_craving_headline"
        case cravingLineDays = "smoking_craving_line_days"
        case cravingLineDaysOne = "smoking_craving_line_days_one"
        case cravingLineFocus = "smoking_craving_line_focus"
        case cravingLineSaved = "smoking_craving_line_saved"
        case cravingLineStage = "smoking_craving_line_stage"
        case cravingPassed = "smoking_craving_passed"
        case cravingPhaseHold = "smoking_craving_phase_hold"
        case cravingPhaseIn = "smoking_craving_phase_in"
        case cravingPhaseOut = "smoking_craving_phase_out"
        case cravingReason = "smoking_craving_reason"
        case cravingTimerSemantics = "smoking_craving_timer_semantics"
    }

    static func localized(_ key: CravingKey) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
