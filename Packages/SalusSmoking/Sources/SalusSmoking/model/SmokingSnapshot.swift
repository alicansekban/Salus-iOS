// The calculator's answer (`smoking-domain-contract.md` §2). Progress is integer `permille`
// (0–1000) and every `*Ms`, `*Minor` and unit total is 64-bit; floats exist only in the UI.

/// Which of the three screens' worth of state the user is in.
public enum SmokingSnapshot: Sendable, Equatable {
    case notSetUp
    case quit(QuitSnapshot)
    case reduce(ReduceSnapshot)
}

public struct QuitSnapshot: Sendable, Equatable {
    public let plan: SmokingPlan
    public let attemptId: String
    public let attemptStartedAtMs: Int64
    public let attemptElapsedMs: Int64
    public let sinceLastSmokeMs: Int64
    public let slipCount: Int
    public let unitsNotSmoked: Int64
    public let unitsNotSmokedToday: Int64
    public let savedMinor: Int64
    /// `unitsNotSmoked` times 11; nil for VAPE, which has no per-unit minutes.
    public let timeRegainedMinutes: Int64?
    /// CRAVING_RESISTED events inside the active attempt.
    public let cravingsBeaten: Int
    public let cravingsBeatenAllTime: Int
    public let stages: [StageProgress]
    /// The first stage not yet reached; nil once every stage is done.
    public let nextStage: StageProgress?
    /// Every attempt, in ordinal order.
    public let attempts: [AttemptSummary]
    public let goal: GoalProgress?

    public init(
        plan: SmokingPlan,
        attemptId: String,
        attemptStartedAtMs: Int64,
        attemptElapsedMs: Int64,
        sinceLastSmokeMs: Int64,
        slipCount: Int,
        unitsNotSmoked: Int64,
        unitsNotSmokedToday: Int64,
        savedMinor: Int64,
        timeRegainedMinutes: Int64?,
        cravingsBeaten: Int,
        cravingsBeatenAllTime: Int,
        stages: [StageProgress],
        nextStage: StageProgress?,
        attempts: [AttemptSummary],
        goal: GoalProgress?
    ) {
        self.plan = plan
        self.attemptId = attemptId
        self.attemptStartedAtMs = attemptStartedAtMs
        self.attemptElapsedMs = attemptElapsedMs
        self.sinceLastSmokeMs = sinceLastSmokeMs
        self.slipCount = slipCount
        self.unitsNotSmoked = unitsNotSmoked
        self.unitsNotSmokedToday = unitsNotSmokedToday
        self.savedMinor = savedMinor
        self.timeRegainedMinutes = timeRegainedMinutes
        self.cravingsBeaten = cravingsBeaten
        self.cravingsBeatenAllTime = cravingsBeatenAllTime
        self.stages = stages
        self.nextStage = nextStage
        self.attempts = attempts
        self.goal = goal
    }
}

public struct ReduceSnapshot: Sendable, Equatable {
    public let plan: SmokingPlan
    public let todayEpochDay: Int64
    public let todayUnits: Int64
    /// Any SMOKED event today, including the `units == 0` "none today" marker.
    public let todayHasEntry: Bool
    public let dailyLimit: Int64
    /// The rolling seven days ending today, oldest first.
    public let last7Days: [DayUnits]
    public let weekReductionUnits: Int64
    public let weekSavedMinor: Int64
    public let savedSinceSetupMinor: Int64
    public let cravingsBeatenAllTime: Int
    /// Every stage PENDING at permille 0: REDUCE has no "since last smoke" clock.
    public let stagesPreview: [StageProgress]
    public let goal: GoalProgress?

    public init(
        plan: SmokingPlan,
        todayEpochDay: Int64,
        todayUnits: Int64,
        todayHasEntry: Bool,
        dailyLimit: Int64,
        last7Days: [DayUnits],
        weekReductionUnits: Int64,
        weekSavedMinor: Int64,
        savedSinceSetupMinor: Int64,
        cravingsBeatenAllTime: Int,
        stagesPreview: [StageProgress],
        goal: GoalProgress?
    ) {
        self.plan = plan
        self.todayEpochDay = todayEpochDay
        self.todayUnits = todayUnits
        self.todayHasEntry = todayHasEntry
        self.dailyLimit = dailyLimit
        self.last7Days = last7Days
        self.weekReductionUnits = weekReductionUnits
        self.weekSavedMinor = weekSavedMinor
        self.savedSinceSetupMinor = savedSinceSetupMinor
        self.cravingsBeatenAllTime = cravingsBeatenAllTime
        self.stagesPreview = stagesPreview
        self.goal = goal
    }
}

/// One local day of REDUCE history. `units == nil` means no data that day, which is never the same
/// as zero: only an explicit "none today" marker (`units == 0`) says the user smoked nothing.
public struct DayUnits: Sendable, Equatable {
    public let epochDay: Int64
    public let units: Int64?

    public init(epochDay: Int64, units: Int64?) {
        self.epochDay = epochDay
        self.units = units
    }
}

public struct AttemptSummary: Sendable, Equatable {
    public let id: String
    /// 1-based by `startedAtMs`.
    public let ordinal: Int
    public let startedAtMs: Int64
    public let endedAtMs: Int64?
    public let durationMs: Int64
    public let slipCount: Int
    public let savedMinor: Int64
    public let cravingsBeaten: Int
    /// The maximum `durationMs`; the earliest attempt on a tie.
    public let isLongest: Bool

    public init(
        id: String,
        ordinal: Int,
        startedAtMs: Int64,
        endedAtMs: Int64?,
        durationMs: Int64,
        slipCount: Int,
        savedMinor: Int64,
        cravingsBeaten: Int,
        isLongest: Bool
    ) {
        self.id = id
        self.ordinal = ordinal
        self.startedAtMs = startedAtMs
        self.endedAtMs = endedAtMs
        self.durationMs = durationMs
        self.slipCount = slipCount
        self.savedMinor = savedMinor
        self.cravingsBeaten = cravingsBeaten
        self.isLongest = isLongest
    }
}

public struct GoalProgress: Sendable, Equatable {
    public let goal: SavingsGoal
    /// Only money accrued after the goal was created.
    public let savedTowardMinor: Int64
    public let permille: Int
    public let reached: Bool

    public init(goal: SavingsGoal, savedTowardMinor: Int64, permille: Int, reached: Bool) {
        self.goal = goal
        self.savedTowardMinor = savedTowardMinor
        self.permille = permille
        self.reached = reached
    }
}

public enum StageState: Sendable, Equatable {
    case done
    case inProgress
    case pending
}

public struct StageProgress: Sendable, Equatable {
    public let stageId: String
    public let state: StageState
    public let permille: Int
    public let remainingMs: Int64
    /// Not done, longer than 72 hours, yet the attempt itself has already run that long: a slip
    /// reset the clock, so the stage is being counted again from the last slip.
    public let countingAgain: Bool

    public init(stageId: String, state: StageState, permille: Int, remainingMs: Int64, countingAgain: Bool) {
        self.stageId = stageId
        self.state = state
        self.permille = permille
        self.remainingMs = remainingMs
        self.countingAgain = countingAgain
    }
}
