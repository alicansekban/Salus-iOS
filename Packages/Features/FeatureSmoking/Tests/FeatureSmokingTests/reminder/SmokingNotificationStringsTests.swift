// The milestone-notification copy: the two plural pairs differ only where English does, and the
// formatted sentences render as Android's.
// Key/value parity with the Android XML is pinned by `SmokingStringsTests` over
// `SmokingNotificationStringTable`; this suite covers what that table cannot.

import Foundation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@Suite("Smoking notification strings")
struct SmokingNotificationStringsTests {
    @Test("the plural pairs carry one count and differ only where English does")
    func pluralPairsDifferOnlyWhereEnglishDoes() throws {
        let catalog = try SmokingStringsTests.loadCatalog()

        for base in ["smoking_notification_days", "smoking_notification_years"] {
            let turkishMany = try #require(catalog.value(of: base, in: "tr"))
            let turkishOne = try #require(catalog.value(of: "\(base)_one", in: "tr"))
            let englishMany = try #require(catalog.value(of: base, in: "en"))
            let englishOne = try #require(catalog.value(of: "\(base)_one", in: "en"))

            #expect(turkishMany == turkishOne)
            #expect(englishMany != englishOne)
            for value in [turkishMany, turkishOne, englishMany, englishOne] {
                #expect(value.components(separatedBy: "%lld").count == 2, "\(value) must carry one count")
            }
        }
    }

    @Test("the formatted notification sentences render as Android's")
    func formattedSentencesRender() throws {
        let catalog = try SmokingStringsTests.loadCatalog()
        let render = { (key: String, locale: String, argument: CVarArg) throws -> String in
            try SmokingStringsTests.render(catalog, key, locale, argument)
        }

        #expect(try render("smoking_notification_stage", "tr", "12 saat · Kandaki karbonmonoksit")
            == "Yeni aşama: 12 saat · Kandaki karbonmonoksit")
        #expect(try render("smoking_notification_stage", "en", "48 hours · Taste and smell")
            == "New stage: 48 hours · Taste and smell")
        #expect(try render("smoking_notification_days", "tr", 7) == "7 gün oldu!")
        #expect(try render("smoking_notification_days_one", "en", 1) == "It's been 1 day!")
        #expect(try render("smoking_notification_years", "en", 2) == "It's been 2 years!")
        #expect(try render("smoking_notification_units", "tr", "1.000") == "1.000 adet içmedin")
        #expect(try render("smoking_notification_money", "en", "₺1,000") == "You've saved ₺1,000")
    }
}
