// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingScreen.kt`.
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
//                                      it is already `canGoBack`-gated by `OnboardingHeader` being
//                                      drawn at all (Welcome has no header) plus the ViewModel's
//                                      `max(stepIndex - 1, 0)`.
//   `Column(weight(1f) +             → `GeometryReader` + `ScrollView` + a
//     verticalScroll +                 `.frame(minHeight: proxy.size.height)` on the content. That
//     Arrangement.Center)`             one frame is the whole trick, and it is Kotlin's comment
//                                      verbatim: the scroll lets content grow past the viewport,
//                                      the minimum height pins short steps to it, so short steps
//                                      centre and long ones simply scroll.
//   `rememberLauncherForActivity-    → `UNUserNotificationCenter.requestAuthorization`, awaited in
//     Result(RequestPermission)`       the Route. Divergence (e): grant **or** denial always sends
//                                      `.nextClicked`, exactly as the Kotlin callback does —
//                                      "denial is not a dead end", Reminder health stays the place
//                                      to fix it later. Kotlin's `Build.VERSION` gate has no twin:
//                                      `UNUserNotificationCenter` exists on every supported iOS, so
//                                      the step is never dropped (`OnboardingViewModel.swift:49-53`
//                                      already records that `includeNotificationStep` defaults to
//                                      true here).
//   `SalusButton(trailingIcon)`  → `trailingSystemImage:`, which this task adds to the
//                                      component. Kotlin's `SalusButton` has carried both
//                                      `icon` and `trailingIcon` since `SalusButton.kt:45-46`;
//                                      the iOS port only had the leading one because no caller
//                                      needed the other. This footer is the first
//                                      (`OnboardingScreen.kt:145`), so the parameter arrives with
//                                      it rather than the pill being redrawn here.
//   `AnimatedContent(targetState =   → `.id(state.stepIndex)` + an asymmetric
//     state.stepIndex)`                `stepTransition(width:)` (offset+opacity via
//   (`OnboardingScreen.kt:124-137`,   `.modifier(active:identity:)`) + a container-level
//   parity row A45)                    `.animation(_, value: state.stepIndex)`. Steps travel in
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
//                                      the phase jumps. The outgoing step renders during the
//                                      transition for free because `.id()` rebinds identity and
//                                      SwiftUI keeps the old view alive for the removal phase — no
//                                      `state.copy(stepIndex:)` is needed, the twin of Kotlin's
//                                      `state.copy(stepIndex = targetStepIndex)`.
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
//                                      approach would lag by one eval and read single-step backs as
//                                      forward. See `OnboardingUiState`'s doc comment.
//
// ONE ADDITION WITH NO KOTLIN TWIN, and it is the one this port always owes a form:
// `.salusDismissesKeyboardOnTap()` + `.scrollDismissesKeyboard(.interactively)` on the step
// scroller. Compose gives every field an IME action and Android's decimal IME draws that key;
// UIKit's `.decimalPad` — which the Boy and Kilo steps ask for — draws no return key at all, so
// without this the user is left with a keyboard and nothing to press. The modifier's own file
// records that it swallows nothing (`DismissKeyboardOnTap.swift`), which is why it can sit over
// three tappable steps safely.
//   `TextButton { Text(skip) }`      → a `.plain` `Button` over `SalusTypography.labelLarge` in the
//                                      primary role, which is what a Material `TextButton` draws.
//                                      `SalusUI` has no text-button component to reach for.
//
// The eight `@PreviewLightDark`s at the bottom of the Kotlin file are the eight `#Preview`s here,
// one per step — they ship for the user's later inspection and no agent renders them
// (`scripts/m8-manual-qa.md` is where anything visual is checked).

import SalusDesignSystem
import SalusUI
import SwiftUI
import UserNotifications

/// Owns the ViewModel and asks for the notification permission (`OnboardingScreen.kt:42-66`).
public struct OnboardingRoute: View {
    @Environment(\.onboardingModule) private var module
    @Environment(\.salusTheme) private var theme
    @State private var viewModel: OnboardingViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                OnboardingScreen(state: viewModel.state, onEvent: viewModel.onEvent) {
                    requestNotificationPermission(then: viewModel)
                }
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
        // the eight previews, and painting the same colour twice costs nothing.
        .background(theme.colorScheme.background.ignoresSafeArea())
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeOnboardingViewModel()
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

