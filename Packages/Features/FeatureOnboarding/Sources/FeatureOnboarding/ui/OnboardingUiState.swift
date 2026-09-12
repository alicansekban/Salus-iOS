// The twin of `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/OnboardingUiState.kt`,
// ported 1:1 (M15/M16: `OnboardingUiState.kt:13-105`).
//
// Three pages rather than one question per screen: a cover, everything the profile needs, and the
// notes plus the one permission (`OnboardingUiState.kt:8-12`). The flow is linear and disposable,
// so the pages are an index into a list rather than a nav stack — nothing here should end up on
// the app's back stack. `OnboardingSection` and the eight per-field steps are deleted with the
// flow change; the field state and the field events are untouched.
//
// `OnboardingUiState` lives under `ui/` but does NOT import SwiftUI: it is the UDF state type,
// and the domain-layer rule keeps UI frameworks out of model-shaped types even when they sit
// beside the screens that read them. It imports `SalusModel` (for `Sex`) and `SalusCommon`
// (for `MeasurementInput`), exactly as the Kotlin twin imports `core.model.Sex` and
// `core.common.MeasurementInput`.

import SalusCommon
import SalusModel

/// The three pages the onboarding flow walks, in order (`OnboardingUiState.kt:13-17`).
public enum OnboardingStep: String, CaseIterable, Sendable {
    case welcome
    case personalDetails
    case healthAndPermissions
}

/// The direction of a page change — iOS-only, no Kotlin twin. Android's `AnimatedContent`
/// derives `forward = targetState >= initialState` inside the `transitionSpec` lambda where both
/// values are known at transition time; SwiftUI has no equivalent, so the direction must travel in
/// the state instead. Set by the ViewModel's `nextClicked`/`backClicked`/`skipClicked` events so the
/// transition reads the correct direction on the FIRST body evaluation after the change.
public enum StepDirection: Sendable, Equatable {
    case forward
    case backward
}

/// The onboarding flow's UDF state. The twin of Kotlin's `OnboardingUiState`
/// (`OnboardingUiState.kt:19-74`).
///
/// `steps` is a plain `[OnboardingStep]` array rather than Kotlin's `ImmutableList` — the M2+
/// precedent is that Swift has no immutable-list wrapper, and a value-type array on a struct is
/// already copy-on-write. `steps.getOrElse(stepIndex) { .welcome }` becomes a safe subscript that
/// falls back to `.welcome`, exactly as the Kotlin twin does.
///
/// `lastStepDirection` is iOS-only (no Kotlin twin): Android's `AnimatedContent` receives both
/// `initialState` and `targetState` in its `transitionSpec` lambda, so it derives direction at
/// transition time. SwiftUI's `.transition` + `.animation(value:)` mechanism evaluates the
/// transition in `body`, where only the new state is visible — a `@State`/`.onChange` approach
/// lags by one body eval (SwiftUI fires `onChange` AFTER the body that constructs the transition).
/// Carrying the direction in the state eliminates the race: the ViewModel sets it from the event,
/// and the first body eval after the change reads the correct value.
public struct OnboardingUiState: Sendable, Equatable {
    public var steps: [OnboardingStep]
    public var stepIndex: Int
    public var name: String
    public var sex: Sex?
    public var birthDateEpochDay: Int?
    public var heightText: String
    public var weightText: String
    public var healthNotes: String
    /// The switch on the last page; only ever acted on when ``remindersAvailable``
    /// (`OnboardingUiState.kt:28-29`).
    public var remindersEnabled: Bool
    /// Whether the reminder row is offered at all (`OnboardingUiState.kt:30-34`). Android turns it
    /// off below API 33, where `POST_NOTIFICATIONS` does not exist; iOS has no such gate, so the
    /// composition root leaves it on and only a test turns it off. The page itself stays either
    /// way, so the page list cannot carry this.
    public var remindersAvailable: Bool
    public var isSaving: Bool
    /// The direction of the last page change, set by the ViewModel so the page transition reads
    /// it on the first body eval (iOS-only — see the type-level doc comment above).
    public var lastStepDirection: StepDirection

