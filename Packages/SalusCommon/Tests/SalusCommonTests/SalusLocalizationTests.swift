// `SalusLocalization` against a bundle built on disk — two `.lproj`s with one key each — so the
// mechanism the 13 `…Strings` helpers rely on is proven where `swift test` can run it: the picked
// code selects the sub-bundle, `nil` falls back, and a code the bundle lacks leaves the bundle alone.
//
// `.serialized`: the override is process-wide by design, so these tests must not interleave with
// each other, and each one puts the override back to `nil` before it returns.

import Foundation
import Testing

@testable import SalusCommon

@Suite("SalusLocalization", .serialized)
struct SalusLocalizationTests {
    /// A throwaway bundle: `<tmp>/<uuid>.bundle/{tr,en}.lproj/Localizable.strings`.
    private func makeBundle() throws -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bundle")
        for (code, value) in [("tr", "Merhaba"), ("en", "Hello")] {
            let lproj = root.appendingPathComponent("\(code).lproj")
            try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
            try "\"greeting\" = \"\(value)\";\n".write(
                to: lproj.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )
        }
        return try #require(Bundle(path: root.path))
    }

    @Test("the picked code selects that .lproj")
    func pickedCodeSelectsItsLproj() throws {
        let bundle = try makeBundle()
        defer { SalusLocalization.setLanguageCode(nil) }

        SalusLocalization.setLanguageCode("tr")
        #expect(SalusLocalization.string("greeting", bundle: bundle) == "Merhaba")

        SalusLocalization.setLanguageCode("en")
        #expect(SalusLocalization.string("greeting", bundle: bundle) == "Hello")
    }

    @Test("a code the bundle does not carry leaves the bundle itself in place")
    func unknownCodeFallsBackToTheBundle() throws {
        let bundle = try makeBundle()
        defer { SalusLocalization.setLanguageCode(nil) }

        SalusLocalization.setLanguageCode("de")

        #expect(SalusLocalization.localizedBundle(bundle).bundlePath == bundle.bundlePath)
    }

    @Test("nil follows the device: a supported preferred language is picked, otherwise the bundle")
    func nilFollowsTheDevice() throws {
        let bundle = try makeBundle()
        SalusLocalization.setLanguageCode(nil)

        let resolved = SalusLocalization.localizedBundle(bundle)
        let supported = Bundle.preferredLocalizations(
            from: bundle.localizations,
            forPreferences: Locale.preferredLanguages
        ).first

        if let supported {
            #expect(resolved.bundlePath.hasSuffix("\(supported).lproj"))
        } else {
            #expect(resolved.bundlePath == bundle.bundlePath)
        }
    }

    @Test("the resolved bundle is cached per bundle and dropped on a change")
    func cacheFollowsTheCode() throws {
        let bundle = try makeBundle()
        defer { SalusLocalization.setLanguageCode(nil) }

        SalusLocalization.setLanguageCode("tr")
        let first = SalusLocalization.localizedBundle(bundle)
        #expect(SalusLocalization.localizedBundle(bundle) === first)

        SalusLocalization.setLanguageCode("en")
        #expect(SalusLocalization.localizedBundle(bundle) !== first)
        #expect(SalusLocalization.languageCode == "en")
    }

    @Test("a key no .lproj carries comes back as the key, as before")
    func missingKeyReturnsTheKey() throws {
        let bundle = try makeBundle()
        defer { SalusLocalization.setLanguageCode(nil) }

        SalusLocalization.setLanguageCode("tr")

        #expect(SalusLocalization.string("nowhere", bundle: bundle) == "nowhere")
    }
}
