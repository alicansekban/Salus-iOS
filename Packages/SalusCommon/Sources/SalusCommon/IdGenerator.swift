// The injectable id source, ported 1:1 from Android
// `core/common/src/main/kotlin/com/alicansekban/salus/core/common/IdGenerator.kt`.
//
// Kotlin's `fun interface` is a single-method protocol here; Swift has no need for the SAM
// conversion, and a test double is a two-line struct either way.

import Foundation

/// Where every row id in the app comes from (`IdGenerator.kt:5-7`).
///
/// Injected rather than called for the same reason `SalusClock` is: an id that cannot be fixed is
/// an assertion that cannot be written.
public protocol IdGenerator: Sendable {
    /// A fresh, unique id.
    func newId() -> String
}

/// The production generator: a random UUID, spelled the way Android spells it
/// (`IdGenerator.kt:9-11`).
public struct UUIDIdGenerator: IdGenerator {
    public init() {}

    /// A random UUID in Java's `UUID.toString()` spelling.
    ///
    /// The `lowercased()` is the whole difference between the platforms and is not cosmetic:
    /// `Foundation.UUID.uuidString` is UPPERCASE, while `java.util.UUID.toString()` is lowercase.
    /// Ids travel between the platforms inside a backup archive
    /// (`docs/contracts/backup-format-v1.md`), where a row's id is matched verbatim, so an
    /// uppercase id written on iOS would read as a different row on Android. `lowercased()` is
    /// locale-independent in Swift, so the Turkish dotless-i does not reach hex digits.
    public func newId() -> String {
        UUID().uuidString.lowercased()
    }
}
