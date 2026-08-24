// Ported 1:1 from `core/database/src/main/kotlin/com/alicansekban/salus/core/database/dao/VitalsDao.kt`.
//
// Conventions — the plain struct over the database, the `@Query` strings carried verbatim — are
// `ProfileDao`'s; its doc comments explain why each of them is what it is, and are not repeated
// here. The `AsyncThrowingStream` standing in for Room's `Flow` comes from `conflatedStream`,
// which is where that decision is written down.
//
// The one thing worth naming again: `BETWEEN` is inclusive at both ends, so the window a caller
// asks for is closed on both sides. That is the Kotlin semantics, not a rounding of it.

import GRDB

/// Reads and writes vitals measurements — weight, blood pressure and blood glucose share one
/// table, told apart by `type` (`VitalsMeasurementRecord`).
public struct VitalsDao: Sendable {
    private let database: SalusDatabase

    public init(database: SalusDatabase) {
        self.database = database
    }

    /// `VitalsDao.kt:12-13`.
    public func upsert(_ measurement: VitalsMeasurementRecord) async throws {
        try await database.writer.write { db in
            try measurement.upsert(db)
        }
    }

    /// `VitalsDao.kt:15-16`.
    public func getById(_ id: String) async throws -> VitalsMeasurementRecord? {
        try await database.reader.read { db in
            try VitalsMeasurementRecord.fetchOne(
                db,
                sql: "SELECT * FROM vitals_measurements WHERE id = ?",
                arguments: [id]
            )
        }
    }

    /// One profile's measurements of one type inside a closed time window, oldest first
    /// (`VitalsDao.kt:18-31`).
    public func observeRange(
        profileId: String,
        type: String,
        fromEpochMs: Int64,
        untilEpochMs: Int64
    ) -> AsyncThrowingStream<[VitalsMeasurementRecord], any Error> {
        let observation = ValueObservation.tracking { db in
            try VitalsMeasurementRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM vitals_measurements
                WHERE profile_id = ? AND type = ?
                    AND measured_at_epoch_ms BETWEEN ? AND ?
                ORDER BY measured_at_epoch_ms ASC
                """,
                arguments: [profileId, type, fromEpochMs, untilEpochMs]
            )
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// The newest measurement of one type, or none (`VitalsDao.kt:33-41`).
    public func observeLatest(
        profileId: String,
        type: String
    ) -> AsyncThrowingStream<VitalsMeasurementRecord?, any Error> {
        let observation = ValueObservation.tracking { db in
            try VitalsMeasurementRecord.fetchOne(
                db,
                sql: """
                SELECT * FROM vitals_measurements
                WHERE profile_id = ? AND type = ?
                ORDER BY measured_at_epoch_ms DESC
                LIMIT 1
                """,
                arguments: [profileId, type]
            )
        }
        return conflatedStream(observation.values(in: database.reader))
    }

    /// Every type at once, for callers that summarise a whole period and would otherwise pay one
    /// round trip per type (`VitalsDao.kt:43-57`).
    public func getMeasurementsBetween(
        profileId: String,
        fromEpochMs: Int64,
        untilEpochMs: Int64
    ) async throws -> [VitalsMeasurementRecord] {
        try await database.reader.read { db in
            try VitalsMeasurementRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM vitals_measurements
                WHERE profile_id = ?
                    AND measured_at_epoch_ms BETWEEN ? AND ?
                ORDER BY measured_at_epoch_ms ASC
                """,
                arguments: [profileId, fromEpochMs, untilEpochMs]
            )
        }
    }

    /// `VitalsDao.kt:59-60`.
    public func deleteById(_ id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM vitals_measurements WHERE id = ?", arguments: [id])
        }
    }
}
