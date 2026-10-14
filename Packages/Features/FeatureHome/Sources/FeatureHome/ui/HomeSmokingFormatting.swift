// The display rules of the smoking card that have no catalog string of their own, ported from
// `HomeSmokingCards.kt` (`formatWholeMoney`, `percentText`) and the next-stage text over
// `StageTimeLeft`, the shared time-left rule.
//
// Android keeps its money formatter private to its smoking feature and copies the reading here;
// this is the same copy for the same reason — a feature never imports another. The one
// difference is the currency's decimals: `java.util.Currency` has no Foundation twin, so they come
// from `NumberFormatter`, which asks ICU for the currency's own digits (the reading
// `FeatureSmoking`'s `SmokingMoney.swift` makes), with two for any code that is not an ISO one —
// Kotlin answers two for anything unknown as well.

import Foundation
import SalusSmoking

enum HomeSmokingFormatting {
    private static let defaultFractionDigits = 2

    /// "3 gün" and its siblings. The rounding is the one every smoking surface shares
    /// (`StageTimeLeft`, contract section 8.15): a count rounded up, never below one minute, with
    /// the unit following the rounded count, so "3 days left" never promises the stage sooner than
    /// it comes and Home agrees with Main and the timeline for the same snapshot.
    static func nextStageText(remainingMs: Int64) -> String {
        let left = StageTimeLeft.of(remainingMs: remainingMs)
        return switch left.unit {
        case .days: HomeStrings.smokingNextDays(left.count)
        case .hours: HomeStrings.smokingNextHours(left.count)
        case .minutes: HomeStrings.smokingNextMinutes(left.count)
        }
    }

    /// `minor` in `currencyCode` for `locale`, rounded half up to whole units ("₺3.150").
    static func wholeMoney(minor: Int64, currencyCode: String, locale: Locale) -> String {
        let isISO = Locale.Currency(currencyCode).isISOCurrency
        let digits = isISO ? fractionDigits(ofCurrency: currencyCode) : defaultFractionDigits
        let value = Decimal(
            sign: minor < 0 ? .minus : .plus,
            exponent: -digits,
            significand: Decimal(minor.magnitude)
        )
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        if isISO {
            formatter.currencyCode = currencyCode
        }
        formatter.roundingMode = .halfUp
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(minor / Int64(pow10(digits)))"
    }

    /// `permille` as the locale writes a percent ("%70" in Turkish, "70%" in English).
    static func percent(permille: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        let value = Decimal(sign: .plus, exponent: -3, significand: Decimal(permille))
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(permille / 10)%"
    }

    private static func fractionDigits(ofCurrency code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.currencyCode = code
        let digits = formatter.maximumFractionDigits
        return digits >= 0 ? digits : defaultFractionDigits
    }

    private static func pow10(_ digits: Int) -> Int {
        (0 ..< digits).reduce(1) { result, _ in result * 10 }
    }
}
