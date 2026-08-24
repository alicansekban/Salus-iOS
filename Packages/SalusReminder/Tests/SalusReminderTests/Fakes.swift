// Ported from Android
// `core/reminder/src/test/kotlin/com/alicansekban/salus/core/reminder/engine/Fakes.kt`.
//
// Two of Kotlin's five fakes are gone on purpose. `FixedClock` is `SalusTesting`'s
// `FixedSalusClock`, which the whole tree already injects, and `FakeReminderAlarmDao` is not
// needed at all: `SalusDatabase.inMemory` gives the synchronizer tests the **real** `ReminderAlarmDao`
// and its real SQL, so the ledger assertions below prove the queries the engine actually runs
// rather than a second hand-written implementation of them.
//
// The remaining fakes are classes with a lock rather than Kotlin's plain `var`s: `ReminderHandler`,
// `NotificationGateway` and `ReminderEnvironment` are all `Sendable`, and a fake a test mutates
// between `sync()` calls is mutable state. The lock is what makes the unchecked promise true —
// the same trade `FixedSalusClock` makes, and for the same reason (the protocols declare
// non-`async` members that an actor could not provide).

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting

@testable import SalusReminder

/// One `NotificationGateway.schedule` call, kept whole so a test can assert the baked content.
struct ScheduledNotification: Equatable {
    let requestCode: Int32
    let triggerAt: Date
    let content: ReminderNotificationContent
    let ref: ReminderRef
}

/// `Fakes.kt:26-31` — ids a test can predict.
final class SequentialIdGenerator: IdGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0

    func newId() -> String {
        lock.withLock {
            defer { next += 1 }
            return "id-\(next)"
        }
    }
}

/// The iOS twin of `RecordingAlarmGateway` (`Fakes.kt:70-82`), widened the way
/// `NotificationGateway` is: it records the baked content, takes cancellations in batches, and
/// keeps a `pending` set so `pendingRequestCodes()` answers what an OS notification centre would.
final class RecordingNotificationGateway: NotificationGateway, @unchecked Sendable {
    private let lock = NSLock()
    private var scheduled: [ScheduledNotification] = []
    private var cancelled: [Int32] = []
    private var pending: Set<Int32> = []

    /// Every schedule call, in order — the twin of `scheduleCalls`.
    var scheduleCalls: [ScheduledNotification] { lock.withLock { scheduled } }

    /// Every cancelled request code, flattened out of the batches — the twin of `cancelCalls`.
    var cancelCalls: [Int32] { lock.withLock { cancelled } }

    func schedule(
        requestCode: Int32,
        triggerAt: Date,
        content: ReminderNotificationContent,
        ref: ReminderRef
    ) async throws {
        lock.withLock {
            scheduled.append(
                ScheduledNotification(requestCode: requestCode, triggerAt: triggerAt, content: content, ref: ref)
            )
            // Adding a request with an identifier the centre already holds replaces it, so the
            // pending set is a set: re-scheduling the same occurrence adds nothing.
            pending.insert(requestCode)
        }
    }

    func cancel(requestCodes: [Int32]) async {
        lock.withLock {
            cancelled += requestCodes
            pending.subtract(requestCodes)
        }
    }

    func pendingRequestCodes() async -> Set<Int32> {
        lock.withLock { pending }
    }

    /// The OS dropped a pending request without telling anyone — what the reconciliation against
    /// `pendingRequestCodes()` exists for. Not a cancellation: `cancelCalls` stays untouched.
    func evictFromPending(_ requestCode: Int32) {
        lock.withLock { _ = pending.remove(requestCode) }
    }
}

/// `Fakes.kt:84-97`, plus the iOS content seam: `notificationContent` is what the synchronizer
/// bakes at sync time, and a test sets it to nil to say the occurrence stopped being relevant.
final class FakeReminderHandler: ReminderHandler, @unchecked Sendable {
    let type: ReminderType

    private let lock = NSLock()
    private var storedOccurrences: [ReminderOccurrence] = []
    private var storedContent: ReminderNotificationContent? =
        ReminderNotificationContent(title: "title", text: "text")

    init(type: ReminderType = .medicationDose) {
        self.type = type
    }

    var occurrences: [ReminderOccurrence] {
        get { lock.withLock { storedOccurrences } }
        set { lock.withLock { storedOccurrences = newValue } }
    }

