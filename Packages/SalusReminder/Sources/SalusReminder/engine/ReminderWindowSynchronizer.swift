// Ported from Android
// `core/reminder/src/main/kotlin/.../engine/ReminderWindowSynchronizer.kt`.
//
// The algorithm, the ordering of its phases and the occurrence identity are Kotlin's, verbatim.
// Five things differ, all of them forced by iOS having **no code of ours running at fire time**
// (Android runs a BroadcastReceiver; a `UNNotificationRequest` is presented by the OS alone):
//
//  1. The content is baked HERE, at sync time, by asking the handler. A `nil` answer means the
//     occurrence stopped being relevant, and it is cancelled instead of scheduled.
//  2. Every desired occurrence is re-`schedule`d on every pass. Adding a request under an
//     identifier the centre already holds replaces it, so a re-bake refreshes stale text (a
//     renamed medication) without disturbing anything. That also subsumes delta 5: a request the
//     OS dropped comes back on the next sync without a special branch. Idempotence therefore
//     holds *by identity* — same ledger rows, same pending identifiers — rather than by call
//     count, which is the one place the ported Kotlin test asserts something different.
//  3. A past-due `SCHEDULED` row is `FIRED` when notifications are authorized and `MISSED` when
//     they are not. Android knows because its receiver writes `FIRED`; iOS can only ask whether
//     the OS was *allowed* to present it. Delivered-then-dismissed is indistinguishable from
//     delivered-and-read, and both are `FIRED`.
//  4. Cancellation is batched, because the notification centre's own API is.
//  5. `sync()` does not throw. Its callers — a background task and `requestSync()` — have nobody
//     to report to, so a failure is absorbed and the next pass reconciles from wherever this one
//     stopped. Kotlin's `suspend fun sync()` propagates to WorkManager, which retries the worker.
//
// This type reads `SalusDatabase` records directly rather than through a repository, which is the
// one place in the tree that happens. It is not a leak: the ledger has no domain type — it *is*
// the engine's own bookkeeping — and Android's synchronizer holds `ReminderAlarmDao` for the same
// reason (`:core:reminder` depends on `:core:database`).

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel

/// The heart of the reminder engine: reconciles the `reminder_alarms` ledger and the OS's pending
/// notifications against what the feature handlers currently want, inside a rolling window.
///
/// Only the next ``ReminderWindowConfig/window`` / ``ReminderWindowConfig/maxOccurrences``
/// occurrences are materialized. The window refills when a feature calls
/// ``ReminderScheduler/requestSync()``, on the background refresh task, and after
/// launch/time/timezone/permission changes.
public final class ReminderWindowSynchronizer: Sendable {
    /// How long a finished row is kept before it is purged (`ReminderWindowSynchronizer.kt:94`).
    /// Unlike the window it is not a point of variation between the platforms, so it stays a
    /// constant rather than joining ``ReminderWindowConfig``.
    public static let retention: TimeInterval = 30 * 24 * 60 * 60

    private let dao: ReminderAlarmDao
    private let gateway: any NotificationGateway
    private let handlerRegistry: ReminderHandlerRegistry
    private let environment: any ReminderEnvironment
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator
    private let config: ReminderWindowConfig

    public init(
        dao: ReminderAlarmDao,
        gateway: any NotificationGateway,
        handlerRegistry: ReminderHandlerRegistry,
        environment: any ReminderEnvironment,
        clock: any SalusClock,
        idGenerator: any IdGenerator,
        config: ReminderWindowConfig
    ) {
        self.dao = dao
        self.gateway = gateway
        self.handlerRegistry = handlerRegistry
        self.environment = environment
        self.clock = clock
        self.idGenerator = idGenerator
        self.config = config
    }

    /// One full reconciliation pass. Safe to call as often as a feature likes.
    public func sync() async {
        do {
            try await reconcile()
        } catch {
            // Delta 5 of the header: there is no caller to report to. Whatever committed before
            // the failure is consistent on its own — every write below is a single-row statement
            // that either happened or did not — and the next pass reconciles from there.
        }
    }

