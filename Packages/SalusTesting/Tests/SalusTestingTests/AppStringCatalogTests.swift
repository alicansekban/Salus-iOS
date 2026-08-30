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
/// and `AppStrings.Key` are therefore kept in step by review.
///
/// **The set is three keys.** They are the shell's permanently — Android's app-module strings
/// (`app/src/main/res/values{,-en}/strings.xml:11-13`), drawn by `App/Lock/AppLockScreen.swift`. The
/// two `more_cycle*` copies that lived here while `PlaceholderScreen` drew the cycle row were
/// deleted with it in iOS-M8 T6: the More hub now owns the row and reads `FeatureSettings`' own
/// copies, so this pin carries exactly the three `app_lock_*` keys.
@Suite("App target strings")
struct AppStringCatalogTests {
    /// Every key the shell owns, with both translations.
    ///
    /// The `app_lock_*` rows are copied from Android's app module,
    /// `app/src/main/res/values{,-en}/strings.xml:11-13`.
    static let samples: [Sample] = [
        Sample(
            key: "app_lock_locked_title",
            turkish: "Salus kilitli",
            english: "Salus is locked"
        ),
        Sample(
            key: "app_lock_unlock",
            turkish: "Kilidi aç",
            english: "Unlock"
        ),
        Sample(
            key: "app_lock_prompt_title",
            turkish: "Salus kilidini aç",
            english: "Unlock Salus"
        )
    ]

    static var expectedKeys: Set<String> { Set(samples.map(\.key)) }

    @Test("the catalog holds exactly the three keys the shell owns")
    func catalogHoldsExactlyTheThreeKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 3)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("the three app_lock keys are the shell's own")
    func theThreeAppLockKeysAreTheShellsOwn() {
        let appLockKeys = Self.expectedKeys.filter { $0.hasPrefix("app_lock_") }

        #expect(appLockKeys == ["app_lock_locked_title", "app_lock_unlock", "app_lock_prompt_title"])
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values are Android-verbatim (app + feature/settings res/values*/strings.xml)",
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
