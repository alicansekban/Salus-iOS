import FeatureAIHealth
import FeatureAppointments
import FeatureCycle
import FeatureHome
import FeatureMedications
import FeatureOnboarding
import FeaturePaywall
import FeatureSettings
import FeatureTrends
import FeatureVitals
import SalusDesignSystem
import SalusModel
import SalusNavigation
import SalusPremium
import SalusUI
import SwiftUI

/// The five-tab shell — the iOS twin of `app/src/main/kotlin/com/alicansekban/salus/ui/SalusApp.kt`.
///
/// It owns three jobs, exactly as the Compose shell does:
///
///  1. **It is the only thing that mutates the back stack.** `Navigator` publishes commands; this
///     view applies them to `TabBackStacks` (`SalusApp.kt:89-99`).
///  2. **It resolves the theme once**, from the stored mode and the system appearance, and injects
///     it — the `MaterialTheme(...)` wrapper of `Theme.kt:99-104`, spelled as an environment value.
///  3. **It hosts one navigation stack per tab.** Android flattens its per-tab stacks into the one
///     list `NavDisplay` renders; SwiftUI gives each tab its own `NavigationStack`.
///  4. **It mounts the app's one snackbar host** (`SalusApp.kt:106-136`) — over the selected tab's
///     content, above the tab bar — so an undo survives the screen the delete was triggered from.
///  5. **It draws the two gates and the splash-hold** (`MainActivity.kt:47-107`, iOS-M8 T11).
///     Android's are in `MainActivity` rather than in `SalusApp.kt` because that is where its
///     splash screen and its `BiometricPrompt` live; on iOS `SalusApp` is a `Scene` with no view of
///     its own, so the shell's outermost view is the only place an overlay *over* the `TabView` can
///     be written. See `RootGates` for the order and why each flag is what it is.
///
/// `@MainActor` on the struct rather than only on `body`: `TabBackStacks` is a main-actor
/// `@Observable`, and a stored-property initializer runs outside `body`'s isolation.
@MainActor
struct RootView: View {
    /// The graph `SalusApp` built and injected. Nothing here reaches for a global.
    @Environment(AppCompositionRoot.self) private var root

    /// What the OS currently reports — the iOS shape of Compose's `isSystemInDarkTheme()`, which is
    /// what Android's `SalusTheme` defaults `darkTheme` to (`Theme.kt:87`).
    @Environment(\.colorScheme) private var systemColorScheme

    /// One `NavigationPath` per tab, so a tab switch preserves what was pushed inside each
    /// (`SalusApp.kt:87`: `remember { TopLevelBackStack(HomeKey) }`).
    @State private var backStacks = TabBackStacks<RootTab>(initial: .home)

    /// The stored `theme_mode`, mirrored out of `SalusPreferencesDataSource` by the `.task` below.
    /// Seeded with the same default the store returns before anything has been written.
    @State private var themeMode: ThemeMode = .default

    /// The stored `secure_screen_enabled`, mirrored out of the **same** stream and the same loop as
    /// `themeMode` above — one subscription, two values, because `userSettings` publishes the whole
    /// `UserSettings` and a second `for await` over it would only cost a second observer.
    ///
    /// It is the *masking* half of spec §6.2 (global constraints, ruling 2): the app-switcher blur
    /// `.secureScreen(maskingEnabled:)` draws is on whatever this says. Seeded `false`, which is
    /// `UserSettings`' own default (`Settings.kt:21`) and the safe direction while the store answers
    /// — a curtain that appears a frame late is a flicker, one that never lifts is a broken app.
    @State private var secureScreenEnabled = false

    /// The stored `premium_theme` — what the user *selected*. `effectivePremiumTheme` folds it
    /// with `premiumStatus` to produce what they are *entitled* to draw (iOS-M9).
    @State private var premiumTheme: PremiumTheme = .classic

    /// The current entitlement from `premiumRepository.status`. Free → `.classic` regardless of
    /// `premiumTheme`; entitled → the selected palette (`EffectiveTheme.kt:13`).
    @State private var premiumStatus: PremiumStatus = .free

