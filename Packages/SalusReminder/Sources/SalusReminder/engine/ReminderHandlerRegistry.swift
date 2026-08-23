// Ported 1:1 from Android
// `core/reminder/src/main/kotlin/com/alicansekban/salus/core/reminder/engine/ReminderHandlerRegistry.kt`.
//
// Kotlin's registry is a class Koin builds from `getAll<ReminderHandler>()`. There is no
// container in this tree, so the twin is a value the composition root builds by hand from the
// handlers it already constructed — same reach, no discovery magic.

import SalusModel

/// All feature handlers, collected at graph creation.
public struct ReminderHandlerRegistry: Sendable {
    public let all: [any ReminderHandler]

    private let byType: [ReminderType: any ReminderHandler]

    public init(all: [any ReminderHandler]) {
        self.all = all
        // Kotlin's `associateBy` puts every entry into the map in order, so a second handler for
        // the same type overwrites the first. Swift's initializer traps on a duplicate key unless
        // the tie-break is spelled out, so it is spelled out to say the same thing: last wins.
        byType = Dictionary(all.map { ($0.type, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// The handler that owns `type`, or nil when no feature registered one.
    public func forType(_ type: ReminderType) -> (any ReminderHandler)? {
        byType[type]
    }

    /// The same lookup from a persisted type name (a notification's `userInfo`, a ledger row),
    /// which is a `ReminderType` raw value. An unknown name answers nil rather than trapping.
    public func forType(typeName: String) -> (any ReminderHandler)? {
        ReminderType(rawValue: typeName).flatMap(forType)
    }
}
