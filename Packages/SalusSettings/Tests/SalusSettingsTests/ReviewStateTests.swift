// The review prompt counters on `SalusPreferencesDataSource` (in-app review spec §1), against a
// throwaway `UserDefaults` suite — the `SalusPreferencesDataSourceTests` fixture, cut down.

import Foundation
import SalusModel
import Testing

@testable import SalusSettings

@Suite("Review prompt state")
struct ReviewStateTests {
    private func makeSource() throws -> (TestUserDefaults, SalusPreferencesDataSource) {
        let env = try TestUserDefaults()
        let source = SalusPreferencesDataSource(defaults: env.defaults, appLockFlagStore: InMemoryAppLockFlagStore())
        return (env, source)
    }

    @Test("an untouched store has never counted and never asked")
    func defaults() throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        #expect(source.reviewState() == ReviewState(homeOpenCount: 0, lastRequestedEpochMs: nil))
    }

    @Test("each increment adds one and returns the new count")
    func incrementTwice() throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        #expect(source.incrementHomeOpenCount() == 1)
        #expect(source.incrementHomeOpenCount() == 2)
        #expect(source.reviewState().homeOpenCount == 2)
        #expect(env.defaults.integer(forKey: SettingsKeys.homeOpenCount) == 2)
    }

    @Test("the request stamp round-trips at full Int64 range")
    func stampRoundTrips() throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        let stamp: Int64 = 1_757_179_200_000
        source.setReviewLastRequested(epochMs: stamp)

        #expect(source.reviewState().lastRequestedEpochMs == stamp)
        #expect(env.defaults.object(forKey: SettingsKeys.reviewLastRequestedMs) != nil)
    }

    @Test("the counters never enter UserSettings")
    func countersStayOutOfUserSettings() async throws {
        let (env, source) = try makeSource()
        defer { _ = env }

        source.incrementHomeOpenCount()
        source.setReviewLastRequested(epochMs: 1)

        let settings = try #require(await source.userSettings.firstValue())
        #expect(settings == UserSettings())
    }
}
