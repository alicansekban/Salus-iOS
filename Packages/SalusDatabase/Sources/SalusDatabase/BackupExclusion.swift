// The iOS half of parity-ledger row S-10, "no health data in cloud backup".
//
// Android ships `android:allowBackup="false"`, so the Room file never reaches Google's backup
// transport. iOS has no manifest flag: everything under `Application Support` is backed up to
// iCloud and to the encrypted local backup unless the file itself carries
// `isExcludedFromBackup`. Without this, a health log the app promises "never leaves your device"
// would leave it on the next backup — a claim in the App Store listing and in
// `about_privacy_body`, not only a preference.
//
// The flag is a per-file resource value, not a policy, so it has to be applied to the file that
// exists. That is why this is called after `SalusDatabase.init` has created the store rather than
// on the URL beforehand.

import Foundation

extension SalusDatabase {
    /// Marks the database file — and any journal sidecar next to it — as excluded from iCloud and
    /// iTunes/Finder backup.
    ///
    /// `DatabaseQueue` leaves SQLite's journal mode at `delete`, so `salus.db-journal` exists only
    /// for the length of a write and `-wal` / `-shm` never appear at all (they are a
    /// `DatabasePool` concern). The sidecars are covered anyway, best effort: a rollback journal
    /// that happens to exist when a backup runs holds the same health rows the store does, and
    /// `setResourceValues` on a path with no file throws rather than doing nothing.
    ///
    /// - Parameter url: the database file, as passed to `init(path:clock:)`.
    /// - Throws: whatever `URL.setResourceValues` throws for the main file. A sidecar that cannot
    ///   be marked is ignored — it is transient, and failing the app's launch over one would trade
    ///   a smaller problem for a larger one.
    public static func excludeFromBackup(at url: URL) throws {
        var target = url
        try target.setExcludedFromBackup()
        for suffix in ["-journal", "-wal", "-shm"] {
            var sidecar = URL(fileURLWithPath: url.path + suffix)
            try? sidecar.setExcludedFromBackup()
        }
    }
}

extension URL {
    /// `isExcludedFromBackup = true`, spelled once.
    ///
    /// `URLResourceValues` is a value type read back through the URL, so the URL has to be `var`
    /// and the call has to be `mutating` — a `let` URL silently keeps the old cached values.
    fileprivate mutating func setExcludedFromBackup() throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try setResourceValues(values)
    }
}
