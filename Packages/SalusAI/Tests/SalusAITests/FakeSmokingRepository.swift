import Foundation
import SalusSmoking

// Twin of Android's `FakeSmokingRepository` in `core/ai/src/test`. The real repository's streams
// are non-throwing, so a storage failure is modelled the way it really arrives: the stream ends
// without a single element.

final class FakeSmokingRepository: SmokingRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var current: SmokingInput = notSetUp
    private var failing = false

    static let notSetUp = SmokingInput(plan: nil, prices: [], attempts: [], events: [], goal: nil)

    var input: SmokingInput {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    /// True makes every read end without an element, as a failed read does.
    var failsToRead: Bool {
        get { lock.withLock { failing } }
        set { lock.withLock { failing = newValue } }
    }

    func observeInput() -> AsyncStream<SmokingInput> {
        let shouldFail = failsToRead
        let snapshot = input
        return AsyncStream { continuation in
            if !shouldFail {
                continuation.yield(snapshot)
            }
            continuation.finish()
        }
    }

    func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        AsyncStream { $0.finish() }
    }

    func snapshotNow() async -> SmokingSnapshot {
        .notSetUp
    }
}

/// Builders for the smoking inputs these tests feed the aggregator.
enum SmokingFixture {
    static let dayMs: Int64 = 86_400_000
    static let hourMs: Int64 = 3_600_000

    static func plan(
        mode: SmokingMode = .quit,
        reason: String? = nil,
        createdAtEpochDay: Int64
    ) -> SmokingPlan {
        SmokingPlan(
            id: "plan",
            mode: mode,
            productType: .cigarette,
            baselineUnitsPerDay: 10,
            dailyLimit: mode == .reduce ? 6 : nil,
            currencyCode: "TRY",
            reason: reason,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: createdAtEpochDay * dayMs,
            tzId: "UTC"
        )
    }

    static func smoked(
        _ id: String,
        epochDay: Int64,
        hour: Int64 = 12,
        trigger: CravingTrigger? = nil
    ) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: .smoked,
            occurredAtMs: epochDay * dayMs + hour * hourMs,
            tzId: "UTC",
            epochDay: epochDay,
            units: 1,
            trigger: trigger,
            intensity: nil,
            productType: .cigarette,
            attemptId: nil
        )
    }

    static func input(plan: SmokingPlan?, events: [SmokingEvent] = []) -> SmokingInput {
        SmokingInput(plan: plan, prices: [], attempts: [], events: events, goal: nil)
    }
}
