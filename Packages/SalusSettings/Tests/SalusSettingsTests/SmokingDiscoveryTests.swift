// The Home smoking card's "dismiss forever" flag on `SalusPreferencesDataSource` (plan Task 16),
// against a throwaway `UserDefaults` suite. Twin of Android's `SalusPreferencesSmokingDiscoveryTest`.

import Foundation
import SalusModel
import Testing

@testable import SalusSettings

@Suite("Smoking discovery dismissal")
struct SmokingDiscoveryTests {
    private func makeSource() throws -> (TestUserDefaults, SalusPreferencesDataSource) {
        let env = try TestUserDefaults()
        let source = SalusPreferencesDataSource(defaults: env.defaults, appLockFlagStore: InMemoryAppLockFlagStore())
        return (env, source)
    }

    @Test("the row is not dismissed until the person closes it")
    func defaultsToNotDismissed() async throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        #expect(await source.smokingDiscoveryDismissed.firstValue() == false)
    }

    @Test("a dismissal is remembered under the Android key")
    func dismissalIsRemembered() async throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        source.setSmokingDiscoveryDismissed(true)

        #expect(await source.smokingDiscoveryDismissed.firstValue() == true)
        #expect(env.defaults.bool(forKey: "smoking_discovery_dismissed"))
    }

    @Test("a running stream sees the dismissal")
    func streamEmitsTheChange() async throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        var iterator = source.smokingDiscoveryDismissed.makeAsyncIterator()
        #expect(await iterator.next() == false)
        source.setSmokingDiscoveryDismissed(true)
        #expect(await iterator.next() == true)
    }

    @Test("the flag never enters UserSettings")
    func staysOutOfUserSettings() async throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        source.setSmokingDiscoveryDismissed(true)

        let settings = try #require(await source.userSettings.firstValue())
        #expect(settings == UserSettings())
    }
}
