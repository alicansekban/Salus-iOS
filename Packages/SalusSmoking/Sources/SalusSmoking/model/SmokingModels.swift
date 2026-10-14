// The smoking-cessation domain models, per `smoking-domain-contract.md` §1–§2 in `salus-android`
// (the cross-platform source of truth; Android twin: `:core:smoking` `SmokingModels.kt`).
//
// Enum cases are lowerCamel and the raw value is the stored `NAME` string, so a persisted value
// round-trips with Android byte for byte (contract §2). Every field is the contract §1 column,
// camelCased. Millisecond instants, minor-unit money and epoch days are `Int64` on both platforms,
// so a 20-year horizon cannot overflow where Android's `Long` would not.

/// Whether the user is quitting outright or tapering toward a daily limit.
public enum SmokingMode: String, Sendable, CaseIterable {
    case quit = "QUIT"
    case reduce = "REDUCE"
}

/// What is smoked. `vape` is counted in sessions with a baseline of 1 (contract §6, `SetUpSmoking`).
public enum ProductType: String, Sendable, CaseIterable {
    case cigarette = "CIGARETTE"
    case rolled = "ROLLED"
    case heated = "HEATED"
    case vape = "VAPE"
}

public enum SmokingEventType: String, Sendable, CaseIterable {
    case smoked = "SMOKED"
    case cravingResisted = "CRAVING_RESISTED"
}

public enum CravingTrigger: String, Sendable, CaseIterable {
    case coffee = "COFFEE"
    case stress = "STRESS"
    case alcohol = "ALCOHOL"
    case afterMeal = "AFTER_MEAL"
    case social = "SOCIAL"
    case boredom = "BOREDOM"
    case other = "OTHER"
}

public enum AttemptEndReason: String, Sendable, CaseIterable {
    case restarted = "RESTARTED"
    case switchedToReduce = "SWITCHED_TO_REDUCE"
}

/// The single `smoking_plan` row.
public struct SmokingPlan: Sendable, Equatable {
    public let id: String
    public let mode: SmokingMode
    public let productType: ProductType
    /// Units per day before the user started; at least 1 (VAPE: 1).
    public let baselineUnitsPerDay: Int64
    /// REDUCE only; nil in QUIT.
    public let dailyLimit: Int64?
    public let currencyCode: String
    /// Never leaves the device.
    public let reason: String?
    public let notificationsEnabled: Bool
    public let eveningReminderEnabled: Bool
    public let createdAtMs: Int64
    public let tzId: String

    public init(
        id: String,
        mode: SmokingMode,
        productType: ProductType,
        baselineUnitsPerDay: Int64,
        dailyLimit: Int64?,
        currencyCode: String,
        reason: String?,
        notificationsEnabled: Bool,
        eveningReminderEnabled: Bool,
        createdAtMs: Int64,
        tzId: String
    ) {
        self.id = id
        self.mode = mode
        self.productType = productType
        self.baselineUnitsPerDay = baselineUnitsPerDay
        self.dailyLimit = dailyLimit
        self.currencyCode = currencyCode
        self.reason = reason
        self.notificationsEnabled = notificationsEnabled
        self.eveningReminderEnabled = eveningReminderEnabled
        self.createdAtMs = createdAtMs
        self.tzId = tzId
    }
}

/// A unit price in force from `effectiveFromEpochDay` on (`smoking_price_period`).
public struct PricePeriod: Sendable, Equatable {
    public let id: String
    public let effectiveFromEpochDay: Int64
    public let unitCostMinor: Int64

    public init(id: String, effectiveFromEpochDay: Int64, unitCostMinor: Int64) {
        self.id = id
        self.effectiveFromEpochDay = effectiveFromEpochDay
        self.unitCostMinor = unitCostMinor
    }
}

public struct QuitAttempt: Sendable, Equatable {
    public let id: String
    public let startedAtMs: Int64
    public let tzId: String
    /// Nil while the attempt is active.
    public let endedAtMs: Int64?
    public let endReason: AttemptEndReason?

    public init(id: String, startedAtMs: Int64, tzId: String, endedAtMs: Int64?, endReason: AttemptEndReason?) {
        self.id = id
        self.startedAtMs = startedAtMs
        self.tzId = tzId
        self.endedAtMs = endedAtMs
        self.endReason = endReason
    }
}

public struct SmokingEvent: Sendable, Equatable {
    public let id: String
    public let type: SmokingEventType
    public let occurredAtMs: Int64
    public let tzId: String
    /// From the event's own `tzId`, computed once at write time.
    public let epochDay: Int64
    /// SMOKED: at least 1, or 0 for the REDUCE "none today" marker. Nil for CRAVING_RESISTED.
    public let units: Int64?
    public let trigger: CravingTrigger?
    /// 1–5.
    public let intensity: Int?
    /// The product at event time.
    public let productType: ProductType
    public let attemptId: String?

    public init(
        id: String,
        type: SmokingEventType,
        occurredAtMs: Int64,
        tzId: String,
        epochDay: Int64,
        units: Int64?,
        trigger: CravingTrigger?,
        intensity: Int?,
        productType: ProductType,
        attemptId: String?
    ) {
        self.id = id
        self.type = type
        self.occurredAtMs = occurredAtMs
        self.tzId = tzId
        self.epochDay = epochDay
        self.units = units
        self.trigger = trigger
        self.intensity = intensity
        self.productType = productType
        self.attemptId = attemptId
    }
}

public struct SavingsGoal: Sendable, Equatable {
    public let id: String
    public let title: String
    /// Greater than zero.
    public let targetMinor: Int64
    public let createdAtMs: Int64
    public let achievedAtMs: Int64?

    public init(id: String, title: String, targetMinor: Int64, createdAtMs: Int64, achievedAtMs: Int64?) {
        self.id = id
        self.title = title
        self.targetMinor = targetMinor
        self.createdAtMs = createdAtMs
        self.achievedAtMs = achievedAtMs
    }
}

/// Everything the calculators read: the stored rows, loaded once by the repository.
public struct SmokingInput: Sendable, Equatable {
    public let plan: SmokingPlan?
    public let prices: [PricePeriod]
    public let attempts: [QuitAttempt]
    public let events: [SmokingEvent]
    public let goal: SavingsGoal?

    public init(
        plan: SmokingPlan?,
        prices: [PricePeriod],
        attempts: [QuitAttempt],
        events: [SmokingEvent],
        goal: SavingsGoal?
    ) {
        self.plan = plan
        self.prices = prices
        self.attempts = attempts
        self.events = events
        self.goal = goal
    }
}
