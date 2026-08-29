import Foundation
import Testing

@testable import SalusUI

/// `SalusWeekdaySymbols` is the tree's one sanctioned localized `Calendar` read, so what is pinned
/// here is exactly the two things that make it sanctioned: seven symbols, and Monday at the front.
///
/// The Turkish case does not spell the letters out — ICU owns them and may re-cut a narrow name
/// between OS releases — it checks each letter against the full standalone name of the day it is
/// supposed to head, which is what "Monday first" actually means. The English case can be spelled
/// out, and is, so a rotation that silently became a no-op has one literal to fail against.
@Suite("SalusWeekdaySymbols")
struct SalusWeekdaySymbolsTests {
    @Test("seven symbols, in both project locales")
    func answersSevenSymbols() {
        #expect(SalusWeekdaySymbols.narrowMondayFirst(locale: Locale(identifier: "en_US")).count == 7)
        #expect(SalusWeekdaySymbols.narrowMondayFirst(locale: Locale(identifier: "tr_TR")).count == 7)
    }

    @Test("en_US reads Monday to Sunday")
    func englishStartsOnMonday() {
        let symbols = SalusWeekdaySymbols.narrowMondayFirst(locale: Locale(identifier: "en_US"))

        #expect(symbols == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test("tr_TR starts on Monday too — every letter heads the day it names")
    func turkishStartsOnMonday() {
        let locale = Locale(identifier: "tr_TR")
        let symbols = SalusWeekdaySymbols.narrowMondayFirst(locale: locale)
        // Foundation's own Sunday-first full names, rotated the same way by hand: Pazartesi, Salı,
        // Çarşamba, Perşembe, Cuma, Cumartesi, Pazar.
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let full = calendar.standaloneWeekdaySymbols
        let expectedOrder = Array(full.dropFirst()) + full.prefix(1)

        #expect(expectedOrder.first?.hasPrefix("Pazartesi") == true)
        #expect(expectedOrder.last?.hasPrefix("Pazar") == true)
        for (symbol, name) in zip(symbols, expectedOrder) {
            #expect(name.lowercased(with: locale).hasPrefix(symbol.lowercased(with: locale)))
        }
    }

    /// The calendar is pinned to Gregorian, so a locale that asks for another calendar still gets
    /// the seven Gregorian weekdays — the grid this feeds is Gregorian by construction.
    @Test("a non-Gregorian locale preference does not change the week")
    func ignoresTheLocalesCalendarPreference() {
        let symbols = SalusWeekdaySymbols.narrowMondayFirst(
            locale: Locale(identifier: "en_US@calendar=islamic")
        )

        #expect(symbols == ["M", "T", "W", "T", "F", "S", "S"])
    }
}
