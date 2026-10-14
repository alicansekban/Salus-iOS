// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/common/
// SmokingMoney.kt`.
//
// Money in this feature is an `Int64` of minor units everywhere except at the edge: what a person
// types is read into minor units here, and what a screen shows is formatted from them here.
// Nothing in between touches a `Float` or a `Double` (contract §2).
//
// `java.util.Currency` has no Foundation twin. Its decimals come from `NumberFormatter`, which asks
// ICU for the currency's own digits, after `Locale.Currency` has vouched that the code is an ISO
// 4217 one (Kotlin answers two for anything unknown, and so does this).

import Foundation

private let defaultFractionDigits = 2
private let maxWholeDigits = 9
private let fallbackCurrency = "TRY"

/// The decimals ISO 4217 gives `code`; two for anything unknown, the common case.
func fractionDigits(ofCurrency code: String) -> Int {
    guard Locale.Currency(code).isISOCurrency else { return defaultFractionDigits }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.currencyCode = code
    let digits = formatter.maximumFractionDigits
    return digits >= 0 ? digits : defaultFractionDigits
}

/// Reads `text` as an amount in minor units, or `nil` when it is not a plain non-negative amount
/// with at most `fractionDigits` decimals. Either `.` or `,` may be the separator; thousands
/// separators are not accepted, because "1.234" cannot be told from 1.234 without a locale.
func parseMinorUnits(_ text: String, fractionDigits: Int) -> Int64? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(
        maxSplits: 1,
        omittingEmptySubsequences: false,
        whereSeparator: { $0 == "." || $0 == "," }
    )
    guard let whole = parts.first, (1 ... maxWholeDigits).contains(whole.count), whole.allSatisfy(isASCIIDigit) else {
        return nil
    }
    var fraction = ""
    if parts.count == 2 {
        let typed = parts[1]
        // A separator needs at least one digit after it, and no more than the currency has.
        guard !typed.isEmpty, typed.count <= fractionDigits, typed.allSatisfy(isASCIIDigit) else { return nil }
        fraction = String(typed)
    }
    let padded = fraction.padding(toLength: fractionDigits, withPad: "0", startingAt: 0)
    return Int64(String(whole) + padded)
}

private func isASCIIDigit(_ character: Character) -> Bool {
    character.isASCII && character.isNumber
}

/// `minor` as the text a field holds: no decimals it does not need, `.` as the separator.
func plainAmount(minor: Int64, fractionDigits: Int) -> String {
    let scale = pow10(fractionDigits)
    let whole = minor / scale
    let remainder = String(minor % scale)
    var fraction = String(repeating: "0", count: max(0, fractionDigits - remainder.count)) + remainder
    while fraction.hasSuffix("0") {
        fraction.removeLast()
    }
    return fractionDigits == 0 || fraction.isEmpty ? String(whole) : "\(whole).\(fraction)"
}

/// The factor between a whole currency unit and its minor unit.
func pow10(_ digits: Int) -> Int64 {
    var result: Int64 = 1
    for _ in 0 ..< digits {
        result *= 10
    }
    return result
}

/// `minor` in `currencyCode` for `locale`. `showFraction == false` rounds half up to whole units,
/// which is how the summaries read ("₺34.675"); the amounts a person typed keep their decimals.
func formatMoney(minor: Int64, currencyCode: String, locale: Locale, showFraction: Bool) -> String {
    let digits = fractionDigits(ofCurrency: currencyCode)
    let value = Decimal(
        sign: minor < 0 ? .minus : .plus,
        exponent: -digits,
        significand: Decimal(minor.magnitude)
    )
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = locale
    if Locale.Currency(currencyCode).isISOCurrency {
        formatter.currencyCode = currencyCode
    }
    formatter.roundingMode = .halfUp
    if !showFraction {
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
    }
    return formatter.string(from: NSDecimalNumber(decimal: value)) ?? plainAmount(minor: minor, fractionDigits: digits)
}

/// The symbol of `code` in `locale` alone ("₺"), for labels like "+₺50".
func currencySymbol(of code: String, locale: Locale) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = locale
    formatter.currencyCode = code
    return formatter.currencySymbol ?? code
}

/// The currency of `locale`'s country. A language-only locale (the app's own per-app locale is
/// "tr", with no region) names none, and lira is the market the app ships to first; the setup
/// lets the person change it either way.
func defaultCurrencyCode(for locale: Locale) -> String {
    guard locale.region != nil else { return fallbackCurrency }
    return locale.currency?.identifier ?? fallbackCurrency
}
