import GRDB

/// Namespace placeholder for the `SalusDatabase` package.
///
/// M0 ships the package graph only; the real types arrive in later milestones.
/// Mirrors Android module `:core:database`.
public enum SalusDatabaseModule {
    /// Stable module identifier, used to prove the module compiles and links.
    public static let name = "SalusDatabase"

    /// The GRDB database access type this package is built on (Android's Room database twin).
    ///
    /// Declared here so the GRDB dependency is actually resolved, compiled and linked by every
    /// gate — `swift test` on the host and `xcodebuild` on the iOS SDK — rather than only
    /// listed in the manifest. The real database types replace it with the schema.
    public typealias Queue = DatabaseQueue
}
