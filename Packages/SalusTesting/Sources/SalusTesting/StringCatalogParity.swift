// The TR/EN parity checks every String Catalog in the tree runs, in one place.
//
// The rule they enforce is CLAUDE.md's: Turkish is the default AND the fallback locale (spec
// §6.4) and English is a full peer, so every key exists in both and in neither more nor fewer.
//
// Two things are deliberately NOT here.
//
//   * There is no test framework. `SalusTesting` links none — the checks throw, and each suite
//     reports the failure with whatever framework it already uses. This mirrors
//     `BannedHealthClaims`, and it is why `swift test` in `SalusModel` does not drag Swift
//     Testing into a production target.
//   * There is no lookup through `Bundle.module`. A `.xcstrings` is compiled into
//     `.lproj/Localizable.strings` by *Xcode's* build system only; command-line `swift build` /
//     `swift test` copies the catalog verbatim, so `String(localized:)` under `swift test` finds
//     no table and answers with the key. Every check below therefore reads the FILE. The
//     end-to-end check that the app resolves these strings is the simulator run.
//
// The Android twin is the pair of `values/` and `values-en/` directories plus the per-module
// `*StringsTest.kt`; Gradle enforces the key-set parity itself with `MissingTranslation`, which
// SwiftPM has no equivalent of — hence `assertEveryKeyIsLocalized`.

import Foundation

/// Parity checks for a `.xcstrings` String Catalog.
public enum StringCatalogParity {
    /// Turkish, the default and the fallback (spec §6.4).
    public static let sourceLanguage = "tr"

    /// The two languages the app ships. Not "at least these": a third locale in a catalog is a
    /// translation nobody reviewed and nobody can maintain, so it fails rather than passes.
    public static let locales: Set = ["tr", "en"]

    /// Why a catalog failed parity. Descriptive on purpose: the message is the whole value of the
    /// check to whoever trips it.
    public enum ParityError: Error, Equatable, CustomStringConvertible {
        /// The catalog declares a source language other than the expected one.
        case unexpectedSourceLanguage(actual: String, expected: String)
        /// The catalog's key set is not the pinned one. Both lists are sorted.
        case keySetMismatch(missing: [String], unexpected: [String])
        /// A key is translated into a set of locales other than the expected one. Both sorted.
        case unexpectedLocales(key: String, actual: [String], expected: [String])
        /// A key is present in a locale but its text is empty, which a key-set pin cannot see.
        case emptyValue(key: String, locale: String)

        public var description: String {
            switch self {
            case let .unexpectedSourceLanguage(actual, expected):
                "The catalog's source language is \"\(actual)\", not \"\(expected)\". Turkish is "
                    + "the default AND the fallback locale (spec 6.4): a device set to neither "
                    + "Turkish nor English gets Turkish, exactly as Android's values/ default does."

            case let .keySetMismatch(missing, unexpected):
                "The catalog does not hold the pinned key set. Missing: \(missing). "
                    + "Not pinned: \(unexpected). A key is added to the catalog and to the pin in "
                    + "the same commit, so that the Android XML stays the one source of names."

            case let .unexpectedLocales(key, actual, expected):
                "\"\(key)\" is localized into \(actual), not \(expected). Turkish is the default "
                    + "and English a full peer, so every key exists in both and in no others."

            case let .emptyValue(key, locale):
                "\"\(key)\" is empty in \"\(locale)\". A blank translation passes a key-set pin "
                    + "and ships as blank UI."
            }
        }
    }

    /// Reads and decodes the catalog at `url`.
    ///
    /// The caller resolves the URL from its own `#filePath`: `swift test` runs with the package
    /// directory as its working directory, so a relative path would resolve differently depending
    /// on which package invoked the run.
    public static func load(at url: URL) throws -> StringCatalog {
        try JSONDecoder().decode(StringCatalog.self, from: Data(contentsOf: url))
    }

    /// Checks that the catalog's source language is `expected`.
    public static func assertSourceLanguage(
        of catalog: StringCatalog,
        is expected: String = sourceLanguage
    ) throws {
        guard catalog.sourceLanguage == expected else {
            throw ParityError.unexpectedSourceLanguage(actual: catalog.sourceLanguage, expected: expected)
        }
    }

    /// Checks that the catalog holds exactly `expected` — no key more, no key fewer.
    ///
    /// The pin is a literal set copied from the Android XML rather than something derived from the
    /// catalog, because a check that reads its expectation out of the thing it is checking agrees
    /// with itself by construction.
    public static func assertKeys(of catalog: StringCatalog, are expected: Set<String>) throws {
        let actual = catalog.keys
        guard actual == expected else {
            throw ParityError.keySetMismatch(
                missing: expected.subtracting(actual).sorted(),
                unexpected: actual.subtracting(expected).sorted()
            )
        }
    }

    /// Checks that every key is translated into exactly `expected`, with no empty text.
    ///
    /// The emptiness check rides along rather than living in a fourth function: both halves answer
    /// the one question a key-set pin cannot, which is whether a listed translation is real.
    public static func assertEveryKeyIsLocalized(
        in catalog: StringCatalog,
        into expected: Set<String> = locales
    ) throws {
        for (key, entry) in catalog.strings.sorted(by: { $0.key < $1.key }) {
            let actual = Set(entry.localizations.keys)
            guard actual == expected else {
                throw ParityError.unexpectedLocales(
                    key: key,
                    actual: actual.sorted(),
                    expected: expected.sorted()
                )
            }

            for locale in actual.sorted() where entry.localizations[locale]?.stringUnit.value.isEmpty ?? true {
                throw ParityError.emptyValue(key: key, locale: locale)
            }
        }
    }
}
