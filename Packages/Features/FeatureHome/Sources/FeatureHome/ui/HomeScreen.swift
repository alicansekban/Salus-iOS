// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomeScreen.kt`
// — the Route (`:64-83`), the screen itself (`:85-143`) and the two helpers every card shares
// (`DashboardCard` `:406-418`, `EmptyLine` `:420-427`). The five cards live beside this file, one
// per file, the way `MedicationDetailSections.swift` was split out of its screen: Kotlin can keep
// them private in one file, Swift cannot, so each is an internal `View` this package alone can
// name.
//
// Material → SwiftUI:
//   `Column(verticalScroll(rememberScrollState()))` → `ScrollView` + `VStack`.
//   `CircularProgressIndicator`                     → `ProgressView()`.
//   `Arrangement.spacedBy(SalusSpacing.xs)`         → `VStack(spacing: SalusSpacing.xs)`.
//   `Spacer(Modifier.height(sm))`                   → `Spacer().frame(height: sm)`.
//   `state.cycle?.let { … }`                        → `if let cycle = state.cycle { … }`.
//
// No `Scaffold` twin and no `NavigationStack`: the shell owns the one stack, its insets and the
// tab bar, and a feature never writes `.toolbar(…, for: .tabBar)` (`CLAUDE.md`).
//
// THE ORDER IS LOAD-BEARING and it is Kotlin's, header first and doses immediately after
// (`HomeScreen.kt:107-141`, whose comment says today's doses must stay the first thing the user
// sees). Do not reorder to fit a new card in.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The Home tab's root (`HomeScreen.kt:64-83`).
///
/// The template's Route: the module comes from the environment, the ViewModel is built once and
/// owned for the route's lifetime, and the stateless `HomeScreen` gets `state`, `onEvent` and the
/// four shell callbacks. `onOpenAiSummary`, Kotlin's fifth, is absent along with the AI card — see
/// the note in `sections` (plan ruling 1).
public struct HomeRoute: View {
    private let onOpenMedications: () -> Void
    private let onOpenAppointments: () -> Void
    private let onOpenCycle: () -> Void
    private let onOpenVitals: () -> Void

    @Environment(\.homeModule) private var module
    @State private var viewModel: HomeViewModel?

    /// - Parameters:
    ///   - onOpenMedications: switches to the Medications tab (`HomeNavigation.kt`, spec §4).
    ///   - onOpenAppointments: switches to the Appointments tab.
    ///   - onOpenCycle: pushes the cycle calendar onto Home's own stack.
    ///   - onOpenVitals: switches to the Vitals tab.
    public init(
        onOpenMedications: @escaping () -> Void,
        onOpenAppointments: @escaping () -> Void,
        onOpenCycle: @escaping () -> Void,
        onOpenVitals: @escaping () -> Void
    ) {
        self.onOpenMedications = onOpenMedications
        self.onOpenAppointments = onOpenAppointments
        self.onOpenCycle = onOpenCycle
        self.onOpenVitals = onOpenVitals
    }

    public var body: some View {
        Group {
            if let viewModel {
                HomeScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onOpenMedications: onOpenMedications,
                    onOpenAppointments: onOpenAppointments,
                    onOpenCycle: onOpenCycle,
                    onOpenVitals: onOpenVitals
                )
            } else {
                // A dropped injection draws the spinner rather than a half-built graph — the
                // reason `homeModule` is optional (`HomeModule.swift`'s `@Entry` note).
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let module else { return }
            // Built once and never recreated: the ViewModel owns the observation of four tables.
            if viewModel == nil {
                viewModel = module.makeHomeViewModel()
            }
            // Plan ruling 3, and it is what `SharingStarted.WhileSubscribed(5_000)` buys on Android
            // (`HomeViewModel.kt:41-45`): `TodayRepositoryImpl.observeTodayOverview()` captures
            // today, the current minute and "now" **once, when the stream is created**, so a
            // returning tab has to re-create it or the dashboard keeps yesterday's window.
            // SwiftUI re-runs `.task` on every appearance, which is exactly that re-subscribe.
            //
            // On the FIRST appearance this restarts the observation `init` has just opened —
            // one extra `cancel` + re-subscribe before anything has been drawn. Deliberate: the
            // alternative is a branch that decides whether the capture is fresh enough, and a
            // wrong answer there is a stale dashboard, where a wrong answer here is one redundant
            // query on a screen that is already showing its spinner.
            viewModel?.restartObservation()
        }
    }
}

