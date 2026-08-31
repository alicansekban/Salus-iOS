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
// `core/ai/src/test/kotlin/com/alicansekban/salus/core/ai/AiSummaryRepositoryTest.kt` (the gate-5,
// failure, disclaimer and badge cases).

/// The second half of the gating-core suite — the call, the failures that spend nothing, the
/// shared disclaimer and the badge. Split from `AiSummaryRepositoryTests` to stay under the repo's
/// lint length limits; both share `SummaryRepositoryFixture` in `Fakes.swift`.
@Suite("AiSummaryRepository gate 5 and failures (Android parity)")
struct AiSummaryRepositoryGatesTests {
    private let fixture = SummaryRepositoryFixture()

    // --- gate 5: the call ----------------------------------------------------------------

    @Test("a Turkish summary is stored with the disclaimer appended")
    func aTurkishSummaryIsStoredWithTheDisclaimerAppended() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.premium)
        fixture.aiClient.enqueue(.success(fixture.modelText))

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        let expectedText = "\(fixture.modelText)\n\nBu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."
        #expect(outcome == .ready(
            summary: AiSummary(
                periodType: .weekly,
                startEpochDay: fixture.weekStart,
                endEpochDay: fixture.today,
                language: .tr,
                text: expectedText,
                createdAtEpochMs: SummaryRepositoryFixture.nowEpochMs
            ),
            fromCache: false
        ))
        #expect(fixture.summaryDao.upserts == [AiSummaryRecord(
            periodType: "WEEKLY",
            startEpochDay: fixture.weekStart,
            endEpochDay: fixture.today,
            language: "tr",
            text: expectedText,
            createdAtEpochMs: SummaryRepositoryFixture.nowEpochMs
        )])
    }

    @Test("an English summary carries the English disclaimer")
    func anEnglishSummaryCarriesTheEnglishDisclaimer() async {
        fixture.givenEnoughDataForAMonth()
        fixture.premiumRepository.set(.premium)
        fixture.aiClient.enqueue(.success(fixture.modelText))

        let outcome = await fixture.repository()
            .getSummary(period: .monthly, todayEpochDay: fixture.today, language: .en)

        guard case let .ready(summary, _) = outcome else {
            Issue.record("expected a ready, got \(outcome)")
            return
        }
        #expect(
            summary.text
                == "\(fixture.modelText)\n\nThis report is for informational purposes only and is not medical advice."
        )
        #expect(fixture.summaryDao.upserts[0].language == "en")
        #expect(fixture.summaryDao.upserts[0].periodType == "MONTHLY")
    }

    @Test("a stored summary is served from the cache on the next call")
    func aStoredSummaryIsServedFromTheCacheOnTheNextCall() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.premium)
        let repository = fixture.repository()

        let first = await repository.getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)
        let second = await repository.getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready(let firstSummary, fromCache: false) = first,
              case .ready(let secondSummary, fromCache: true) = second
        else {
            Issue.record("expected fresh then cached, got \(first) then \(second)")
            return
        }
        #expect(firstSummary == secondSummary)
        #expect(fixture.aiClient.prompts.count == 1)
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 1)
    }

    // --- failures spend nothing ----------------------------------------------------------

    @Test("a model error fails without spending the allowance")
    func aModelErrorFailsWithoutSpendingTheAllowance() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.aiClient.enqueue(.error("quota exceeded"))

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        #expect(outcome == .failed(reason: .error))
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == false)
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 0)
        #expect(fixture.summaryDao.upserts.isEmpty)
    }

    @Test("an unconfigured client fails without spending the allowance")
    func anUnconfiguredClientFailsWithoutSpendingTheAllowance() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.aiClient.isConfigured = false

        let outcome = await fixture.repository()
            .getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        // UNAVAILABLE, not ERROR: nothing was ever sent, so the screen must not offer a retry or
        // blame the connection.
        #expect(outcome == .failed(reason: .unavailable))
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == false)
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 0)
        #expect(fixture.summaryDao.upserts.isEmpty)
    }

    @Test("an offline failure leaves the free summary for the next attempt")
    func anOfflineFailureLeavesTheFreeSummaryForTheNextAttempt() async {
        fixture.givenEnoughDataForAWeek()
        fixture.premiumRepository.set(.free)
        fixture.aiClient.enqueue(.error("offline"), .success(fixture.modelText))
        let repository = fixture.repository()

        let offline = await repository.getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)
        #expect(offline == .failed(reason: .error))
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == false)

        let retry = await repository.getSummary(period: .weekly, todayEpochDay: fixture.today, language: .tr)

        guard case .ready(_, fromCache: false) = retry else {
            Issue.record("expected a fresh ready, got \(retry)")
            return
        }
        #expect(await fixture.usage.usage.firstValue()?.freeSummaryUsed == true)
        #expect(await fixture.usage.usage.firstValue()?.callsOn(todayEpochDay: fixture.today) == 1)
        #expect(fixture.aiClient.prompts.count == 2)
    }

    // --- the shared disclaimer -----------------------------------------------------------

    @Test("the disclaimer sentences are byte-exact in both languages")
    func theDisclaimerSentencesAreByteExactInBothLanguages() {
        // Pinned here as well as through the repository: the exported PDF renders the same helper,
        // and the two must never drift apart by a word.
        #expect(disclaimerFor(.tr) == "Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir.")
        #expect(
            disclaimerFor(.en)
                == "This report is for informational purposes only and is not medical advice."
        )
    }

    // --- the badge -----------------------------------------------------------------------

    @Test("freeSummaryAvailable follows the stored usage")
    func freeSummaryAvailableFollowsTheStoredUsage() async {
        let repository = fixture.repository()

        #expect(await repository.freeSummaryAvailable.firstValue() == true)

        fixture.usage.markFreeSummaryUsed()

        #expect(await repository.freeSummaryAvailable.firstValue() == false)
    }

    @Test("recording a call does not take the free summary away")
    func recordingACallDoesNotTakeTheFreeSummaryAway() async {
        let repository = fixture.repository()

        fixture.usage.recordCall(todayEpochDay: fixture.today)

        #expect(await repository.freeSummaryAvailable.firstValue() == true)
    }
}
