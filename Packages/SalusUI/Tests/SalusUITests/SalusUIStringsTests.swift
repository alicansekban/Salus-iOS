import Foundation
import Testing

@testable import SalusUI

/// The twin of Android's `core/ui/src/main/res/values/strings.xml` (`tr`, the source language) and
/// `values-en/strings.xml`. Three shared strings live there because they are used by every feature
/// that deletes something, so they belong to `:core:ui` rather than to any one feature.
///
/// The catalog is read off disk rather than through `Bundle.module`, for two reasons. Android's own
/// parity checks read the XML for the first: `String(localized:)` answers for ONE locale — the
/// host's — so it can never prove that both locales carry the key. The second is the toolchain note
/// in `SalusUIStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all, so a
/// resolved string here would only ever be the key. iOS-M2 Task 5 generalises this into
/// `SalusTesting.StringCatalogParity`; until it lands, the check lives with the catalog it guards.
@Suite("SalusUI strings")
struct SalusUIStringsTests {
    /// The three keys `:core:ui` owns. Copied from the XML by name — a new key here means a new
    /// key there, in the same commit.
    static let expectedKeys: Set = ["salus_undo", "salus_cancel", "salus_delete"]

    @Test("the catalog holds exactly the three keys :core:ui owns")
    func catalogHoldsExactlyTheThreeKeys() throws {
        let catalog = try Self.loadCatalog()

        #expect(Set(catalog.strings.keys) == Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.sourceLanguage == "tr")
        for (key, entry) in catalog.strings {
            let locales = Set(entry.localizations.keys)
            #expect(locales == ["tr", "en"], "\(key) is localized into \(locales.sorted())")
            for (locale, localization) in entry.localizations {
                #expect(!localization.stringUnit.value.isEmpty, "\(key) is empty in \(locale)")
            }
        }
    }

    @Test("the values are Android-verbatim (core/ui/res/values*/strings.xml)")
    func valuesAreAndroidVerbatim() throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: "salus_undo", in: "tr") == "Geri al")
        #expect(catalog.value(of: "salus_undo", in: "en") == "Undo")
        #expect(catalog.value(of: "salus_cancel", in: "tr") == "Vazgeç")
        #expect(catalog.value(of: "salus_cancel", in: "en") == "Cancel")
        #expect(catalog.value(of: "salus_delete", in: "tr") == "Sil")
        #expect(catalog.value(of: "salus_delete", in: "en") == "Delete")
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `SalusUIStrings.Key`'s literals does not fail to compile — it ships the
        // key itself as the button label. This is the check that catches it.
        #expect(SalusUIStrings.Key.all == Set(catalog.strings.keys))
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> Catalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SalusUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SalusUI
        let url = packageRoot
            .appendingPathComponent("Sources/SalusUI/Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }
}

// MARK: - Reading the catalog

//
// The subset of the `.xcstrings` schema these tests assert on. Flat rather than nested inside the
// suite: SwiftLint caps nesting at two levels and the schema is four deep.

struct CatalogUnit: Decodable {
    let value: String
}

struct CatalogLocalization: Decodable {
    let stringUnit: CatalogUnit
}

struct CatalogEntry: Decodable {
    let localizations: [String: CatalogLocalization]
}

struct Catalog: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogEntry]

    func value(of key: String, in locale: String) -> String? {
        strings[key]?.localizations[locale]?.stringUnit.value
    }
}
