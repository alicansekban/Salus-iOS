import Foundation
import SalusTesting
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
/// resolved string here would only ever be the key.
///
/// The parity mechanics moved to `SalusTesting.StringCatalogParity` with iOS-M2 Task 5, so this
/// suite is `:core:ui`'s application of them plus the Android-verbatim values, which no shared
/// helper can own.
@Suite("SalusUI strings")
struct SalusUIStringsTests {
    /// The three keys `:core:ui` owns. Copied from the XML by name — a new key here means a new
    /// key there, in the same commit.
    static let expectedKeys: Set = ["salus_undo", "salus_cancel", "salus_delete"]

    @Test("the catalog holds exactly the three keys :core:ui owns")
    func catalogHoldsExactlyTheThreeKeys() throws {
        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
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
        #expect(SalusUIStrings.Key.all == catalog.keys)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SalusUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SalusUI
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/SalusUI/Resources/Localizable.xcstrings")
        )
    }
}
