// A ``SettingsPreferences`` whose four values a test sets and re-emits on every write, for
// `MoreViewModelTests` (T4) and any T3 test that wants to drive the domain without a
// `UserDefaults`-backed data source.
//
// `@unchecked Sendable` over a lock rather than an actor because the protocol's streams and setters
// are not `@MainActor`-isolated — a fake that made them `async` on an actor would still conform, but
// it would change the scheduling the test is trying to observe. The same shape
// `FakeReminderEnvironment.swift` uses.
//
// Swift 6 disallows `NSLock.lock()` from an `async` context, so each `async` setter delegates to a
// synchronous helper — the same constraint `InMemoryAppLockFlagStore.write` satisfies by being
// sync, and the only honest way to keep the lock off the cooperative pool.
//
// **Push-capable** (T4): the Kotlin `MoreViewModelTest` flips `preferences.themeMode.value` after
// the ViewModel is subscribed and asserts the new value reaches `state`, and `MoreViewModel`'s
// "changing sex updates visibility" case needs a setter write to propagate through the held stream
// without a re-subscribe. A one-shot fake (emit-once-then-open) could not carry those, so each
// stream holds its continuation and the setter pushes the new value to it — the same shape
// `FakeMorePremiumStatus.swift` uses for `status`. A value-equal write is still pushed, matching
// `MutableStateFlow` (which re-emits on `value =` regardless of equality); the production
// `SettingsPreferencesImpl` drops equal writes, but the fake is the simpler reference shape and no
// T4 case depends on the dedupe.

import Foundation
import SalusModel

@testable import FeatureSettings

/// A ``SettingsPreferences`` whose four fields a test holds, flips, and sees propagate through the
/// held streams.
final class FakeSettingsPreferences: SettingsPreferences, @unchecked Sendable {
    private let lock = NSLock()

    private var themeModeValue: ThemeMode
    private var appLockEnabledValue: Bool
    private var secureScreenEnabledValue: Bool
    private var premiumThemeValue: PremiumTheme

    private var themeModeContinuations: [UUID: AsyncStream<ThemeMode>.Continuation] = [:]
    private var appLockContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private var secureScreenContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private var premiumThemeContinuations: [UUID: AsyncStream<PremiumTheme>.Continuation] = [:]

    init(
        themeMode: ThemeMode = .system,
        appLockEnabled: Bool = false,
        secureScreenEnabled: Bool = false,
        premiumTheme: PremiumTheme = .classic
    ) {
        themeModeValue = themeMode
        appLockEnabledValue = appLockEnabled
        secureScreenEnabledValue = secureScreenEnabled
        premiumThemeValue = premiumTheme
    }

    /// The current held value, read synchronously — the twin of Kotlin's
    /// `preferences.themeMode.value`. Safe to call from any actor; the lock is the same one the
    /// setters take.
    var themeModeValueSync: ThemeMode {
        lock.lock()
        defer { lock.unlock() }
        return themeModeValue
    }

    /// The current held value — see `themeModeValueSync`.
    var appLockEnabledValueSync: Bool {
        lock.lock()
        defer { lock.unlock() }
        return appLockEnabledValue
    }

    /// The current held value — see `themeModeValueSync`.
    var secureScreenEnabledValueSync: Bool {
        lock.lock()
        defer { lock.unlock() }
        return secureScreenEnabledValue
    }

    /// The current held value — see `themeModeValueSync`.
    var premiumThemeValueSync: PremiumTheme {
        lock.lock()
        defer { lock.unlock() }
        return premiumThemeValue
    }

    var themeMode: AsyncStream<ThemeMode> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            themeModeContinuations[id] = continuation
            let current = themeModeValue
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.remove(themeModeContinuationID: id)
            }
        }
    }

    var appLockEnabled: AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            appLockContinuations[id] = continuation
            let current = appLockEnabledValue
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.remove(appLockContinuationID: id)
            }
        }
    }

    var secureScreenEnabled: AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            secureScreenContinuations[id] = continuation
            let current = secureScreenEnabledValue
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.remove(secureScreenContinuationID: id)
            }
        }
    }

    var premiumTheme: AsyncStream<PremiumTheme> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            premiumThemeContinuations[id] = continuation
            let current = premiumThemeValue
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.remove(premiumThemeContinuationID: id)
            }
        }
    }

    func setThemeMode(_ mode: ThemeMode) async {
        setThemeModeSync(mode)
    }

    func setAppLockEnabled(_ enabled: Bool) async {
        setAppLockEnabledSync(enabled)
    }

    func setSecureScreenEnabled(_ enabled: Bool) async {
        setSecureScreenEnabledSync(enabled)
    }

    func setPremiumTheme(_ theme: PremiumTheme) async {
        setPremiumThemeSync(theme)
    }

    /// The synchronous helpers keep `NSLock` out of an asynchronous context, which Swift 6
    /// disallows — the same constraint `InMemoryAppLockFlagStore.write` satisfies by being sync.
    private func setThemeModeSync(_ mode: ThemeMode) {
        lock.lock()
        themeModeValue = mode
        let pending = Array(themeModeContinuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(mode)
        }
    }

    private func setAppLockEnabledSync(_ enabled: Bool) {
        lock.lock()
        appLockEnabledValue = enabled
        let pending = Array(appLockContinuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(enabled)
        }
    }

    private func setSecureScreenEnabledSync(_ enabled: Bool) {
        lock.lock()
        secureScreenEnabledValue = enabled
        let pending = Array(secureScreenContinuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(enabled)
        }
    }

    private func setPremiumThemeSync(_ theme: PremiumTheme) {
        lock.lock()
        premiumThemeValue = theme
        let pending = Array(premiumThemeContinuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(theme)
        }
    }

    /// Four removal helpers rather than one generic one, so each stream's `onTermination` closure
    /// captures exactly the book it owns — no tag, no overload resolution, no ambiguity.
    private func remove(themeModeContinuationID id: UUID) {
        lock.lock()
        themeModeContinuations[id] = nil
        lock.unlock()
    }

    private func remove(appLockContinuationID id: UUID) {
        lock.lock()
        appLockContinuations[id] = nil
        lock.unlock()
    }

    private func remove(secureScreenContinuationID id: UUID) {
        lock.lock()
        secureScreenContinuations[id] = nil
        lock.unlock()
    }

    private func remove(premiumThemeContinuationID id: UUID) {
        lock.lock()
        premiumThemeContinuations[id] = nil
        lock.unlock()
    }
}