    /// `permissionLauncher` (`OnboardingScreen.kt:48-53`) — the result is discarded on purpose:
    /// granted or denied, the flow moves on.
    private func requestNotificationPermission(then viewModel: OnboardingViewModel) {
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            viewModel.onEvent(.nextClicked)
        }
    }
}

/// A full-screen gate rendered above the shell's `TabView`, so — unlike screens inside it — this
/// one owns its insets. It is the app's only other inset owner (`OnboardingScreen.kt:73-120`).
struct OnboardingScreen: View {
    let state: OnboardingUiState
    let onEvent: (OnboardingEvent) -> Void
    let onRequestNotificationPermission: () -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `true` when the flow is moving forward — `targetState >= initialState`
    /// (`OnboardingScreen.kt:126`). The direction travels in `state.lastStepDirection` (set by the
    /// ViewModel from the event), so it is correct on the FIRST body eval after the change. Falls
    /// back to forward when the indices match (e.g. a value change inside the same step), matching
    /// Android's `>=`.
    private var isForward: Bool { state.lastStepDirection == .forward }

    var body: some View {
        VStack(spacing: 0) {
            // Welcome is the cover, not a question: it carries no heading, no position and nothing
            // to go back to (`OnboardingScreen.kt:88-99`).
            if let section = state.section {
                OnboardingHeader(
                    title: section.title,
                    stepNumber: state.stepNumber,
                    stepCount: state.stepCount,
                    progress: state.progress
                ) {
                    onEvent(.backClicked)
                }
            }
            steps
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colorScheme.background.ignoresSafeArea())
    }

