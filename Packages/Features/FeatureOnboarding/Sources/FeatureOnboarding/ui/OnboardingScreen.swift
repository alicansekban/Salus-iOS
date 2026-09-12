// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingScreen.kt:42-143` (M15/M16).
//
// The M15 flow change reaches this file twice: the header is now drawn on every page (the cover
// has one too, "ADIM 1/3"), and the footer is gone — each page carries its own primary and
// secondary buttons, because the three pages no longer agree on what those are.
//
// Material → SwiftUI:
//   `koinViewModel()`                → the module from the environment, the ViewModel in `@State`,
//                                      built in `.task` — the Route shape
//                                      `docs/ios-feature-template.md` records and
//                                      `ProfileScreen.swift:41-62` shows.
//   `Surface(fillMaxSize,            → a `VStack` over `.background(theme.colorScheme.background)`.
//     color = background)`
//   `.safeDrawingPadding()`          → nothing. This is a full-screen gate drawn *above* the shell,
//                                      so it is the app's only other inset owner — and on iOS that
//                                      is the default: SwiftUI lays a view out inside the safe area
//                                      unless it opts out. Only the background reaches under it
//                                      (`.ignoresSafeArea()` on the colour alone), which is what
//                                      `safeDrawingPadding` on a `Surface` draws.
//   `.imePadding()`                  → nothing, for the same reason: SwiftUI moves the focused
//                                      field clear of the keyboard by default.
//   `BackHandler { … }`              → nothing to write, and that is ruling 8 satisfied rather than
//                                      skipped. The gate is an overlay with no navigation
//                                      container, so there is no edge-swipe and no system back to
//                                      intercept; the header's own button is the only way back and
//                                      it is already `canGoBack`-gated.
//   `Column(weight(1f) +             → `GeometryReader` + `ScrollView` + a
//     verticalScroll +                 `.frame(minHeight: proxy.size.height)` on the content. That
//     Arrangement.Center)`             one frame is the whole trick, and it is Kotlin's comment
//                                      verbatim: the scroll lets a page grow past the viewport, the
//                                      minimum height pins short ones to it, so the cover sits in
//                                      the middle and the long form simply scrolls.
//   `rememberLauncherForActivity-    → `UNUserNotificationCenter.requestAuthorization`, awaited in
//     Result(RequestPermission)`       the Route and driven by `OnboardingEffect`, the twin of
//                                      Kotlin's `viewModel.effects.collect`
//                                      (`OnboardingScreen.kt:56-67`). The answer is discarded on
//                                      both platforms: `finish()` has already run by the time the
//                                      effect is delivered, so a denial leaves a working app with
//                                      its reminders off, not a stuck gate. Kotlin's
//                                      `Build.VERSION` gate has no twin —
//                                      `UNUserNotificationCenter` exists on every supported iOS, so
//                                      `remindersAvailable` is true here and only a test turns it
//                                      off.
//   `AnimatedContent(targetState =   → `.id(state.stepIndex)` + an asymmetric
//     state.stepIndex)`                `stepTransition(width:)` (offset+opacity via
//   (`OnboardingScreen.kt:103-140`,   `.modifier(active:identity:)`) + a container-level
//   parity row A45)                    `.animation(_, value: state.stepIndex)`. Pages travel in
//                                      the flow's direction: forward from the trailing edge, back
//                                      from the leading one, a quarter of the width each way (§10
//                                      `parallaxDivisor`'s 4, the sibling of Android's
//                                      `full / 4`). The slide rides `SalusMotion.entranceAnimation`
//                                      (450 ms emphasized); the fade composes inside the same
//                                      transition. SwiftUI's `Transition` API binds one animation
//                                      to every phase-driven property, so the fade rides the same
//                                      450 ms emphasized curve rather than a separate 300 ms — that
//                                      is the platform mechanical limit of "combined in one
//                                      asymmetric transition", not a design choice. Reduce motion
//                                      swaps instantly: the container animation becomes `nil` and
//                                      the phase jumps. The outgoing page renders during the
//                                      transition for free because `.id()` rebinds identity and
//                                      SwiftUI keeps the old view alive for the removal phase.
//                                      DIVERGENCE FROM THE KOTLIN TWIN (iOS-only): Android's
//                                      `AnimatedContent` receives both `initialState` and
//                                      `targetState` in its `transitionSpec` lambda, so it derives
//                                      `forward = targetState >= initialState` at transition time.
//                                      SwiftUI's `.transition` + `.animation(value:)` evaluates the
//                                      transition in `body`, where only the new state is visible,
//                                      so the direction travels in `OnboardingUiState.lastStepDirection`
//                                      (set by the ViewModel from the event) rather than from a
//                                      `.onChange` index comparison — SwiftUI fires `onChange` AFTER
//                                      the body that constructs the transition, so a `@State`-based
//                                      approach would lag by one eval and read single-page backs as
//                                      forward. See `OnboardingUiState`'s doc comment.
//
// ONE ADDITION WITH NO KOTLIN TWIN, and it is the one this port always owes a form:
// `.salusDismissesKeyboardOnTap()` + `.scrollDismissesKeyboard(.interactively)` on the page
// scroller. Compose gives every field an IME action and Android's decimal IME draws that key;
// UIKit's `.decimalPad` — which the height and weight fields ask for — draws no return key at all,
// so without this the user is left with a keyboard and nothing to press. The modifier's own file
// records that it swallows nothing (`DismissKeyboardOnTap.swift`), which is why it can sit over
// three tappable pages safely.
//
// The three `@PreviewLightDark`s at the bottom of the Kotlin file (`OnboardingScreen.kt:154-188`)
// are the six `#Preview`s here, one per page per mode — they ship for the user's later inspection
// and no agent renders them (`docs/qa/m16-manual-qa.md` is where anything visual is checked).

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI
import UserNotifications

