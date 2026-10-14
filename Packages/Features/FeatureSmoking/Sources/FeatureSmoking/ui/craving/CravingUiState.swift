// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/craving/
// CravingUiState.kt`.
//
// One shape difference. Android's `CravingEffect.ShowError` carries a string resource id; here the
// one effect is a bare case and the Route picks the words (`SmokingStrings.errorGeneric`), the way
// `SmokingMainEffect` hands the Route an error to word.

import Foundation
import SalusSmoking

/// How long the countdown runs: a craving usually passes within 3 to 5 minutes.
let cravingDurationMs: Int64 = 300_000

/// The line under the ring changes this often.
let cravingLinePeriodMs: Int64 = 8000

// The breath is 4 s in, 4 s held, 6 s out (spec §5.5, review R6): one 14 s cycle.
let inhaleMs: Int64 = 4000
let holdMs: Int64 = 4000
let exhaleMs: Int64 = 6000
let breathCycleMs: Int64 = inhaleMs + holdMs + exhaleMs

public enum BreathPhase: CaseIterable, Sendable {
    case inhale
    case hold
    case exhale
}

/// Where in the 14 s breath `elapsedMs` falls.
func breathPhaseAt(elapsedMs: Int64) -> BreathPhase {
    let inCycle = max(0, elapsedMs) % breathCycleMs
    if inCycle < inhaleMs {
        return .inhale
    }
    if inCycle < inhaleMs + holdMs {
        return .hold
    }
    return .exhale
}

/// "04:12": the time left as minutes and seconds, a part second rounded up so the clock reads
/// 00:00 only when nothing is left. Digits only, so it needs no locale.
func countdownText(remainingMs: Int64) -> String {
    let seconds = (max(0, remainingMs) + 999) / 1000
    let minutes = seconds / 60
    let rest = seconds % 60
    return "\(minutes < 10 ? "0" : "")\(minutes):\(rest < 10 ? "0" : "")\(rest)"
}

/// Which mode's plan the person is in, as far as the exits are concerned.
public enum CravingMode: Equatable, Sendable {
    case quit
    case reduce
}

/// One line of the rotation under the ring, as data: the text is resolved where the locale is
/// known. Every figure is a snapshot value (review R8): no per-craving money, nothing physiological.
public enum CravingLine: Hashable, Sendable {
    case smokeFreeDays(Int)
    case saved(minor: Int64, currencyCode: String)
    case nextStage(stageId: String)
    /// The line that is always there: nothing about the person, only the breath.
    case focus
}

/// A sheet over the flow. The slip sheet is QUIT's "Sigara içtim"; the trigger sheet follows a write.
public enum CravingSheet: Equatable, Sendable {
    case slip
    /// Describes the entry `eventId`, which is already written.
    case trigger(eventId: String)
}

/// What the craving screen shows. Everything on it is a function of `elapsedMs`, so the timer, the
/// breathing phase and the shown line cannot disagree. `elapsedMs` is measured from the instant the
/// flow began, which the ViewModel holds across backgrounding.
///
/// `completed` is true once the five minutes are up or the craving is logged. Reaching the end of
/// the timer is only a visual: nothing is written until the person says "Geçti" (`logged`).
/// `loggedCount` is the ordinal of the craving just logged, `nil` when it is not known.
public struct CravingUiState: Equatable, Sendable {
    public var elapsedMs: Int64 = 0
    public var mode: CravingMode?
    public var lines: [CravingLine] = [.focus]
    public var reason: String?
    public var logged = false
    public var loggedCount: Int?
    public var sheet: CravingSheet?
    public var writing = false

    public init() {}

    public var remainingMs: Int64 {
        max(0, cravingDurationMs - elapsedMs)
    }

    public var completed: Bool {
        remainingMs == 0 || logged
    }

    public var phase: BreathPhase {
        breathPhaseAt(elapsedMs: elapsedMs)
    }

    /// The line for this moment; `lines` is never empty.
    public var line: CravingLine {
        let index = Int((max(0, elapsedMs) / cravingLinePeriodMs) % Int64(lines.count))
        return lines[index]
    }
}

public enum CravingEvent: Equatable, Sendable {
    /// "Geçti": writes the craving.
    case passedTapped
    /// "Devam" on the completed screen: asks what triggered the craving.
    case continueTapped
    /// "Sigara içtim".
    case smokedTapped
    case slipConfirmed(units: Int, restart: Bool)
    /// "Şimdilik kapat" and a swipe away: stays on the craving screen, writes nothing.
    case slipDismissed
    case triggerSaved(trigger: CravingTrigger?, intensity: Int?)
    /// "Atla" and a swipe away: the entry stays as it was written.
    case triggerSkipped
    /// The close button: leaves without writing anything.
    case closeTapped
}

/// One-shot UI work. Navigation is not here: the ViewModel navigates through the `Navigator`.
public enum CravingEffect: Equatable, Sendable {
    /// A refused or failed write; the Route says so.
    case showError
}
