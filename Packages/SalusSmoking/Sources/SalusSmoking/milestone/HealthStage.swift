// The health-stage catalog, from `smoking-health-stages.md` in `salus-android` (the cross-platform
// contract). Ids are never renamed or renumbered; `h_9mo` was dropped on 2026-10-14 and is retired,
// so ten ids remain. Copy (titles, statements, attributions) belongs to the UI package and comes
// from the same file; this type carries only what the calculators and the scheduler read.

/// Where a stage's claim was verified.
public enum HealthStageSource: String, Sendable, Equatable {
    case who = "WHO"
    case nhs = "NHS"
}

public struct HealthStage: Sendable, Equatable {
    public let id: String
    /// Time since the last cigarette at which the stage unlocks.
    public let thresholdMinutes: Int64
    public let source: HealthStageSource
    /// Defined for combustible tobacco only; the UI says so next to the stage.
    public let combustionOnly: Bool

    public var thresholdMs: Int64 {
        thresholdMinutes * 60000
    }

    public init(id: String, thresholdMinutes: Int64, source: HealthStageSource, combustionOnly: Bool) {
        self.id = id
        self.thresholdMinutes = thresholdMinutes
        self.source = source
        self.combustionOnly = combustionOnly
    }

    /// In unlock order. A month is 30 days and a year 365 days (the stages file's own definition).
    public static let catalog: [HealthStage] = [
        HealthStage(id: "h_20m", thresholdMinutes: 20, source: .who, combustionOnly: false),
        HealthStage(id: "h_12h", thresholdMinutes: 720, source: .who, combustionOnly: true),
        HealthStage(id: "h_48h", thresholdMinutes: 2880, source: .nhs, combustionOnly: true),
        HealthStage(id: "h_72h", thresholdMinutes: 4320, source: .nhs, combustionOnly: false),
        HealthStage(id: "h_2w", thresholdMinutes: 20160, source: .who, combustionOnly: false),
        HealthStage(id: "h_1mo", thresholdMinutes: 43200, source: .who, combustionOnly: false),
        HealthStage(id: "h_1y", thresholdMinutes: 525_600, source: .who, combustionOnly: false),
        HealthStage(id: "h_5y", thresholdMinutes: 2_628_000, source: .who, combustionOnly: false),
        HealthStage(id: "h_10y", thresholdMinutes: 5_256_000, source: .who, combustionOnly: false),
        HealthStage(id: "h_15y", thresholdMinutes: 7_884_000, source: .who, combustionOnly: false)
    ]
}
