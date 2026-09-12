// Split out of `RootView.swift`, which holds the rest of the shell. The five stacks and the
// destination registrars they carry are the longest single thing the shell does, and the two would
// not fit in one file under the 500-line rule.
//
// A view rather than an `extension RootView`, because an extension in another file cannot read
// `RootView`'s `private` state — and widening that state to make it readable would be a worse
// trade than passing the two values this actually needs. `AppCompositionRoot` and `TabBackStacks`
// are both classes, and `TabBackStacks` is `@Observable`, so passing them as `let` keeps the
// observation SwiftUI already does: a push recorded on the shared instance still re-renders here.

import FeatureAIHealth
import FeatureAppointments
import FeatureCycle
import FeatureHome
import FeatureMedications
import FeatureSettings
import FeatureTrends
import FeatureVitals
import SalusNavigation
import SalusUI
import SwiftUI

/// One tab's `NavigationStack`, with the destinations that tab can reach registered on it
/// (`SalusApp.kt:139-247`, the `entryProvider` block).
///
/// Which registrars go on which stack is not cosmetic: SwiftUI resolves `navigationDestination(for:)`
/// per stack, so a key pushed onto a stack that does not register it draws nothing. That is why
/// `cycleDestinations()` appears twice, why `appointmentsDestinations()` appears on Home as well as
/// on its own tab — a Home appointment card opens that appointment's detail (parity row A58) — and
/// why `settingsDestinations()` is on all five stacks since iOS-M16: the root toolbar's bell and
/// avatar push `ReminderHealthKey` and `ProfileKey` from every tab, so every stack has to be able
/// to draw them. A registrar is a feature's whole set of keys, so the ones a given stack cannot
/// actually reach ride along with the ones it can.
///
/// **The root toolbar is the shell's** (spec §2.2, decision Q2): `salusRootToolbar` is applied here
/// to each of the five tab ROOTS and nowhere else, the twin of `SalusApp.kt:281-287` drawing
/// `SalusTopBar.Home` only while a top-level destination is showing. A feature never writes it —
/// a pushed screen sets its own `.navigationTitle` + `.navigationBarTitleDisplayMode(.inline)` and
/// its own `ToolbarItem` actions instead (`docs/ios-feature-template.md`). Applied to the ROOT view
/// rather than to the stack, which is the opposite of the tab-bar visibility rule on
/// `RootView.tabStack(for:)` and for the same reason: this one describes the root alone, and a
/// pushed screen must NOT inherit a brand tile where its back button goes.
@MainActor
struct RootNavigationStack: View {
    let tab: RootTab

    /// The graph `SalusApp` built. Handed down rather than read from the environment so this view
    /// has exactly the two things it needs and no ambient state.
    let root: AppCompositionRoot

    /// The shell's one back-stack store — the same instance `RootView` holds in `@State`.
    let backStacks: TabBackStacks<RootTab>

