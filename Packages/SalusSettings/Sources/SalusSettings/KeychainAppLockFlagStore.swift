import Foundation
import Security

/// The production `AppLockFlagStore`: one generic-password item in the Keychain.
///
/// Shape of the item, fixed because it is a persistence contract:
///  * class   `kSecClassGenericPassword`
///  * service `com.alicansekban.salus` — the bundle identifier, shared with Android's
///    `applicationId` (CLAUDE.md)
///  * account `SettingsKeys.appLockEnabled`, so the key string stays the one Android uses
///  * value   a single byte, `1` for enabled and `0` for disabled. A byte rather than a
///    property list because the payload is one bit and the item should stay unambiguous when
///    read by a future migration.
///  * access  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — background code (the
///    reminder scheduler) must be able to read it before the user has unlocked *today*, but
///    `ThisDeviceOnly` keeps it out of iCloud Keychain and out of an encrypted device backup
///    restored onto someone else's phone.
///
/// **Not unit-tested, on purpose.** `SecItemAdd` on the host toolchain requires a signed test
/// host with a keychain-access-group entitlement; `swift test` has neither and every call would
/// fail with `errSecMissingEntitlement`, which would make the test assert the sandbox rather than
/// the store. What *is* tested is everything around it: `AppLockFlagStore` has a fake
/// (`InMemoryAppLockFlagStore`) that the data-source tests use, and the routing — that the flag
/// never lands in `UserDefaults` — is pinned there. This type is verified on device.
public struct KeychainAppLockFlagStore: AppLockFlagStore {
    /// The Keychain service, equal to the bundle identifier.
    public static let service = "com.alicansekban.salus"

    public init() {}

    public func read() -> Bool {
        var query = Self.itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        // An absent item is not an error: it is a user who has never touched the switch, which
        // reads as off — the Kotlin `?: false` of `SalusPreferencesDataSource.kt:23`. Any other
        // failure reads as off too, because a lock that cannot be confirmed must not be claimed.
        guard status == errSecSuccess, let data = item as? Data, let flag = data.first else {
            return false
        }
        return flag == 1
    }

    public func write(_ enabled: Bool) {
        let value = Data([enabled ? 1 : 0])
        let query = Self.itemQuery

        // Add-or-update, in that order of attempts: `SecItemUpdate` first because the item
        // usually exists, and `SecItemAdd` only for the very first write. Deleting and re-adding
        // would be simpler but leaves a window in which the flag is absent — which reads as
        // "app lock off" to anything that looks while the write is in flight.
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        guard updated == errSecItemNotFound else { return }

        var insert = query
        insert[kSecValueData as String] = value
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(insert as CFDictionary, nil)
    }

    /// The attributes that identify the one item this store owns; every call starts from these.
    ///
    /// `kSecUseDataProtectionKeychain` is not decoration: it is a no-op on iOS, but on macOS —
    /// where the host build and any future Catalyst target run — leaving it out routes the call
    /// to the legacy file-based keychain, which ignores `kSecAttrAccessible` entirely. The
    /// `AfterFirstUnlockThisDeviceOnly` protection above would then be silently dropped.
    private static var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: SettingsKeys.appLockEnabled,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
