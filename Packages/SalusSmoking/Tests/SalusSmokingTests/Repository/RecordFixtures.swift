import SalusDatabase

// Raw rows for the tests that must bypass the use cases: a plan written the way an older build
// (or a half-finished restore) would have left it, an entry stored without its attempt link.

enum SmokingPlanRecordFixture {
    static func plan(mode: String, createdAtMs: Int64) -> SmokingPlanRecord {
        SmokingPlanRecord(
            id: "plan",
            mode: mode,
            productType: "CIGARETTE",
            baselineUnitsPerDay: 10,
            dailyLimit: mode == "REDUCE" ? 8 : nil,
            currencyCode: "TRY",
            reason: nil,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: createdAtMs,
            tzId: "Europe/Istanbul"
        )
    }
}

enum SmokingEventRecordFixture {
    static func slip(id: String, atMs: Int64, attemptId: String?, epochDay: Int64 = 0) -> SmokingEventRecord {
        SmokingEventRecord(
            id: id,
            type: "SMOKED",
            occurredAtMs: atMs,
            tzId: "Europe/Istanbul",
            epochDay: epochDay,
            units: 1,
            trigger: nil,
            intensity: nil,
            productType: "CIGARETTE",
            attemptId: attemptId
        )
    }

    /// A "none today" marker row (zero units), optionally carrying an attempt link no use case would write.
    static func marker(id: String, atMs: Int64, epochDay: Int64, attemptId: String?) -> SmokingEventRecord {
        SmokingEventRecord(
            id: id,
            type: "SMOKED",
            occurredAtMs: atMs,
            tzId: "Europe/Istanbul",
            epochDay: epochDay,
            units: 0,
            trigger: nil,
            intensity: nil,
            productType: "CIGARETTE",
            attemptId: attemptId
        )
    }
}