    var body: some View {
        switch tab {
        case .medications:
            medicationsStack

        case .vitals:
            NavigationStack(path: backStacks.binding(for: tab)) {
                VitalsRoute(onOpenTrends: {
                    // Trends belongs to `FeatureTrends`; the shell sees every key, so it pushes
                    // `TrendsKey` through the navigator. The destination is `trendsDestinations()`.
                    root.navigator.navigate(TrendsKey())
                })
                .rootToolbar(for: tab, navigator: root.navigator)
                .vitalsDestinations()
                .trendsDestinations()
                // Registered because the root toolbar's bell and avatar push `ReminderHealthKey`
                // and `ProfileKey` onto THIS stack. `AboutKey` rides along — the modifier is that
                // feature's whole registrar — and is not reachable from here.
                .settingsDestinations()
            }
            // Applied to the stack, not inside its root: a pushed `WeightEditorKey` destination is
            // rendered by the stack, so an environment value set on the root view would not reach
            // the editor.
            .environment(\.vitalsModule, root.vitalsModule)
            .environment(\.trendsModule, root.trendsModule)
            // What the pushed `ReminderHealthRoute` / `ProfileRoute` read, for the same reason the
            // two lines above exist.
            .environment(\.settingsModule, root.settingsModule)

        case .appointments:
            NavigationStack(path: backStacks.binding(for: tab)) {
                AppointmentsRoute()
                    .rootToolbar(for: tab, navigator: root.navigator)
                    .appointmentsDestinations()
                    // Registered for the root toolbar's two pushes, exactly as on the vitals stack.
                    .settingsDestinations()
            }
            // On the stack, not inside its root: a pushed `AppointmentDetailKey` or
            // `AppointmentEditorKey` destination is rendered by the stack, so an environment value
            // set on the root view would not reach either.
            .environment(\.appointmentsModule, root.appointmentsModule)
            // What the pushed `ReminderHealthRoute` / `ProfileRoute` read.
            .environment(\.settingsModule, root.settingsModule)

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
                .rootToolbar(for: tab, navigator: root.navigator)
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
                    // The section header's "Tümünü Gör" — the tab, not one appointment
                    // (`SalusApp.kt:220`).
                    onOpenAppointments: { backStacks.switchTopLevel(.appointments) },
                    // A card names one appointment, so it opens that appointment
                    // (`SalusApp.kt:223`, parity row A58). `AppointmentDetailKey` is
                    // `FeatureAppointments`' to name and features never depend on each other, so
                    // the shell pushes it — onto THIS stack, which is why
                    // `appointmentsDestinations()` and the appointments module appear below.
                    onOpenAppointment: { id in root.navigator.navigate(AppointmentDetailKey(id: id)) },
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
                    onOpenAiSummary: { root.navigator.navigate(AiSummaryKey()) },
                    // The readiness card. `ReminderHealthKey` belongs to `FeatureSettings`, so the
                    // shell is what pushes it — onto THIS stack, the one the dashboard is on, which
                    // is why `settingsDestinations()` and the settings module appear below. No pop
                    // first, unlike the medication editor's Fix: the dashboard is a tab root and
                    // there is nothing above it to replace.
                    onOpenReminderHealth: { root.navigator.navigate(ReminderHealthKey()) }
                )
                .rootToolbar(for: tab, navigator: root.navigator)
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
                // Registered here as well as on the appointments stack, because an appointment
                // card now pushes `AppointmentDetailKey` onto this one. `AppointmentEditorKey`
                // rides along — the modifier is that feature's whole registrar — and the detail
                // screen's "Düzenle" is exactly what reaches it from here.
                .appointmentsDestinations()
                // Registered here as well as on the More and medications stacks, because the
                // readiness card can now push `ReminderHealthKey` onto this one and SwiftUI
                // resolves `navigationDestination(for:)` per stack. `ProfileKey` and `AboutKey`
                // ride along — the modifier is that feature's whole registrar — and neither is
                // reachable from here.
                .settingsDestinations()
            }
            // On the stack, not inside its root — the pushed `CycleKey`, `AiSummaryKey` and
            // `AppointmentDetailKey` destinations are rendered by the stack, so an environment
            // value set on the root view would not reach any of them.
            .environment(\.homeModule, root.homeModule)
            .environment(\.cycleModule, root.cycleModule)
            .environment(\.aiHealthModule, root.aiHealthModule)
            // What a pushed `AppointmentDetailRoute` (and the editor behind its "Düzenle") reads.
            .environment(\.appointmentsModule, root.appointmentsModule)
            // What a pushed `ReminderHealthRoute` reads, for the same reason the three lines above
            // exist.
            .environment(\.settingsModule, root.settingsModule)
        }
        // No `default:` clause on purpose: `RootTab` lives in this target, so an exhaustive switch
        // is what makes a sixth tab added to the enum land as a compile error here rather than as a
        // silently empty stack.
    }

    /// The medications tab's stack — split out of ``body`` because it is the only one that
    /// registers a *second* feature's destinations, and the reason takes more lines than the four
    /// stacks that do not.
    private var medicationsStack: some View {
        NavigationStack(path: backStacks.binding(for: tab)) {
            MedicationsRoute()
                .rootToolbar(for: tab, navigator: root.navigator)
                .medicationsDestinations(
                    // The editor's post-save warning: "Fix" replaces the editor with Reminder
                    // health, which belongs to `FeatureSettings`, so the shell is what pushes the
                    // key — onto THIS stack, the one the editor is on.
                    //
                    // Both halves happen here, and in this order, exactly as Android's
                    // `topLevelBackStack.pop()` then `push(ReminderHealthKey)`: the editor's own
                    // pop would tear down the Route that delivers the effect, and popping first is
                    // what puts the medication list — not the editor — under Reminder health's
                    // Back.
                    onOpenReminderHealth: {
                        root.navigator.pop()
                        root.navigator.navigate(ReminderHealthKey())
                    }
                )
                // Registered here as well as on the More stack, because `ReminderHealthKey` can now
                // be pushed onto this one. `ProfileKey` and `AboutKey` come with it: the modifier is
                // that feature's whole registrar, and splitting it per key would be a second shape
                // for the same thing. Neither is reachable from here.
                .settingsDestinations()
        }
        // On the stack, not inside its root: a pushed `MedicationDetailKey` or
        // `MedicationEditorKey` destination is rendered by the stack, so an environment value set
        // on the root view would not reach either.
        .environment(\.medicationsModule, root.medicationsModule)
        // What a pushed `ReminderHealthRoute` reads, for the same reason the line above exists.
        .environment(\.settingsModule, root.settingsModule)
    }
}

extension View {
    /// The shell's root toolbar, wired to this tab.
    ///
    /// One helper rather than five copies of the same three arguments: the title is always the tab
    /// label (`SalusApp.kt:283` passes the same value), and the two destinations are always
    /// `FeatureSettings`' — which is why they are pushed here, by the shell, rather than by a
    /// feature that cannot see that package (spec §4's cross-feature rule).
    ///
    /// `fileprivate` so the sixth caller has to be a tab root in this file.
    fileprivate func rootToolbar(for tab: RootTab, navigator: Navigator) -> some View {
        salusRootToolbar(
            title: tab.label,
            onBell: { navigator.navigate(ReminderHealthKey()) },
            onAvatar: { navigator.navigate(ProfileKey()) }
        )
    }
}