    /// `AnimatedContent(targetState = state.stepIndex)` (`OnboardingScreen.kt:124-137`) — steps
    /// travel in the flow's direction: forward from the trailing edge, back from the leading one.
    /// `.id(state.stepIndex)` rebinds identity so SwiftUI keeps the outgoing step alive for the
    /// removal phase, and the container-level `.animation(_, value:)` drives the
    /// `stepTransition(width:)` in both directions. Reduce motion swaps instantly (`nil` animation).
    ///
    /// The direction comes from `state.lastStepDirection` (set by the ViewModel from the event),
    /// not from a `.onChange` comparison — SwiftUI fires `onChange` AFTER the body that constructs
    /// the transition, so the stale-value race that a `@State previousStepIndex` approach has is
    /// eliminated: the transition reads the correct direction on the first body eval.
    private var steps: some View {
        GeometryReader { proxy in
            ScrollView {
                OnboardingStepContent(state: state, onEvent: onEvent)
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

    /// `OnboardingFooter` (`OnboardingScreen.kt:123-159`).
    private var footer: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: SalusSpacing.xxl)
            SalusButton(
                text: state.primaryLabel,
                enabled: state.canContinue,
                trailingSystemImage: state.primarySystemImage,
                fillsWidth: true
            ) {
                primaryTapped()
            }
            Spacer().frame(height: SalusSpacing.lg)
            if state.isSkippable {
                Button { onEvent(.skipClicked) } label: {
                    Text(verbatim: state.skipLabel)
                        .font(SalusTypography.labelLarge.font)
                        .tracking(SalusTypography.labelLarge.tracking)
                        .foregroundStyle(theme.colorScheme.primary)
                        .frame(minHeight: SalusTouchTarget.min)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(state.isSaving)
                Spacer().frame(height: SalusSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// `OnboardingScreen.kt:137-143` — the notifications step asks the system; every other step
    /// simply advances.
    private func primaryTapped() {
        if state.step == .notifications {
            onRequestNotificationPermission()
        } else {
            onEvent(.nextClicked)
        }
    }
}

/// The directional step transition — the twin of `AnimatedContent`'s `enter togetherWith exit`
/// (`OnboardingScreen.kt:127-135`, parity row A45). Both phases compose a quarter-width horizontal
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
/// `.animation(SalusMotion.entranceAnimation, value: state.stepIndex)` in `steps`; reduce motion
/// sets that animation to `nil`, so this transition's phases are never run and the swap is instant.
///
/// `SalusMotion.parallaxDivisor` (4, §10) is the sibling of Android's `full / 4` quarter-width
/// travel. `.move(edge:)` would travel the full width, so the offset is driven by hand via
/// `.modifier(active:identity:)`: the active phase offsets the view by a quarter width from its
/// arrival edge, the identity phase rests at zero — the move plus the fade come from the one
/// asymmetric `AnyTransition`.
extension OnboardingScreen {
    /// `slideInHorizontally { full -> if (forward) full / 4 else -full / 4 } + fadeIn`
    /// (`OnboardingScreen.kt:128-131`) — the insertion phase.
    private func stepTransition(width: CGFloat) -> AnyTransition {
        let travel = width / CGFloat(SalusMotion.parallaxDivisor)
        return .asymmetric(
            insertion: stepInsertion(travel: travel, forward: isForward),
            removal: stepRemoval(travel: travel, forward: isForward)
        )
    }

    /// Forward: the arriving step enters from the trailing edge (offset `+travel` → 0) and fades in.
    /// Back: it enters from the leading edge (offset `-travel` → 0).
    private func stepInsertion(travel: CGFloat, forward: Bool) -> AnyTransition {
        let offset = forward ? travel : -travel
        return .modifier(
            active: StepSlidePhase(offset: offset, opacity: 0),
            identity: StepSlidePhase(offset: 0, opacity: 1)
        )
    }

    /// Forward: the leaving step exits toward the leading edge (0 → offset `-travel`) and fades out.
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

extension OnboardingSection {
    /// `OnboardingSection.titleRes()` (`OnboardingScreen.kt:162-166`).
    fileprivate var title: String {
        switch self {
        case .personalDetails: OnboardingStrings.onboardingSectionPersonal
        case .healthNotes: OnboardingStrings.onboardingSectionNotes
        case .privacy: OnboardingStrings.onboardingSectionPrivacy
        }
    }
}

extension OnboardingUiState {
    /// `primaryLabelRes()` (`OnboardingScreen.kt:169-174`).
    fileprivate var primaryLabel: String {
        if step == .welcome {
            return OnboardingStrings.onboardingStart
        }
        if step == .notifications {
            return OnboardingStrings.onboardingAllowNotifications
        }
        return isLastStep ? OnboardingStrings.onboardingFinish : OnboardingStrings.onboardingNext
    }

    /// Granting a permission is an act of consent, not another step; it gets a tick, not an arrow
    /// (`primaryIcon()`, `OnboardingScreen.kt:177-180`). `Icons.Filled.CheckCircle` →
    /// `checkmark.circle.fill`, `Icons.AutoMirrored.Filled.ArrowForward` → `arrow.forward`, which
    /// SF Symbols mirrors for right-to-left on its own.
    fileprivate var primarySystemImage: String {
        step == .notifications ? "checkmark.circle.fill" : "arrow.forward"
    }

    /// `skipLabelRes()` (`OnboardingScreen.kt:183-186`).
    fileprivate var skipLabel: String {
        step == .notifications
            ? OnboardingStrings.onboardingNotificationsLater
            : OnboardingStrings.onboardingSkip
    }
}

// MARK: - Previews

/// The eight step previews (`OnboardingScreen.kt:188-306`), one per `OnboardingStep`.
private func previewState(
    _ step: OnboardingStep,
    birthDateEpochDay: Int? = nil,
    heightText: String = "",
    weightText: String = ""
) -> OnboardingUiState {
    OnboardingUiState(
        steps: OnboardingStep.allCases,
        stepIndex: OnboardingStep.allCases.firstIndex(of: step) ?? 0,
        birthDateEpochDay: birthDateEpochDay,
        heightText: heightText,
        weightText: weightText
    )
}

@MainActor
private func previewScreen(_ state: OnboardingUiState) -> some View {
    OnboardingScreen(state: state, onEvent: { _ in }, onRequestNotificationPermission: {})
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("1 Welcome") { previewScreen(previewState(.welcome)) }
#Preview("2 Name") { previewScreen(previewState(.name)) }
#Preview("3 Sex") { previewScreen(previewState(.sex)) }
// 1995-05-12 is `OnboardingBirthDatePreview`'s date (`OnboardingScreen.kt:238`), as an epoch day.
#Preview("4 Birth date") { previewScreen(previewState(.birthDate, birthDateEpochDay: 9262)) }
#Preview("5 Height") { previewScreen(previewState(.height, heightText: "170")) }
#Preview("6 Weight") { previewScreen(previewState(.weight, weightText: "68")) }
#Preview("7 Health notes") { previewScreen(previewState(.healthNotes)) }
#Preview("8 Notifications") { previewScreen(previewState(.notifications)) }
