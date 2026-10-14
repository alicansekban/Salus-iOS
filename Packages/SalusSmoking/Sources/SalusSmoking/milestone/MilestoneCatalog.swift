// The milestone lists of `smoking-domain-contract.md` §4 that the scheduler plans from. The health
// stages themselves are the stage contract (`smoking-health-stages.md`) and live in
// `HealthStage.catalog`; this type only re-exposes them next to the other lists. Twin of Android's
// `MilestoneCatalog.kt`.

public enum MilestoneCatalog {
    private static let yearDays: Int64 = 365
    private static let fixedDays: [Int64] = [1, 3, 7, 14, 30, 60, 100, 180, yearDays]

    public static let healthStages: [HealthStage] = HealthStage.catalog

    /// Units not smoked; the list ends at 5 000 (contract §4).
    public static let unitMilestones: [Int64] = [100, 500, 1000, 5000]

    /// Every day milestone up to and including `days`: the fixed list, then every 365 days with no
    /// upper end, so a quit that passed the last health stage (15 years) still has milestones.
    public static func dayMilestones(upTo days: Int64) -> [Int64] {
        var milestones = fixedDays.filter { $0 <= days }
        var yearly = 2 * yearDays
        while yearly <= days {
            milestones.append(yearly)
            yearly += yearDays
        }
        return milestones
    }
}
