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
// sees). Do not reorder to fit a new card in. The reminder readiness card is the one thing that
// sits above the doses, and it is Android's own exception (`HomeScreen.kt:173-176`): a dose list
// is worthless when the alarm behind it cannot fire.

import SalusDesignSystem
import SalusUI
import StoreKit
import SwiftUI

/// The Home tab's root (`HomeScreen.kt:64-83`).
///
/// The template's Route: the module comes from the environment, the ViewModel is built once and
/// owned for the route's lifetime, and the stateless `HomeScreen` gets `state`, `onEvent` and the
/// six shell callbacks. `onOpenAiSummary`, Kotlin's fifth, arrives with the AI card (iOS-M10);
/// `onOpenReminderHealth` is the readiness card's, and pushes a `FeatureSettings` key, so the
/// shell is what names it.
public struct HomeRoute: View {
    private let onOpenMedications: () -> Void
    private let onOpenAppointments: () -> Void
    private let onOpenCycle: () -> Void
    private let onOpenVitals: () -> Void
    private let onOpenAiSummary: () -> Void
    private let onOpenReminderHealth: () -> Void

    @Environment(\.homeModule) private var module
    /// StoreKit's rating sheet, the twin of Play's `launchReviewFlow` (in-app review spec §3).
    /// Only a view can ask, which is why the ViewModel emits an effect rather than calling it.
    @Environment(\.requestReview) private var requestReview
    @State private var viewModel: HomeViewModel?

