// The previews of ``HomeScreen``, split out of `HomeScreen.swift` to keep that file under the
// 500-line lint limit (see the note at its end).
//
// Ported alongside it from `HomeScreen.kt:232-361` — `populatedPreviewState()`,
// `emptyPreviewState()` and the readiness-problem copy — plus the M17 smoking card's three states.

import SalusDesignSystem
import SalusReminder
import SalusUI
import SwiftUI

@MainActor
func homePreview(_ state: HomeUiState) -> some View {
    HomeScreen(
        state: state,
        onEvent: { _ in },
        onOpenMedications: {},
        onOpenAppointments: {},
        onOpenAppointment: { _ in },
        onOpenCycle: {},
        onOpenVitals: {},
        onOpenAiSummary: {},
        onOpenReminderHealth: {},
        onOpenSmoking: {},
        onOpenSmokingSetup: {},
        onOpenCraving: {}
    )
}

/// The fixtures the previews share — `populatedPreviewState()` (`HomeScreen.kt:232-284`) and
/// `emptyPreviewState()` (`HomeScreen.kt:286-300`), value for value, plus the readiness-problem
/// state Kotlin builds by `copy` (`HomeScreen.kt:307-316`).
///
/// Everything preview-only in one block a reader can skip; internal only because the previews and
/// this fixture sit in the same file now, not the screen's.
enum HomePreviewData {
    /// `todayEpochDay = 20_680` (`HomeScreen.kt:235`), `profileName = "Alican"`,
    /// `doseProgress = 2 to 4` (`HomeScreen.kt:237-238`).
    static let loaded = HomeUiState(
        isLoading: false,
        todayEpochDay: 20680,
        greeting: .morning,
        profileName: "Alican",
        doseProgress: (taken: 2, total: 4),
        doses: [
            TodayDose(
                scheduleId: "s1",
                medicationId: "m1",
                medicationName: "Metformin",
                minuteOfDay: 8 * 60,
                doseAmount: 1,
                status: .pending
            ),
            TodayDose(
                scheduleId: "s2",
                medicationId: "m2",
                medicationName: "Vitamin D",
                minuteOfDay: 22 * 60,
                doseAmount: 1,
                status: .taken
            )
        ],
        appointments: [
            UpcomingAppointment(
                id: "a1",
                title: "Annual check-up",
                doctorName: "Dr. Lee",
                startsAtEpochMs: 1_787_212_800_000,
                timeZoneId: "Europe/Istanbul"
            )
        ],
        cycle: CycleSnapshot(cycleDay: 12, isPeriodOpen: false, averageCycleLengthDays: 28),
        vitals: VitalsSnapshot(
            latestWeightKg: 72.5,
            weightTrend: [73.4, 73.1, 72.8, 73.0, 72.5],
            latestSystolic: 120,
            latestDiastolic: 80,
            latestGlucoseMgdl: 95,
            glucoseUnit: .mgDl
        ),
        freeAiSummaryAvailable: true
    )

    /// A loaded dashboard with nothing recorded yet — every empty state at once, which is what a
    /// first run draws. No profile name, no doses: the `*_plain` greeting and no dose chip
    /// (`emptyPreviewState()`, `HomeScreen.kt:286-300`).
    static let allEmpty = HomeUiState(
        isLoading: false,
        todayEpochDay: 20680,
        greeting: .evening,
        cycle: CycleSnapshot(cycleDay: nil, isPeriodOpen: false),
        vitals: VitalsSnapshot(
            latestWeightKg: nil,
            weightTrend: [],
            latestSystolic: nil,
            latestDiastolic: nil,
            latestGlucoseMgdl: nil,
            glucoseUnit: .mgDl
        )
    )

    /// The populated root with the REDUCE card, the card's second place in the column — and the
    /// quit and discovery states beside it, so each can be read in its real surroundings.
    static let smokingReduce: HomeUiState = {
        var state = loaded
        state.smokingCard = .reduce(today: 6, limit: 10, overflow: 0)
        return state
    }()

    static let smokingQuit: HomeUiState = {
        var state = loaded
        state.smokingCard = .quit(HomeSmokingQuit(
            days: 42,
            savedMinor: 315_000,
            currency: "TRY",
            nextStagePermille: 700,
            nextStageRemainingMs: 3 * 86_400_000
        ))
        return state
    }()

