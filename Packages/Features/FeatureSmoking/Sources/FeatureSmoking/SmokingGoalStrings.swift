// The accessors for the keys `:feature:smoking` owns on the premium cards of the main screen (the
// savings-goal card, its sheet and the insights teaser) — an extension of ``SmokingStrings`` so the
// enum itself stays inside SwiftLint's 300-line `type_body_length`. The key names are in
// ``SmokingStrings/GoalKey``, beside the accessors.
//
// `smoking_goal_eta` is two keys selected in code (spec §9 (h)), where Android keeps one `<plurals>`:
// the general key carries the `other` item, `_one` the `one` item.
//
// `smoking_goal_sheet_keep_note` replaces the earlier "a new goal starts counting from zero" note:
// editing a goal in progress keeps what was saved toward it (contract §8.17, parity D-M17-ae).

import Foundation
import SalusCommon

extension SmokingStrings {
    public static var premiumUnlock: String { localized(.premiumUnlock) }
    public static var goalOverline: String { localized(.goalOverline) }
    public static var goalLockedBody: String { localized(.goalLockedBody) }
    public static var goalNoneTitle: String { localized(.goalNoneTitle) }
    public static var goalReachedTitle: String { localized(.goalReachedTitle) }
    public static var goalReachedAction: String { localized(.goalReachedAction) }
    public static var insightsOverline: String { localized(.insightsOverline) }
    public static var insightsTitle: String { localized(.insightsTitle) }
    public static var goalSheetTitle: String { localized(.goalSheetTitle) }
    public static var goalSheetNameLabel: String { localized(.goalSheetNameLabel) }
    public static var goalSheetNamePlaceholder: String { localized(.goalSheetNamePlaceholder) }
    public static var goalSheetAmountLabel: String { localized(.goalSheetAmountLabel) }
    public static var goalSheetAmountError: String { localized(.goalSheetAmountError) }
    public static var goalSheetKeepNote: String { localized(.goalSheetKeepNote) }
    public static var goalSheetSave: String { localized(.goalSheetSave) }

    // MARK: - Formatted strings

    /// `smoking_goal_amounts`: "₺3.150 / ₺8.000".
    public static func goalAmounts(_ saved: String, _ target: String) -> String {
        String(format: localized(.goalAmounts), locale: .current, saved, target)
    }

    /// `smoking_goal_eta`: "yaklaşık 49 gün" / "about 1 day".
    public static func goalEta(_ days: Int64) -> String {
        String(format: localized(days == 1 ? .goalEtaOne : .goalEta), locale: .current, days)
    }

    /// `smoking_goal_reached_body`: the goal's name and its target, "Yeni bisiklet · ₺8.000".
    public static func goalReachedBody(_ title: String, _ target: String) -> String {
        String(format: localized(.goalReachedBody), locale: .current, title, target)
    }

    // MARK: - Keys

    /// The premium cards' catalog keys, named once. They sit beside their accessors, and not in
    /// ``SmokingStrings/Key``, so that enum stays inside SwiftLint's 300-line `type_body_length`;
    /// the parity test checks the union of the enums against the catalog.
    enum GoalKey: String, CaseIterable {
        case premiumUnlock = "smoking_premium_unlock"
        case goalOverline = "smoking_goal_overline"
        case goalLockedBody = "smoking_goal_locked_body"
        case goalNoneTitle = "smoking_goal_none_title"
        case goalAmounts = "smoking_goal_amounts"
        case goalEta = "smoking_goal_eta"
        case goalEtaOne = "smoking_goal_eta_one"
        case goalReachedTitle = "smoking_goal_reached_title"
        case goalReachedBody = "smoking_goal_reached_body"
        case goalReachedAction = "smoking_goal_reached_action"
        case insightsOverline = "smoking_insights_overline"
        case insightsTitle = "smoking_insights_title"
        case goalSheetTitle = "smoking_goal_sheet_title"
        case goalSheetNameLabel = "smoking_goal_sheet_name_label"
        case goalSheetNamePlaceholder = "smoking_goal_sheet_name_placeholder"
        case goalSheetAmountLabel = "smoking_goal_sheet_amount_label"
        case goalSheetAmountError = "smoking_goal_sheet_amount_error"
        case goalSheetKeepNote = "smoking_goal_sheet_keep_note"
        case goalSheetSave = "smoking_goal_sheet_save"
    }

    static func localized(_ key: GoalKey) -> String {
        SalusLocalization.string(key.rawValue, bundle: .module)
    }
}
