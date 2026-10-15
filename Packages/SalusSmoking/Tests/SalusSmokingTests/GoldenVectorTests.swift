import Foundation
import Testing

@testable import SalusSmoking

// Golden-vector parity (`smoking-domain-contract.md` §7 in `salus-android`): the vectors file is
// authored by Android and copied unchanged by `scripts/dev/sync-m17-contracts.sh`, so a calculator
// that drifts from the twin fails here by case name. A disagreement is settled against the
// contract text, never by editing the vectors. JSON is read with `JSONSerialization` because the
// `expected` objects are sparse: a missing key is not asserted and an explicit null asserts nil.
// Everything else is strict, because the vectors are the drift detector: an unknown key, a value of
// the wrong type, an enum value the port does not know or a field the decoder does not read is a
// failure, never a silent default.

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

private func fail(_ message: String) -> GoldenVectors.Failure {
    GoldenVectors.Failure(description: message)
}

/// The nullable field `key` of `json`: nil when absent or an explicit null, the decoded value
/// otherwise — and a failure when it is there but does not decode (a wrong type, an unknown enum
/// value), where `?? default` would have hidden it.
private func optional<T>(
    _ json: JSON, _ key: String, _ what: String, _ decode: (Any) -> T?
) throws -> T? {
    guard let raw = json[key], !(raw is NSNull) else { return nil }
    guard let value = decode(raw) else { throw fail("vector field invalid: \(what).\(key) = \(raw)") }
    return value
}

private func optionalInt64(_ json: JSON, _ key: String, _ what: String) throws -> Int64? {
    try optional(json, key, what) { int64($0) }
}

private func optionalString(_ json: JSON, _ key: String, _ what: String) throws -> String? {
    try optional(json, key, what) { string($0) }
}

private func optionalBool(_ json: JSON, _ key: String, _ what: String) throws -> Bool? {
    try optional(json, key, what) { $0 as? Bool }
}

private func optionalEnum<T: RawRepresentable>(
    _ json: JSON, _ key: String, _ what: String
) throws -> T? where T.RawValue == String {
    try optional(json, key, what) { string($0).flatMap { T(rawValue: $0) } }
}

/// Fails on a key the decoder does not read: a field Android added would otherwise never be seen.
private func requireKnownKeys(_ json: JSON, _ known: Set<String>, _ what: String) throws {
    let unknown = Set(json.keys).subtracting(known)
    guard unknown.isEmpty else { throw fail("vector \(what) has keys the decoder does not read: \(unknown.sorted())") }
}

private func decodePlan(_ json: JSON?) throws -> SmokingPlan? {
    guard let json else { return nil }
    try requireKnownKeys(json, [
        "id", "mode", "productType", "baselineUnitsPerDay", "dailyLimit", "currencyCode", "reason",
        "notificationsEnabled", "eveningReminderEnabled", "createdAtMs", "tzId"
    ], "plan")
    return try SmokingPlan(
        id: require(string(json["id"]), "plan.id"),
        mode: require(SmokingMode(rawValue: string(json["mode"]) ?? ""), "plan.mode"),
        productType: require(ProductType(rawValue: string(json["productType"]) ?? ""), "plan.productType"),
        baselineUnitsPerDay: require(int64(json["baselineUnitsPerDay"]), "plan.baselineUnitsPerDay"),
        dailyLimit: optionalInt64(json, "dailyLimit", "plan"),
        currencyCode: require(string(json["currencyCode"]), "plan.currencyCode"),
        reason: optionalString(json, "reason", "plan"),
        notificationsEnabled: optionalBool(json, "notificationsEnabled", "plan") ?? false,
        eveningReminderEnabled: optionalBool(json, "eveningReminderEnabled", "plan") ?? false,
        createdAtMs: require(int64(json["createdAtMs"]), "plan.createdAtMs"),
        tzId: require(string(json["tzId"]), "plan.tzId")
    )
}

private func decodePrice(_ json: JSON) throws -> PricePeriod {
    try requireKnownKeys(json, ["id", "effectiveFromEpochDay", "unitCostMinor"], "price")
    return try PricePeriod(
        id: require(string(json["id"]), "price.id"),
        effectiveFromEpochDay: require(int64(json["effectiveFromEpochDay"]), "price.effectiveFromEpochDay"),
        unitCostMinor: require(int64(json["unitCostMinor"]), "price.unitCostMinor")
    )
}