/// Owns the ViewModel and asks for the notification permission (`OnboardingScreen.kt:42-70`).
public struct OnboardingRoute: View {
    @Environment(\.onboardingModule) private var module
    @Environment(\.salusTheme) private var theme
    @State private var viewModel: OnboardingViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                OnboardingScreen(state: viewModel.state, onEvent: viewModel.onEvent)
            } else {
                placeholder
            }
        }
        // THE GATE IS OPAQUE IN EVERY STATE, and this is the one Route where that matters (review
        // I-1). Every other Route renders *inside* a tab that already paints a background; this one
        // is the app's outermost overlay, so a transparent frame is a frame of the live TabView
        // showing through a gate whose whole job is to be in front of it. `.task` runs after the
        // first render pass, so without this the first launch flashes Home before the Welcome
        // cover — and a dropped module injection would leave a fully interactive app behind a
        // permanent spinner, the opposite of `OnboardingModule`'s "nothing pretends to work".
        // `OnboardingScreen` keeps its own identical background: it has to stand up on its own in
        // the six previews, and painting the same colour twice costs nothing.
        .background(theme.colorScheme.background.ignoresSafeArea())
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeOnboardingViewModel()
        }
        // The collector for `Channel<OnboardingEffect>` (`OnboardingScreen.kt:56-67`), spelled for
        // an `@Observable`: the queue is a property, so `.onChange` is the twin of the Kotlin
        // `LaunchedEffect { viewModel.effects.collect { … } }` — it fires on every append, for as
        // long as this view lives. The M8 `MoreScreen` set the shape.
        .onChange(of: viewModel?.pendingEffects ?? []) { _, pending in
            // Fires on the drain's own write as well as on the append; the empty edge is dropped.
            guard !pending.isEmpty, let viewModel else { return }
            deliver(viewModel.consumeEffects())
        }
    }

    /// Only until `.task` has run, or if the shell forgot to inject the module.
    ///
    /// A full-screen surface rather than a bare spinner: `.contentShape(.rect)` makes the whole
    /// frame take the tap, so nothing behind the gate is reachable while it is up, and the
    /// indeterminate spinner is hidden from VoiceOver because it names nothing a user can act on.
    private var placeholder: some View {
        ProgressView()
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
    }

    /// Performs the drained effects in order (`OnboardingScreen.kt:56-67`).
    @MainActor
    private func deliver(_ effects: [OnboardingEffect]) {
        for effect in effects {
            switch effect {
            case .requestNotificationPermission:
                requestNotificationPermission()
            }
        }
    }

    /// `permissionLauncher` (`OnboardingScreen.kt:49-54`) — the result is discarded on purpose:
    /// granted or denied, the setup is already finished and Reminder health stays the place to fix
    /// a denial later.
    private func requestNotificationPermission() {
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
    }
}

