// The subset of Xcode's `.xcstrings` schema the parity checks assert on.
//
// It lives in `SalusTesting` rather than beside the first catalog for the reason the ban list
// does: a second copy of a schema drifts, and the drift is invisible until a check quietly stops
// checking. Every package that owns a String Catalog decodes it through this type.
//
// The schema is deeper than these four types — `substitutions`, `variations`, `state`, device
// qualifiers — and none of it is modelled, because `Decodable` ignores what it is not asked for.
// A key that ever needs a plural variation will need this type widened in the same commit, which
// is the intended forcing function.

import Foundation

/// One `.xcstrings` file, decoded.
public struct StringCatalog: Decodable, Sendable {
    /// The catalog's source language. Turkish everywhere in this app (spec §6.4).
    public let sourceLanguage: String
    /// Every key in the catalog, by name.
    public let strings: [String: Entry]

    /// The catalog's keys as a set, which is the shape every pin compares against.
    ///
    /// A bare `""` entry is dropped: it is not a key anything can look up, only what Xcode's string
    /// extraction writes when it meets an empty `LocalizedStringKey` literal (`Toggle("")`,
    /// `Picker("")`). The sources no longer contain one, but a stray entry must fail the *parity*
    /// checks with a clear message, not the decode with `keyNotFound: localizations`.
    public var keys: Set<String> { Set(strings.keys).subtracting([""]) }

    /// The translation of `key` into `locale`, or `nil` if the catalog carries neither.
    public func value(of key: String, in locale: String) -> String? {
        strings[key]?.localizations[locale]?.stringUnit.value
    }

    // The three nested types are siblings rather than a chain because `.swiftlint.yml` caps type
    // nesting at two levels and the schema is four deep.

    /// One key's translations, keyed by locale identifier. Empty for an entry that has none —
    /// Xcode's stray `""` — rather than a decode failure for the whole catalog.
    public struct Entry: Decodable, Sendable {
        public let localizations: [String: Localization]

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            localizations = try container.decodeIfPresent([String: Localization].self, forKey: .localizations) ?? [:]
        }

        private enum CodingKeys: String, CodingKey {
            case localizations
        }
    }

    /// One key in one locale.
    public struct Localization: Decodable, Sendable {
        public let stringUnit: StringUnit
    }

    /// The translated text itself.
    public struct StringUnit: Decodable, Sendable {
        public let value: String
    }
}
