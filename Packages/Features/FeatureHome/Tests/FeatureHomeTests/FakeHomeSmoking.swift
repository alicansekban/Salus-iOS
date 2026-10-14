// The Swift twin of Android's `FakeSmokingStore` / `SmokingTestSupport` pair
// (`feature/home/src/test/.../FakeSmokingStore.kt`), cut to what the Home card reads and writes:
// a snapshot that can change, the "+1" write that returns an event id, and the delete by id.
//
// Like `FakeTodayRepository`, the current value is replayed to every new subscription (a
// `restartObservation()` opens a second one), and the lock discipline is the same: mutate and copy
// the observers out under the lock, yield after releasing it, because a continuation's
// `onTermination` takes the same lock.

import Foundation
import SalusModel
import SalusSmoking

@testable import FeatureHome

/// The write failing the way a refused use case does.
struct FakeSmokingWriteFailure: Error {}

final class FakeHomeSmoking: HomeSmoking, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: SmokingSnapshot
    private var observers: [UUID: @Sendable (SmokingSnapshot) -> Void] = [:]
    private var loggedAtMs: [Int64] = []
    private var deletedIds: [String] = []
    private var failNextLog = false
    private var failNextDelete = false
    /// Resumed by ``releaseLogs()``; while the gate is armed a log call suspends, so a second tap can
    /// arrive while the first write is still in flight.
    private var logGates: [CheckedContinuation<Void, Never>] = []
    private var gateArmed = false

    init(_ snapshot: SmokingSnapshot = .notSetUp) {
        self.snapshot = snapshot
    }

    /// Every instant a "+1" was written at, in order.
    var logged: [Int64] {
        lock.withLock { loggedAtMs }
    }

    /// Every event id a delete was asked for, in order.
    var deleted: [String] {
        lock.withLock { deletedIds }
    }

    func set(_ newValue: SmokingSnapshot) {
        let publishers = lock.withLock { () -> [@Sendable (SmokingSnapshot) -> Void] in
            snapshot = newValue
            return Array(observers.values)
        }
        for publish in publishers {
            publish(newValue)
        }
    }

    func refuseNextLog() {
        lock.withLock { failNextLog = true }
    }

    func refuseNextDelete() {
        lock.withLock { failNextDelete = true }
    }

    /// Makes the next log call suspend until ``releaseLogs()``.
    func holdLogs() {
        lock.withLock { gateArmed = true }
    }

    func releaseLogs() {
        // Every suspended call is resumed, not only the latest: a guard that failed to drop the
        // second tap would otherwise strand the first and still count one write.
        let waiting = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            gateArmed = false
            defer { logGates = [] }
            return logGates
        }
        for continuation in waiting {
            continuation.resume()
        }
    }

    func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = UUID()
            let current = lock.withLock { () -> SmokingSnapshot in
                observers[token] = { value in continuation.yield(value) }
                return snapshot
            }
            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.observers.removeValue(forKey: token) }
            }
        }
    }

    func logOneSmoked(atMs: Int64) async throws -> String {
        let (fail, hold) = lock.withLock { () -> (Bool, Bool) in
            defer { failNextLog = false }
            return (failNextLog, gateArmed)
        }
        if hold {
            await withCheckedContinuation { continuation in
                lock.withLock { logGates.append(continuation) }
            }
        }
        if fail {
            throw FakeSmokingWriteFailure()
        }
        return lock.withLock {
            loggedAtMs.append(atMs)
            return "evt-\(loggedAtMs.count)"
        }
    }

    func deleteEvent(eventId: String) async throws {
        let fail = lock.withLock { () -> Bool in
            defer { failNextDelete = false }
            return failNextDelete
        }
        if fail {
            throw FakeSmokingWriteFailure()
        }
        lock.withLock { deletedIds.append(eventId) }
    }
}

/// Snapshot builders for the Home card cases, with only the fields the card reads varying.
enum HomeSmokingFixture {
    static let day: Int64 = 86_400_000

    private static func plan(mode: SmokingMode, limit: Int64?, currency: String = "TRY") -> SmokingPlan {
        SmokingPlan(
            id: "plan",
            mode: mode,
            productType: .cigarette,
            baselineUnitsPerDay: 20,
            dailyLimit: limit,
            currencyCode: currency,
            reason: nil,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: 0,
            tzId: "Europe/Istanbul"
        )
    }

    static func quit(
        elapsedMs: Int64 = 42 * day + 5 * 3_600_000,
        savedMinor: Int64 = 315_000,
        currency: String = "TRY",
        nextStage: StageProgress? = StageProgress(
            stageId: "s5",
            state: .inProgress,
            permille: 700,
            remainingMs: 3 * day,
            countingAgain: false
        )
    ) -> SmokingSnapshot {
        .quit(QuitSnapshot(
            plan: plan(mode: .quit, limit: nil, currency: currency),
            attemptId: "att-1",
            attemptStartedAtMs: 0,
            attemptElapsedMs: elapsedMs,
            sinceLastSmokeMs: elapsedMs,
            slipCount: 0,
            unitsNotSmoked: 840,
            unitsNotSmokedToday: 10,
            savedMinor: savedMinor,
            timeRegainedMinutes: nil,
            cravingsBeaten: 0,
            cravingsBeatenAllTime: 0,
            stages: [],
            nextStage: nextStage,
            attempts: [],
            goal: nil
        ))
    }

    static func reduce(today: Int64, limit: Int64) -> SmokingSnapshot {
        .reduce(ReduceSnapshot(
            plan: plan(mode: .reduce, limit: limit),
            todayEpochDay: 20680,
            todayUnits: today,
            todayHasEntry: today > 0,
            dailyLimit: limit,
            last7Days: [],
            weekReductionUnits: 0,
            weekSavedMinor: 0,
            savedSinceSetupMinor: 0,
            cravingsBeatenAllTime: 0,
            stagesPreview: [],
            goal: nil
        ))
    }
}
