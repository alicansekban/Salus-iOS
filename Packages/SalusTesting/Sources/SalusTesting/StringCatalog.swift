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
    public var keys: Set<String> { Set(strings.keys) }

    /// The translation of `key` into `locale`, or `nil` if the catalog carries neither.
    public func value(of key: String, in locale: String) -> String? {
        strings[key]?.localizations[locale]?.stringUnit.value
    }

    // The three nested types are siblings rather than a chain because `.swiftlint.yml` caps type
    // nesting at two levels and the schema is four deep.

    /// One key's translations, keyed by locale identifier.
    public struct Entry: Decodable, Sendable {
        public let localizations: [String: Localization]
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
