// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/HomeScreen.kt`
// — the Route (`:55-106`), the screen itself (`:118-190`), the hero band (`:192-212`) and the
// greeting (`:214-230`). The pager, the AI card, the appointments section, the readiness card and
// the three pager pages live beside this file, one per file, the way
// `MedicationDetailSections.swift` was split out of its screen: Kotlin can keep them private in
// two files, Swift cannot, so each is an internal `View` this package alone can name.
//
// Material → SwiftUI:
//   `Column(verticalScroll(rememberScrollState()))` → `ScrollView` + `VStack`.
//   `CircularProgressIndicator`                     → `ProgressView()`.
//   `Arrangement.spacedBy(SalusSpacing.lg)`         → `VStack(spacing: SalusSpacing.lg)`.
//   `state.reminderReadiness?.let { … }`            → `if let report = state.reminderReadiness`.
//   `SalusTopBarDefaults.Clearance` padding          — **not ported**, see below.
//
// No `Scaffold` twin, no `NavigationStack` and no toolbar of its own: the shell owns the one stack,
// its insets, the tab bar and — since Task 5 — the root toolbar with the brand tile, the tab title,
// the bell and the avatar (`App/RootNavigationStack.swift`). Home therefore draws no title, no
// avatar and no bell, and never writes `.toolbar(…, for: .tabBar)` (`CLAUDE.md`).
//
// ANDROID'S BAR CLEARANCE IS DELIBERATELY NOT PORTED. Its bars float over the content, so the tab
// root pads itself by `SalusTopBarDefaults.Clearance` / `SalusBottomBarDefaults.Clearance` inside
// the scroll (`HomeScreen.kt:136-147`). iOS's bars are the system's: they reserve their own space
// and the scroll view already carries the safe-area insets, so padding here would leave a gap under
// the navigation bar and push the hero band's gradient off the top edge.
//
// THE ORDER IS LOAD-BEARING and it is Kotlin's (`HomeScreen.kt:148-189`): hero band, then the
// reminder readiness card when reminders are in trouble, then the snapshot pager, the AI card and
// the appointments — `salusEnter` 0 to 4, the same ladder here. The M17 smoking card sits between
// the pager and the AI card (spec §3), so the ladder is 0 to 5 and the cards after it each moved
// down one (Android renumbers its `salusEnter` the same way). The readiness card sits *between*
// the greeting and the pager after owner QA (`HomeScreen.kt:152-155`): a dose list is worthless
// when the alarm behind it cannot fire, and the card only exists when there is something wrong, so
// it belongs immediately above the doses it is about.

import SalusDesignSystem
import SalusReminder
import SalusUI
import StoreKit
import SwiftUI

/// The Home tab's root (`HomeScreen.kt:64-83`).
///
/// The template's Route: the module comes from the environment, the ViewModel is built once and
/// owned for the route's lifetime, and the stateless `HomeScreen` gets `state`, `onEvent` and the
/// seven shell callbacks. `onOpenAiSummary`, Kotlin's fifth, arrives with the AI card (iOS-M10);
/// `onOpenReminderHealth` is the readiness card's, and pushes a `FeatureSettings` key, so the
/// shell is what names it; `onOpenAppointment` is the appointment card's, and pushes a
/// `FeatureAppointments` key for the same reason.
public struct HomeRoute: View {
    private let onOpenMedications: () -> Void
    private let onOpenAppointments: () -> Void
    private let onOpenAppointment: (String) -> Void
    private let onOpenCycle: () -> Void
    private let onOpenVitals: () -> Void
    private let onOpenAiSummary: () -> Void
    private let onOpenReminderHealth: () -> Void
    private let onOpenSmoking: () -> Void
    private let onOpenSmokingSetup: () -> Void
    private let onOpenCraving: () -> Void

    @Environment(\.homeModule) private var module
    /// StoreKit's rating sheet, the twin of Play's `launchReviewFlow` (in-app review spec §3).
    /// Only a view can ask, which is why the ViewModel emits an effect rather than calling it.
    @Environment(\.requestReview) private var requestReview
    @State private var viewModel: HomeViewModel?

