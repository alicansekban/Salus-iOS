import Foundation
import SalusAI
import SalusCommon
import SalusDatabase
import SalusPremium
import SalusSettings
import SalusTesting

// Test doubles for the gating core, ported 1:1 from Android
// `core/ai/src/test/kotlin/com/alicansekban/salus/core/ai/AiSummaryRepositoryTest.kt` (the
// `FakeAiSummaryDao` and `FakePremiumRepository` classes at the bottom of that file).

/// Records what was written so a test can assert the cache row, not just the returned value
/// (`AiSummaryRepositoryTest.kt:633-656`).
final class FakeAiSummaryDao: AiSummaryDao, @unchecked Sendable {
    private let lock = NSLock()
    private var rows: [Key: AiSummaryRecord] = [:]
    private var recordedUpserts: [AiSummaryRecord] = []

    struct Key: Hashable {
        let periodType: String
        let startEpochDay: Int
        let language: String
    }

    /// Every row written, in write order.
    var upserts: [AiSummaryRecord] {
        lock.lock()
        defer { lock.unlock() }
        return recordedUpserts
    }

    func put(_ record: AiSummaryRecord) {
        lock.lock()
        rows[record.key()] = record
        lock.unlock()
    }

    func get(periodType: String, startEpochDay: Int, language: String) async -> AiSummaryRecord? {
        lock.withLock {
            rows[Key(periodType: periodType, startEpochDay: startEpochDay, language: language)]
        }
    }

    func upsert(_ record: AiSummaryRecord) async {
        lock.withLock {
            recordedUpserts.append(record)
            rows[record.key()] = record
        }
    }
}

extension AiSummaryRecord {
    fileprivate func key() -> FakeAiSummaryDao.Key {
        FakeAiSummaryDao.Key(periodType: periodType, startEpochDay: startEpochDay, language: language)
    }
}

/// A `PremiumRepository` whose status a test sets by hand, and which counts every `refresh`
/// (`AiSummaryRepositoryTest.kt:658-686`).
final class FakePremiumRepository: PremiumRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var current: PremiumStatus
    private var continuations: [UUID: AsyncStream<PremiumStatus>.Continuation] = [:]

    /// How many times the store was re-checked — a premium user should never cause one.
    private(set) var refreshCalls = 0

    /// What `refresh` does to the status. The default mirrors an unreachable store: the real
    /// repository leaves the last known entitlement alone rather than dropping to FREE.
    var onRefresh: () -> Void = {}

    init(status: PremiumStatus = .free) {
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

    /// Makes `refresh` behave like a store that answers late with an active entitlement.
    func answersOnRefreshWith(_ newStatus: PremiumStatus) {
        onRefresh = { [weak self] in self?.set(newStatus) }
    }

    func refresh() async {
        lock.withLock {
            refreshCalls += 1
        }
        onRefresh()
    }

    private func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}

/// A `HealthPeriodReader` that answers a configurable snapshot, so the repository's data gate can
/// be driven without GRDB. The real aggregator's two DAO reads are thin orchestration; what the
/// gating core needs is the `distinctRecordDays` it reports.
///
/// The snapshot's `periodType` and day bounds are overridden to match the requested period, so a
/// test that asks for a month stores a `MONTHLY` row exactly as the real aggregator would — the
/// fake only controls the data gate, never the period identity.
final class FakeHealthPeriodReader: HealthPeriodReader, @unchecked Sendable {
    private let lock = NSLock()
    private var recordDays: Int

    init(recordDays: Int) {
        self.recordDays = recordDays
    }

    func setRecordDays(_ recordDays: Int) {
        lock.withLock {
            self.recordDays = recordDays
        }
    }

