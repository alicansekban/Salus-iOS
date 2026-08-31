import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusPremium
import SalusSettings
import SalusTesting
import Testing

@testable import SalusAI

// Ported 1:1 from Android
// `core/ai/src/test/kotlin/com/alicansekban/salus/core/ai/AiSummaryRepositoryTest.kt`.

/// The gating core of the AI feature: which of the five ordered gates answers a request, and
/// exactly what a request costs the user.
///
/// The order is the part worth pinning — a user with too little data must never be shown a
/// paywall, and a cached summary must never be re-gated, because the allowance was already spent
/// when it was generated. The failure that costs a user money is silent, so every test that
/// expects no call asserts on `FakeAiClient.prompts` rather than on the outcome alone.
///
/// Usage is exercised through a real `AiUsageDataSource` rather than a hand-rolled double: the
/// daily quota's day-reset rule lives in `AiUsageDataSource`, and a fake would let this repository
/// pass while the real counter locks the user out on yesterday's count.
///
/// The suite is split across two files — this one and `AiSummaryRepositoryGatesTests` — to stay
/// under the repo's lint length limits; the fixture is shared in `Fakes.swift`.
@Suite("AiSummaryRepository (Android parity)")
struct AiSummaryRepositoryTests {
    private let fixture = SummaryRepositoryFixture()

    // --- gate 1: cache -------------------------------------------------------------------