/// A full-screen gate rendered above the shell's `TabView`, so — unlike screens inside it — this
/// one owns its insets. It is the app's only other inset owner (`OnboardingScreen.kt:76-143`).
struct OnboardingScreen: View {
    let state: OnboardingUiState
    let onEvent: (OnboardingEvent) -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `true` when the flow is moving forward — `targetState >= initialState`
    /// (`OnboardingScreen.kt:107`). The direction travels in `state.lastStepDirection` (set by the
    /// ViewModel from the event), so it is correct on the FIRST body eval after the change.
    private var isForward: Bool { state.lastStepDirection == .forward }

    var body: some View {
        VStack(spacing: 0) {
            // Every page carries the header now, the cover included: "the cover is page one of
            // three, not a prologue" (`OnboardingUiState.kt:43-44`).
            OnboardingHeader(
                stepNumber: state.stepNumber,
                stepCount: state.stepCount,
                canGoBack: state.canGoBack
            ) {
                onEvent(.backClicked)
            }
            pages
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background.ignoresSafeArea())
    }

    /// `AnimatedContent(targetState = state.stepIndex)` (`OnboardingScreen.kt:103-140`) — pages
    /// travel in the flow's direction: forward from the trailing edge, back from the leading one.
    /// `.id(state.stepIndex)` rebinds identity so SwiftUI keeps the outgoing page alive for the
    /// removal phase, and the container-level `.animation(_, value:)` drives the
    /// `stepTransition(width:)` in both directions. Reduce motion swaps instantly (`nil` animation).
    private var pages: some View {
        GeometryReader { proxy in
            ScrollView {
                page
                    .id(state.stepIndex)
                    .padding(.horizontal, SalusSpacing.lg)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .transition(stepTransition(width: proxy.size.width))
            }
            .scrollDismissesKeyboard(.interactively)
            .salusDismissesKeyboardOnTap()
            .animation(
                reduceMotion ? nil : SalusMotion.entranceAnimation,
                value: state.stepIndex
            )
        }
    }

    /// `when (state.steps.getOrElse(pageIndex) { Welcome })` (`OnboardingScreen.kt:130-138`).
    @ViewBuilder
    private var page: some View {
        switch state.step {
        case .welcome:
            OnboardingWelcomePage(onEvent: onEvent)

        case .personalDetails:
            OnboardingPersonalPage(state: state, onEvent: onEvent)

        case .healthAndPermissions:
            OnboardingHealthPage(state: state, onEvent: onEvent)
        }
    }
}

