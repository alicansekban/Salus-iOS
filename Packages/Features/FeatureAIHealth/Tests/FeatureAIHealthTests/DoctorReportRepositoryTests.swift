// Ported 1:1 from Android
// `feature/aihealth/src/test/kotlin/com/alicansekban/salus/feature/aihealth/report/
// DoctorReportRepositoryTest.kt` — the five load-bearing cases, in the Kotlin order, with the
// Kotlin inputs and expectations.

import Foundation
import SalusAI
import SalusCommon
import SalusPremium
import SalusSettings
import SalusTesting
import Testing

@testable import FeatureAIHealth

/// What a doctor report costs the user, and what it still produces when the AI half fails.
///
/// The load-bearing property is that the deterministic half and the AI half are independent: a
/// user who paid for this feature and is standing in a waiting room with no signal must still
/// walk out with the table of numbers they recorded. Every test that expects no model call
/// asserts on `FakeAiClient.prompts`, and every test that expects no document asserts on
/// `FakeReportGenerator.calls` — both failures are otherwise silent.
@Suite("DoctorReportRepository")
struct DoctorReportRepositoryTests {
    private let aiClient = FakeAiClient()
    private let periodReader = FakeHealthPeriodReader()
    private let premiumRepository = ReportFakePremiumRepository()
    private let generator = FakeReportGenerator()
    private let clock = FixedSalusClock(now: Date(epochMilliseconds: nowEpochMs), timeZone: utc)
    private let usage: AiUsageDataSource

    init() {
        let suiteName = "salus-aihealth-report-test-\(UUID().uuidString)"
        usage = AiUsageDataSource(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
        generator.outputFile = URL(fileURLWithPath: "salus-report.pdf")
        periodReader.stats = statsWith(distinctRecordDays: weeklyMinimumDays)
    }

    // MARK: - Gate 1: premium

    /// A free user is sent to the paywall and nothing else runs.
    @Test("a free user is sent to the paywall and nothing else runs")
    func freeUserSentToPaywall() async {
        premiumRepository.set(.free)

        let outcome = await repository().generate(period: .weekly, todayEpochDay: today, language: .tr)

        #expect(outcome == .needsPremium)
        #expect(aiClient.prompts.isEmpty)
        #expect(generator.calls.isEmpty)
        // Not even the database is read: the gate is the first statement in the body.
        #expect(periodReader.aggregateCalls == 0)
    }

    /// The one-off free AI credit does not unlock the report.
    @Test("the one-off free AI credit does not unlock the report")
    func freeCreditDoesNotUnlockReport() async {
        premiumRepository.set(.free)

        let outcome = await repository().generate(period: .weekly, todayEpochDay: today, language: .tr)

        #expect(outcome == .needsPremium)
    }

    // MARK: - Gate 2: any data at all

    /// A period without a single record needs more data.
    @Test("a period without a single record needs more data")
    func periodWithoutRecordNeedsMoreData() async {
        periodReader.stats = statsWith(distinctRecordDays: 0)

        let outcome = await repository().generate(period: .weekly, todayEpochDay: today, language: .tr)

        #expect(outcome == .needsMoreData)
        #expect(aiClient.prompts.isEmpty)
        #expect(generator.calls.isEmpty)
    }

    // MARK: - The narrative is the optional half

    /// A successful call includes the narrative and records the call.
    @Test("a successful call includes the narrative and records the call")
    func successfulCallIncludesNarrative() async {
        aiClient.enqueue(.success(modelText))

        let outcome = await repository().generate(period: .weekly, todayEpochDay: today, language: .tr)

        #expect(outcome == .ready(pdfFile: generator.outputFile, narrativeIncluded: true))
        #expect(generator.calls.first?.narrative == modelText)
        #expect(await usage.usage.firstValue()?.callsOn(todayEpochDay: today) == 1)
    }

    /// A model error still produces the PDF without a narrative.
    @Test("a model error still produces the PDF without a narrative")
    func modelErrorStillProducesPdf() async {
        aiClient.enqueue(.error("offline"))

        let outcome = await repository().generate(period: .weekly, todayEpochDay: today, language: .tr)

        // Ready, never Failed: the tables are the report's value and they need no network.
        #expect(outcome == .ready(pdfFile: generator.outputFile, narrativeIncluded: false))
        #expect(generator.calls.first?.narrative == nil)
        // A failed call costs nothing, so the day's quota is untouched.
        #expect(await usage.usage.firstValue()?.callsOn(todayEpochDay: today) == 0)
    }

    /// A spent daily quota skips the call entirely.
    @Test("a spent daily quota skips the call entirely")
    func spentDailyQuotaSkipsCall() async {
        for _ in 0 ..< dailyLimit {
            usage.recordCall(todayEpochDay: today)
        }

        let outcome = await repository().generate(period: .weekly, todayEpochDay: today, language: .tr)

        #expect(outcome == .ready(pdfFile: generator.outputFile, narrativeIncluded: false))
        #expect(aiClient.prompts.isEmpty)
        #expect(await usage.usage.firstValue()?.callsOn(todayEpochDay: today) == dailyLimit)
    }

    // MARK: - Helpers

    private func repository() -> DoctorReportRepository {
        DoctorReportRepositoryImpl(
            aiClient: aiClient,
            periodReader: periodReader,
            usageDataSource: usage,
            premiumRepository: premiumRepository,
            generator: generator,
            clock: clock
        )
    }

    private func statsWith(distinctRecordDays: Int) -> HealthPeriodStats {
        HealthPeriodStats(
            periodType: .weekly,
            startEpochDay: today - 6,
            endEpochDay: today,
            distinctRecordDays: distinctRecordDays,
            systolic: nil,
            diastolic: nil,
            pulse: nil,
            glucoseMgDl: nil,
            weightKg: nil,
            loggedDoses: 4,
            takenDoses: 3
        )
    }

    /// 2026-08-20 — an arbitrary but realistic epoch day.
    private let today = 20685
    private let dailyLimit = 5
    private let weeklyMinimumDays = 3
    private let modelText = "Blood pressure stayed within range across the period."

    private static let nowEpochMs: Int64 = 20685 * 86_400_000 + 12 * 3_600_000
    // swiftlint:disable force_unwrapping
    private static let utc = TimeZone(secondsFromGMT: 0)!
    // swiftlint:enable force_unwrapping
}

// MARK: - Fakes

/// Results are queued and handed out in FIFO order; once the queue is empty `defaultResult` is
/// returned, so a test that does not care about the answer does not have to enqueue one. Every
/// prompt is recorded — including the ones answered with `.unavailable` — so a test can assert
/// both *what* was asked and *how often*.
private final class FakeAiClient: AiClient, @unchecked Sendable {
    private let lock = NSLock()
    private var queued: [AiResult] = []
    private var recorded: [AiPrompt] = []
    var isConfigured = true
    var defaultResult: AiResult = .success("fake narrative")