private func decodeAttempt(_ json: JSON) throws -> QuitAttempt {
    try requireKnownKeys(json, ["id", "startedAtMs", "tzId", "endedAtMs", "endReason"], "attempt")
    return try QuitAttempt(
        id: require(string(json["id"]), "attempt.id"),
        startedAtMs: require(int64(json["startedAtMs"]), "attempt.startedAtMs"),
        tzId: require(string(json["tzId"]), "attempt.tzId"),
        endedAtMs: optionalInt64(json, "endedAtMs", "attempt"),
        endReason: optionalEnum(json, "endReason", "attempt")
    )
}

private func decodeEvent(_ json: JSON) throws -> SmokingEvent {
    try requireKnownKeys(json, [
        "id", "type", "occurredAtMs", "tzId", "epochDay", "units", "trigger", "intensity", "productType", "attemptId"
    ], "event")
    return try SmokingEvent(
        id: require(string(json["id"]), "event.id"),
        type: require(SmokingEventType(rawValue: string(json["type"]) ?? ""), "event.type"),
        occurredAtMs: require(int64(json["occurredAtMs"]), "event.occurredAtMs"),
        tzId: require(string(json["tzId"]), "event.tzId"),
        epochDay: require(int64(json["epochDay"]), "event.epochDay"),
        units: optionalInt64(json, "units", "event"),
        trigger: optionalEnum(json, "trigger", "event"),
        intensity: optionalInt64(json, "intensity", "event").map { Int($0) },
        productType: require(ProductType(rawValue: string(json["productType"]) ?? ""), "event.productType"),
        attemptId: optionalString(json, "attemptId", "event")
    )
}

private func decodeGoal(_ json: JSON?) throws -> SavingsGoal? {
    guard let json else { return nil }
    try requireKnownKeys(json, ["id", "title", "targetMinor", "createdAtMs", "achievedAtMs"], "goal")
    return try SavingsGoal(
        id: require(string(json["id"]), "goal.id"),
        title: require(string(json["title"]), "goal.title"),
        targetMinor: require(int64(json["targetMinor"]), "goal.targetMinor"),
        createdAtMs: require(int64(json["createdAtMs"]), "goal.createdAtMs"),
        achievedAtMs: optionalInt64(json, "achievedAtMs", "goal")
    )
}