    /// - Parameters:
    ///   - onOpenMedications: switches to the Medications tab (`HomeNavigation.kt`, spec §4).
    ///   - onOpenAppointments: switches to the Appointments tab.
    ///   - onOpenCycle: pushes the cycle calendar onto Home's own stack.
    ///   - onOpenVitals: switches to the Vitals tab.
    ///   - onOpenAiSummary: pushes the AI health summary onto Home's own stack.
    ///   - onOpenReminderHealth: pushes Reminder health onto Home's own stack.
    public init(
        onOpenMedications: @escaping () -> Void,
        onOpenAppointments: @escaping () -> Void,
        onOpenCycle: @escaping () -> Void,
        onOpenVitals: @escaping () -> Void,
        onOpenAiSummary: @escaping () -> Void,
        onOpenReminderHealth: @escaping () -> Void
    ) {
        self.onOpenMedications = onOpenMedications
        self.onOpenAppointments = onOpenAppointments
        self.onOpenCycle = onOpenCycle
        self.onOpenVitals = onOpenVitals
        self.onOpenAiSummary = onOpenAiSummary
        self.onOpenReminderHealth = onOpenReminderHealth
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
                    onOpenVitals: onOpenVitals,
                    onOpenAiSummary: onOpenAiSummary,
                    onOpenReminderHealth: onOpenReminderHealth
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
            // Android's `LifecycleResumeEffect` (`HomeScreen.kt`): every appearance is an "open"
            // for the review prompt, and a re-read of the device state the user can change outside
            // our process (the readiness card). A foreground return reaches the ViewModel through
            // `AppForegroundSignal` instead, because `.task` does not re-run for it.
            viewModel?.onEvent(.appeared)
        }
        .onDisappear {
            viewModel?.didDisappear()
        }
        // `LaunchedEffect { viewModel.effects.collect { … } }` — fires on every append for as long
        // as this view lives; the drain's own write is the empty edge dropped below.
        .onChange(of: viewModel?.pendingEffects ?? []) { _, pending in
            guard !pending.isEmpty, let viewModel else { return }
            deliver(viewModel.consumeEffects())
        }
    }

    /// Performs the drained effects in order.
    @MainActor
    private func deliver(_ effects: [HomeEffect]) {
        for effect in effects {
            switch effect {
            case .requestReview:
                // Whether a sheet appears is StoreKit's call (Apple caps it at three a year);
                // the ViewModel has already stamped the request, so nothing is read back here.
                requestReview()
            }
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
    let onOpenAiSummary: () -> Void
    let onOpenReminderHealth: () -> Void

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
                HomeHeader(
                    todayEpochDay: state.todayEpochDay,
                    greeting: state.greeting,
                    profileName: state.profileName,
                    doseProgress: state.doseProgress
                )
                .salusEntrance(index: 0)
                sections
            }
        }
    }

    /// The inner column: a section header above each card, `xs` between them, `sm` around the lot
    /// (`HomeScreen.kt:112-141`).
    private var sections: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            // First on purpose, and it is the one card that outranks the doses
            // (`HomeScreen.kt:173-176`): a dose list is worthless when the alarm behind it cannot
            // fire. No section header — it is a warning, not a section of the dashboard. Nil while
            // the device is healthy or has not been read yet, which is the same thing here.
            if let report = state.reminderReadiness {
                HomeReminderReadinessCard(report: report, onTap: onOpenReminderHealth)
                    .salusEntrance(index: 1)
            }

            Group {
                SalusSectionHeader(title: HomeStrings.dosesTitle)
                HomeDosesCard(doses: state.doses, onEvent: onEvent, onTap: onOpenMedications)
            }
            .salusEntrance(index: 2)

            Group {
                SalusSectionHeader(title: HomeStrings.appointmentsTitle)
                HomeAppointmentsCard(appointments: state.appointments, onTap: onOpenAppointments)
            }
            .salusEntrance(index: 3)

            // Drawn only for a female profile: `cycleForProfile` returns nil for a male or missing
            // profile (`TodayModels.kt:10-11`), so `state.cycle` is nil and the card is skipped —
            // the same rule that hides the More row (`MoreViewModel.kt:64-65`). The optional is the
            // gate's, not the default state's.
            if let cycle = state.cycle {
                Group {
                    SalusSectionHeader(title: HomeStrings.cycleTitle)
                    HomeCycleCard(cycle: cycle, onTap: onOpenCycle)
                }
                .salusEntrance(index: 4)
            }

            if let vitals = state.vitals {
                Group {
                    SalusSectionHeader(title: HomeStrings.vitalsTitle)
                    HomeVitalsCard(vitals: vitals, onTap: onOpenVitals)
                }
                .salusEntrance(index: 5)
            }

            // The AI summary card, last on purpose because it summarises everything above it
            // (`HomeScreen.kt:132-138`). Always drawn once loaded, and for every user: the free
            // credit line is the only conditional, shown when the one-off free summary is still
            // unspent and the user is not entitled.
            Group {
                SalusSectionHeader(title: HomeStrings.aiSummaryTitle)
                HomeDashboardCard(onTap: onOpenAiSummary) {
                    // `Row(verticalAlignment = Top) { SalusIconBadge(AutoAwesome, trends); … Column(weight(1f)) }`
                    // (`HomeScreen.kt:251-271`). `AutoAwesome` → `sparkles` (SF Symbol twin).
                    //
                    // The greedy frame is the twin of Kotlin's `Column(modifier = Modifier.weight(1f))`
                    // (`HomeScreen.kt:258`): `HomeDashboardCard` routes through `SalusCard(onTap:)`'s
                    // Button branch, and SwiftUI centers a Button's label when it does not fill the
                    // width — without the greedy frame the text column would sit centered instead of
                    // flush left with the other cards' padding rhythm.
                    HStack(alignment: .top, spacing: 0) {
                        SalusIconBadge(systemImage: "sparkles", accent: theme.extendedColors.trends)
                        Spacer().frame(width: SalusSpacing.md)
                        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                            Text(verbatim: HomeStrings.aiSummaryDescription)
                                .font(SalusTypography.bodyMedium.font)
                                .tracking(SalusTypography.bodyMedium.tracking)
                            if state.freeAiSummaryAvailable, !state.isPremium {
                                Text(verbatim: HomeStrings.aiSummaryFreeCredit)
                                    .font(SalusTypography.bodySmall.font)
                                    .tracking(SalusTypography.bodySmall.tracking)
                                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .salusEntrance(index: 6)

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
    /// `todayEpochDay = 20_680` (`HomeScreen.kt:446`), `profileName = "Alican"`, `doseProgress = 2 to 4`
    /// (`HomeScreen.kt:457-458`).
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

    /// A loaded dashboard with nothing recorded yet — the four empty lines, which is what a first
    /// run draws. No profile name, no doses: the `*_plain` greeting and no dose ring.
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
        onOpenVitals: {},
        onOpenAiSummary: {},
        onOpenReminderHealth: {}
    )
}

#Preview("Home — loading") {
    HomeScreen(
        state: HomeUiState(),
        onEvent: { _ in },
        onOpenMedications: {},
        onOpenAppointments: {},
        onOpenCycle: {},
        onOpenVitals: {},
        onOpenAiSummary: {},
        onOpenReminderHealth: {}
    )
}

#Preview("Home — nothing recorded") {
    HomeScreen(
        state: PreviewData.allEmpty,
        onEvent: { _ in },
        onOpenMedications: {},
        onOpenAppointments: {},
        onOpenCycle: {},
        onOpenVitals: {},
        onOpenAiSummary: {},
        onOpenReminderHealth: {}
    )
}
