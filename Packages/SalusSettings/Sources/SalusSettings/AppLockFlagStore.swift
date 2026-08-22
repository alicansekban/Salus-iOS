import Foundation

/// Where the app-lock flag is kept.
///
/// Android stores all ten settings in one DataStore file
/// (`SalusPreferencesDataSource.kt:79`). iOS splits one of them out: `app_lock_enabled` is the
/// switch that decides whether the app demands Face ID before showing any health data, so it must
/// not live in a plist that a file-level backup, a jailbroken filesystem read, or a `defaults
/// write` from another process can flip (spec §5). It goes to the Keychain instead, behind this
/// protocol so the store can be faked in tests and previews.
///
/// The two operations are deliberately synchronous and non-throwing: they mirror
/// `preferences[KEY_APP_LOCK_ENABLED]`, which cannot fail either. A Keychain that will not answer
/// reads as "locked off" rather than as an error the settings screen would have to render.
public protocol AppLockFlagStore: Sendable {
    /// The stored flag, or `false` when nothing has been stored yet
    /// (`SalusPreferencesDataSource.kt:23` — `?: false`).
    func read() -> Bool

    /// Stores the flag, replacing whatever was there.
    func write(_ enabled: Bool)
}

/// An `AppLockFlagStore` that keeps the flag in memory only.
///
/// For tests and SwiftUI previews. It is also what makes `KeychainAppLockFlagStore` testable by
/// omission: the real Keychain store needs a signed host with a keychain-access-group
/// entitlement, which `swift test` on the host toolchain does not have, so it is exercised on
/// device rather than pinned by a unit test (see the note on `KeychainAppLockFlagStore`).
public final class InMemoryAppLockFlagStore: AppLockFlagStore, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled: Bool

    /// - Parameter enabled: the flag's starting value; `false` is the Android default.
    public init(enabled: Bool = false) {
        self.enabled = enabled
    }

    public func read() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return enabled
    }

    public func write(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.enabled = enabled
    }
}
