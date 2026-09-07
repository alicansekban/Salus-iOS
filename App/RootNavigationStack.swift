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
import SwiftUI

/// One tab's `NavigationStack`, with the destinations that tab can reach registered on it
/// (`SalusApp.kt:139-247`, the `entryProvider` block).
///
/// Which registrars go on which stack is not cosmetic: SwiftUI resolves `navigationDestination(for:)`
/// per stack, so a key pushed onto a stack that does not register it draws nothing. That is why
/// `cycleDestinations()` appears twice and why `settingsDestinations()` now appears on the
/// medications stack as well as on More's.
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

    /// The medications tab's stack — split out of ``body`` because it is the only one that
    /// registers a *second* feature's destinations, and the reason takes more lines than the four
    /// stacks that do not.
    private var medicationsStack: some View {
        NavigationStack(path: backStacks.binding(for: tab)) {
            MedicationsRoute()
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