    private func reconcile() async throws {
        let now = clock.now()
        let nowMs = now.epochMilliseconds
        let windowEnd = now.addingTimeInterval(config.window)

        let desired = try await desiredOccurrences(from: now, until: windowEnd)
        let scheduled = try await dao.getScheduled()

        // A SCHEDULED row in the past means the reminder's moment came and went while this pass
        // was not running — nothing of ours observed it either way.
        let stale = scheduled.filter { $0.triggerAtEpochMs < nowMs }
        let active = scheduled.filter { $0.triggerAtEpochMs >= nowMs }
        try await settle(stale: stale)

        let desiredIdentities = Set(desired.map(\.identity))
        // Kotlin's `associateBy` keeps the last entry for a duplicate key; Swift traps unless the
        // tie-break is spelled out, so it is spelled out to say the same thing.
        let activeByIdentity = Dictionary(
            active.map { (Self.identity(of: $0), $0) },
            uniquingKeysWith: { _, last in last }
        )

        // Occurrences the features no longer want (entity deleted, schedule edited).
        try await cancel(unwanted: active.filter { !desiredIdentities.contains(Self.identity(of: $0)) })

        let pending = await gateway.pendingRequestCodes()
        for entry in desired {
            try await materialize(entry, existing: activeByIdentity[entry.identity], pending: pending)
        }

        try await dao.purgeFinishedBefore(now.addingTimeInterval(-Self.retention).epochMilliseconds)
    }

    /// Everything the handlers want inside `[from, until)`, earliest first, capped.
    private func desiredOccurrences(from: Date, until: Date) async throws -> [DesiredOccurrence] {
        var collected: [DesiredOccurrence] = []
        for handler in handlerRegistry.all {
            let occurrences = try await handler.occurrencesBetween(from: from, until: until)
            collected += occurrences
                .filter { $0.triggerAt >= from && $0.triggerAt < until }
                .map { DesiredOccurrence(handler: handler, occurrence: $0) }
        }

        // The cap is applied to the sorted list, so which of two occurrences sharing an instant
        // survives it depends on the sort being stable. Kotlin's `sortedBy` is; Swift's
        // `sorted(by:)` promises nothing, hence the explicit index tie-break.
        return collected.enumerated()
            .sorted { lhs, rhs in
                lhs.element.occurrence.triggerAt == rhs.element.occurrence.triggerAt
                    ? lhs.offset < rhs.offset
                    : lhs.element.occurrence.triggerAt < rhs.element.occurrence.triggerAt
            }
            .prefix(config.maxOccurrences)
            .map(\.element)
    }

    /// Closes out past-due rows. See delta 3 of the header for why the state is a question about
    /// the authorization rather than about the ledger.
    private func settle(stale: [ReminderAlarmRecord]) async throws {
        guard !stale.isEmpty else { return }

        let state: AlarmState = await environment.notificationsAuthorized() ? .fired : .missed
        await gateway.cancel(requestCodes: stale.map(Self.code(of:)))
        for row in stale {
            try await dao.updateState(id: row.id, newState: state.rawValue)
        }
    }

    private func cancel(unwanted rows: [ReminderAlarmRecord]) async throws {
        guard !rows.isEmpty else { return }

        await gateway.cancel(requestCodes: rows.map(Self.code(of:)))
        for row in rows {
            try await dao.updateState(id: row.id, newState: AlarmState.cancelled.rawValue)
        }
    }

    private func materialize(
        _ entry: DesiredOccurrence,
        existing: ReminderAlarmRecord?,
        pending: Set<Int32>
    ) async throws {
        let requestCode = Self.requestCode(of: entry.ref)
        guard let content = try await entry.handler.notificationContent(for: entry.ref) else {
            // The withdrawn occurrence keeps the cap slot it was given. The cap is over what the
            // handlers *asked for*, which is the number Android caps too; back-filling it would
            // mean a second pass over the tail for a case that means "the entity behind this is
            // gone", and the next sync no longer asks for it at all.
            try await withdraw(existing: existing, requestCode: requestCode, pending: pending)
            return
        }

        let triggerMs = entry.occurrence.triggerAt.epochMilliseconds
        let row = try await ledgerRow(for: entry, existing: existing, requestCode: requestCode, triggerMs: triggerMs)

        try await dao.upsert(row)
        // Unconditional, including when nothing at all changed — delta 2 of the header.
        try await gateway.schedule(
            requestCode: Self.code(of: row),
            triggerAt: entry.occurrence.triggerAt,
            content: content,
            ref: entry.ref
        )
    }

    /// The ledger row this occurrence belongs in: the live one, a finished one resurrected, or a
    /// new one.
    private func ledgerRow(
        for entry: DesiredOccurrence,
        existing: ReminderAlarmRecord?,
        requestCode: Int32,
        triggerMs: Int64
    ) async throws -> ReminderAlarmRecord {
        if let existing {
            if existing.triggerAtEpochMs != triggerMs {
                // Same occurrence, new wall-clock instant (time/timezone change, edit).
                await gateway.cancel(requestCodes: [Self.code(of: existing)])
            }
            return Self.scheduled(existing, at: triggerMs)
        }

        // Reuse a finished row for the same occurrence (e.g. previously CANCELLED and now wanted
        // again) — the unique request_code index forbids a second row anyway.
        let finished = try await dao.getByOccurrence(
            type: entry.ref.type.rawValue,
            entityId: entry.occurrence.entityId,
            occurrenceKey: entry.occurrence.occurrenceKey
        )
        if let finished {
            return Self.scheduled(finished, at: triggerMs)
        }

        return ReminderAlarmRecord(
            id: idGenerator.newId(),
            type: entry.ref.type.rawValue,
            entityId: entry.occurrence.entityId,
            occurrenceKey: entry.occurrence.occurrenceKey,
            triggerAtEpochMs: triggerMs,
            requestCode: Int(requestCode),
            state: AlarmState.scheduled.rawValue
        )
    }