    @Test("a cached summary is served without asking the model")
    func aCachedSummaryIsServedWithoutAskingTheModel() async {
        fixture.summaryDao.put(fixture.cachedEntity())

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .ready(
            summary: AiSummary(
                periodType: .weekly,
                startEpochDay: fixture.weekStart,
                endEpochDay: fixture.today,
                language: .tr,
                text: fixture.cachedText,
                createdAtEpochMs: fixture.cachedAtEpochMs
            ),
            fromCache: true
        ))
        #expect(fixture.aiClient.prompts.isEmpty)
    }

    @Test("a cached summary is served even when nothing is left to spend")
    func aCachedSummaryIsServedEvenWhenNothingIsLeftToSpend() async {
        // Entitlement revoked, free summary gone, quota exhausted: the summary was paid for when
        // it was generated, so re-opening the same week must not be re-gated.
        fixture.summaryDao.put(fixture.cachedEntity())
        fixture.premiumRepository.set(.free)
        fixture.usage.markFreeSummaryUsed()
        for _ in 0 ..< fixture.dailyLimit {
            fixture.usage.recordCall(todayEpochDay: fixture.today)
        }

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready(_, fromCache: true) = outcome else {
            Issue.record("expected a cached ready, got \(outcome)")
            return
        }
        #expect(fixture.aiClient.prompts.isEmpty)
    }

    @Test("a summary cached in another language is not served")
    func aSummaryCachedInAnotherLanguageIsNotServed() async {
        fixture.summaryDao.put(fixture.cachedEntity())
        fixture.givenEnoughDataForAWeek()

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .en)

        guard case .ready(_, fromCache: false) = outcome else {
            Issue.record("expected a fresh ready, got \(outcome)")
            return
        }
        #expect(fixture.aiClient.prompts.count == 1)
    }

    // --- gate 2: enough data -------------------------------------------------------------

    @Test("a week with two recorded days needs more data and never reaches the model")
    func aWeekWithTwoRecordedDaysNeedsMoreDataAndNeverReachesTheModel() async {
        fixture.givenStats(distinctRecordDays: 2)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .needsMoreData)
        #expect(fixture.aiClient.prompts.isEmpty)
    }

    @Test("too little data is reported before the paywall")
    func tooLittleDataIsReportedBeforeThePaywall() async {
        // The order is binding: a free user who has spent their free summary and has two days of
        // records is told to keep logging, not asked to pay for a summary of nothing.
        fixture.premiumRepository.set(.free)
        fixture.usage.markFreeSummaryUsed()
        fixture.givenStats(distinctRecordDays: 2)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .needsMoreData)
    }

    @Test("a month needs seven recorded days")
    func aMonthNeedsSevenRecordedDays() async {
        // A week's worth of records is enough for WEEKLY but not for MONTHLY.
        fixture.givenEnoughDataForAWeek()

        #expect(
            await fixture.repository()
                .getSummary(period: .monthly, todayEpochDay: fixture.today, language: .tr)
                == .needsMoreData
        )

        fixture.givenEnoughDataForAMonth()

        let outcome = await fixture.repository()
            .getSummary(period: .monthly, todayEpochDay: fixture.today, language: .tr)
        guard case .ready(_, fromCache: false) = outcome else {
            Issue.record("expected a fresh ready, got \(outcome)")
            return
        }
    }

    @Test("recorded doses count towards the data a week needs")
    func recordedDosesCountTowardsTheDataAWeekNeeds() async {
        fixture.givenStats(distinctRecordDays: 3)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready(_, fromCache: false) = outcome else {
            Issue.record("expected a fresh ready, got \(outcome)")
            return
        }
    }

    // --- gate 3: entitlement -------------------------------------------------------------

    @Test("a free user who already spent the free summary is sent to the paywall")
    func aFreeUserWhoAlreadySpentTheFreeSummaryIsSentToThePaywall() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.usage.markFreeSummaryUsed()

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .needsPremium)
        #expect(fixture.aiClient.prompts.isEmpty)
    }

    @Test("a free user with the free summary in hand gets one and spends it")
    func aFreeUserWithTheFreeSummaryInHandGetsOneAndSpendsIt() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready(_, fromCache: false) = outcome else {
            Issue.record("expected a fresh ready, got \(outcome)")
            return
        }
        #expect(fixture.aiClient.prompts.count == 1)
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == true)
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 1)
    }

    @Test("a premium user keeps the free summary unspent")
    func aPremiumUserKeepsTheFreeSummaryUnspent() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.premium)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready = outcome else {
            Issue.record("expected a ready, got \(outcome)")
            return
        }
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == false)
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 1)
    }

    @Test("a grace period user is still entitled")
    func aGracePeriodUserIsStillEntitled() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.gracePeriod)
        fixture.usage.markFreeSummaryUsed()

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready = outcome else {
            Issue.record("expected a ready, got \(outcome)")
            return
        }
    }

    // --- gate 3: the entitlement hydration race ------------------------------------------

    @Test("a late store answer is caught before the free summary is burned")
    func aLateStoreAnswerIsCaughtBeforeTheFreeSummaryIsBurned() async {
        // The premium status starts FREE until the store's customer stream answers. A paying user
        // who opens a summary in that window must not be charged their one-off free credit for it
        // — the credit is irreversible, so it is worth one refresh to be sure.
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.premiumRepository.answersOnRefreshWith(.premium)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready(_, fromCache: false) = outcome else {
            Issue.record("expected a fresh ready, got \(outcome)")
            return
        }
        #expect(fixture.premiumRepository.refreshCalls == 1)
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == false)
        // The call still counts against the daily quota: it was made either way.
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 1)
    }

    @Test("a late store answer rescues a user who already spent the free summary")
    func aLateStoreAnswerRescuesAUserWhoAlreadySpentTheFreeSummary() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.usage.markFreeSummaryUsed()
        fixture.premiumRepository.answersOnRefreshWith(.premium)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready = outcome else {
            Issue.record("expected a ready, got \(outcome)")
            return
        }
        #expect(fixture.premiumRepository.refreshCalls == 1)
    }

    @Test("a refresh that leaves the user free still spends the free summary")
    func aRefreshThatLeavesTheUserFreeStillSpendsTheFreeSummary() async {
        // Offline, refresh() leaves the status alone. Behaviour must be exactly what it was before
        // the refresh existed.
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(fixture.premiumRepository.refreshCalls == 1)
        guard case .ready(_, fromCache: false) = outcome else {
            Issue.record("expected a fresh ready, got \(outcome)")
            return
        }
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == true)
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 1)
    }

    @Test("a refresh that leaves the user free still hits the paywall")
    func aRefreshThatLeavesTheUserFreeStillHitsThePaywall() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.usage.markFreeSummaryUsed()

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .needsPremium)
        #expect(fixture.premiumRepository.refreshCalls == 1)
        #expect(fixture.aiClient.prompts.isEmpty)
    }

    @Test("an entitled user is never refreshed")
    func anEntitledUserIsNeverRefreshed() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.premium)

        _ = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(fixture.premiumRepository.refreshCalls == 0)
    }

    @Test("a grace period user is never refreshed")
    func aGracePeriodUserIsNeverRefreshed() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.gracePeriod)

        _ = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(fixture.premiumRepository.refreshCalls == 0)
    }

    @Test("a cache hit never reaches the store")
    func aCacheHitNeverReachesTheStore() async {
        fixture.summaryDao.put(fixture.cachedEntity())
        fixture.premiumRepository.set(.free)

        _ = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(fixture.premiumRepository.refreshCalls == 0)
    }

    @Test("too little data never reaches the store")
    func tooLittleDataNeverReachesTheStore() async {
        fixture.premiumRepository.set(.free)
        fixture.givenStats(distinctRecordDays: 2)

        _ = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(fixture.premiumRepository.refreshCalls == 0)
    }

    // --- gate 4: daily quota -------------------------------------------------------------

    @Test("the daily quota stops a premium user at five calls")
    func theDailyQuotaStopsAPremiumUserAtFiveCalls() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.premium)
        for _ in 0 ..< fixture.dailyLimit {
            fixture.usage.recordCall(todayEpochDay: fixture.today)
        }

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .dailyLimitReached)
        #expect(fixture.aiClient.prompts.isEmpty)
    }

    @Test("the fifth call of the day is still allowed")
    func theFifthCallOfTheDayIsStillAllowed() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.premium)
        for _ in 0 ..< (fixture.dailyLimit - 1) {
            fixture.usage.recordCall(todayEpochDay: fixture.today)
        }

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready = outcome else {
            Issue.record("expected a ready, got \(outcome)")
            return
        }
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == fixture.dailyLimit)
    }

    @Test("a quota spent yesterday does not block today")
    func aQuotaSpentYesterdayDoesNotBlockToday() async {
        // The stored count is only reset by the next write, so between midnight and the first call
        // of the day it still belongs to yesterday. Reading `callsToday` directly here would lock
        // the user out for a whole day.
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.premium)
        for _ in 0 ..< fixture.dailyLimit {
            fixture.usage.recordCall(todayEpochDay: fixture.today - 1)
        }

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready = outcome else {
            Issue.record("expected a ready, got \(outcome)")
            return
        }
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 1)
    }

    @Test("the paywall is reported before the daily quota")
    func thePaywallIsReportedBeforeTheDailyQuota() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.usage.markFreeSummaryUsed()
        for _ in 0 ..< fixture.dailyLimit {
            fixture.usage.recordCall(todayEpochDay: fixture.today)
        }

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .needsPremium)
    }
}
