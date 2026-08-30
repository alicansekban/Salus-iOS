// The twin of Android's `feature/settings/src/test/kotlin/.../data/SettingsPreferencesImplTest.kt`,
// which has no test class of its own on Android either: the Kotlin impl is four one-line `map`s
// over DataStore and the round-trip is covered by `SalusPreferencesDataSourceTest`. The iOS impl
// carries its own machinery — the per-field `distinctUntilChanged` narrowing rebuilt as an
// `AsyncStream` (the `VitalsPreferencesImpl.swift:40-55` shape) — so each of those gets a test here.
//
// The scratch `UserDefaults` + `InMemoryAppLockFlagStore` fixture is the same one
// `SalusPreferencesDataSourceTests.swift:82-97` builds, restated here because this package's tests
// cannot import `@testable import SalusSettings`'s `TestUserDefaults` (it is `internal`). The
// shape is identical: a fresh UUID-named suite per test, `removePersistentDomain` in `deinit`.

import Foundation
import SalusModel
import SalusSettings
import Testing

@testable import FeatureSettings

/// One throwaway `UserDefaults` suite per test, wiped when the instance goes away — the twin of
/// `SalusSettingsTests.TestUserDefaults`, restated here because that type is `internal` to its
/// package.
final class ScratchUserDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init() throws {
        let suiteName = "salus-settings-test-\(UUID().uuidString)"
        self.suiteName = suiteName
        defaults = try #require(
            UserDefaults(suiteName: suiteName),
            "UserDefaults refused the suite name \(suiteName)"
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@Suite("SettingsPreferencesImpl")
struct SettingsPreferencesImplTests {
    /// The preferences under test plus the scratch stores they were built on.
    private struct Fixture {
        let env: ScratchUserDefaults
        let flagStore: InMemoryAppLockFlagStore
        let dataSource: SalusPreferencesDataSource
        let preferences: SettingsPreferencesImpl
    }

    private func makeFixture() throws -> Fixture {
        let env = try ScratchUserDefaults()
        let flagStore = InMemoryAppLockFlagStore()
        let dataSource = SalusPreferencesDataSource(defaults: env.defaults, appLockFlagStore: flagStore)
        return Fixture(
            env: env,
            flagStore: flagStore,
            dataSource: dataSource,
            preferences: SettingsPreferencesImpl(dataSource: dataSource)
        )
    }

    // MARK: - each stream carries the stored value and updates on the setter

    @Test("themeMode carries the stored value and updates on the setter")
    func themeModeCarriesStoredValueAndUpdates() async throws {
        let fixture = try makeFixture()

        let first = await fixture.preferences.themeMode.firstValue()
        #expect(first == .system)

        await fixture.preferences.setThemeMode(.dark)
        let second = await fixture.preferences.themeMode.firstValue()
        #expect(second == .dark)
    }

    @Test("appLockEnabled carries the stored value and updates on the setter")
    func appLockEnabledCarriesStoredValueAndUpdates() async throws {
        let fixture = try makeFixture()

        let first = await fixture.preferences.appLockEnabled.firstValue()
        #expect(first == false)

        await fixture.preferences.setAppLockEnabled(true)
        let second = await fixture.preferences.appLockEnabled.firstValue()
        #expect(second == true)
    }

    @Test("secureScreenEnabled carries the stored value and updates on the setter")
    func secureScreenEnabledCarriesStoredValueAndUpdates() async throws {
        let fixture = try makeFixture()

        let first = await fixture.preferences.secureScreenEnabled.firstValue()
        #expect(first == false)

        await fixture.preferences.setSecureScreenEnabled(true)
        let second = await fixture.preferences.secureScreenEnabled.firstValue()
        #expect(second == true)
    }

    @Test("premiumTheme carries the stored value and updates on the setter")
    func premiumThemeCarriesStoredValueAndUpdates() async throws {
        let fixture = try makeFixture()

        let first = await fixture.preferences.premiumTheme.firstValue()
        #expect(first == .classic)

        await fixture.preferences.setPremiumTheme(.forest)
        let second = await fixture.preferences.premiumTheme.firstValue()
        #expect(second == .forest)
    }

    // MARK: - equal consecutive writes are dropped (distinct guard)

