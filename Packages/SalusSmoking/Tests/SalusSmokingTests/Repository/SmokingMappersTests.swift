import Testing

import SalusDatabase

@testable import SalusSmoking

private func sampleEvent(
    id: String = "e",
    type: SmokingEventType = .smoked,
    units: Int64? = 2,
    trigger: CravingTrigger? = nil,
    productType: ProductType = .cigarette,
    attemptId: String? = nil
) -> SmokingEvent {
    SmokingEvent(
        id: id,
        type: type,
        occurredAtMs: 10,
        tzId: "Europe/Istanbul",
        epochDay: 20000,
        units: units,
        trigger: trigger,
        intensity: units == nil ? nil : 4,
        productType: productType,
        attemptId: attemptId
    )
}

private func eventRecord(type: String = "SMOKED", trigger: String? = nil) -> SmokingEventRecord {
    SmokingEventRecord(
        id: "e",
        type: type,
        occurredAtMs: 0,
        tzId: "UTC",
        epochDay: 0,
        units: 1,
        trigger: trigger,
        intensity: nil,
        productType: "CIGARETTE",
        attemptId: nil
    )
}

private func planRecord(mode: String = "QUIT", productType: String = "CIGARETTE") -> SmokingPlanRecord {
    SmokingPlanRecord(
        id: "p",
        mode: mode,
        productType: productType,
        baselineUnitsPerDay: 1,
        dailyLimit: nil,
        currencyCode: "TRY",
        reason: nil,
        notificationsEnabled: true,
        eveningReminderEnabled: false,
        createdAtMs: 0,
        tzId: "UTC"
    )
}

@Suite("Smoking mappers")
struct SmokingMappersTests {
    @Test("the plan survives a round trip and stores enums as their NAME")
    func planRoundTrip() throws {
        let plan = SmokingPlan(
            id: "p",
            mode: .reduce,
            productType: .heated,
            baselineUnitsPerDay: 12,
            dailyLimit: 7,
            currencyCode: "EUR",
            reason: "why",
            notificationsEnabled: false,
            eveningReminderEnabled: true,
            createdAtMs: 1_700_000_000_123,
            tzId: "Europe/Berlin"
        )

        let record = plan.toRecord()

        #expect(record.mode == "REDUCE")
        #expect(record.productType == "HEATED")
        #expect(record.baselineUnitsPerDay == 12)
        #expect(record.dailyLimit == 7)
        #expect(try record.toDomain() == plan)
    }

    @Test("a quit attempt, price period and goal survive a round trip")
    func smallRowsRoundTrip() throws {
        let attempt = QuitAttempt(id: "a", startedAtMs: 5, tzId: "UTC", endedAtMs: 9, endReason: .switchedToReduce)
        let price = PricePeriod(id: "p", effectiveFromEpochDay: 20000, unitCostMinor: 4500)
        let goal = SavingsGoal(id: "g", title: "Bike", targetMinor: 90000, createdAtMs: 3, achievedAtMs: 4)

        #expect(attempt.toRecord().endReason == "SWITCHED_TO_REDUCE")
        #expect(try attempt.toRecord().toDomain() == attempt)
        #expect(try price.toRecord().toDomain() == price)
        #expect(try goal.toRecord().toDomain() == goal)
    }

    @Test("an event survives a round trip with and without its optional columns")
    func eventRoundTrip() throws {
        let full = sampleEvent(trigger: .afterMeal, productType: .rolled, attemptId: "a")
        let craving = sampleEvent(id: "c", type: .cravingResisted, units: nil, productType: .vape)

        #expect(full.toRecord().trigger == "AFTER_MEAL")
        #expect(full.toRecord().type == "SMOKED")
        #expect(craving.toRecord().type == "CRAVING_RESISTED")
        #expect(try full.toRecord().toDomain() == full)
        #expect(try craving.toRecord().toDomain() == craving)
    }

    @Test("a stored plan value this build does not know is corruption and throws")
    func unknownPlanValueThrows() {
        #expect(throws: SmokingMappingError.self) { try planRecord(mode: "BOGUS").toDomain() }
        #expect(throws: SmokingMappingError.self) { try planRecord(productType: "BOGUS").toDomain() }
    }

    @Test("an unknown trigger, event type or end reason throws")
    func unknownEventValuesThrow() {
        let badReason = SmokingQuitAttemptRecord(id: "a", startedAtMs: 0, tzId: "UTC", endedAtMs: 1, endReason: "BOGUS")

        #expect(throws: SmokingMappingError.self) { try eventRecord(trigger: "BOGUS").toDomain() }
        #expect(throws: SmokingMappingError.self) { try eventRecord(type: "BOGUS").toDomain() }
        #expect(throws: SmokingMappingError.self) { try badReason.toDomain() }
    }
}