    /// A desired occurrence whose handler answered `nil`: it is still on the schedule, but the
    /// feature no longer recognizes it, so nothing may reach the user for it.
    private func withdraw(
        existing: ReminderAlarmRecord?,
        requestCode: Int32,
        pending: Set<Int32>
    ) async throws {
        if let existing {
            await gateway.cancel(requestCodes: [Self.code(of: existing)])
            try await dao.updateState(id: existing.id, newState: AlarmState.cancelled.rawValue)
        } else if pending.contains(requestCode) {
            // No ledger row, yet the centre is still holding the request: reconcile against
            // reality, or it would present text the feature has disowned.
            await gateway.cancel(requestCodes: [requestCode])
        }
    }

    // MARK: - Identity

    /// The request code for one occurrence, derived — never stored — so it is recomputable after
    /// the process dies, which is what makes cancellation correct (`ReminderWindowSynchronizer.kt:97`).
    public static func requestCode(of ref: ReminderRef) -> Int32 {
        requestCode(type: ref.type.rawValue, entityId: ref.entityId, occurrenceKey: ref.occurrenceKey)
    }

    /// The same derivation from a persisted type name — the shape a ledger row or a fired
    /// notification arrives in (`ReminderWindowSynchronizer.kt:99-100`).
    public static func requestCode(type: String, entityId: String, occurrenceKey: String) -> Int32 {
        javaStringHash(identity(type: type, entityId: entityId, occurrenceKey: occurrenceKey))
    }

    private static func identity(type: String, entityId: String, occurrenceKey: String) -> String {
        "\(type)|\(entityId)|\(occurrenceKey)"
    }

    private static func identity(of row: ReminderAlarmRecord) -> String {
        identity(type: row.type, entityId: row.entityId, occurrenceKey: row.occurrenceKey)
    }

    /// `java.lang.String.hashCode()`, which is what Kotlin's `String.hashCode()` is on the JVM and
    /// what `requestCodeOf` returns: `h = 31 * h + unit` over the **UTF-16 code units**, in 32-bit
    /// two's-complement arithmetic that wraps rather than trapping.
    ///
    /// Both halves of that sentence are load-bearing. Swift's own `hashValue` is seeded per process
    /// and would answer differently on every launch; iterating `Character`s or Unicode scalars
    /// instead of `utf16` would answer differently for anything outside the BMP, where Java hashes
    /// the surrogate pair. The two platforms have to derive the same identifier forever, so this is
    /// pinned by `requestCodesMatchTheKotlinStringHash`.
    private static func javaStringHash(_ value: String) -> Int32 {
        var hash: Int32 = 0
        for unit in value.utf16 {
            hash = hash &* 31 &+ Int32(unit)
        }
        return hash
    }

    private static func code(of row: ReminderAlarmRecord) -> Int32 {
        Int32(truncatingIfNeeded: row.requestCode)
    }

    private static func scheduled(_ row: ReminderAlarmRecord, at triggerAtEpochMs: Int64) -> ReminderAlarmRecord {
        ReminderAlarmRecord(
            id: row.id,
            type: row.type,
            entityId: row.entityId,
            occurrenceKey: row.occurrenceKey,
            triggerAtEpochMs: triggerAtEpochMs,
            requestCode: row.requestCode,
            state: AlarmState.scheduled.rawValue
        )
    }

    /// One occurrence a handler wants, kept next to the handler that wants it so the content can be
    /// baked from the same object the window came from.
    private struct DesiredOccurrence {
        let handler: any ReminderHandler
        let occurrence: ReminderOccurrence

        var ref: ReminderRef {
            ReminderRef(
                type: handler.type,
                entityId: occurrence.entityId,
                occurrenceKey: occurrence.occurrenceKey
            )
        }

        var identity: String {
            ReminderWindowSynchronizer.identity(
                type: handler.type.rawValue,
                entityId: occurrence.entityId,
                occurrenceKey: occurrence.occurrenceKey
            )
        }
    }
}
