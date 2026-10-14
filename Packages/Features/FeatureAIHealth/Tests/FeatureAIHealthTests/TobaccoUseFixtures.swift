import Foundation
import SalusModel
import SalusSmoking

// Builders for the snapshots the report's tobacco section is read from. The snapshots carry saved
// money and craving counts on purpose: the tests assert none of it reaches the page.

enum TobaccoFixture {
    /// 2026-08-20.
    static let day = LocalDate(year: 2026, month: 8, day: 20).epochDay
    static let dayMs: Int64 = 86_400_000
    static let hourMs: Int64 = 3_600_000
    static let savedMinor: Int64 = 123_456
    static let istanbul = TimeZone(identifier: "Europe/Istanbul") ?? .gmt

    static func plan(_ mode: SmokingMode) -> SmokingPlan {
        SmokingPlan(
            id: "plan",
            mode: mode,
            productType: .cigarette,
            baselineUnitsPerDay: 10,
            dailyLimit: mode == .reduce ? 6 : nil,
            currencyCode: "TRY",
            reason: "private",
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: 0,
            tzId: "Europe/Istanbul"
        )
    }

    /// Started on 2026-08-10 at 21:30 UTC - already the next morning in Istanbul.
    static func quitSnapshot(slips: Int = 2) -> SmokingSnapshot {
        let start = Int64(LocalDate(year: 2026, month: 8, day: 10).epochDay) * dayMs + 21 * hourMs + 30 * 60000
        return .quit(
            QuitSnapshot(
                plan: plan(.quit),
                attemptId: "a1",
                attemptStartedAtMs: start,
                attemptElapsedMs: 9 * dayMs + 5 * hourMs,
                sinceLastSmokeMs: 3 * dayMs,
                slipCount: slips,
                unitsNotSmoked: 90,
                unitsNotSmokedToday: 4,
                savedMinor: savedMinor,
                timeRegainedMinutes: 990,
                cravingsBeaten: 5,
                cravingsBeatenAllTime: 5,
                stages: [],
                nextStage: nil,
                attempts: [],
                goal: nil
            )
        )
    }

    static func reduceSnapshot(_ units: [Int64?]) -> SmokingSnapshot {
        .reduce(
            ReduceSnapshot(
                plan: plan(.reduce),
                todayEpochDay: Int64(day),
                todayUnits: 3,
                todayHasEntry: true,
                dailyLimit: 6,
                last7Days: units.enumerated().map { DayUnits(epochDay: Int64(day - $0.offset), units: $0.element) },
                weekReductionUnits: 12,
                weekSavedMinor: savedMinor,
                savedSinceSetupMinor: savedMinor,
                cravingsBeatenAllTime: 0,
                stagesPreview: [],
                goal: nil
            )
        )
    }
}