private func decodeInput(_ json: JSON) throws -> SmokingInput {
    try requireKnownKeys(json, ["plan", "prices", "attempts", "events", "goal"], "input")
    return try SmokingInput(
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
    guard let value else { throw fail("vector field missing or invalid: \(what)") }
    return value
}

private func decodeKind(_ text: String) throws -> MilestoneKind {
    let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { throw fail("malformed kind \(text)") }
    let number = Int64(parts[1])
    switch (parts[0], number) {
    case ("STAGE", _): return .stage(parts[1])
    case let ("DAYS", value?): return .days(value)
    case let ("UNITS", value?): return .units(value)
    case let ("MONEY", value?): return .money(value)
    case let ("EVENING", value?): return .evening(value)
    default: throw fail("unknown kind \(text)")
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

/// Every key an `expected` object may carry, by snapshot kind. The two integer lists mirror
/// `quitValue` and `reduceValue`; a key outside its kind's list is a problem (`expectedProblems`).
private let quitExpectedKeys: Set<String> = [
    "kind", "nextStageId", "attemptElapsedMs", "sinceLastSmokeMs", "slipCount", "unitsNotSmoked", "savedMinor",
    "timeRegainedMinutes", "cravingsBeaten", "nextStagePermille", "goalSavedTowardMinor"
]
private let reduceExpectedKeys: Set<String> = [
    "kind", "todayUnits", "weekReductionUnits", "weekSavedMinor", "savedSinceSetupMinor", "goalSavedTowardMinor"
]

/// What is wrong with an `expected` object, one line per problem: a key its kind does not have
/// (a misspelled one, or `nextStageId` on a REDUCE vector), an integer that is not a number or a
/// null, a stage id that is not a string or a null. Empty when the object is sound.
private func expectedProblems(_ expected: JSON, kind: String) -> [String] {
    let known: Set<String> = switch kind {
    case "QUIT": quitExpectedKeys
    case "REDUCE": reduceExpectedKeys
    default: ["kind"]
    }
    var problems = Set(expected.keys).subtracting(known).sorted().map { "unknown expected key \($0) for kind \(kind)" }
    for key in integerKeys {
        if let raw = expected[key], !(raw is NSNull), !(raw is NSNumber) {
            problems.append("expected.\(key) is not a number: \(raw)")
        }
    }
    if let stage = expected["nextStageId"], !(stage is NSNull), !(stage is String) {
        problems.append("expected.nextStageId is not a string: \(stage)")
    }
    return problems
}

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
        for problem in expectedProblems(expected, kind: kind) {
            Issue.record("\(name): \(problem)")
        }
        switch (kind, snapshot) {
        case ("NOT_SET_UP", .notSetUp):
            break

        case let ("QUIT", .quit(quit)):
            assertIntegers(expected, name) { quitValue($0, quit) }
            // Present as a string it names the stage; present as null it asserts there is none.
            if let stage = expected["nextStageId"] {
                #expect(quit.nextStage?.stageId == string(stage), "\(name): nextStageId")
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

// MARK: - The decoders fail loudly

/// The vectors are the cross-platform drift detector, so a decoder that quietly drops what it does
/// not understand would let a renamed key, a new enum value or a retyped field pass unnoticed.
@Suite("Golden vectors: decoders fail loudly")
struct GoldenVectorDecoderTests {
    private let attempt: JSON = [
        "id": "a1", "startedAtMs": 1, "tzId": "Europe/Istanbul", "endedAtMs": NSNull(), "endReason": NSNull()
    ]
    private let plan: JSON = [
        "id": "p1", "mode": "QUIT", "productType": "CIGARETTE", "baselineUnitsPerDay": 20, "dailyLimit": NSNull(),
        "currencyCode": "TRY", "reason": NSNull(), "notificationsEnabled": true, "eveningReminderEnabled": false,
        "createdAtMs": 1, "tzId": "Europe/Istanbul"
    ]

    @Test("a well-formed attempt and plan decode")
    func wellFormedDecodes() throws {
        #expect(try decodeAttempt(attempt).id == "a1")
        #expect(try decodePlan(plan)?.notificationsEnabled == true)
    }

    @Test("an unknown expected key is a problem")
    func unknownExpectedKey() {
        #expect(expectedProblems(["kind": "QUIT", "savedMinor": 1], kind: "QUIT").isEmpty)
        #expect(!expectedProblems(["kind": "QUIT", "savedMinro": 1], kind: "QUIT").isEmpty)
        #expect(!expectedProblems(["kind": "NOT_SET_UP", "savedMinor": 1], kind: "NOT_SET_UP").isEmpty)
    }

    @Test("an expected key the snapshot kind has no field for is a problem, not a skip")
    func extraKeyForTheKind() {
        #expect(!expectedProblems(["kind": "REDUCE", "nextStageId": "h_1mo"], kind: "REDUCE").isEmpty)
        #expect(!expectedProblems(["kind": "REDUCE", "savedMinor": 1], kind: "REDUCE").isEmpty)
        #expect(!expectedProblems(["kind": "QUIT", "todayUnits": 1], kind: "QUIT").isEmpty)
    }

    @Test("an expected value of the wrong type is a problem")
    func wrongExpectedType() {
        #expect(!expectedProblems(["kind": "QUIT", "savedMinor": "12"], kind: "QUIT").isEmpty)
        #expect(!expectedProblems(["kind": "QUIT", "nextStageId": 7], kind: "QUIT").isEmpty)
        #expect(expectedProblems(["kind": "QUIT", "nextStageId": NSNull(), "savedMinor": NSNull()], kind: "QUIT").isEmpty)
    }

    @Test("an enum value the port does not know throws")
    func undecodableEnum() throws {
        var badReason = attempt
        badReason["endReason"] = "ABANDONED"
        #expect(throws: GoldenVectors.Failure.self) { try decodeAttempt(badReason) }

        var badTrigger: JSON = [
            "id": "e1", "type": "SMOKED", "occurredAtMs": 1, "tzId": "Europe/Istanbul", "epochDay": 0,
            "units": 1, "trigger": "FULL_MOON", "intensity": NSNull(), "productType": "CIGARETTE", "attemptId": NSNull()
        ]
        #expect(throws: GoldenVectors.Failure.self) { try decodeEvent(badTrigger) }
        badTrigger["trigger"] = "STRESS"
        #expect(try decodeEvent(badTrigger).trigger == .stress)
    }

    @Test("a boolean that is present must be a boolean")
    func presentBooleanMustDecode() {
        var bad = plan
        bad["notificationsEnabled"] = "yes"
        #expect(throws: GoldenVectors.Failure.self) { try decodePlan(bad) }
    }

    @Test("an optional number that is present must be a number")
    func presentNumberMustDecode() {
        var bad = attempt
        bad["endedAtMs"] = "soon"
        #expect(throws: GoldenVectors.Failure.self) { try decodeAttempt(bad) }
    }

    @Test("an input key the decoder does not read throws")
    func unknownInputKey() {
        var extra = plan
        extra["quietHours"] = true
        #expect(throws: GoldenVectors.Failure.self) { try decodePlan(extra) }
    }
}
