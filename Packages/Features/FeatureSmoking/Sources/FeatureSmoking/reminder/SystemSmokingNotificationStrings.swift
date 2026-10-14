// Twin of `AndroidSmokingNotificationStrings.kt` on branch `feature/m17-smoking-cessation`: the
// catalog-backed texts, the only part of the smoking reminder that reads resources.

import Foundation
import SalusCommon

public struct SystemSmokingNotificationStrings: SmokingNotificationStrings {
    private static let daysPerYear: Int64 = 365

    public init() {}

    /// Read per call, so a language switched in the app settings applies to the next notification.
    private var locale: Locale {
        SalusLocalization.languageCode.map { Locale(identifier: $0) } ?? .current
    }

    public func stageReached(stageId: String) -> String? {
        StageCopy.title(of: stageId).map(SmokingStrings.notificationStage)
    }

    public func daysReached(_ days: Int64) -> String {
        if days >= Self.daysPerYear, days.isMultiple(of: Self.daysPerYear) {
            return SmokingStrings.notificationYears(Int(days / Self.daysPerYear))
        }
        // Day milestones stay far below Int.max (one a year, then a handful of years).
        return SmokingStrings.notificationDays(Int(days))
    }

    public func unitsSkipped(_ units: Int64) -> String {
        SmokingStrings.notificationUnits(units.formatted(.number.locale(locale)))
    }

    public func moneySaved(minor: Int64, currencyCode: String) -> String {
        SmokingStrings.notificationMoney(
            formatMoney(minor: minor, currencyCode: currencyCode, locale: locale, showFraction: false)
        )
    }

    public func stageHint() -> String {
        SmokingStrings.notificationStageHint
    }

    public func cheer() -> String {
        SmokingStrings.notificationCheer
    }

    public func eveningTitle() -> String {
        SmokingStrings.notificationEveningTitle
    }

    public func eveningText() -> String {
        SmokingStrings.notificationEveningText
    }
}