    /// The stored `onboarding_completed`, mirrored out of the same one loop as the two above — and
    /// the only one of the three that is an **optional**, because here `nil` is a state rather than
    /// a missing value: "Null until DataStore has answered; the splash stays up so Home never
    /// flashes" (`MainActivity.kt:44-45`, whose `MutableStateFlow<Boolean?>(null)` this is).
    ///
    /// A default of `false` would open onboarding for a frame on every launch; a default of `true`
    /// would show Home for a frame on a first launch. Ruling 3 takes the third option and draws
    /// neither — see ``splashHold`` and `RootGates`.
    @State private var onboardingCompleted: Bool?

    /// The appointment detail a tapped reminder last pushed, and how deep the appointments stack was
    /// left by that push — the two halves of "is this key still on top?".
    ///
    /// `NavigationPath` is opaque: it exposes a count and nothing else, so the only way to know what
    /// is on top of a stack is to remember what was put there. Hence a memo rather than a read.
    @State private var reminderPushedAppointment: PushedAppointmentDetail?

    /// How deep Home's stack was left by the cycle calendar a tapped reminder last pushed — the
    /// cycle half of the same "is this key still on top?" question.
    ///
    /// One `Int` rather than a pair because `CycleKey` carries no payload: there is only ever one
    /// calendar, so the depth alone identifies it.
    @State private var reminderPushedCycleDepth: Int?

    /// `Theme.kt:99-104`. The premium palette is resolved from entitlement via
    /// `effectivePremiumTheme` — a free user draws `.classic`, a lapsed selection survives.
    private var theme: SalusResolvedTheme {
        SalusTheme.resolve(
            mode: themeMode,
            premiumTheme: effectivePremiumTheme(premiumStatus, premiumTheme),
            systemIsDark: systemColorScheme == .dark
        )
    }

    /// The tab-bar selection, written through `switchTopLevel` — the holder's `selection` is
    /// `private(set)`, so that method is the only door, exactly as `TopLevelBackStack.topLevelKey`
    /// moves only through Kotlin's `switchTopLevel` (`TopLevelBackStack.kt:18, 30-35`). A press on
    /// the tab that is already selected changes nothing, on both platforms.
    private var selection: Binding<RootTab> {
        Binding(
            get: { backStacks.selection },
            set: { backStacks.switchTopLevel($0) }
        )
    }

    /// What `RootGates` says is covering the app right now, recomputed on every update out of the
    /// three values that decide it. A computed property rather than stored state: two of the three
    /// live on the `@Observable` `AppLockManager`, so reading them here is also what subscribes
    /// this view to them.
    private var gates: RootGates {
        RootGates.resolve(
            onboardingCompleted: onboardingCompleted,
            lockHasReadSetting: root.appLockManager.hasReadSetting,
            isLocked: root.appLockManager.isLocked
        )
    }

    var body: some View {
        ZStack {
            tabs.liveLocale()
            // The gates, in Android's z-order — later is on top. Overlays over the `TabView` and
            // outside every `NavigationStack`, keeping back stacks and deep links intact.
            if gates.showsLock {
                AppLockGate(manager: root.appLockManager)
            }
            if gates.showsOnboarding {
                OnboardingRoute()
                    .environment(\.onboardingModule, root.onboardingModule)
            }
            // Topmost, only while nothing has been decided.
            if gates.holdsSplash {
                SplashHoldCover()
            }
            // The paywall, above the TabView and outside every NavigationStack — the same z-order
            // the gates use. Driven by `paywallController.request`.
            PaywallHost()
        }
        .preferredColorScheme(themeMode.preferredColorScheme)
        // Out here rather than on the `TabView` so the splash-hold cannot change the `ZStack`'s
        // identity — a branch swapped at the top would tear down every subscription below.
        .onChange(of: root.reminderOpenRouter.pending, initial: true) { _, _ in openTappedReminder() }
        .task { await observeUserSettings() }
        .task { await observePremiumStatus() }
        .task { await observeNavigationCommands() }
        .task { await root.logSeededProfile() }
        // The one-time premium intro, after onboarding resolves (`IntroPaywallGate.kt:39`).
        .task { await root.introPaywallGate.run() }
        // The §6.2 secure screen, applied over the `TabView` and outside every `NavigationStack`:
        // the always-on app-switcher blur, plus the screenshot mask and the capture hide that
        // `secure_screen_enabled` adds. Both gates and the splash-hold are BELOW this line, so the
        // curtain is drawn over them too (`m8-manual-qa.md` §2.8).
        .secureScreen(maskingEnabled: secureScreenEnabled)
        // Resolved once, read everywhere below — no screen takes a `theme:` parameter. Outermost on
        // purpose, and it is the one modifier that stays outside `.secureScreen`: an overlay reads
        // the environment its host was *handed*, not the one its host writes, so a curtain applied
        // after this line would draw the default palette over a dark-themed app.
        .salusTheme(theme)
    }

