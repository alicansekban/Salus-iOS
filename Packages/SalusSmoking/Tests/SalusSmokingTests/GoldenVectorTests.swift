import Foundation
import Testing

@testable import SalusSmoking

// Golden-vector parity (`smoking-domain-contract.md` §7 in `salus-android`): the vectors file is
// authored by Android and copied unchanged by `scripts/dev/sync-m17-contracts.sh`, so a calculator
// that drifts from the twin fails here by case name. A disagreement is settled against the
// contract text, never by editing the vectors. JSON is read with `JSONSerialization` because the
// `expected` objects are sparse: a missing key is not asserted and an explicit null asserts nil.

private typealias JSON = [String: Any]

private enum GoldenVectors {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// The raw file; `Any`-based JSON is not `Sendable`, so each use parses this `Data` again.
    static let data: Data = {
        guard
            let url = Bundle.module.url(
                forResource: "smoking-golden-vectors", withExtension: "json", subdirectory: "Resources"
            ),
            let data = try? Data(contentsOf: url)
        else { return Data() }
        return data
    }()

    static var root: JSON {
        (try? JSONSerialization.jsonObject(with: data)) as? JSON ?? [:]
    }

    static var snapshotCases: [JSON] { root["snapshotCases"] as? [JSON] ?? [] }
    static var scheduleCases: [JSON] { root["scheduleCases"] as? [JSON] ?? [] }

    static func names(_ cases: [JSON]) -> [String] {
        cases.compactMap { $0["name"] as? String }
    }

    static func named(_ name: String, in cases: [JSON]) throws -> JSON {
        guard let found = cases.first(where: { $0["name"] as? String == name }) else {
            throw Failure(description: "no vector named \(name)")
        }
        return found
    }
}

// MARK: - Decoding

private func int64(_ value: Any?) -> Int64? {
    (value as? NSNumber)?.int64Value
}

private func string(_ value: Any?) -> String? {
    value as? String
}

private func decodePlan(_ json: JSON?) throws -> SmokingPlan? {
    guard let json else { return nil }
    return try SmokingPlan(
        id: require(string(json["id"]), "plan.id"),
        mode: require(SmokingMode(rawValue: string(json["mode"]) ?? ""), "plan.mode"),
        productType: require(ProductType(rawValue: string(json["productType"]) ?? ""), "plan.productType"),
        baselineUnitsPerDay: require(int64(json["baselineUnitsPerDay"]), "plan.baselineUnitsPerDay"),
        dailyLimit: int64(json["dailyLimit"]),
        currencyCode: require(string(json["currencyCode"]), "plan.currencyCode"),
        reason: string(json["reason"]),
        notificationsEnabled: (json["notificationsEnabled"] as? Bool) ?? false,
        eveningReminderEnabled: (json["eveningReminderEnabled"] as? Bool) ?? false,
        createdAtMs: require(int64(json["createdAtMs"]), "plan.createdAtMs"),
        tzId: require(string(json["tzId"]), "plan.tzId")
    )
}

private func decodePrice(_ json: JSON) throws -> PricePeriod {
    try PricePeriod(
        id: require(string(json["id"]), "price.id"),
        effectiveFromEpochDay: require(int64(json["effectiveFromEpochDay"]), "price.effectiveFromEpochDay"),
        unitCostMinor: require(int64(json["unitCostMinor"]), "price.unitCostMinor")
    )
}

private func decodeAttempt(_ json: JSON) throws -> QuitAttempt {
    try QuitAttempt(
        id: require(string(json["id"]), "attempt.id"),
        startedAtMs: require(int64(json["startedAtMs"]), "attempt.startedAtMs"),
        tzId: require(string(json["tzId"]), "attempt.tzId"),
        endedAtMs: int64(json["endedAtMs"]),
        endReason: string(json["endReason"]).flatMap { AttemptEndReason(rawValue: $0) }
    )
}

