// The twin of the `@Preview` list at the foot of `SmokingMainScreen.kt:159-301`, `SlipSheet.kt` and
// `TriggerSheet.kt`: the three QUIT states of design review screens `03` and `06` (no slips, slips,
// first hour), a vape, and a write in flight, each in light and dark across the palettes
// (`SalusPreviewPalettes`), the sheets' bodies, and one Dynamic Type `.accessibility3` render per
// screen. The counters are frozen at the preview instant, so a picture does not depend on when it
// was taken.

import Foundation
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

private enum MainPreviewDefaults {
    /// 2026-03-10T12:00 Europe/Istanbul.
    static let nowMs: Int64 = 1_773_133_200_000
    static let minuteMs: Int64 = 60 * 1000
    static let hourMs: Int64 = 60 * minuteMs
    static let dayMs: Int64 = 24 * hourMs

    /// A panel is a whole screen, so the palette stack gives each one a screen's height.
    static let panelHeight: CGFloat = 820
}

private func previewPlan(_ product: ProductType) -> SmokingPlan {
    SmokingPlan(
        id: "plan",
        mode: .quit,
        productType: product,
        baselineUnitsPerDay: 20,
        dailyLimit: nil,
        currencyCode: "TRY",
        reason: nil,
        notificationsEnabled: true,
        eveningReminderEnabled: false,
        createdAtMs: MainPreviewDefaults.nowMs - 50 * MainPreviewDefaults.dayMs,
        tzId: "Europe/Istanbul"
    )
}

private struct PreviewQuit {
    var elapsedMs: Int64
    var sinceLastSmokeMs: Int64?
    var slips = 0
    var unitsNotSmoked: Int64
    var savedMinor: Int64
    var cravings: Int
    var regainedMinutes: Int64?
    var nextStage: StageProgress? = StageProgress(
        stageId: "h_1mo",
        state: .inProgress,
        permille: 640,
        remainingMs: 3 * MainPreviewDefaults.dayMs,
        countingAgain: false
    )
    var product = ProductType.cigarette

    var snapshot: SmokingSnapshot {
        .quit(
            QuitSnapshot(
                plan: previewPlan(product),
                attemptId: "attempt",
                attemptStartedAtMs: MainPreviewDefaults.nowMs - elapsedMs,
                attemptElapsedMs: elapsedMs,
                sinceLastSmokeMs: sinceLastSmokeMs ?? elapsedMs,
                slipCount: slips,
                unitsNotSmoked: unitsNotSmoked,
                unitsNotSmokedToday: unitsNotSmoked > 20 ? 18 : 0,
                savedMinor: savedMinor,
                timeRegainedMinutes: regainedMinutes,
                cravingsBeaten: cravings,
                cravingsBeatenAllTime: cravings,
                stages: [],
                nextStage: nextStage,
                attempts: [],
                goal: nil
            )
        )
    }
}

private let noSlips = PreviewQuit(
    elapsedMs: 42 * MainPreviewDefaults.dayMs + 6 * MainPreviewDefaults.hourMs + 12 * MainPreviewDefaults.minuteMs,
    unitsNotSmoked: 840,
    savedMinor: 315_000,
    cravings: 17,
    regainedMinutes: 9240
)

private let withSlips = PreviewQuit(
    elapsedMs: 42 * MainPreviewDefaults.dayMs + 6 * MainPreviewDefaults.hourMs + 12 * MainPreviewDefaults.minuteMs,
    sinceLastSmokeMs: 9 * MainPreviewDefaults.dayMs + 4 * MainPreviewDefaults.hourMs,
    slips: 1,
    unitsNotSmoked: 839,
    savedMinor: 314_525,
    cravings: 17,
    regainedMinutes: 9229
)

private let firstHour = PreviewQuit(
    elapsedMs: 13 * MainPreviewDefaults.minuteMs + 28000,
    unitsNotSmoked: 0,
    savedMinor: 0,
    cravings: 0,
    regainedMinutes: 0,
    nextStage: StageProgress(
        stageId: "h_20m",
        state: .inProgress,
        permille: 673,
        remainingMs: 6 * MainPreviewDefaults.minuteMs + 32000,
        countingAgain: false
    )
)

private let vape = PreviewQuit(
    elapsedMs: 12 * MainPreviewDefaults.dayMs,
    unitsNotSmoked: 12,
    savedMinor: 84000,
    cravings: 4,
    regainedMinutes: nil,
    product: .vape
)

private struct MainPreview: View {
    let quit: PreviewQuit
    var writing = false

    var body: some View {
        NavigationStack {
            SmokingMainScreen(
                state: SmokingMainUiState(snapshot: quit.snapshot, writing: writing),
                onEvent: { _ in },
                counterClock: .frozen(atMs: MainPreviewDefaults.nowMs)
            )
        }
        .frame(height: MainPreviewDefaults.panelHeight)
    }
}

#Preview("Main — no slips") {
    SalusPreviewPalettes { MainPreview(quit: noSlips) }
}

#Preview("Main — one slip") {
    SalusPreviewPalettes { MainPreview(quit: withSlips) }
}

#Preview("Main — first hour") {
    SalusPreviewPalettes { MainPreview(quit: firstHour) }
}

// A vape: "time regained" has no estimate, so it reads "—".
#Preview("Main — vape") {
    SalusPreviewPalettes { MainPreview(quit: vape) }
}

// A write in flight: both pinned buttons are off.
#Preview("Main — writing") {
    SalusPreviewPalettes { MainPreview(quit: noSlips, writing: true) }
}

// The system font scale is the axis a card layout cannot control; the busiest state has to survive it.
#Preview("Main — one slip, accessibility3") {
    MainPreview(quit: withSlips)
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}

// MARK: - Sheets

#Preview("Slip sheet — continue chosen") {
    SalusPreviewPalettes {
        SlipSheetContent(
            units: 1,
            restart: false,
            writing: false,
            onUnitsChange: { _ in },
            onRestartChange: { _ in },
            onConfirm: {},
            onDismiss: {}
        )
    }
}

// Starting over chosen and the write in flight: the confirm is off.
#Preview("Slip sheet — restart, writing") {
    SalusPreviewPalettes {
        SlipSheetContent(
            units: 3,
            restart: true,
            writing: true,
            onUnitsChange: { _ in },
            onRestartChange: { _ in },
            onConfirm: {},
            onDismiss: {}
        )
    }
}

#Preview("Slip sheet — accessibility3") {
    SlipSheetContent(
        units: 1,
        restart: false,
        writing: false,
        onUnitsChange: { _ in },
        onRestartChange: { _ in },
        onConfirm: {},
        onDismiss: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}

#Preview("Trigger sheet — nothing chosen") {
    SalusPreviewPalettes {
        TriggerSheetContent(
            trigger: nil,
            intensity: nil,
            writing: false,
            onTriggerChange: { _ in },
            onIntensityChange: { _ in },
            onSave: {},
            onSkip: {}
        )
    }
}

// A trigger and an intensity chosen: "Kaydet" is on.
#Preview("Trigger sheet — chosen") {
    SalusPreviewPalettes {
        TriggerSheetContent(
            trigger: .coffee,
            intensity: 4,
            writing: false,
            onTriggerChange: { _ in },
            onIntensityChange: { _ in },
            onSave: {},
            onSkip: {}
        )
    }
}

#Preview("Trigger sheet — accessibility3") {
    TriggerSheetContent(
        trigger: .stress,
        intensity: 2,
        writing: false,
        onTriggerChange: { _ in },
        onIntensityChange: { _ in },
        onSave: {},
        onSkip: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}
