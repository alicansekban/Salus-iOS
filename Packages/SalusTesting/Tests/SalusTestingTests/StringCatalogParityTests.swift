import Foundation
import Testing

@testable import SalusTesting

// Guards the parity helper itself, the way `BannedHealthClaimsTests` guards the scan: every check
// is exercised in both directions, because an assertion that cannot fail is not an assertion.
//
// The catalogs here are written to temporary files rather than taken from a package, so a failure
// points at the helper rather than at whichever catalog happened to be nearby.

@Suite("StringCatalogParity")
struct StringCatalogParityTests {
    /// A two-key, two-locale catalog in the shape Xcode writes.
    static func catalogJSON(
        sourceLanguage: String = "tr",
        entries: [String: [String: String]] = ["greeting": ["tr": "Merhaba", "en": "Hello"]]
    ) -> String {
        let strings = entries.map { key, localizations -> String in
            let units = localizations.map { locale, value in
                """
                "\(locale)" : { "stringUnit" : { "state" : "translated", "value" : "\(value)" } }
                """
            }
            return """
            "\(key)" : { "localizations" : { \(units.joined(separator: ", ")) } }
            """
        }
        return """
        { "sourceLanguage" : "\(sourceLanguage)", "strings" : { \(strings
            .joined(separator: ", ")) }, "version" : "1.0" }
        """
    }

    static func writeCatalog(_ json: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("Localizable.xcstrings")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("a well-formed catalog loads, and its values are readable per locale")
    func aWellFormedCatalogLoads() throws {
        let url = try Self.writeCatalog(Self.catalogJSON())

        let catalog = try StringCatalogParity.load(at: url)

        #expect(catalog.sourceLanguage == "tr")
        #expect(catalog.keys == ["greeting"])
        #expect(catalog.value(of: "greeting", in: "tr") == "Merhaba")
        #expect(catalog.value(of: "greeting", in: "en") == "Hello")
        #expect(catalog.value(of: "greeting", in: "de") == nil)
    }

    @Test("a catalog that satisfies every rule passes all three checks")
    func aCatalogThatSatisfiesEveryRulePasses() throws {
        let url = try Self.writeCatalog(Self.catalogJSON())
        let catalog = try StringCatalogParity.load(at: url)

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertKeys(of: catalog, are: ["greeting"])
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test("English as the source language fails: Turkish is the default AND the fallback (spec 6.4)")
    func englishAsSourceLanguageFails() throws {
        let url = try Self.writeCatalog(Self.catalogJSON(sourceLanguage: "en"))
        let catalog = try StringCatalogParity.load(at: url)

        #expect(throws: StringCatalogParity.ParityError.unexpectedSourceLanguage(actual: "en", expected: "tr")) {
            try StringCatalogParity.assertSourceLanguage(of: catalog)
        }
    }

    @Test("a key the pin does not name fails the key-set check")
    func anUnpinnedKeyFails() throws {
        let url = try Self.writeCatalog(Self.catalogJSON())
        let catalog = try StringCatalogParity.load(at: url)

        #expect(throws: StringCatalogParity.ParityError.keySetMismatch(missing: [], unexpected: ["greeting"])) {
            try StringCatalogParity.assertKeys(of: catalog, are: [])
        }
    }

    @Test("a pinned key the catalog is missing fails the key-set check")
    func aMissingKeyFails() throws {
        let url = try Self.writeCatalog(Self.catalogJSON())
        let catalog = try StringCatalogParity.load(at: url)

        #expect(throws: StringCatalogParity.ParityError.keySetMismatch(missing: ["farewell"], unexpected: [])) {
            try StringCatalogParity.assertKeys(of: catalog, are: ["greeting", "farewell"])
        }
    }

    @Test("a key translated into Turkish only fails parity")
    func aTurkishOnlyKeyFails() throws {
        let url = try Self.writeCatalog(Self.catalogJSON(entries: ["greeting": ["tr": "Merhaba"]]))
        let catalog = try StringCatalogParity.load(at: url)

        #expect(
            throws: StringCatalogParity.ParityError.unexpectedLocales(
                key: "greeting",
                actual: ["tr"],
                expected: ["en", "tr"]
            )
        ) {
            try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
        }
    }

    @Test("a third locale fails parity: a catalog carries exactly the two languages the app ships")
    func aThirdLocaleFails() throws {
        let entries = ["greeting": ["tr": "Merhaba", "en": "Hello", "de": "Hallo"]]
        let url = try Self.writeCatalog(Self.catalogJSON(entries: entries))
        let catalog = try StringCatalogParity.load(at: url)

        #expect(
            throws: StringCatalogParity.ParityError.unexpectedLocales(
                key: "greeting",
                actual: ["de", "en", "tr"],
                expected: ["en", "tr"]
            )
        ) {
            try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
        }
    }

    @Test("an empty translation fails: a present-but-blank key is the failure a key-set pin cannot see")
    func anEmptyTranslationFails() throws {
        let url = try Self.writeCatalog(Self.catalogJSON(entries: ["greeting": ["tr": "Merhaba", "en": ""]]))
        let catalog = try StringCatalogParity.load(at: url)

        #expect(throws: StringCatalogParity.ParityError.emptyValue(key: "greeting", locale: "en")) {
            try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
        }
    }
}
