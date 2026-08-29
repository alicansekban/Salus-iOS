import Foundation
import SalusTesting
import Testing

/// The key-set pin for the **app target's** String Catalog, `App/Localizable.xcstrings`.
///
/// It lives here rather than beside the catalog for one mechanical reason: the app target has no
/// test bundle (`project.yml`'s `scheme.testTargets: []`), so a test that reads a file under
/// `App/` has nowhere else in this repository to run. `BannedHealthClaimsTests` in this same suite
/// already reaches `App/` for exactly that reason, and this file resolves the repository root the
/// same way.
///
/// What it pins is what every package catalog's own suite pins: the key set, Turkish as the source
/// language, both locales on every key, and the Android-verbatim values. The catalog is read off
/// disk rather than through a bundle — `swift test` does not compile a `.xcstrings` at all, so a
/// resolved string here would only ever be the key back (`AppStrings.swift`'s toolchain note). The
/// end-to-end check is the simulator run.
///
/// The accessor check every package suite carries — `Strings.Key.allCases` against the catalog —
/// has no twin here: `AppStrings` is in the app target, which no package can import. The catalog
/// and `AppStrings.Key` are therefore kept in step by review, and both are deleted together when
/// M8's settings hub replaces `PlaceholderScreen`.
@Suite("App target strings")
struct AppStringCatalogTests {
    /// Every key the shell owns, with both translations, copied from Android's
    /// `feature/settings/src/main/res/values{,-en}/strings.xml:79-80`.
    static let samples: [Sample] = [
        Sample(
            key: "more_cycle",
            turkish: "Regl Takibi",
            english: "Cycle tracking"
        ),
        Sample(
            key: "more_cycle_subtitle",
            turkish: "Takvim, tahminler ve belirtiler",
            english: "Calendar, predictions and symptoms"
        )
    ]

    static var expectedKeys: Set<String> { Set(samples.map(\.key)) }

    @Test("the catalog holds exactly the two keys the shell owns")
    func catalogHoldsExactlyTheTwoKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 2)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values are Android-verbatim (feature/settings/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: Sample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    /// The catalog file itself, read from the repository tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SalusTestingTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // SalusTesting
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // <repository root>
        return try StringCatalogParity.load(
            at: repositoryRoot.appendingPathComponent("App/Localizable.xcstrings")
        )
    }

    /// One key with both of its Android values.
    struct Sample: Sendable {
        let key: String
        let turkish: String
        let english: String
    }
}