    var prompts: [AiPrompt] {
        lock.withLock { recorded }
    }

    func enqueue(_ result: AiResult) {
        lock.withLock { queued.append(result) }
    }

    func generate(_ prompt: AiPrompt) async -> AiResult {
        lock.withLock {
            recorded.append(prompt)
            if !isConfigured {
                return .unavailable
            }
            return queued.isEmpty ? defaultResult : queued.removeFirst()
        }
    }
}

/// Serves whatever the test set, and counts the reads so a test can assert the gates ran in the
/// order that keeps a free user's tap from touching the database at all.
private final class FakeHealthPeriodReader: HealthPeriodReader, @unchecked Sendable {
    private let lock = NSLock()
    var stats: HealthPeriodStats = .init(
        periodType: .weekly,
        startEpochDay: 0,
        endEpochDay: 0,
        distinctRecordDays: 0,
        systolic: nil,
        diastolic: nil,
        pulse: nil,
        glucoseMgDl: nil,
        weightKg: nil,
        loggedDoses: 0,
        takenDoses: 0
    )
    var rows: HealthPeriodRows = .empty
    private(set) var aggregateCalls = 0

    func aggregate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodStats {
        lock.withLock { aggregateCalls += 1 }
        return lock.withLock { stats }
    }

    func periodRows(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodRows {
        lock.withLock { rows }
    }
}

/// Premium by default: the report is a premium feature, so that is the interesting path.
private final class ReportFakePremiumRepository: PremiumRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var current: PremiumStatus
    private var continuations: [UUID: AsyncStream<PremiumStatus>.Continuation] = [:]

    init(status: PremiumStatus = .premium) {
        current = status
    }

    var status: AsyncStream<PremiumStatus> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let value = current
            lock.unlock()
            continuation.yield(value)
            continuation.onTermination = { [weak self] _ in
                self?.remove(id)
            }
        }
    }

    func set(_ newStatus: PremiumStatus) {
        lock.lock()
        current = newStatus
        let continuations = Array(continuations.values)
        lock.unlock()
        for continuation in continuations {
            continuation.yield(newStatus)
        }
    }

    func refresh() async {}

    private func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}

/// Records every argument, so a test can assert what the document would have been drawn from.
private final class FakeReportGenerator: PdfReportGenerator, @unchecked Sendable {
    struct Call: Equatable {
        let stats: HealthPeriodStats
        let rows: HealthPeriodRows
        let narrative: String?
        let language: AiLanguage
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    var outputFile = URL(fileURLWithPath: "salus-report.pdf")

    var calls: [Call] {
        lock.withLock { recorded }
    }

    func generate(
        stats: HealthPeriodStats,
        rows: HealthPeriodRows,
        narrative: String?,
        language: AiLanguage
    ) throws -> URL {
        lock.withLock {
            recorded.append(Call(stats: stats, rows: rows, narrative: narrative, language: language))
        }
        return outputFile
    }
}

extension AsyncStream {
    fileprivate func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}
