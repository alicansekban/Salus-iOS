// A ``SettingsPreferences`` whose four values a test sets, for `MoreViewModelTests` (T4) and any
// T3 test that wants to drive the domain without a `UserDefaults`-backed data source.
//
// `@unchecked Sendable` over a lock rather than an actor because the protocol's streams and setters
// are not `@MainActor`-isolated — a fake that made them `async` on an actor would still conform, but
// it would change the scheduling the test is trying to observe. The same shape
// `FakeReminderEnvironment.swift` uses.
//
// Swift 6 disallows `NSLock.lock()` from an `async` context, so each `async` setter delegates to a
// synchronous helper — the same constraint `InMemoryAppLockFlagStore.write` satisfies by being
// sync, and the only honest way to keep the lock off the cooperative pool.

import Foundation
import SalusModel

@testable import FeatureSettings

/// A ``SettingsPreferences`` whose four fields a test holds and flips.
final class FakeSettingsPreferences: SettingsPreferences, @unchecked Sendable {
    private let lock = NSLock()

    private var themeModeValue: ThemeMode
    private var appLockEnabledValue: Bool
    private var secureScreenEnabledValue: Bool
    private var premiumThemeValue: PremiumTheme

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

    var themeMode: AsyncStream<ThemeMode> {
        stream { $0.themeModeValue }
    }

    var appLockEnabled: AsyncStream<Bool> {
        stream { $0.appLockEnabledValue }
    }

    var secureScreenEnabled: AsyncStream<Bool> {
        stream { $0.secureScreenEnabledValue }
    }

    var premiumTheme: AsyncStream<PremiumTheme> {
        stream { $0.premiumThemeValue }
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
        defer { lock.unlock() }
        themeModeValue = mode
    }

    private func setAppLockEnabledSync(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        appLockEnabledValue = enabled
    }

    private func setSecureScreenEnabledSync(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        secureScreenEnabledValue = enabled
    }

    private func setPremiumThemeSync(_ theme: PremiumTheme) {
        lock.lock()
        defer { lock.unlock() }
        premiumThemeValue = theme
    }

    /// Emits the current value once, then stays open — the consumer that goes away cancels and ends
    /// the iteration. The fake does not push later changes through the same stream a test is
    /// already holding, which is the same contract `FakeAppLocaleController` keeps: the ViewModel
    /// tests that need change propagation read the first value and re-fetch, rather than hold an
    /// open iterator.
    private func stream<T: Sendable>(_ select: @escaping @Sendable (FakeSettingsPreferences) -> T) -> AsyncStream<T> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            lock.lock()
            let value = select(self)
            lock.unlock()
            continuation.yield(value)
        }
    }
}
