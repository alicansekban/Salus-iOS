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
/// **The set is eight keys**, and they are the shell's permanently — both groups Android app-module
/// strings, because both surfaces are the app's on that side too:
///
///   - three `app_lock_*` (`app/src/main/res/values{,-en}/strings.xml:11-13`), drawn by
///     `App/Lock/AppLockScreen.swift`; and
///   - five `nav_*` (`…/strings.xml:5-10` minus `nav_cycle`), drawn by `App/RootView.swift`'s
///     `.tabItem` through `RootTab.label`.
///
/// The two `more_cycle*` copies that lived here while `PlaceholderScreen` drew the cycle row were
/// deleted with it in iOS-M8 T6: the More hub now owns the row and reads `FeatureSettings`' own
/// copies. The five `nav_*` arrived in iOS-M8 T12 under controller ruling H-10, which read ruling
/// 9's three-key pin as the `AppStrings`/`more_cycle*` cleanup it was rather than a ban on the
/// shell owning the strings the shell draws — §6.4's TR default outranks a key count.
///
/// Two Android app-module keys are deliberately absent. `nav_cycle` (`…/strings.xml:7`) is **dead
/// on Android**: it is declared but nothing references it, because `SalusApp.kt:80-84` lists five
/// `TopLevelDestination`s and the M9 restructure removed the cycle tab. `app_name`
/// (`…/strings.xml:3`) is the manifest label, whose iOS twin is `CFBundleDisplayName` in
/// `project.yml`, not a catalog key.
@Suite("App target strings")
struct AppStringCatalogTests {
    /// Every key the shell owns, with both translations.
    ///
    /// Every row is copied from Android's app module,
    /// `app/src/main/res/values{,-en}/strings.xml` — `app_lock_*` from `:11-13`, `nav_*` from
    /// `:5-10`. Listed in the two groups' own source order rather than alphabetically, so a drift
    /// against the XML is read by scanning down one column.
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
        Sample(key: "nav_home", turkish: "Ana Sayfa", english: "Home"),
        Sample(key: "nav_medications", turkish: "İlaçlar", english: "Medications"),
        Sample(key: "nav_vitals", turkish: "Ölçümler", english: "Vitals"),
        Sample(key: "nav_appointments", turkish: "Randevular", english: "Appointments"),
        Sample(key: "nav_more", turkish: "Daha Fazla", english: "More")
    ]

    static var expectedKeys: Set<String> { Set(samples.map(\.key)) }

    @Test("the catalog holds exactly the eight keys the shell owns")
    func catalogHoldsExactlyTheEightKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        //
        // The arithmetic behind 8: Android's app module declares 10 keys. Two are not ported —
        // `app_name` (its twin is `CFBundleDisplayName`, a plist value, not a catalog key) and
        // `nav_cycle` (declared on Android but referenced by nothing since the M9 restructure cut
        // the cycle tab from `SalusApp.kt:80-84`'s five destinations). 10 − 2 = 8.
        #expect(Self.samples.count == 8)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("the three app_lock keys are the shell's own")
    func theThreeAppLockKeysAreTheShellsOwn() {
        let appLockKeys = Self.expectedKeys.filter { $0.hasPrefix("app_lock_") }

        #expect(appLockKeys == ["app_lock_locked_title", "app_lock_unlock", "app_lock_prompt_title"])
    }

    @Test("the five nav keys are the tab bar's, and nav_cycle is not among them")
    func theFiveNavKeysAreTheTabBars() {
        let navKeys = Self.expectedKeys.filter { $0.hasPrefix("nav_") }

        // The set, not the count: a future edit that ported `nav_cycle` (which Android declares and
        // never draws) while dropping another would keep the count and break the tab bar.
        #expect(
            navKeys == ["nav_home", "nav_medications", "nav_vitals", "nav_appointments", "nav_more"]
        )
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
