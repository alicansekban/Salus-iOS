import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting

@testable import SalusSmoking

// Twin of Android's `SmokingTestEnv`: one in-memory database, one fixed clock and sequential ids
// ("id-1", "id-2", ...), with the whole module built over them. Nothing here reads the wall clock.

/// Hands out "id-1", "id-2", ... so an assertion can name the row a use case wrote.
final class SequentialSmokingIds: IdGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0

    func newId() -> String {
        lock.withLock {
            next += 1
            return "id-\(next)"
        }
    }
}

/// Counts how often the store told its listeners about a committed write.
final class NotificationCounter: SmokingChangeListener, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func smokingDataChanged() {
        lock.withLock { count += 1 }
    }
}

let istanbulZone = FixedSalusClock.defaultZone

/// The instant of a local wall-clock reading, written `2026-03-10T12:00`, in `zone`.
func ms(_ local: String, _ zone: TimeZone = istanbulZone) -> Int64 {
    let parts = local.split { "-T:".contains($0) }.compactMap { Int($0) }
    precondition(parts.count == 5, "expected yyyy-MM-ddTHH:mm, got \(local)")
    let date = LocalDate(year: parts[0], month: parts[1], day: parts[2])
    return LocalDateTime(date: date, minuteOfDay: parts[3] * 60 + parts[4]).instant(in: zone).epochMilliseconds
}

/// The epoch day of a `yyyy-MM-dd` date.
func day(_ date: String) -> Int64 {
    let parts = date.split(separator: "-").compactMap { Int($0) }
    precondition(parts.count == 3, "expected yyyy-MM-dd, got \(date)")
    return Int64(LocalDate(year: parts[0], month: parts[1], day: parts[2]).epochDay)
}

final class SmokingTestEnv: @unchecked Sendable {
    let database: SalusDatabase
    let dao: SmokingDao
    let clock: FixedSalusClock
    let ids = SequentialSmokingIds()
    let notifications = NotificationCounter()
    let module: SmokingCoreModule

    var repository: any SmokingRepository {
        module.repository
    }

    init(nowLocal: String = "2026-03-10T12:00", zone: TimeZone = istanbulZone, listenerBound: Bool = true) throws {
        clock = FixedSalusClock(now: Date(epochMilliseconds: ms(nowLocal, zone)), timeZone: zone)
        database = try SalusDatabase.inMemory(clock: clock)
        dao = SmokingDao(database: database)
        module = SmokingCoreModule(smokingDao: dao, clock: clock, idGenerator: ids)
        if listenerBound {
            module.changeListeners.add(notifications)
        }
    }

    /// Moves "now" (and optionally the zone), the twin of `SmokingTestEnv.at`.
    func at(_ local: String, _ zone: TimeZone? = nil) {
        let target = zone ?? clock.timeZone()
        clock.moveToZone(target)
        clock.advanceTo(Date(epochMilliseconds: ms(local, target)))
    }

    /// The rows as the repository serves them (the repair has already run).
    func input() async throws -> SmokingInput {
        for await input in repository.observeInput() {
            return input
        }
        throw SmokingTestEnvError.streamEnded
    }

    /// A QUIT plan of 10 a day at 5 000 minor per unit, quit at `quitLocal`.
    func quitSetUp(_ quitLocal: String = "2026-03-01T08:00") async throws {
        try await module.setUp(
            mode: .quit,
            productType: .cigarette,
            baselineUnitsPerDay: 10,
            price: .perUnit(5000),
            currencyCode: "TRY",
            quitAtMs: ms(quitLocal)
        )
    }

    /// A REDUCE plan of 10 a day with a limit of 8.
    func reduceSetUp() async throws {
        try await module.setUp(
            mode: .reduce,
            productType: .cigarette,
            baselineUnitsPerDay: 10,
            price: .perUnit(5000),
            currencyCode: "TRY",
            dailyLimit: 8
        )
    }
}

enum SmokingTestEnvError: Error {
    case streamEnded
}
