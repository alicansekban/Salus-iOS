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
//   `SalusPillButton(trailingIcon)`  → `trailingSystemImage:`, which this task adds to the
//                                      component. Kotlin's `SalusPillButton` has carried both
//                                      `icon` and `trailingIcon` since `SalusPillButton.kt:45-46`;
//                                      the iOS port only had the leading one because no caller
//                                      needed the other. This footer is the first
//                                      (`OnboardingScreen.kt:145`), so the parameter arrives with
//                                      it rather than the pill being redrawn here.
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
    @State private var viewModel: OnboardingViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                OnboardingScreen(state: viewModel.state, onEvent: viewModel.onEvent) {
                    requestNotificationPermission(then: viewModel)
                }
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeOnboardingViewModel()
        }
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

    /// `OnboardingScreen.kt:101-111`.
    private var steps: some View {
        GeometryReader { proxy in
            ScrollView {
                OnboardingStepContent(state: state, onEvent: onEvent)
                    .padding(.horizontal, SalusSpacing.lg)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .salusDismissesKeyboardOnTap()
        }
    }

    /// `OnboardingFooter` (`OnboardingScreen.kt:123-159`).
    private var footer: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: SalusSpacing.xxl)
            SalusPillButton(
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