    public init(
        steps: [OnboardingStep] = [.welcome],
        stepIndex: Int = 0,
        name: String = "",
        sex: Sex? = nil,
        birthDateEpochDay: Int? = nil,
        heightText: String = "",
        weightText: String = "",
        healthNotes: String = "",
        remindersEnabled: Bool = true,
        remindersAvailable: Bool = true,
        isSaving: Bool = false,
        lastStepDirection: StepDirection = .forward
    ) {
        self.steps = steps
        self.stepIndex = stepIndex
        self.name = name
        self.sex = sex
        self.birthDateEpochDay = birthDateEpochDay
        self.heightText = heightText
        self.weightText = weightText
        self.healthNotes = healthNotes
        self.remindersEnabled = remindersEnabled
        self.remindersAvailable = remindersAvailable
        self.isSaving = isSaving
        self.lastStepDirection = lastStepDirection
    }

    /// `OnboardingUiState.kt:37`.
    public var step: OnboardingStep {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : .welcome
    }

    /// `OnboardingUiState.kt:39`.
    public var isLastStep: Bool { stepIndex >= steps.count - 1 }

    /// `OnboardingUiState.kt:41`.
    public var stepCount: Int { steps.count }

    /// Position in the flow, 1-based: the cover is page one of three, not a prologue
    /// (`OnboardingUiState.kt:43-44`).
    public var stepNumber: Int { stepIndex + 1 }

    /// Page 1 has nothing behind it: the flow can be stepped through, never escaped
    /// (`OnboardingUiState.kt:46-47`).
    public var canGoBack: Bool { stepIndex > 0 }

    /// The cover asks nothing, so there is nothing on it to pass over (`OnboardingUiState.kt:49-50`).
    public var isSkippable: Bool { step != .welcome }

    /// `OnboardingUiState.kt:52-53`.
    public var showInvalidHeight: Bool {
        !heightText.trimmingCharacters(in: .whitespaces).isEmpty && MeasurementInput.parseHeightCm(heightText) == nil
    }

    /// `OnboardingUiState.kt:55-56`.
    public var showInvalidWeight: Bool {
        !weightText.trimmingCharacters(in: .whitespaces).isEmpty && MeasurementInput.parseWeightKg(weightText) == nil
    }

    /// Cycle tracking turns itself on for these profiles, so the page says so while it is chosen
    /// (`OnboardingUiState.kt:58-59`).
    public var showCycleNote: Bool { sex == .female || sex == .other }

    /// Sex is the one hard gate; the measurements only block on a value that is present but
    /// unusable, so a blank field is still a way forward (`OnboardingUiState.kt:61-69`).
    public var canContinue: Bool {
        if isSaving {
            return false
        }
        switch step {
        case .personalDetails: return sex != nil && !showInvalidHeight && !showInvalidWeight
        case .healthAndPermissions, .welcome: return true
        }
    }

    /// Skipping is leaving the answers blank, which the mandatory one cannot be
    /// (`OnboardingUiState.kt:71-73`).
    public var canSkip: Bool {
        isSkippable && !isSaving && (step != .personalDetails || sex != nil)
    }
}

/// The events the onboarding screen emits. The twin of Kotlin's `OnboardingEvent` sealed
/// interface (`OnboardingUiState.kt:76-97`), ported to a Swift enum with associated values (the
/// UDF event shape).
public enum OnboardingEvent: Sendable, Equatable {
    case nextClicked
    case backClicked
    /// Clears whatever the current page collects and moves on.
    case skipClicked
    case nameChanged(String)
    case sexSelected(Sex)
    case birthDateSelected(Int)
    case heightChanged(String)
    case weightChanged(String)
    case healthNotesChanged(String)
    case remindersToggled(Bool)
}

/// The one-shot outcome the screen has to carry out, because only it can reach the system
/// (`OnboardingUiState.kt:99-105`).
public enum OnboardingEffect: Sendable, Equatable {
    /// Ask the system for notification authorization — Android's `POST_NOTIFICATIONS`. The answer
    /// is not a gate: the setup finishes either way, and Reminder health stays the place to fix a
    /// denial later.
    case requestNotificationPermission
}