private func decodeEvent(_ json: JSON) throws -> SmokingEvent {
    try SmokingEvent(
        id: require(string(json["id"]), "event.id"),
        type: require(SmokingEventType(rawValue: string(json["type"]) ?? ""), "event.type"),
        occurredAtMs: require(int64(json["occurredAtMs"]), "event.occurredAtMs"),
        tzId: require(string(json["tzId"]), "event.tzId"),
        epochDay: require(int64(json["epochDay"]), "event.epochDay"),
        units: int64(json["units"]),
        trigger: string(json["trigger"]).flatMap { CravingTrigger(rawValue: $0) },
        intensity: int64(json["intensity"]).map { Int($0) },
        productType: require(ProductType(rawValue: string(json["productType"]) ?? ""), "event.productType"),
        attemptId: string(json["attemptId"])
    )
}

private func decodeGoal(_ json: JSON?) throws -> SavingsGoal? {
    guard let json else { return nil }
    return try SavingsGoal(
        id: require(string(json["id"]), "goal.id"),
        title: require(string(json["title"]), "goal.title"),
        targetMinor: require(int64(json["targetMinor"]), "goal.targetMinor"),
        createdAtMs: require(int64(json["createdAtMs"]), "goal.createdAtMs"),
        achievedAtMs: int64(json["achievedAtMs"])
    )
}

private func decodeInput(_ json: JSON) throws -> SmokingInput {
    try SmokingInput(
        plan: decodePlan(json["plan"] as? JSON),
        prices: (json["prices"] as? [JSON] ?? []).map(decodePrice),
        attempts: (json["attempts"] as? [JSON] ?? []).map(decodeAttempt),
        events: (json["events"] as? [JSON] ?? []).map(decodeEvent),
        goal: decodeGoal(json["goal"] as? JSON)
    )
}

private func decodeZone(_ json: JSON) throws -> TimeZone {
    let identifier = try require(string(json["zone"]), "zone")
    return try require(TimeZone(identifier: identifier), "TimeZone \(identifier)")
}

private func require<T>(_ value: T?, _ what: String) throws -> T {
    guard let value else { throw GoldenVectors.Failure(description: "vector field missing or invalid: \(what)") }
    return value
}

private func decodeKind(_ text: String) throws -> MilestoneKind {
    let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { throw GoldenVectors.Failure(description: "malformed kind \(text)") }
    let number = Int64(parts[1])
    switch (parts[0], number) {
    case ("STAGE", _): return .stage(parts[1])
    case let ("DAYS", value?): return .days(value)
    case let ("UNITS", value?): return .units(value)
    case let ("MONEY", value?): return .money(value)
    case let ("EVENING", value?): return .evening(value)
    default: throw GoldenVectors.Failure(description: "unknown kind \(text)")
    }
}

// MARK: - Snapshot expectations

/// The fields of a snapshot that contract §7 lets a vector assert, `nil` where the snapshot kind
/// has no such field. `timeRegainedMinutes` and `nextStageId`/`nextStagePermille` are themselves
/// optional, so the extractor returns the doubly optional value: `.some(nil)` is "present, null".
private func quitValue(_ key: String, _ snapshot: QuitSnapshot) -> Int64?? {
    switch key {
    case "attemptElapsedMs": .some(snapshot.attemptElapsedMs)
    case "sinceLastSmokeMs": .some(snapshot.sinceLastSmokeMs)
    case "slipCount": .some(Int64(snapshot.slipCount))
    case "unitsNotSmoked": .some(snapshot.unitsNotSmoked)
    case "savedMinor": .some(snapshot.savedMinor)
    case "timeRegainedMinutes": .some(snapshot.timeRegainedMinutes)
    case "cravingsBeaten": .some(Int64(snapshot.cravingsBeaten))
    case "nextStagePermille": .some(snapshot.nextStage.map { Int64($0.permille) })
    case "goalSavedTowardMinor": .some(snapshot.goal?.savedTowardMinor)
    default: nil
    }
}

private func reduceValue(_ key: String, _ snapshot: ReduceSnapshot) -> Int64?? {
    switch key {
    case "todayUnits": .some(snapshot.todayUnits)
    case "weekReductionUnits": .some(snapshot.weekReductionUnits)
    case "weekSavedMinor": .some(snapshot.weekSavedMinor)
    case "savedSinceSetupMinor": .some(snapshot.savedSinceSetupMinor)
    case "goalSavedTowardMinor": .some(snapshot.goal?.savedTowardMinor)
    default: nil
    }
}

