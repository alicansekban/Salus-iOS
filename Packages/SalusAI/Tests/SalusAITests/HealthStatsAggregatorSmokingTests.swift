import Foundation
import SalusCommon
import SalusDatabase
import SalusSmoking
import SalusTesting
import Testing

@testable import SalusAI

// Twin of Android `core/ai/src/test/.../HealthStatsAggregatorSmokingTest.kt`. The aggregator hands
// the model the contract's smoking aggregate and nothing else. The privacy test runs the real
// aggregator into the real prompt builder, so a later change that lets the plan's reason (or
// anything else free-form) travel turns it red at the end of the path.

@Suite("HealthStatsAggregator smoking")
struct HealthStatsAggregatorSmokingTests {
    private let smoking = FakeSmokingRepository()
    private let today = 20000
    private let utc = TimeZone(secondsFromGMT: 0) ?? .gmt

    @Test("an aggregate carries the contract's smoking stats for exactly the period")
    func aggregateCarriesSmokingStatsForThePeriod() async throws {
        smoking.input = SmokingFixture.input(
            plan: SmokingFixture.plan(createdAtEpochDay: Int64(today - 30)),
            events: [
                SmokingFixture.smoked("e1", epochDay: Int64(today - 1), hour: 19, trigger: .coffee),
                SmokingFixture.smoked("e2", epochDay: Int64(today - 2), hour: 20, trigger: .coffee),
                SmokingFixture.smoked("e3", epochDay: Int64(today - 3), hour: 19, trigger: .stress),
                // Before the weekly window: must not count.
                SmokingFixture.smoked("old", epochDay: Int64(today - 9), hour: 9, trigger: .boredom)
            ]
        )

        let stats = try #require(try await aggregator().aggregate(period: .weekly, todayEpochDay: today, timeZone: utc)
            .smoking)

        #expect(stats.mode == .quit)
        #expect(stats.daysTracked == 7)
        #expect(stats.slipCount == 3)
        #expect(stats.topTriggers.first?.trigger == .coffee)
        #expect(stats.busiestBand == .h18_22)
        #expect(stats.reductionPercent == nil)
    }

    @Test("no smoking is attached when nothing is set up")
    func noSmokingWhenNotSetUp() async throws {
        smoking.input = FakeSmokingRepository.notSetUp

        let stats = try await aggregator().aggregate(period: .weekly, todayEpochDay: today, timeZone: utc)

        #expect(stats.smoking == nil)
    }

    @Test("a failed smoking read leaves the rest of the aggregate intact")
    func failedReadLeavesTheRestIntact() async throws {
        smoking.failsToRead = true

        let stats = try await aggregator().aggregate(period: .weekly, todayEpochDay: today, timeZone: utc)

        #expect(stats.smoking == nil)
        #expect(stats.periodType == .weekly)
    }

    @Test("the plan's free-text reason never reaches any prompt")
    func reasonNeverReachesAnyPrompt() async throws {
        let planted = "KIZIM_ICIN_SENTINEL"
        smoking.input = SmokingFixture.input(
            plan: SmokingFixture.plan(reason: planted, createdAtEpochDay: Int64(today - 30)),
            events: [SmokingFixture.smoked("e1", epochDay: Int64(today - 1), trigger: .coffee)]
        )

        let stats = try await aggregator().aggregate(period: .weekly, todayEpochDay: today, timeZone: utc)
        // Without the block this test would prove nothing.
        #expect(stats.smoking != nil)

        for language in [AiLanguage.tr, .en] {
            // The tobacco block has to be in the prompt, or the negative checks below pass because
            // nothing smoking-related was ever written.
            let header = language == .tr ? "Tütün kullanımı (özet sayılar):" : "Tobacco use (summary figures):"
            for prompt in [
                PromptBuilder.summaryPrompt(stats, language: language),
                PromptBuilder.doctorReportPrompt(stats, language: language)
            ] {
                #expect(prompt.user.contains(header), "\(language): the tobacco block is in the prompt")
                #expect(!prompt.user.contains(planted))
                #expect(!prompt.system.contains(planted))
            }
        }
        #expect(!String(describing: stats).contains(planted))
    }

    // MARK: - Helpers

    private func aggregator() throws -> HealthStatsAggregator {
        let database = try SalusDatabase.inMemory(clock: FixedSalusClock(now: Date(epochMilliseconds: 0)))
        return HealthStatsAggregator(
            vitalsDao: VitalsDao(database: database),
            medicationDao: MedicationDao(database: database),
            profileId: SalusDatabase.defaultProfileId,
            smokingRepository: smoking
        )
    }
}