    var content: ReminderNotificationContent? {
        get { lock.withLock { storedContent } }
        set { lock.withLock { storedContent = newValue } }
    }

    func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
        occurrences.filter { $0.triggerAt >= from && $0.triggerAt < until }
    }

    func notificationContent(for _: ReminderRef) async throws -> ReminderNotificationContent? {
        content
    }
}

/// Android has no twin: its `ReminderEnvironment` answers about exact-alarm and battery
/// permissions, which the synchronizer never reads. On iOS the notification authorization decides
/// whether a past-due row is `FIRED` or `MISSED`, so it has to be settable.
final class FakeReminderEnvironment: ReminderEnvironment, @unchecked Sendable {
    private let lock = NSLock()
    private var authorized: Bool
    private var alarmKit: Bool
    private var backgroundRefresh: Bool

    init(
        isNotificationsAuthorized: Bool = true,
        isAlarmKitAuthorized: Bool = true,
        isBackgroundRefreshAvailable: Bool = true
    ) {
        authorized = isNotificationsAuthorized
        alarmKit = isAlarmKitAuthorized
        backgroundRefresh = isBackgroundRefreshAvailable
    }

    var isNotificationsAuthorized: Bool {
        get { lock.withLock { authorized } }
        set { lock.withLock { authorized = newValue } }
    }

    func notificationsAuthorized() async -> Bool {
        isNotificationsAuthorized
    }

    func alarmKitAuthorized() async -> Bool {
        lock.withLock { alarmKit }
    }

    func backgroundRefreshAvailable() -> Bool {
        lock.withLock { backgroundRefresh }
    }
}

/// Everything a synchronizer case injects, in one value: the **real** ledger over an in-memory
/// database, the recording gateway, a settable handler and environment, and the fixed clock the
/// whole tree uses. Shared by both synchronizer suites — the ported Kotlin cases and the iOS
/// deltas — which is also what keeps either of them readable in one screenful.
struct SynchronizerFixture {
    /// `ReminderWindowSynchronizerTest.kt:20` — 2025-08-24T02:26:40Z.
    static let baseNow = Date(epochMilliseconds: 1_756_000_000_000)

    let dao: ReminderAlarmDao
    let gateway = RecordingNotificationGateway()
    let handler = FakeReminderHandler()
    let environment = FakeReminderEnvironment()
    let clock: FixedSalusClock

    init() throws {
        let clock = FixedSalusClock(now: Self.baseNow, timeZone: .gmt)
        self.clock = clock
        dao = try ReminderAlarmDao(database: SalusDatabase.inMemory(clock: clock))
    }

    func makeSynchronizer(_ config: ReminderWindowConfig) -> ReminderWindowSynchronizer {
        ReminderWindowSynchronizer(
            dao: dao,
            gateway: gateway,
            handlerRegistry: ReminderHandlerRegistry(all: [handler]),
            environment: environment,
            clock: clock,
            idGenerator: SequentialIdGenerator(),
            config: config
        )
    }

    func occurrence(_ entityId: String, _ key: String, _ triggerAt: Date) -> ReminderOccurrence {
        ReminderOccurrence(entityId: entityId, occurrenceKey: key, triggerAt: triggerAt)
    }

    /// The whole ledger, soonest first. `ReminderAlarmDao` has no "select everything" query and
    /// Room does not declare one either, so the suites read it back through the queries that exist,
    /// over the two entity ids these cases write.
    func ledger() async throws -> [ReminderAlarmRecord] {
        var rows: [ReminderAlarmRecord] = []
        for entityId in ["med-1", "med-2"] {
            rows += try await dao.getByEntity(type: ReminderType.medicationDose.rawValue, entityId: entityId)
        }
        return rows.sorted { $0.triggerAtEpochMs < $1.triggerAtEpochMs }
    }
}

/// Kotlin's cases are written in `2.hours` / `49.hours`; this is that spelling in the unit
/// `Foundation` measures an offset from a `Date` in.
extension TimeInterval {
    static func minutes(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 60
    }

    static func hours(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 60 * 60
    }

    static func days(_ count: Int) -> TimeInterval {
        TimeInterval(count) * 24 * 60 * 60
    }
}
