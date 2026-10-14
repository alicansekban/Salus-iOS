// The twin of the REDUCE `@Preview` list at the foot of `SmokingMainScreen.kt:311-428`: the states of
// design review screen `04` (empty, under, at the limit, over it, a plan's first week), a vape and
// a write in flight, each in light and dark across the palettes (`SalusPreviewPalettes`), and one
// Dynamic Type `.accessibility3` render of the busiest state. The week is fixed, so a picture does
// not depend on when it was taken.

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

private enum ReducePreviewDefaults {
    /// 2026-03-10 as an epoch day (Europe/Istanbul).
    static let todayEpochDay: Int64 = 20522
    static let dayMs: Int64 = 24 * 60 * 60 * 1000
    /// 2026-03-10T12:00 Europe/Istanbul.
    static let nowMs: Int64 = 1_773_133_200_000
    static let panelHeight: CGFloat = 1100
    static let dailyLimit: Int64 = 10
}

private struct PreviewReduce {
    var today: Int64
    var hasEntry: Bool?
    var week: [Int64?]
    var weekReduction: Int64 = 23
    var weekSavedMinor: Int64 = 16100
    var product = ProductType.cigarette

    var snapshot: SmokingSnapshot {
        let plan = SmokingPlan(
            id: "plan",
            mode: .reduce,
            productType: product,
            baselineUnitsPerDay: 20,
            dailyLimit: ReducePreviewDefaults.dailyLimit,
            currencyCode: "TRY",
            reason: nil,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: ReducePreviewDefaults.nowMs - 30 * ReducePreviewDefaults.dayMs,
            tzId: "Europe/Istanbul"
        )
        let stages = ["h_20m", "h_12h", "h_48h"].map {
            StageProgress(
                stageId: $0,
                state: .pending,
                permille: 0,
                remainingMs: ReducePreviewDefaults.dayMs,
                countingAgain: false
            )
        }
        return .reduce(
            ReduceSnapshot(
                plan: plan,
                todayEpochDay: ReducePreviewDefaults.todayEpochDay,
                todayUnits: today,
                todayHasEntry: hasEntry ?? (today > 0),
                dailyLimit: ReducePreviewDefaults.dailyLimit,
                last7Days: week.enumerated().map {
                    DayUnits(epochDay: ReducePreviewDefaults.todayEpochDay - 6 + Int64($0.offset), units: $0.element)
                },
                weekReductionUnits: weekReduction,
                weekSavedMinor: weekSavedMinor,
                savedSinceSetupMinor: weekSavedMinor,
                cravingsBeatenAllTime: 0,
                stagesPreview: stages,
                goal: nil
            )
        )
    }
}

private let empty = PreviewReduce(
    today: 0,
    hasEntry: false,
    week: [8, 7, 6, 7, 6, 5, nil],
    weekReduction: 19,
    weekSavedMinor: 13300
)
private let under = PreviewReduce(today: 6, week: [8, 7, 6, 7, 6, 5, 6])
private let atLimit = PreviewReduce(today: 10, week: [8, 7, 6, 7, 6, 5, 10], weekReduction: 19)
private let over = PreviewReduce(
    today: 12,
    week: [8, 7, 6, 9, 7, 5, 12],
    weekReduction: 17,
    weekSavedMinor: 11900
)

/// A plan three days old: the days before it have no data and are empty slots.
private let firstWeek = PreviewReduce(
    today: 4,
    week: [nil, nil, nil, nil, 8, 7, 4],
    weekReduction: 21,
    weekSavedMinor: 9975
)

/// A vape: money only, and no old-average marker.
private let vape = PreviewReduce(
    today: 1,
    week: [1, 1, 2, 1, 1, 1, 1],
    weekReduction: 0,
    weekSavedMinor: 4200,
    product: .vape
)

private struct ReducePreview: View {
    let reduce: PreviewReduce
    var writing = false

    var body: some View {
        NavigationStack {
            SmokingMainScreen(
                state: SmokingMainUiState(snapshot: reduce.snapshot, writing: writing),
                onEvent: { _ in }
            )
        }
        .frame(height: ReducePreviewDefaults.panelHeight)
    }
}

#Preview("Reduce — empty day") {
    SalusPreviewPalettes { ReducePreview(reduce: empty) }
}

#Preview("Reduce — under the limit") {
    SalusPreviewPalettes { ReducePreview(reduce: under) }
}

#Preview("Reduce — at the limit") {
    SalusPreviewPalettes { ReducePreview(reduce: atLimit) }
}

// Over the limit: a neutral lap and a neutral "+2" chip, never red (review R2).
#Preview("Reduce — over the limit") {
    SalusPreviewPalettes { ReducePreview(reduce: over) }
}

#Preview("Reduce — first week") {
    SalusPreviewPalettes { ReducePreview(reduce: firstWeek) }
}

#Preview("Reduce — vape") {
    SalusPreviewPalettes { ReducePreview(reduce: vape) }
}

// A write in flight: "+1", "none today" and "ready to quit" are off.
#Preview("Reduce — writing") {
    SalusPreviewPalettes { ReducePreview(reduce: empty, writing: true) }
}

// The system font scale is the axis a card layout cannot control; the busiest state has to survive it.
#Preview("Reduce — over the limit, accessibility3") {
    ReducePreview(reduce: over)
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}