    static let smokingDiscovery: HomeUiState = {
        var state = loaded
        state.smokingCard = .discovery
        return state
    }()

    /// The populated root with reminders broken — the one state that draws
    /// ``HomeReminderReadinessCard``, between the hero and the pager
    /// (`readinessProblemPreviewState()`, `HomeScreen.kt:301-316`).
    static let readinessProblem: HomeUiState = {
        var state = loaded
        state.reminderReadiness = ReminderReadinessReport(
            problems: [.notificationsOff, .backgroundRefreshOff]
        )
        return state
    }()
}

// The eight-panel fan-out every restyled surface gets (spec §7): one render per premium palette in
// both modes, so a palette regression is visible without opening the app.
#Preview("Home") {
    SalusPreviewPalettes {
        HomeScreen(
            state: HomePreviewData.loaded,
            onEvent: { _ in },
            onOpenMedications: {},
            onOpenAppointments: {},
            onOpenAppointment: { _ in },
            onOpenCycle: {},
            onOpenVitals: {},
            onOpenAiSummary: {},
            onOpenReminderHealth: {},
            onOpenSmoking: {},
            onOpenSmokingSetup: {},
            onOpenCraving: {}
        )
    }
}

#Preview("Home — loading") {
    SalusPreviewPalettes {
        HomeScreen(
            state: HomeUiState(),
            onEvent: { _ in },
            onOpenMedications: {},
            onOpenAppointments: {},
            onOpenAppointment: { _ in },
            onOpenCycle: {},
            onOpenVitals: {},
            onOpenAiSummary: {},
            onOpenReminderHealth: {},
            onOpenSmoking: {},
            onOpenSmokingSetup: {},
            onOpenCraving: {}
        )
    }
}

#Preview("Home — nothing recorded") {
    SalusPreviewPalettes {
        HomeScreen(
            state: HomePreviewData.allEmpty,
            onEvent: { _ in },
            onOpenMedications: {},
            onOpenAppointments: {},
            onOpenAppointment: { _ in },
            onOpenCycle: {},
            onOpenVitals: {},
            onOpenAiSummary: {},
            onOpenReminderHealth: {},
            onOpenSmoking: {},
            onOpenSmokingSetup: {},
            onOpenCraving: {}
        )
    }
}

#Preview("Home — smoking reduce") {
    SalusPreviewPalettes { homePreview(HomePreviewData.smokingReduce) }
}

#Preview("Home — smoking quit") {
    SalusPreviewPalettes { homePreview(HomePreviewData.smokingQuit) }
}

#Preview("Home — smoking discovery") {
    SalusPreviewPalettes { homePreview(HomePreviewData.smokingDiscovery) }
}

// The smoking card inside the real column at the largest accessibility size, where the QUIT card's
// figures stack and the REDUCE button drops under the count.
#Preview("Home — smoking quit, accessibility3") {
    homePreview(HomePreviewData.smokingQuit)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Home — reminders broken") {
    SalusPreviewPalettes {
        HomeScreen(
            state: HomePreviewData.readinessProblem,
            onEvent: { _ in },
            onOpenMedications: {},
            onOpenAppointments: {},
            onOpenAppointment: { _ in },
            onOpenCycle: {},
            onOpenVitals: {},
            onOpenAiSummary: {},
            onOpenReminderHealth: {},
            onOpenSmoking: {},
            onOpenSmokingSetup: {},
            onOpenCraving: {}
        )
    }
}

// The tab root at the largest text size the design is checked against — Kotlin's
// `@Preview(fontScale = 1.3f)` (`HomeScreen.kt:356-361`), and the step spec §7 names for iOS.
#Preview("Home — xxxLarge") {
    HomeScreen(
        state: HomePreviewData.loaded,
        onEvent: { _ in },
        onOpenMedications: {},
        onOpenAppointments: {},
        onOpenAppointment: { _ in },
        onOpenCycle: {},
        onOpenVitals: {},
        onOpenAiSummary: {},
        onOpenReminderHealth: {},
        onOpenSmoking: {},
        onOpenSmokingSetup: {},
        onOpenCraving: {}
    )
    .dynamicTypeSize(.xxxLarge)
}
