// The review prompt cases of `HomeViewModelTest.kt` (in-app review spec §3), ported by name:
// opens 1 and 2 emit nothing and count; the third emits once and stamps the clock; a fourth the
// same day is silent; fourteen days later it asks again. Plus two iOS-only cases for the
// foreground signal, which has no Android twin (`AppForegroundSignal.swift`).

import Foundation
import SalusCommon
import SalusSettings
import SalusTesting
import Testing

@testable import FeatureHome

enum ReviewPromptFixture {
    /// A `SalusPreferencesDataSource` over a throwaway suite, released when the process exits.
    static func makePreferences() -> SalusPreferencesDataSource {
        let suite = "salus-home-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return SalusPreferencesDataSource(defaults: defaults, appLockFlagStore: InMemoryAppLockFlagStore())
    }
}

@Suite("HomeViewModel review prompt")
@MainActor
struct HomeReviewPromptTests {
    private static let now = Date(timeIntervalSince1970: 1_760_000_000)
    private static let day: TimeInterval = 24 * 60 * 60

    private let clock = FixedSalusClock(now: HomeReviewPromptTests.now)
    private let repository = FakeTodayRepository(
        TodayOverview(
            doses: [],
            appointments: [],
            cycle: nil,
            vitals: VitalsSnapshot(
                latestWeightKg: nil,
                weightTrend: [],
                latestSystolic: nil,
                latestDiastolic: nil,
                latestGlucoseMgdl: nil,
                glucoseUnit: .mgDl
            )
        )
    )
    private let preferences = ReviewPromptFixture.makePreferences()
    private let foreground = AppForegroundSignal()

    private func viewModel() -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            aiSummaryAvailability: FakeHomeAiSummaryAvailability(available: true),
            premiumStatus: FakeHomePremiumStatus(isPremium: false),
            clock: clock,
            doseActions: RecordingDoseActions(),
            preferences: preferences,
            foreground: foreground
        )
    }

    @Test("the first two opens count and ask for nothing")
    func firstTwoOpensAreSilent() {
        let viewModel = viewModel()

        viewModel.onEvent(.appeared)
        viewModel.onEvent(.appeared)

        #expect(viewModel.pendingEffects.isEmpty)
        #expect(preferences.reviewState() == ReviewState(homeOpenCount: 2, lastRequestedEpochMs: nil))
    }

    @Test("the third open asks once and stamps the clock before the effect")
    func thirdOpenAsks() {
        let viewModel = viewModel()

        for _ in 0 ..< 3 {
            viewModel.onEvent(.appeared)
        }

        #expect(viewModel.consumeEffects() == [.requestReview])
        #expect(preferences.reviewState().homeOpenCount == 3)
        #expect(preferences.reviewState().lastRequestedEpochMs == clock.nowEpochMilliseconds())
    }

    @Test("a fourth open the same day is silent")
    func fourthOpenSameDayIsSilent() {
        let viewModel = viewModel()
        for _ in 0 ..< 3 {
            viewModel.onEvent(.appeared)
        }
        _ = viewModel.consumeEffects()

        viewModel.onEvent(.appeared)

        #expect(viewModel.pendingEffects.isEmpty)
        #expect(preferences.reviewState().homeOpenCount == 4)
    }

    @Test("fourteen days after the last request it asks again")
    func asksAgainAfterCooldown() {
        let viewModel = viewModel()
        for _ in 0 ..< 3 {
            viewModel.onEvent(.appeared)
        }
        _ = viewModel.consumeEffects()

        clock.advanceTo(Self.now.addingTimeInterval(14 * Self.day))
        viewModel.onEvent(.appeared)

        #expect(viewModel.consumeEffects() == [.requestReview])
        #expect(preferences.reviewState().lastRequestedEpochMs == clock.nowEpochMilliseconds())
    }

    @Test("a foreground return while the dashboard is showing counts as an open")
    func foregroundWhileVisibleCounts() {
        let viewModel = viewModel()
        viewModel.onEvent(.appeared)

        foreground.signal()

        #expect(preferences.reviewState().homeOpenCount == 2)
    }

    @Test("a foreground return while another tab is showing does not count")
    func foregroundWhileHiddenDoesNotCount() {
        let viewModel = viewModel()
        viewModel.onEvent(.appeared)
        viewModel.didDisappear()

        foreground.signal()

        #expect(preferences.reviewState().homeOpenCount == 1)
    }
}
