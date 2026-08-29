import Foundation
import Testing

@testable import SalusTesting

// Ported from `core/testing/src/test/.../BannedHealthClaimsTest.kt:15-45`, plus the repository-wide
// scan Android runs from each module that owns user-facing copy.
//
// The first two cases guard the list itself: they check the stems, not any one module's copy, so
// they belong next to the list. The remaining three guard the scan — including the case that
// matters most, a scan that finds nothing and would otherwise report success by doing no work.
//
// This file names none of the banned vocabulary itself: it reads the terms out of
// `BannedHealthClaims`, which is the single file the scan skips. That is deliberate, not
// squeamishness — the scan below runs over `Packages/` and `App/`, so a term written out here
// would turn its own test red.

@Suite("BannedHealthClaims (Android parity)")
struct BannedHealthClaimsTests {
    /// The repository root, resolved from this file rather than from the working directory.
    ///
    /// `swift test` runs with the package directory as its working directory, so a relative path
    /// would resolve differently depending on which package invoked the run. Android gets away
    /// with module-relative paths because Gradle guarantees that directory
    /// (`BannedHealthClaims.kt:25-27`); SwiftPM makes no such promise across packages.
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SalusTestingTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // SalusTesting
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // <repository root>

    /// This test suite's own guard file — the one file the scan is allowed to skip
    /// (`BannedHealthClaims.kt:131-134`).
    static let exemptFileName = "BannedHealthClaims.swift"

    @Test(
        "the banned list catches text that was uppercased in Turkish",
        arguments: BannedHealthClaims.turkishUppercased
    )
    func theListCatchesTurkishUppercasedText(written: String) {
        // Turkish has two i's, and both of them break a list that holds only natural spellings:
        // an uppercased term folded back with the root locale is not the term it came from. Both
        // spellings are on the list, and this is the test that says so on a real toolchain rather
        // than on reasoning (`BannedHealthClaimsTest.kt:18-31`).
        let folded = written.lowercased()

        #expect(
            BannedHealthClaims.stems.contains { folded.contains($0) },
            "\"\(written)\" folds to \"\(folded)\", which no banned term matches."
        )
    }

    @Test(
        "the banned list catches inflected forms, not just dictionary ones",
        arguments: BannedHealthClaims.inflectedForms
    )
    func theListCatchesInflectedForms(written: String) {
        // One case per stem, each an inflection a list of whole words would have let through.
        // Shortening an entry back to its dictionary form turns one of these red, which is the
        // point: the next person cannot undo the stems quietly (`BannedHealthClaimsTest.kt:34-44`).
        #expect(
            BannedHealthClaims.stems.contains { written.contains($0) },
            "\"\(written)\" is an inflection no banned stem matches."
        )
    }

    @Test("no Swift source in the repository names anything banned")
    func noSwiftSourceNamesAnythingBanned() throws {
        try BannedHealthClaims.assertSourcesNameNothingBanned(
            roots: [
                Self.repositoryRoot.appendingPathComponent("Packages"),
                Self.repositoryRoot.appendingPathComponent("App")
            ],
            exemptFileName: Self.exemptFileName
        )
    }

    @Test("no string catalog in the repository names anything banned")
    func noStringCatalogNamesAnythingBanned() throws {
        // The Swift scan above reads `.swift` only, so a catalog was invisible to it — and the
        // catalog is where the words a user actually reads live. This is the twin of Android's
        // per-module `assertFilesNameNothingBanned(STRING_FILES)`, hoisted to one repository-wide
        // run: every `.xcstrings` under `Packages/` or `App/` is covered the moment it is added,
        // with no edit to the feature that added it. `App/` is listed for the same reason the Swift
        // scan above lists it — since iOS-M6 the app target carries a catalog of its own.
        try BannedHealthClaims.assertCatalogsNameNothingBanned(
            paths: [
                Self.repositoryRoot.appendingPathComponent("Packages"),
                Self.repositoryRoot.appendingPathComponent("App")
            ]
        )
    }

    @Test("a catalog that names a banned stem fails the scan")
    func aCatalogThatNamesABannedStemFailsTheScan() throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let stem = try #require(BannedHealthClaims.stems.first)
        try #"{"sourceLanguage":"tr","strings":{"k":{"localizations":{"tr":{"stringUnit":{"value":"\#(stem)"}}}}}}"#
            .write(to: root.appendingPathComponent("Localizable.xcstrings"), atomically: true, encoding: .utf8)

        #expect(throws: BannedHealthClaims.ScanError.self) {
            try BannedHealthClaims.assertCatalogsNameNothingBanned(paths: [root])
        }
    }

    @Test("a catalog scan that reaches no catalog fails instead of passing on an empty set")
    func aCatalogScanThatReachesNoCatalogFails() throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // Same failure mode as the source scan, and likelier here: `.xcstrings` files arrive one
        // feature at a time, so a wrong root reads as "nothing banned" rather than as "nothing
        // read".
        #expect(throws: BannedHealthClaims.ScanError.self) {
            try BannedHealthClaims.assertCatalogsNameNothingBanned(paths: [root])
        }
    }

    @Test("a source that names a banned stem fails the scan")
    func aSourceThatNamesABannedStemFailsTheScan() throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let stem = try #require(BannedHealthClaims.stems.first)
        try "let note = \"\(stem)\"\n"
            .write(to: root.appendingPathComponent("Offender.swift"), atomically: true, encoding: .utf8)

        #expect(throws: BannedHealthClaims.ScanError.self) {
            try BannedHealthClaims.assertSourcesNameNothingBanned(roots: [root], exemptFileName: Self.exemptFileName)
        }
    }

    @Test("a scan that reaches no source fails instead of passing on an empty set")
    func aScanThatReachesNoSourceFails() throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // A path typo would otherwise make the guard pass by scanning nothing at all
        // (`BannedHealthClaims.kt:144-145`).
        #expect(throws: BannedHealthClaims.ScanError.self) {
            try BannedHealthClaims.assertSourcesNameNothingBanned(roots: [root], exemptFileName: Self.exemptFileName)
        }
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