    /// - Parameters:
    ///   - onOpenMedications: switches to the Medications tab (`HomeNavigation.kt`, spec §4).
    ///   - onOpenAppointments: switches to the Appointments tab (the section header's action).
    ///   - onOpenAppointment: pushes that appointment's detail onto Home's own stack — Kotlin's
    ///     `onOpenAppointment: (String) -> Unit` (`HomeScreen.kt:59`, `SalusApp.kt:223`).
    ///   - onOpenCycle: pushes the cycle calendar onto Home's own stack.
    ///   - onOpenVitals: switches to the Vitals tab.
    ///   - onOpenAiSummary: pushes the AI health summary onto Home's own stack.
    ///   - onOpenReminderHealth: pushes Reminder health onto Home's own stack.
    ///   - onOpenSmoking: pushes the smoking main screen onto Home's own stack. `FeatureSmoking`
    ///     names the key and features never import each other, so the shell pushes it.
    ///   - onOpenSmokingSetup: pushes the smoking setup (the discovery row's tap).
    ///   - onOpenCraving: pushes the craving flow (the QUIT card's "Canım çekti").
    public init(
        onOpenMedications: @escaping () -> Void,
        onOpenAppointments: @escaping () -> Void,
        onOpenAppointment: @escaping (String) -> Void,
        onOpenCycle: @escaping () -> Void,
        onOpenVitals: @escaping () -> Void,
        onOpenAiSummary: @escaping () -> Void,
        onOpenReminderHealth: @escaping () -> Void,
        onOpenSmoking: @escaping () -> Void,
        onOpenSmokingSetup: @escaping () -> Void,
        onOpenCraving: @escaping () -> Void
    ) {
        self.onOpenMedications = onOpenMedications
        self.onOpenAppointments = onOpenAppointments
        self.onOpenAppointment = onOpenAppointment
        self.onOpenCycle = onOpenCycle
        self.onOpenVitals = onOpenVitals
        self.onOpenAiSummary = onOpenAiSummary
        self.onOpenReminderHealth = onOpenReminderHealth
        self.onOpenSmoking = onOpenSmoking
        self.onOpenSmokingSetup = onOpenSmokingSetup
        self.onOpenCraving = onOpenCraving
    }