    @Test("equal consecutive themeMode writes are dropped by the distinct guard")
    func equalConsecutiveThemeModeWritesAreDropped() async throws {
        let fixture = try makeFixture()

        // Two writes of the same value: the stream must emit the new value only once. A recorder
        // sits in `next()` for the duration so a spurious duplicate is not swallowed by the
        // one-slot buffer — the same reason `SalusPreferencesDataSourceTests` uses `StreamRecorder`.
        let recorder = FieldRecorder(fixture.preferences.themeMode)
        await recorder.wait(forAtLeast: 1)

        await fixture.preferences.setThemeMode(.light)
        await recorder.wait(forAtLeast: 2)

        // A second identical write must produce no third element.
        await fixture.preferences.setThemeMode(.light)
        await Task.yield()
        await Task.yield()

        #expect(recorder.recorded == [.system, .light])
    }

    @Test("equal consecutive appLockEnabled writes are dropped by the distinct guard")
    func equalConsecutiveAppLockEnabledWritesAreDropped() async throws {
        let fixture = try makeFixture()

        let recorder = FieldRecorder(fixture.preferences.appLockEnabled)
        await recorder.wait(forAtLeast: 1)

        await fixture.preferences.setAppLockEnabled(true)
        await recorder.wait(forAtLeast: 2)

        await fixture.preferences.setAppLockEnabled(true)
        await Task.yield()
        await Task.yield()

        #expect(recorder.recorded == [false, true])
    }

    // MARK: - app-lock writes go through the flag store, never the defaults

    @Test("app lock writes go through the flag store, never UserDefaults")
    func appLockWritesGoThroughFlagStoreNeverUserDefaults() async throws {
        let fixture = try makeFixture()

        await fixture.preferences.setAppLockEnabled(true)

        // Spec §5: `app_lock_enabled` is the one setting that gates access to the data, so it
        // lives in the Keychain (the flag store), not in a plist any file-level backup would
        // carry. `SalusPreferencesDataSourceTests.appLockFlagBypassesUserDefaults` pins the same
        // thing at the data source; this test pins it at the preferences layer too, so a future
        // change that rerouted the setter through `defaults.set` would fail here as well.
        #expect(fixture.env.defaults.object(forKey: SettingsKeys.appLockEnabled) == nil)
        #expect(fixture.flagStore.read())

        let settings = await fixture.preferences.appLockEnabled.firstValue()
        #expect(settings == true)
    }

    // MARK: - a change to one field does not re-emit the others

    @Test("a change to secureScreenEnabled does not re-emit themeMode")
    func unrelatedChangeDoesNotReEmit() async throws {
        let fixture = try makeFixture()

        let recorder = FieldRecorder(fixture.preferences.themeMode)
        await recorder.wait(forAtLeast: 1)

        await fixture.preferences.setSecureScreenEnabled(true)
        await Task.yield()
        await Task.yield()

        // The theme mode stream must not see the secure-screen change — the per-field dedupe is
        // what makes the four narrowings independent.
        #expect(recorder.recorded == [.system])
    }
}

// MARK: - Test helpers (restated from SalusSettingsTests, which are internal)

extension AsyncStream {
    /// The stream's current value — the twin of Kotlin's `flow.first()`.
    fileprivate func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}

/// Records every element a stream emits, so a test can assert the whole sequence — the twin of
/// `SalusSettingsTests.StreamRecorder`, restated here because that type is `internal`.
private final class FieldRecorder<Value: Sendable & Equatable>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value] = []
    private var waiter: (threshold: Int, continuation: CheckedContinuation<Void, Never>)?
    private var consumer: Task<Void, Never>?

    init(_ stream: AsyncStream<Value>) {
        consumer = Task { [weak self] in
            for await value in stream {
                self?.record(value)
            }
            self?.streamFinished()
        }
    }

    deinit {
        consumer?.cancel()
    }

    var recorded: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    func wait(forAtLeast count: Int) async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if values.count >= count {
                lock.unlock()
                continuation.resume()
                return
            }
            waiter = (count, continuation)
            lock.unlock()
        }
        await Task.yield()
        await Task.yield()
    }

    private func record(_ value: Value) {
        lock.lock()
        values.append(value)
        let due = waiter.map { values.count >= $0.threshold } ?? false
        let resumed = due ? waiter?.continuation : nil
        if due {
            waiter = nil
        }
        lock.unlock()
        resumed?.resume()
    }

    private func streamFinished() {
        lock.lock()
        let resumed = waiter?.continuation
        waiter = nil
        lock.unlock()
        resumed?.resume()
    }
}
