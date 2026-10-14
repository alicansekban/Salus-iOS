// Twin of `core/smoking/.../data/SmokingMappers.kt`: record <-> domain (contract §1). Enums are
// stored as their NAME, the same string the Android twin stores, so a value this build does not
// know is data corruption and throws rather than being guessed at.

import SalusDatabase

/// A stored enum value this build has no case for.
struct SmokingMappingError: Error, Equatable {
    let field: String
    let value: String
}

private func decode<E: RawRepresentable<String>>(_ type: E.Type, _ raw: String, field: String) throws -> E {
    guard let value = E(rawValue: raw) else {
        throw SmokingMappingError(field: field, value: raw)
    }
    return value
}

extension SmokingPlanRecord {
    func toDomain() throws -> SmokingPlan {
        try SmokingPlan(
            id: id,
            mode: decode(SmokingMode.self, mode, field: "smoking_plan.mode"),
            productType: decode(ProductType.self, productType, field: "smoking_plan.product_type"),
            baselineUnitsPerDay: Int64(baselineUnitsPerDay),
            dailyLimit: dailyLimit.map(Int64.init),
            currencyCode: currencyCode,
            reason: reason,
            notificationsEnabled: notificationsEnabled,
            eveningReminderEnabled: eveningReminderEnabled,
            createdAtMs: createdAtMs,
            tzId: tzId
        )
    }
}

extension SmokingPlan {
    func toRecord() -> SmokingPlanRecord {
        SmokingPlanRecord(
            id: id,
            mode: mode.rawValue,
            productType: productType.rawValue,
            baselineUnitsPerDay: Int(baselineUnitsPerDay),
            dailyLimit: dailyLimit.map(Int.init),
            currencyCode: currencyCode,
            reason: reason,
            notificationsEnabled: notificationsEnabled,
            eveningReminderEnabled: eveningReminderEnabled,
            createdAtMs: createdAtMs,
            tzId: tzId
        )
    }
}

extension SmokingPricePeriodRecord {
    func toDomain() throws -> PricePeriod {
        PricePeriod(id: id, effectiveFromEpochDay: effectiveFromEpochDay, unitCostMinor: unitCostMinor)
    }
}

extension PricePeriod {
    func toRecord() -> SmokingPricePeriodRecord {
        SmokingPricePeriodRecord(id: id, effectiveFromEpochDay: effectiveFromEpochDay, unitCostMinor: unitCostMinor)
    }
}

extension SmokingQuitAttemptRecord {
    func toDomain() throws -> QuitAttempt {
        try QuitAttempt(
            id: id,
            startedAtMs: startedAtMs,
            tzId: tzId,
            endedAtMs: endedAtMs,
            endReason: endReason.map { try decode(AttemptEndReason.self, $0, field: "smoking_quit_attempt.end_reason") }
        )
    }
}

extension QuitAttempt {
    func toRecord() -> SmokingQuitAttemptRecord {
        SmokingQuitAttemptRecord(
            id: id,
            startedAtMs: startedAtMs,
            tzId: tzId,
            endedAtMs: endedAtMs,
            endReason: endReason?.rawValue
        )
    }
}

extension SmokingEventRecord {
    func toDomain() throws -> SmokingEvent {
        try SmokingEvent(
            id: id,
            type: decode(SmokingEventType.self, type, field: "smoking_event.type"),
            occurredAtMs: occurredAtMs,
            tzId: tzId,
            epochDay: epochDay,
            units: units.map(Int64.init),
            trigger: trigger.map { try decode(CravingTrigger.self, $0, field: "smoking_event.trigger") },
            intensity: intensity,
            productType: decode(ProductType.self, productType, field: "smoking_event.product_type"),
            attemptId: attemptId
        )
    }
}

extension SmokingEvent {
    func toRecord() -> SmokingEventRecord {
        SmokingEventRecord(
            id: id,
            type: type.rawValue,
            occurredAtMs: occurredAtMs,
            tzId: tzId,
            epochDay: epochDay,
            units: units.map(Int.init),
            trigger: trigger?.rawValue,
            intensity: intensity,
            productType: productType.rawValue,
            attemptId: attemptId
        )
    }
}

extension SmokingSavingsGoalRecord {
    func toDomain() throws -> SavingsGoal {
        SavingsGoal(
            id: id,
            title: title,
            targetMinor: targetMinor,
            createdAtMs: createdAtMs,
            achievedAtMs: achievedAtMs
        )
    }
}

extension SavingsGoal {
    func toRecord() -> SmokingSavingsGoalRecord {
        SmokingSavingsGoalRecord(
            id: id,
            title: title,
            targetMinor: targetMinor,
            createdAtMs: createdAtMs,
            achievedAtMs: achievedAtMs
        )
    }
}