    /// The five-tab shell itself — everything `SalusApp.kt:106-136` draws, with the gates above it
    /// rather than inside it.
    private var tabs: some View {
        TabView(selection: selection) {
            ForEach(RootTab.allCases) { tab in
                tabStack(for: tab)
                    // `Text(verbatim:)`: the title is a resolved `AppStrings` value (`c726e22`).
                    .tabItem {
                        Label { Text(verbatim: tab.label) } icon: { Image(systemName: tab.symbolName) }
                    }
                    .tag(tab)
            }
        }
        // The selected tab's accent. `primary` rather than a hand-picked highlight, so a premium
        // palette repaints the tab bar for free the moment entitlement is wired up: `primary` is
        // one of the eight roles `withPremiumAccent` swaps.
        .tint(theme.colorScheme.primary)
        // Android's `NavigationBar` sits on `surfaceContainer` by default; pin the same role here
        // instead of inheriting the platform's translucent material, which would sample whatever is
        // behind it and drift from the token.
        .toolbarBackground(theme.colorScheme.surfaceContainer, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    /// One stack per tab. No `navigationDestination` written here on purpose: `TabBackStacks.push`
    /// puts the feature's **concrete** key into the path, so each feature package registers its own
    /// `navigationDestination(for:)` in a `…Destinations()` modifier applied here — the twin of
    /// Android's `vitalsEntries` / `homeEntries` `NavEntry` providers. The shell therefore never
    /// names a key; `medicationsDestinations()`, `vitalsDestinations()`,
    /// `appointmentsDestinations()`, `settingsDestinations()` and `cycleDestinations()` below are
    /// those modifiers — `settingsDestinations()` arrived with the More hub in iOS-M8, which is
    /// what retired the placeholder that used to stand in for it. Home registers no modifier of its
    /// own: its cards push another feature's key or switch tab, so `FeatureHome` ships no
    /// `homeDestinations()` (plan ruling 8).
    ///
    /// `cycleDestinations()` is applied twice, which is the shape a feature without a tab takes:
    /// cycle is reached from the More list and from a tapped cycle reminder, which lands on Home
    /// (iOS-M6 rulings 1 and 2), so both of those stacks have to know how to render `CycleKey`.
    /// SwiftUI resolves `navigationDestination(for:)` per stack, so registering it on one would
    /// leave the other pushing a key nothing draws.
    private func tabStack(for tab: RootTab) -> some View {
        navigationStack(for: tab)
            // Android's `showBottomBar`, one for one (`SalusApp.kt:133-136`): "the bottom bar only
            // exists while a top-level destination is visible; pushed detail/editor screens get the
            // full height." Kotlin asks whether the key on top of the flattened stack is top-level;
            // here each tab holds its own path, so the same question is `isAtRoot(tab)`.
            //
            // The rule lives here and only here — a feature screen never writes
            // `.toolbar(…, for: .tabBar)` itself, so every screen pushed by every future feature
            // inherits it. Placed on the *stack*, not inside its root: a value applied to the root
            // view describes the root view, and SwiftUI resets it for a pushed destination, so the
            // bar came back the moment anything was pushed. Applied to the stack it describes
            // whatever the stack is currently showing, which is what the flag is about.
            //
            // System animation on purpose: no `withAnimation`, no transition — the bar slides the
            // way every other iOS tab bar does.
            .toolbar(backStacks.isAtRoot(tab) ? .visible : .hidden, for: .tabBar)
            // The app's one snackbar host, applied *inside* the tab's content region rather than
            // over the whole window. That placement is the whole fix: the tab bar's inset exists
            // only in here, so an overlay laid out against it lands above the bar (and above the
            // home indicator, in either orientation) — the position Compose's `Scaffold` gives
            // `SnackbarHost` above the `NavigationBar`. Over the window it landed *in* the tab-bar
            // band, hid it, and swallowed tab taps with its own dismiss gesture.
            .overlay(alignment: .bottom) { snackbarHost(for: tab) }
    }

    /// Exactly one host exists at a time: `backStacks.selection` is a single value, so the four
    /// unselected tabs build the empty branch. That keeps the shell rule ("one host, mounted by the
    /// shell") while still letting the host sit inside a tab's safe area — the two properties are
    /// otherwise in conflict, because the only place that knows the tab-bar inset is a tab.
    ///
    /// The controller lives on `AppCompositionRoot`, not here, so switching tabs mid-undo re-creates
    /// this view without touching the queue: the snackbar keeps its remaining time and its action,
    /// and only replays its entrance transition in the tab that now shows it.
    @ViewBuilder
    private func snackbarHost(for tab: RootTab) -> some View {
        if tab == backStacks.selection {
            SalusSnackbarHost(controller: root.snackbar)
        }
    }

    @ViewBuilder
    private func navigationStack(for tab: RootTab) -> some View {
        switch tab {
        case .medications:
            NavigationStack(path: backStacks.binding(for: tab)) {
                MedicationsRoute()
                    .medicationsDestinations()
            }
            // On the stack, not inside its root: a pushed `MedicationDetailKey` or
            // `MedicationEditorKey` destination is rendered by the stack, so an environment value
            // set on the root view would not reach either.
            .environment(\.medicationsModule, root.medicationsModule)

        case .vitals:
            NavigationStack(path: backStacks.binding(for: tab)) {
                VitalsRoute(onOpenTrends: {
                    // Trends belongs to `FeatureTrends`; the shell sees every key, so it pushes
                    // `TrendsKey` through the navigator. The destination is `trendsDestinations()`.
                    root.navigator.navigate(TrendsKey())
                })
                .vitalsDestinations()
                .trendsDestinations()
            }
            // Applied to the stack, not inside its root: a pushed `WeightEditorKey` destination is
            // rendered by the stack, so an environment value set on the root view would not reach
            // the editor.
            .environment(\.vitalsModule, root.vitalsModule)
            .environment(\.trendsModule, root.trendsModule)

        case .appointments:
            NavigationStack(path: backStacks.binding(for: tab)) {
                AppointmentsRoute()
                    .appointmentsDestinations()
            }
            // On the stack, not inside its root: a pushed `AppointmentDetailKey` or
            // `AppointmentEditorKey` destination is rendered by the stack, so an environment value
            // set on the root view would not reach either.
            .environment(\.appointmentsModule, root.appointmentsModule)

        case .more:
            NavigationStack(path: backStacks.binding(for: tab)) {
                // The settings hub (M8 T6). The three cross-feature hops are shell callbacks
                // (`onOpenCycle`/`onOpenDoctorReport`/`onOpenTrends`); the three same-feature
                // destinations (`ReminderHealthKey`/`AboutKey`/`ProfileKey`) are registered by
                // `settingsDestinations()` and the `MoreRoute` pushes them through its module's
                // `navigator`, the same way Kotlin's `MoreRoute` reaches `koinInject<Navigator>()`.
                //
                // `appLockPrompt` is the shell-owned biometric evaluation the enable-re-auth
                // interception calls (ruling 4 — the shell owns the `LAContext`, the same one
                // `AppLockScreen` reaches through `makeLockPrompt()`).
                MoreRoute(
                    onOpenCycle: { root.navigator.navigate(CycleKey()) },
                    onOpenDoctorReport: {
                        // The doctor report lives in `FeatureAIHealth` (iOS-M10 Task 6). Its key is
                        // this feature's to name, so the shell pushes it through the navigator the
                        // same way it pushes `CycleKey` above — registering the destination is
                        // `aiHealthDestinations()` below.
                        root.navigator.navigate(DoctorReportKey())
                    },
                    onOpenTrends: {
                        // Trends lives in `FeatureTrends` (iOS-M11); pushed through the navigator the
                        // way `DoctorReportKey` is. The destination is `trendsDestinations()` below.
                        root.navigator.navigate(TrendsKey())
                    },
                    appLockPrompt: makeLockPrompt()
                )
                .settingsDestinations()
                .cycleDestinations()
                // The AI health destinations — `AiSummaryKey` is pushed from Home, `DoctorReportKey`
                // from More (this stack), so both register here.
                .aiHealthDestinations()
                // The trends screen is pushed from More's row, so this stack registers it.
                .trendsDestinations()
            }
            // On the stack, not inside its root — a pushed `ReminderHealthKey`, `AboutKey`,
            // `ProfileKey` or `CycleKey` destination is rendered by the stack, so an environment
            // value set on the root would not reach it.
            .environment(\.settingsModule, root.settingsModule)
            .environment(\.cycleModule, root.cycleModule)
            .environment(\.aiHealthModule, root.aiHealthModule)
            .environment(\.trendsModule, root.trendsModule)

        case .home:
            NavigationStack(path: backStacks.binding(for: tab)) {
                HomeRoute(
                    onOpenMedications: { backStacks.switchTopLevel(.medications) },
                    onOpenAppointments: { backStacks.switchTopLevel(.appointments) },
                    // Cycle is the one card that pushes instead of switching tabs: it has no tab of
                    // its own (iOS-M6 ruling 1), so it opens on Home's own stack. Through the
                    // navigator rather than `backStacks.push`, because the shell is the only thing
                    // that mutates a back stack and a card is not the shell — the More row does the
                    // same with the same key.
                    onOpenCycle: { root.navigator.navigate(CycleKey()) },
                    onOpenVitals: { backStacks.switchTopLevel(.vitals) },
                    // The AI summary lives in `FeatureAIHealth` (iOS-M10 Task 5). Its key is that
                    // feature's to name, so the shell pushes it through the navigator the same way
                    // it pushes `CycleKey` above — registering the destination is
                    // `aiHealthDestinations()` below.
                    onOpenAiSummary: { root.navigator.navigate(AiSummaryKey()) }
                )
                // `cycleDestinations()` stays on this stack because two things now push `CycleKey`
                // onto it: the card above, and a tapped cycle reminder, which `RootTab.hosting`
                // routes to Home (iOS-M6 ruling 2). Neither ordering stacks two calendars —
                // `pushCycleCalendar` memoizes the depth its push leaves, and
                // `observeNavigationCommands` keeps that memo true for the card's push as well: a
                // `CycleKey` navigate seeds it, any other key clears it. So the two orderings that
                // can actually happen — reminder-then-reminder and card-then-reminder — both no-op
                // the second push, while a push or pop in between moves the depth and lets the
                // calendar open again. The card's own push is unguarded, and needs no guard: while
                // a calendar is on top of Home the card is not on screen to tap.
                //
                // There is no `homeDestinations()`: the dashboard pushes nothing of its own — every
                // card either switches tab or pushes another feature's key (plan ruling 8).
                .cycleDestinations()
                // The AI summary card pushes `AiSummaryKey` onto this stack, so the destination is
                // registered here.
                .aiHealthDestinations()
            }
            // On the stack, not inside its root — the pushed `CycleKey` and `AiSummaryKey`
            // destinations are rendered by the stack, so an environment value set on the root view
            // would not reach either.
            .environment(\.homeModule, root.homeModule)
            .environment(\.cycleModule, root.cycleModule)
            .environment(\.aiHealthModule, root.aiHealthModule)
        }
        // No `default:` clause on purpose: `RootTab` lives in this target, so an exhaustive switch
        // is what makes a sixth tab added to the enum land as a compile error here rather than as a
        // silently empty stack.
    }

    /// Shows a tapped reminder's occurrence: the tab that owns it, then the screen itself.
    ///
    /// iOS-M3 routed to the tab root; M4 pushes the appointment detail and M6 the cycle calendar.
    /// The push has to follow the tab switch, because `TabBackStacks.push` appends to whichever
    /// stack is *selected*.
    ///
    /// **An iOS-only behaviour** (global constraints, decision 2). Android's
    /// `ReminderNotificationPresenter` builds a launcher intent and stops there, so a tapped
    /// appointment reminder lands on whatever screen the app was last on; the ref carries the
    /// entity id on both platforms, and iOS spends it.
    private func openTappedReminder() {
        guard let ref = root.reminderOpenRouter.consume() else { return }
        backStacks.switchTopLevel(RootTab.hosting(ref.type))
        switch ref.type {
        case .appointment:
            pushAppointmentDetail(id: ref.entityId)
        // The calendar itself, onto Home — `RootTab.hosting(.cyclePeriod)` is `.home`, because
        // cycle has no tab of its own (iOS-M6 ruling 1). `CycleKey` carries no payload, so unlike
        // the appointment arm above there is nothing to look up: the ref's `entityId` names the
        // period, and the calendar shows every period there is. The push is memoized all the same,
        // for the reason `pushAppointmentDetail` is: `switchTopLevel` is a no-op when Home is
        // already selected and `push` never inspects the path, so two taps would stack two
        // calendars.
        case .cyclePeriod:
            pushCycleCalendar()
        // A dose stops at the medications tab root, and that is a decision rather than an omission
        // (M5, decision 3): a dose ref's `entityId` is its SCHEDULE's id, and no screen is addressed
        // by one — `MedicationDetailKey` wants the medication.
        case .medicationDose:
            break
        }
    }

    /// Pushes the appointment's detail, unless that same detail is what the last tap already left on
    /// top of the appointments stack.
    ///
    /// Without the guard, answering the same reminder twice — two taps on a notification iOS has not
    /// yet cleared, or a tap arriving while the app was already showing that appointment — stacks a
    /// second identical screen the user then has to dismiss twice. Deferred out of M4; the memo is
    /// what M4 lacked.
    private func pushAppointmentDetail(id: String) {
        let depth = backStacks.path(for: .appointments).count
        guard reminderPushedAppointment != PushedAppointmentDetail(id: id, depth: depth) else { return }
        backStacks.push(AnyNavKey(AppointmentDetailKey(id: id)))
        reminderPushedAppointment = PushedAppointmentDetail(id: id, depth: depth + 1)
    }

    /// Pushes the cycle calendar, unless that same calendar is what the last tap already left on top
    /// of Home's stack.
    ///
    /// The twin of `pushAppointmentDetail`, minus the payload: with nothing to compare but the
    /// stack, a depth that still matches the one the last push left means nothing has been pushed
    /// or popped since, so the calendar is still showing and a second one would only have to be
    /// dismissed twice.
    private func pushCycleCalendar() {
        let depth = backStacks.path(for: .home).count
        guard reminderPushedCycleDepth != depth else { return }
        backStacks.push(AnyNavKey(CycleKey()))
        reminderPushedCycleDepth = depth + 1
    }

    /// The store emits its current value first, then every change, so this both seeds and tracks.
    ///
    /// One loop for every shell-level setting, not one per value: `userSettings` carries the whole
    /// `UserSettings`, so a second `for await` over the same stream would buy a second observer and
    /// nothing else. Android reads all three of these off that one flow too — the first two four
    /// lines apart (`MainActivity.kt:61-67`), the third in its own `lifecycleScope.launch`
    /// (`:50-54`) only because the splash condition is read before `setContent` exists.
    ///
    /// The `onboarding_completed` line is what takes the splash-hold down, and it is also the whole
    /// of the onboarding gate's dismissal: the flow writes the flag through
    /// `OnboardingPreferencesImpl` and this loop is what notices (T8 — the Route has no callback and
    /// hands nothing back out).
    private func observeUserSettings() async {
        for await settings in root.preferences.userSettings {
            themeMode = settings.themeMode
            secureScreenEnabled = settings.secureScreenEnabled
            onboardingCompleted = settings.onboardingCompleted
            premiumTheme = settings.premiumTheme
        }
    }

    /// Mirrors `premiumRepository.status` into `premiumStatus` for the `theme` fold.
    private func observePremiumStatus() async {
        for await status in root.premiumRepository.status {
            premiumStatus = status
        }
    }

    /// `SalusApp.kt:92-99`, one for one: `Navigate` pushes, `Pop` pops, and nothing else in the app
    /// touches the stack.
    private func observeNavigationCommands() async {
        for await command in root.navigator.commands {
            // Anything a feature pushes onto the appointments stack invalidates that stack's memo:
            // it is now that key on top, not what a reminder put there. A pop needs no line — it
            // moves the depth the memo is matched against, so it can never leave a stale match
            // behind.
            if case .navigate = command, backStacks.selection == .appointments {
                reminderPushedAppointment = nil
            }
            // Home's memo is seeded rather than only cleared: a Home card pushes `CycleKey` too,
            // and clearing the memo there would leave a following cycle-reminder tap seeing
            // `nil != depth` and pushing a second calendar onto the one the card just opened. This
            // runs before the push below, so `count + 1` is the depth that push will leave —
            // exactly what `pushCycleCalendar` memoizes. Any other key still clears.
            if case let .navigate(key) = command, backStacks.selection == .home {
                reminderPushedCycleDepth = key == AnyNavKey(CycleKey())
                    ? backStacks.path(for: .home).count + 1
                    : nil
            }
            switch command {
            case let .navigate(key): backStacks.push(key)
            case .pop: backStacks.pop()
            }
        }
    }
}