    func aggregate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodStats {
        let dayCount = switch period {
        case .weekly: 7
        case .monthly: 30
        }
        let days = (todayEpochDay - dayCount + 1) ... todayEpochDay
        return lock.withLock {
            HealthPeriodStats(
                periodType: period,
                startEpochDay: days.lowerBound,
                endEpochDay: days.upperBound,
                distinctRecordDays: recordDays,
                systolic: nil,
                diastolic: nil,
                pulse: nil,
                glucoseMgDl: nil,
                weightKg: nil,
                loggedDoses: 0,
                takenDoses: 0
            )
        }
    }

    func periodRows(
        period: SummaryPeriod,
        todayEpochDay: Int,
        timeZone: TimeZone
    ) async throws -> HealthPeriodRows {
        .empty
    }
}

/// The shared harness for the gating-core tests, ported from the `@Before`/`repository()` helpers
/// of `AiSummaryRepositoryTest.kt:55-84, 555-563`.
///
/// Holds the fakes and the real `AiUsageDataSource` (over a throwaway `UserDefaults` suite) that
/// every test in `AiSummaryRepositoryTests` and `AiSummaryRepositoryGatesTests` drives, plus the
/// constants the Android test's `companion object` pins (`AiSummaryRepositoryTest.kt:612-629`).
final class SummaryRepositoryFixture: @unchecked Sendable {
    let aiClient = FakeAiClient()
    let summaryDao = FakeAiSummaryDao()
    let premiumRepository = FakePremiumRepository()
    let reader = FakeHealthPeriodReader(recordDays: 3)
    let clock = FixedSalusClock(now: Date(epochMilliseconds: nowEpochMs), timeZone: utc)
    let usage: AiUsageDataSource

    /// 2026-08-20 — an arbitrary but realistic epoch day.
    let today = 20685
    let weekStart = 20685 - 6

    let dailyLimit = 5
    let weeklyMinimumDays = 3
    let monthlyMinimumDays = 7
    let modelText = "Your blood pressure stayed in range this week."
    let cachedText = "A summary generated yesterday."

    static let nowEpochMs: Int64 = 20685 * 86_400_000 + 12 * 3_600_000
    let cachedAtEpochMs: Int64 = 20685 * 86_400_000 + 12 * 3_600_000 - 86_400_000

    // A missing tz database entry must fail loudly rather than fall back to some other zone.
    // swiftlint:disable force_unwrapping
    static let utc = TimeZone(secondsFromGMT: 0)!
    // swiftlint:enable force_unwrapping

    init() {
        let suiteName = "salus-ai-test-\(UUID().uuidString)"
        // A named suite is the `UserDefaults` twin of JUnit's `TemporaryFolder`: fresh per test,
        // wiped when the suite goes away. The lookup is failable and this package's tests carry no
        // force unwrap (`CLAUDE.md`), so a refusal falls back to the standard suite.
        usage = AiUsageDataSource(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
    }

    func repository() -> AiSummaryRepository {
        AiSummaryRepositoryImpl(
            aiClient: aiClient,
            aggregator: reader,
            summaryDao: summaryDao,
            usageDataSource: usage,
            premiumRepository: premiumRepository,
            clock: clock
        )
    }

    /// Three recorded days — the weekly minimum — so gate 2 lets the request through.
    func givenEnoughDataForAWeek() {
        givenStats(distinctRecordDays: weeklyMinimumDays)
    }

    /// Seven recorded days — the monthly minimum.
    func givenEnoughDataForAMonth() {
        givenStats(distinctRecordDays: monthlyMinimumDays)
    }

    func givenStats(distinctRecordDays: Int) {
        reader.setRecordDays(distinctRecordDays)
    }

    func cachedEntity() -> AiSummaryRecord {
        AiSummaryRecord(
            periodType: "WEEKLY",
            startEpochDay: weekStart,
            endEpochDay: today,
            language: "tr",
            text: cachedText,
            createdAtEpochMs: cachedAtEpochMs
        )
    }
}

extension AsyncStream {
    /// The stream's current value — the twin of Kotlin's `flow.first()`.
    func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}
