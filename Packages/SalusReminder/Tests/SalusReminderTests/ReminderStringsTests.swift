// The twin of `core/reminder/src/main/res/values/strings.xml` (`tr`, the source language) and
// `values-en/strings.xml`, and the drift detector between them.
//
// `:core:reminder` owns exactly one user-facing string — the label Android's alarm surface puts on
// the button that silences a dose without resolving it (`AlarmService.kt:87`, `AlarmScreen.kt:153`)
// — so this table has one row. It is still a table: a second key added on either platform without
// the other is exactly the difference the key-set pin fails on.
//
// The catalog is read off disk rather than through `Bundle.module`, for the two reasons
// `AppointmentsStringsTests` gives: `String(localized:)` answers for one locale only, so it can
// never prove both carry a key, and command-line `swift test` does not compile a `.xcstrings` at
// all. The end-to-end check is `scripts/build-app.sh` plus a simulator run.

import Foundation
import SalusTesting
import Testing

@testable import SalusReminder

@Suite("SalusReminder strings")
struct ReminderStringsTests {
    /// Every key `:core:reminder` owns, with both translations, copied from the XML.
    static let samples: [ReminderStringSample] = [
        ReminderStringSample(
            key: "alarm_dismiss",
            turkish: "Kapat",
            english: "Dismiss"
        )
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the one key :core:reminder owns")
    func catalogHoldsExactlyTheOneKey() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 1)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test("the values match res/values*/strings.xml", arguments: samples)
    func valuesAreAndroidVerbatim(sample: ReminderStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `ReminderStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the button label. This is the check that catches it.
        #expect(Set(ReminderStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the catalog names nothing on the banned health-claims list")
    func theCatalogNamesNothingBanned() throws {
        // Repository-wide coverage already exists in `SalusTestingTests.BannedHealthClaimsTests`.
        // This narrower run points at this package's own catalog so whoever adds a banned string
        // fails in the suite they are already looking at.
        try BannedHealthClaims.assertCatalogsNameNothingBanned(paths: [Self.catalogURL])
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SalusReminderTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // SalusReminder
        .appendingPathComponent("Sources/SalusReminder/Resources/Localizable.xcstrings")

    static func loadCatalog() throws -> StringCatalog {
        try StringCatalogParity.load(at: catalogURL)
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires a
/// `Sendable` element type.
struct ReminderStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