    public var body: some View {
        Group {
            if let viewModel {
                HomeScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onOpenMedications: onOpenMedications,
                    onOpenAppointments: onOpenAppointments,
                    onOpenAppointment: onOpenAppointment,
                    onOpenCycle: onOpenCycle,
                    onOpenVitals: onOpenVitals,
                    onOpenAiSummary: onOpenAiSummary,
                    onOpenReminderHealth: onOpenReminderHealth,
                    onOpenSmoking: onOpenSmoking,
                    onOpenSmokingSetup: onOpenSmokingSetup,
                    onOpenCraving: onOpenCraving
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

/// The stateless dashboard (`HomeScreen.kt:107-190`).
struct HomeScreen: View {
    let state: HomeUiState
    let onEvent: (HomeEvent) -> Void
    let onOpenMedications: () -> Void
    let onOpenAppointments: () -> Void
    let onOpenAppointment: (String) -> Void
    let onOpenCycle: () -> Void
    let onOpenVitals: () -> Void
    let onOpenAiSummary: () -> Void
    let onOpenReminderHealth: () -> Void
    let onOpenSmoking: () -> Void
    let onOpenSmokingSetup: () -> Void
    let onOpenCraving: () -> Void

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomeScreen.kt:194`).
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if state.isLoading {
                // `HomeScreen.kt:130-135` — the whole screen, not a per-card skeleton.
                ProgressView()
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background)
    }

    /// `Column(fillMaxSize().verticalScroll(...), spacedBy(lg))` (`HomeScreen.kt:137-189`).
    private var content: some View {
        ScrollView {
            VStack(spacing: SalusSpacing.lg) {
                hero
                    .salusEntrance(index: 0)

                // Nil while the device is healthy or has not been read yet, which is the same
                // thing here (`HomeScreen.kt:156-162`).
                if let report = state.reminderReadiness {
                    HomeReminderReadinessCard(report: report, onTap: onOpenReminderHealth)
                        .salusEntrance(index: 1)
                }

                HomeSnapshotPager(
                    state: state,
                    onEvent: onEvent,
                    onOpenMedications: onOpenMedications,
                    onOpenVitals: onOpenVitals,
                    onOpenCycle: onOpenCycle
                )
                .salusEntrance(index: 2)

                // Its own static card between the doses and the AI card (spec §3), never a pager
                // page; nil — dismissed, or not read yet — draws nothing.
                if let smokingCard = state.smokingCard {
                    HomeSmokingSection(
                        card: smokingCard,
                        onEvent: onEvent,
                        onOpenSmoking: onOpenSmoking,
                        onOpenSmokingSetup: onOpenSmokingSetup,
                        onOpenCraving: onOpenCraving
                    )
                    .salusEntrance(index: 3)
                }

                HomeAiCard(
                    newSummaryAvailable: state.freeAiSummaryAvailable,
                    onOpenAiSummary: onOpenAiSummary
                )
                .salusEntrance(index: 4)

                HomeAppointmentsSection(
                    appointments: state.appointments,
                    onOpenAppointments: onOpenAppointments,
                    onOpenAppointment: onOpenAppointment
                )
                .salusEntrance(index: 5)
            }
            // No top padding: the hero band's gradient is full-bleed and meets the navigation bar.
            // The bottom step is the last card's clearance from the tab bar, the `lg` spec §4 gives
            // every root.
            .padding(.bottom, SalusSpacing.lg)
        }
    }

    /// The band Home opens on: today's date over the greeting, with the day's dose progress
    /// (`HomeHero`, `HomeScreen.kt:192-212`).
    ///
    /// Kotlin puts `home_overline_today` in the overline and the date in `trailingOverline`
    /// (`:196-199`). `SalusHeroBand` ports one overline slot and spends it on the date, per the
    /// spec §3.3 contract the component records in its own header — so the fixed "BUGÜN" label is
    /// the one thing of the band that does not cross over (`HomeStrings.swift`'s header).
    private var hero: some View {
        SalusHeroBand(
            overline: HomeFormatting.todayDate(epochDay: state.todayEpochDay, locale: locale),
            title: greetingText
        ) {
            // The Home band has no leading avatar — M16 Task 10 added the slot for Profile.
            EmptyView()
        } chip: {
            // `chip = state.doseProgress?.let { (taken, total) -> { SalusStatusChip(…, Accent) } }`
            // (`HomeScreen.kt:200-209`). A SwiftUI slot has no null, so an absent chip is the
            // `ViewBuilder`'s own empty branch.
            if let doseProgress = state.doseProgress {
                SalusStatusChip(
                    label: HomeStrings.doseProgress(doseProgress.taken, doseProgress.total),
                    status: .accent
                )
            }
        }
    }

    /// `greetingText(greeting, profileName)` (`HomeScreen.kt:214-230`) — the formatted `%1$@` arm
    /// when a profile name exists and the `*_plain` arm otherwise. Kotlin's `profileName != null`
    /// gate is mirrored exactly: a non-nil (even blank) name takes the formatted arm.
    private var greetingText: String {
        guard let profileName = state.profileName else { return HomeStrings.greeting(state.greeting) }
        return HomeStrings.greeting(state.greeting, name: profileName)
    }
}

/// The card the cards outside the pager draw into: full width, `lg` inset
/// (`HomeCards.kt:133`, `:163`, `:208` — every one of them a `SalusCard` the section insets).
///
/// `onTap` is **optional**, and which cards pass it is the one place this screen departs from
/// Kotlin's uniform `SalusCard(onClick = …)`:
///
///   * **The readiness card and each appointment card pass it.** They contain no interactive
///     child, so the card can be the real `Button` `SalusCard(onTap:)` builds — free button
///     semantics, free VoiceOver.
///   * **A card holding a `SalusButton` does not.** A `Button` inside another `Button`'s label is
///     treated as decoration by SwiftUI: the outer one swallows the tap. Three shipped features
///     settled this — `VitalsRow` first, then `MedicationCard` and `AppointmentCard` — so such a
///     card is non-interactive and carries the "open" tap on its content through
///     ``SwiftUI/View/homeOpensCard(_:)``, with the pill as a **sibling** of that content. The two
///     targets are then disjoint by layout rather than ordered by dispatch rules. The doses pager
///     page is the one that needs it today.
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

// `HomeEmptyLine` — the one-line "nothing today" every card used to draw — left with M15: each
// empty case is now the shared `SalusEmptyState` inside its own card (`HomePager.kt:327-331`,
// `HomeCards.kt:134-138`), so the screen no longer owns an empty-state of its own.

// The previews live in `HomeScreenPreviews.swift`: this file passed SwiftLint's 500-line limit when
// the smoking card added its three states, and the fixtures are the half of it nothing ships.
