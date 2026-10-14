// The display rules of the smoking card that have no catalog string of their own, ported from
// `HomeSmokingCards.kt` (`nextStageUnit`, `formatWholeMoney`, `percentText`).
//
// Android keeps its money formatter private to its smoking feature and copies the reading here;
// this is the same copy for the same reason — a feature never imports another. The one
// difference is the currency's decimals: `java.util.Currency` has no Foundation twin, so they come
// from `NumberFormatter`, which asks ICU for the currency's own digits (the reading
// `FeatureSmoking`'s `SmokingMoney.swift` makes), with two for any code that is not an ISO one —
// Kotlin answers two for anything unknown as well.

import Foundation

enum HomeSmokingFormatting {
    enum NextStageUnit: Equatable, Sendable {
        case days
        case hours
        case minutes
    }

    private static let msPerMinute: Int64 = 60000
    private static let msPerHour: Int64 = 3_600_000
    private static let msPerDay: Int64 = 86_400_000
    private static let defaultFractionDigits = 2

    /// The coarsest unit that still reads as a count, rounded up: "3 days left" never promises the
    /// stage sooner than it comes. At least one minute, so a stage seconds away does not say zero.
    static func nextStageUnit(remainingMs: Int64) -> (NextStageUnit, Int) {
        if remainingMs >= msPerDay {
            return (.days, ceilDiv(remainingMs, msPerDay))
        }
        if remainingMs >= msPerHour {
            return (.hours, ceilDiv(remainingMs, msPerHour))
        }
        return (.minutes, max(ceilDiv(remainingMs, msPerMinute), 1))
    }

    private static func ceilDiv(_ value: Int64, _ divisor: Int64) -> Int {
        Int((value + divisor - 1) / divisor)
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