private let integerKeys = [
    "attemptElapsedMs", "sinceLastSmokeMs", "slipCount", "unitsNotSmoked", "savedMinor",
    "timeRegainedMinutes", "cravingsBeaten", "nextStagePermille", "todayUnits", "weekReductionUnits",
    "weekSavedMinor", "savedSinceSetupMinor", "goalSavedTowardMinor"
]

@Suite("Golden vectors: Android parity")
struct GoldenVectorTests {
    @Test("The vectors file is the version-1 file with at least the contract's case counts")
    func fileShape() {
        #expect(int64(GoldenVectors.root["version"]) == 1)
        // Contract §7 asks for 12 / 6; S3 delivered 27 / 14. Pinning the delivered counts makes a
        // sync that silently loses cases fail instead of passing with fewer.
        #expect(GoldenVectors.snapshotCases.count >= 27)
        #expect(GoldenVectors.scheduleCases.count >= 14)
        #expect(Set(GoldenVectors.names(GoldenVectors.snapshotCases)).count == GoldenVectors.snapshotCases.count)
        #expect(Set(GoldenVectors.names(GoldenVectors.scheduleCases)).count == GoldenVectors.scheduleCases.count)
    }

    @Test("Snapshot case", arguments: GoldenVectors.names(GoldenVectors.snapshotCases))
    func snapshotCase(name: String) throws {
        let vector = try GoldenVectors.named(name, in: GoldenVectors.snapshotCases)
        let input = try decodeInput(require(vector["input"] as? JSON, "input"))
        let nowMs = try require(int64(vector["nowMs"]), "nowMs")
        let zone = try decodeZone(vector)
        let expected = try require(vector["expected"] as? JSON, "expected")

        let snapshot = SmokingStatsCalculator.snapshot(input, nowMs: nowMs, zone: zone)

        let kind = try require(string(expected["kind"]), "expected.kind")
        switch (kind, snapshot) {
        case ("NOT_SET_UP", .notSetUp):
            break

        case let ("QUIT", .quit(quit)):
            assertIntegers(expected, name) { quitValue($0, quit) }
            if let stage = expected["nextStageId"] {
                #expect(quit.nextStage?.stageId == stage as? String, "\(name): nextStageId")
            }

        case let ("REDUCE", .reduce(reduce)):
            assertIntegers(expected, name) { reduceValue($0, reduce) }

        default:
            Issue.record("\(name): expected kind \(kind), calculator returned \(snapshot)")
        }
    }

    @Test("Schedule case", arguments: GoldenVectors.names(GoldenVectors.scheduleCases))
    func scheduleCase(name: String) throws {
        let vector = try GoldenVectors.named(name, in: GoldenVectors.scheduleCases)
        let input = try decodeInput(require(vector["input"] as? JSON, "input"))
        let nowMs = try require(int64(vector["nowMs"]), "nowMs")
        let zone = try decodeZone(vector)
        let expected = try require(vector["expected"] as? [JSON], "expected").map { json in
            try PlannedNotification(
                key: require(string(json["key"]), "key"),
                triggerAtMs: require(int64(json["triggerAtMs"]), "triggerAtMs"),
                kinds: (json["kinds"] as? [String] ?? []).map(decodeKind)
            )
        }

        let planned = MilestoneScheduler.plan(input, nowMs: nowMs, zone: zone)

        // `kinds` is an ordered list in the vectors (contract §8.9), so plain equality applies.
        #expect(planned == expected, "\(name)")
    }
}

/// Asserts every integer key a vector carries: a missing key is skipped, an explicit null asserts
/// nil, and a key the snapshot kind does not have is a failure (the vector expects a field the
/// calculator cannot produce).
private func assertIntegers(_ expected: JSON, _ name: String, value: (String) -> Int64??) {
    for key in integerKeys {
        guard let raw = expected[key] else { continue }
        guard let actual = value(key) else {
            Issue.record("\(name): vector asserts \(key), which this snapshot kind has no field for")
            continue
        }
        let want: Int64? = raw is NSNull ? nil : int64(raw)
        #expect(actual == want, "\(name): \(key)")
    }
}