/// The stateless dashboard (`HomeScreen.kt:86-143`).
struct HomeScreen: View {
    let state: HomeUiState
    let onEvent: (HomeEvent) -> Void
    let onOpenMedications: () -> Void
    let onOpenAppointments: () -> Void
    let onOpenCycle: () -> Void
    let onOpenVitals: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Group {
            if state.isLoading {
                // `HomeScreen.kt:95-100` — the whole screen, not a per-card skeleton.
                ProgressView()
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
    }

    /// `Column(fillMaxSize().verticalScroll(...))` (`HomeScreen.kt:102-142`).
    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                HomeHeader(todayEpochDay: state.todayEpochDay, greeting: state.greeting)
                sections
            }
        }
    }

    /// The inner column: a section header above each card, `xs` between them, `sm` around the lot
    /// (`HomeScreen.kt:112-141`).
    private var sections: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            SalusSectionHeader(title: HomeStrings.dosesTitle)
            HomeDosesCard(doses: state.doses, onEvent: onEvent, onTap: onOpenMedications)

            SalusSectionHeader(title: HomeStrings.appointmentsTitle)
            HomeAppointmentsCard(appointments: state.appointments, onTap: onOpenAppointments)

            // Always drawn once loaded, and for every user: Android gates the cycle card on nothing
            // (plan ruling 9). The optional is the default state's, not a per-user condition.
            if let cycle = state.cycle {
                SalusSectionHeader(title: HomeStrings.cycleTitle)
                HomeCycleCard(cycle: cycle, onTap: onOpenCycle)
            }

            if let vitals = state.vitals {
                SalusSectionHeader(title: HomeStrings.vitalsTitle)
                HomeVitalsCard(vitals: vitals, onTap: onOpenVitals)
            }

            // THE AI SUMMARY SECTION IS ABSENT, and that is plan ruling 1. Android draws a fifth
            // header and an `AiSummaryCard` here (`HomeScreen.kt:132-138`), last on purpose because
            // it summarises everything above it. Its two dependencies — `AiSummaryRepository` and
            // `PremiumRepository` — are M0 stubs on iOS, so the card would open a screen that does
            // not exist and promise a free credit nothing can spend. It arrives with the milestone
            // that brings the AI summary screen (iOS-M10), together with `onOpenAiSummary`,
            // `home_ai_summary_title/description/free_credit` and the `SalusSectionHeader` above
            // it. `HomeUiState.freeAiSummaryAvailable` and `isPremium` are already carried, so this
            // is the only place that changes. Recorded as divergence (f).

            // `Spacer(Modifier.height(sm))` (`HomeScreen.kt:140`).
            Spacer().frame(height: SalusSpacing.sm)
        }
        .padding(.vertical, SalusSpacing.sm)
    }
}

/// The card every section draws into: full width, `lg` inset (`HomeScreen.kt:406-418`).
///
/// `onTap` is **optional**, and which cards pass it is the one place this screen departs from
/// Kotlin's uniform `SalusCard(onClick = …)`:
///
///   * **Cycle and vitals pass it.** They contain no interactive child, so the card can be the
///     real `Button` `SalusCard(onTap:)` builds — free button semantics, free VoiceOver.
///   * **Doses and appointments do not.** Each contains a `SalusPillButton`, and a `Button` inside
///     another `Button`'s label is treated as decoration by SwiftUI: the outer one swallows the
///     tap. Three shipped features settled this — `VitalsRow` first, then `MedicationCard` and
///     `AppointmentCard` — so those two cards are non-interactive here and carry the "open" tap on
///     their content through ``SwiftUI/View/homeOpensCard(_:)``, with the pill as a **sibling** of
///     that content. The two targets are then disjoint by layout rather than ordered by dispatch
///     rules.
struct HomeDashboardCard<Content: View>: View {
    private let onTap: (() -> Void)?
    private let content: Content

    init(onTap: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        SalusCard(onTap: onTap) { content }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SalusSpacing.lg)
    }
}

extension View {
    /// Makes this the part of a non-interactive ``HomeDashboardCard`` that opens it.
    ///
    /// The twin of what `SalusCard(onClick =)` gives Compose for free, for the two cards that
    /// cannot be a `Button` (see ``HomeDashboardCard``). `contentShape` makes the whole proposed
    /// area tappable and not just the drawn glyphs; the three accessibility modifiers put back
    /// what a bare gesture costs — a tap gesture is invisible to VoiceOver, where Compose's
    /// clickable card is announced as a button. `MedicationCard.swift:39-51`, line for line.
    func homeOpensCard(_ action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
}

/// Every empty case on this screen is one line (`HomeScreen.kt:420-427`).
///
/// `SalusEmptyState` is deliberately not used: a dashboard card that says "nothing today" is a
/// statement, not a dead end with a call to action, and Android says the same thing the same way.
struct HomeEmptyLine: View {
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // `verbatim:` because the caller hands over a resolved string; the plain initializer would
        // treat it as a `LocalizedStringKey` and look it up in the *main* bundle.
        Text(verbatim: text)
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

/// The fixtures the previews share — `HomeScreen.kt:440-496`, value for value, plus an all-empty
/// state Kotlin has no twin for (Compose renders one preview; SwiftUI gets one per case).
///
/// A `private enum` so everything preview-only is one block a reader can skip.
private enum PreviewData {
    /// `todayEpochDay = 20_680` (`HomeScreen.kt:446`).
    static let loaded = HomeUiState(
        isLoading: false,
        todayEpochDay: 20680,
        greeting: .morning,
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

    /// A loaded dashboard with nothing recorded yet — the four empty lines, which is what a first
    /// run draws.
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
}

#Preview("Home") {
    HomeScreen(
        state: PreviewData.loaded,
        onEvent: { _ in },
        onOpenMedications: {},
        onOpenAppointments: {},
        onOpenCycle: {},
        onOpenVitals: {}
    )
}

#Preview("Home — loading") {
    HomeScreen(
        state: HomeUiState(),
        onEvent: { _ in },
        onOpenMedications: {},
        onOpenAppointments: {},
        onOpenCycle: {},
        onOpenVitals: {}
    )
}

#Preview("Home — nothing recorded") {
    HomeScreen(
        state: PreviewData.allEmpty,
        onEvent: { _ in },
        onOpenMedications: {},
        onOpenAppointments: {},
        onOpenCycle: {},
        onOpenVitals: {}
    )
}