/// The directional page transition — the twin of `AnimatedContent`'s `enter togetherWith exit`
/// (`OnboardingScreen.kt:106-117`, parity row A45). Both phases compose a quarter-width horizontal
/// move with an opacity fade in one `AnyTransition`, and the two phases are asymmetric: insertion
/// comes from the edge the flow is moving toward, removal leaves toward the edge it came from.
///
/// The direction (`isForward`) is read from `state.lastStepDirection`, set by the ViewModel from the
/// event — not from a `.onChange` index comparison (which would lag by one body eval on SwiftUI).
///
/// SwiftUI's `Transition` API binds one animation to every phase-driven property, so the fade rides
/// the same `entranceAnimation` (450 ms emphasized) as the slide rather than a separate 300 ms —
/// that is the platform mechanical limit of "combined in one asymmetric transition", and the slide
/// is the perceptually dominant phase. The animation itself is supplied by the container-level
/// `.animation(SalusMotion.entranceAnimation, value: state.stepIndex)` in `pages`; reduce motion
/// sets that animation to `nil`, so this transition's phases are never run and the swap is instant.
///
/// `SalusMotion.parallaxDivisor` (4, §10) is the sibling of Android's `full / 4` quarter-width
/// travel. `.move(edge:)` would travel the full width, so the offset is driven by hand via
/// `.modifier(active:identity:)`: the active phase offsets the view by a quarter width from its
/// arrival edge, the identity phase rests at zero — the move plus the fade come from the one
/// asymmetric `AnyTransition`.
extension OnboardingScreen {
    /// `slideInHorizontally { full -> if (forward) full / 4 else -full / 4 } + fadeIn`
    /// (`OnboardingScreen.kt:108-111`) — the insertion phase.
    private func stepTransition(width: CGFloat) -> AnyTransition {
        let travel = width / CGFloat(SalusMotion.parallaxDivisor)
        return .asymmetric(
            insertion: stepInsertion(travel: travel, forward: isForward),
            removal: stepRemoval(travel: travel, forward: isForward)
        )
    }

    /// Forward: the arriving page enters from the trailing edge (offset `+travel` → 0) and fades in.
    /// Back: it enters from the leading edge (offset `-travel` → 0).
    private func stepInsertion(travel: CGFloat, forward: Bool) -> AnyTransition {
        let offset = forward ? travel : -travel
        return .modifier(
            active: StepSlidePhase(offset: offset, opacity: 0),
            identity: StepSlidePhase(offset: 0, opacity: 1)
        )
    }

    /// Forward: the leaving page exits toward the leading edge (0 → offset `-travel`) and fades out.
    /// Back: it exits toward the trailing edge (0 → offset `+travel`).
    private func stepRemoval(travel: CGFloat, forward: Bool) -> AnyTransition {
        let offset = forward ? -travel : travel
        return .modifier(
            active: StepSlidePhase(offset: offset, opacity: 0),
            identity: StepSlidePhase(offset: 0, opacity: 1)
        )
    }
}

/// One phase of the directional slide — offset plus opacity — the shape
/// `.modifier(active:identity:)` interpolates between. `Sendable` so it can sit in an
/// `AnyTransition` under Swift 6 strict concurrency.
private struct StepSlidePhase: ViewModifier, Sendable {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
    }
}

// MARK: - Previews

/// The three page previews (`OnboardingScreen.kt:145-188`), each in both modes.
private func previewState(_ step: OnboardingStep, sex: Sex? = nil) -> OnboardingUiState {
    OnboardingUiState(
        steps: OnboardingStep.allCases,
        stepIndex: OnboardingStep.allCases.firstIndex(of: step) ?? 0,
        name: "Ada",
        sex: sex,
        heightText: "170",
        weightText: "68"
    )
}

@MainActor
private func previewScreen(_ state: OnboardingUiState, isDark: Bool) -> some View {
    OnboardingScreen(state: state, onEvent: { _ in })
        .salusTheme(SalusTheme.resolve(systemIsDark: isDark))
}

#Preview("1 Welcome · light") { previewScreen(previewState(.welcome), isDark: false) }
#Preview("1 Welcome · dark") { previewScreen(previewState(.welcome), isDark: true) }
#Preview("2 Personal · light") {
    previewScreen(previewState(.personalDetails, sex: .female), isDark: false)
}

#Preview("2 Personal · dark") {
    previewScreen(previewState(.personalDetails, sex: .female), isDark: true)
}

#Preview("3 Health · light") {
    previewScreen(previewState(.healthAndPermissions, sex: .male), isDark: false)
}

#Preview("3 Health · dark") {
    previewScreen(previewState(.healthAndPermissions, sex: .male), isDark: true)
}
