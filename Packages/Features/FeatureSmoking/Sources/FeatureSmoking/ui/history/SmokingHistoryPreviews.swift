// The twin of the `@Preview` list at the foot of `SmokingHistoryScreen.kt`: many attempts, one
// attempt, a running attempt with no entries, a REDUCE plan's money-less card and the empty state —
// light and dark across the palettes (`SalusPreviewPalettes`), plus one Dynamic Type
// `.accessibility3` render of the busiest list. The editor sheet's own previews are in
// `EventEditSheet.swift`.

import Foundation
import SalusCommon
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

private struct PreviewClock: SalusClock {
    /// 2026-03-10T12:00 Europe/Istanbul.
    static let nowMs: Int64 = 1_773_133_200_000

    func now() -> Date {
        Date(epochMilliseconds: Self.nowMs)
    }

    func timeZone() -> TimeZone {
        TimeZone(identifier: PreviewDefaults.zoneId) ?? .gmt
    }
}

private enum PreviewDefaults {
    static let zoneId = "Europe/Istanbul"
    /// 2026-03-10 as an epoch day, and its midnight in UTC.
    static let today: Int64 = 20522
    static let dayMs = HistoryDefaults.dayMs
    static let hourMs: Int64 = 3_600_000
    /// A panel is a whole screen, so the palette stack gives each one a screen's height.
    static let panelHeight: CGFloat = 820
}

private func row(
    _ id: String,
    _ type: SmokingEventType,
    hour: Int,
    units: Int? = nil,
    trigger: CravingTrigger? = nil,
    intensity: Int? = nil
) -> EventRowUi {
    EventRowUi(
        id: id,
        type: type,
        atMs: PreviewDefaults.today * PreviewDefaults.dayMs + Int64(hour - 3) * PreviewDefaults.hourMs,
        tzId: PreviewDefaults.zoneId,
        units: units,
        trigger: trigger,
        intensity: intensity
    )
}

private let previewDays = [
    DayGroupUi(
        epochDay: PreviewDefaults.today,
        rows: [
            row("a", .cravingResisted, hour: 14, trigger: .coffee, intensity: 4),
            row("b", .smoked, hour: 9, units: 1, trigger: .stress)
        ]
    ),
    DayGroupUi(
        epochDay: PreviewDefaults.today - 1,
        rows: [
            row("c", .cravingResisted, hour: 21, trigger: .afterMeal),
            row("d", .smoked, hour: 8, units: 0)
        ]
    ),
    DayGroupUi(
        epochDay: PreviewDefaults.today - 3,
        rows: [row("e", .smoked, hour: 11, units: 3, trigger: .social)]
    )
]

private func attempt(
    _ ordinal: Int,
    startDaysAgo: Int64,
    endDaysAgo: Int64?,
    slips: Int,
    longest: Bool,
    money: (saved: Int64, cravings: Int)?
) -> AttemptCardUi {
    let start = PreviewDefaults.today * PreviewDefaults.dayMs - startDaysAgo * PreviewDefaults.dayMs
    let end = endDaysAgo.map { PreviewDefaults.today * PreviewDefaults.dayMs - $0 * PreviewDefaults.dayMs }
    return AttemptCardUi(
        id: String(ordinal),
        ordinal: ordinal,
        startedAtMs: start,
        endedAtMs: end,
        durationMs: (end ?? start + startDaysAgo * PreviewDefaults.dayMs) - start,
        slipCount: slips,
        isLongest: longest,
        savedMinor: money?.saved,
        cravingsBeaten: money?.cravings,
        tzId: PreviewDefaults.zoneId
    )
}

private func manyAttempts(withMoney: Bool) -> [AttemptCardUi] {
    [
        attempt(1, startDaysAgo: 80, endDaysAgo: 71, slips: 1, longest: false, money: withMoney ? (4275, 5) : nil),
        attempt(2, startDaysAgo: 71, endDaysAgo: 53, slips: 0, longest: false, money: withMoney ? (135_000, 12) : nil),
        attempt(3, startDaysAgo: 53, endDaysAgo: nil, slips: 1, longest: true, money: withMoney ? (315_000, 17) : nil)
    ]
}

private func previewState(
    attempts: [AttemptCardUi] = manyAttempts(withMoney: true),
    days: [DayGroupUi] = previewDays
) -> SmokingHistoryUiState {
    SmokingHistoryUiState(
        loaded: true,
        journeyDays: 69,
        currencyCode: "TRY",
        attempts: attempts,
        days: days,
        todayEpochDay: PreviewDefaults.today,
        zoneId: PreviewDefaults.zoneId
    )
}

private struct HistoryPreview: View {
    let state: SmokingHistoryUiState

    var body: some View {
        NavigationStack {
            SmokingHistoryScreen(state: state, onEvent: { _ in }, onBack: {}, clock: PreviewClock())
        }
        .frame(height: PreviewDefaults.panelHeight)
    }
}

#Preview("History — many attempts") {
    SalusPreviewPalettes { HistoryPreview(state: previewState()) }
}

// One attempt, the active one, no slips yet: the longest chip sits on it.
#Preview("History — one attempt") {
    SalusPreviewPalettes {
        HistoryPreview(
            state: previewState(
                attempts: [attempt(1, startDaysAgo: 5, endDaysAgo: nil, slips: 0, longest: true, money: (23750, 3))],
                days: [DayGroupUi(epochDay: PreviewDefaults.today, rows: [row("a", .cravingResisted, hour: 10)])]
            )
        )
    }
}

// The first visit of a QUIT plan: a running attempt and no entries yet, so the explainer sits in the
// log section.
#Preview("History — one attempt, no entries") {
    SalusPreviewPalettes {
        HistoryPreview(
            state: previewState(
                attempts: [attempt(1, startDaysAgo: 2, endDaysAgo: nil, slips: 0, longest: true, money: (9500, 0))],
                days: []
            )
        )
    }
}

// REDUCE: the closed attempt is drawn from stored rows, so it has no money and no cravings.
#Preview("History — REDUCE") {
    SalusPreviewPalettes {
        HistoryPreview(
            state: previewState(
                attempts: [attempt(1, startDaysAgo: 80, endDaysAgo: 71, slips: 1, longest: true, money: nil)]
            )
        )
    }
}

#Preview("History — empty") {
    SalusPreviewPalettes { HistoryPreview(state: previewState(attempts: [], days: [])) }
}

#Preview("History — accessibility3") {
    HistoryPreview(state: previewState())
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}
