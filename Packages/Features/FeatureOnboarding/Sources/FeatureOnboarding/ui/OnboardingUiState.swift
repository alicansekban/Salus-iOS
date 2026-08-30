// The twin of `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/OnboardingUiState.kt`,
// ported 1:1. The flow is linear and disposable, so the steps are an index into a list rather
// than a nav stack — nothing here should end up on the app's back stack.
//
// `OnboardingUiState` lives under `ui/` but does NOT import SwiftUI: it is the UDF state type,
// and the domain-layer rule keeps UI frameworks out of model-shaped types even when they sit
// beside the screens that read them. It imports `SalusModel` (for `Sex`) and `SalusCommon`
// (for `MeasurementInput`), exactly as the Kotlin twin imports `core.model.Sex` and
// `core.common.MeasurementInput`.

import SalusCommon
import SalusModel

/// The steps the onboarding flow walks, in order. The twin of Kotlin's `OnboardingStep`.
public enum OnboardingStep: String, CaseIterable, Sendable {
    case welcome
    case name
    case sex
    case birthDate
    case height
    case weight
    case healthNotes
    case notifications
}

/// The heading the step sits under. Welcome has none: it is the cover, not a question, so it
/// carries no header at all. The twin of Kotlin's `OnboardingSection`.
public enum OnboardingSection: String, Sendable {
    case personalDetails
    case healthNotes
    case privacy
}

extension OnboardingStep {
    /// The heading the step sits under; `nil` on Welcome, which has no header.
    var section: OnboardingSection? {
        switch self {
        case .welcome: nil
        case .birthDate, .height, .name, .sex, .weight: .personalDetails
        case .healthNotes: .healthNotes
        case .notifications: .privacy
        }
    }
}

/// The onboarding flow's UDF state. The twin of Kotlin's `OnboardingUiState`.
///
/// `steps` is a plain `[OnboardingStep]` array rather than Kotlin's `ImmutableList` — the M2+
/// precedent is that Swift has no immutable-list wrapper, and a value-type array on a struct is
/// already copy-on-write. `steps.getOrElse(stepIndex) { .welcome }` becomes a safe subscript that
/// falls back to `.welcome`, exactly as the Kotlin twin does.
public struct OnboardingUiState: Sendable, Equatable {
    public var steps: [OnboardingStep]
    public var stepIndex: Int
    public var name: String
    public var sex: Sex?
    public var birthDateEpochDay: Int?
    public var heightText: String
    public var weightText: String
    public var healthNotes: String
    public var isSaving: Bool

    public init(
        steps: [OnboardingStep] = [.welcome],
        stepIndex: Int = 0,
        name: String = "",
        sex: Sex? = nil,
        birthDateEpochDay: Int? = nil,
        heightText: String = "",
        weightText: String = "",
        healthNotes: String = "",
        isSaving: Bool = false
    ) {
        self.steps = steps
        self.stepIndex = stepIndex
        self.name = name
        self.sex = sex
        self.birthDateEpochDay = birthDateEpochDay
        self.heightText = heightText
        self.weightText = weightText
        self.healthNotes = healthNotes
        self.isSaving = isSaving
    }

    public var step: OnboardingStep {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : .welcome
    }

    public var isLastStep: Bool { stepIndex >= steps.count - 1 }

    /// Heading the header shows; `nil` on Welcome, which has no header.
    public var section: OnboardingSection? { step.section }

    /// How many steps actually ask the user something. Derived from `steps` rather than from
    /// the enum so a shortened flow still counts to its own end.
    public var stepCount: Int { steps.filter { $0 != .welcome }.count }

    /// Position among the collecting steps, 1-based; 0 while Welcome is showing.
    public var stepNumber: Int {
        if step == .welcome {
            return 0
        }
        return steps.prefix(stepIndex + 1).filter { $0 != .welcome }.count
    }

    /// Overall, not per-section: a bar that reset at each heading would read as going back.
    public var progress: Float {
        stepCount == 0 ? 0 : Float(stepNumber) / Float(stepCount)
    }

    /// Step 1 has nothing behind it: the flow can be stepped through, never escaped.
    public var canGoBack: Bool { stepIndex > 0 }

    public var isSkippable: Bool { step != .welcome && step != .sex }

    public var showInvalidHeight: Bool {
        !heightText.trimmingCharacters(in: .whitespaces).isEmpty && MeasurementInput.parseHeightCm(heightText) == nil
    }

    public var showInvalidWeight: Bool {
        !weightText.trimmingCharacters(in: .whitespaces).isEmpty && MeasurementInput.parseWeightKg(weightText) == nil
    }

    /// Sex is the one hard gate; the numeric steps only block on a value that is present but
    /// unusable.
    public var canContinue: Bool {
        if isSaving {
            return false
        }
        switch step {
        case .sex: return sex != nil
        case .height: return !showInvalidHeight
        case .weight: return !showInvalidWeight
        default: return true
        }
    }
}

/// The events the onboarding screen emits. The twin of Kotlin's `OnboardingEvent` sealed
/// interface, ported to a Swift enum with associated values (the UDF event shape).
public enum OnboardingEvent: Sendable, Equatable {
    case nextClicked
    case backClicked
    /// Clears whatever the current step collects and moves on.
    case skipClicked
    case nameChanged(String)
    case sexSelected(Sex)
    case birthDateSelected(Int)
    case heightChanged(String)
    case weightChanged(String)
    case healthNotesChanged(String)
}
