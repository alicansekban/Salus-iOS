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
/// **The set is five keys and is on its way to three.** The three `app_lock_*` keys are the shell's
/// permanently — they are Android's app-module strings, drawn by `App/Lock/AppLockScreen.swift`.
/// The two `more_cycle*` keys are `feature/settings` strings that now also live in
/// `FeatureSettings`' catalog; the copies here are what `PlaceholderScreen` still draws while it is
/// the More tab, and they are deleted together with it when the shell mounts the real hub (iOS-M6
/// ruling 1, closed by M8's shell task). That task drops the two `Sample` rows below, the two
/// `AppStrings` accessors and the two catalog entries in one commit, and this pin — being a literal
/// key set — is what fails if it forgets one of the three.
@Suite("App target strings")
struct AppStringCatalogTests {
    /// Every key the shell owns, with both translations.
    ///
    /// The `app_lock_*` rows are copied from Android's app module,
    /// `app/src/main/res/values{,-en}/strings.xml:11-13`; the `more_cycle*` rows from
    /// `feature/settings/src/main/res/values{,-en}/strings.xml:79-80`.
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
        ),
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

    @Test("the catalog holds exactly the five keys the shell owns")
    func catalogHoldsExactlyTheFiveKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 5)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("the three app_lock keys are the shell's own")
    func theThreeAppLockKeysAreTheShellsOwn() {
        // The half of the set that survives `PlaceholderScreen`'s deletion, pinned separately so
        // that trimming the two `more_cycle*` rows above cannot quietly take one of these with it.
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
