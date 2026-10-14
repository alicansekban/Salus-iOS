// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainUiState.kt`.
//
// Two shape differences from the Kotlin state. `liveNowMs` is gone: Android's ViewModel moves it
// between snapshots, here the view's `TimelineView` hands the counters their instant, so the state
// holds only what the screen has been told. And `isPremium` is not here yet — nothing on this task's
// screen reads it; the savings-goal and insights cards (plan Task 15) add it with their consumers.

import SalusSmoking

/// What the main screen shows. `snapshot` is `nil` until the first one arrives. `writing` is true
/// from the first tap of a confirm until its write ends, and disables the sheets' buttons.
public struct SmokingMainUiState: Equatable, Sendable {
    public var snapshot: SmokingSnapshot?
    public var sheet: MainSheet?
    public var writing: Bool

    public init(snapshot: SmokingSnapshot? = nil, sheet: MainSheet? = nil, writing: Bool = false) {
        self.snapshot = snapshot
        self.sheet = sheet
        self.writing = writing
    }
}

/// The sheet over the main screen, if any.
public enum MainSheet: Equatable, Sendable {
    /// Which entry is being described: the one the slip sheet has just written.
    case trigger(eventId: String)
    /// `units` is where the stepper starts.
    case slip(units: Int)
}

public enum SmokingMainEvent: Equatable, Sendable {
    case cravingTapped
    /// "Sigara içtim": opens the slip sheet; nothing is written yet.
    case smokedTapped
    case slipConfirmed(units: Int, restart: Bool)
    /// "Şimdilik kapat" and a swipe away: writes nothing.
    case slipDismissed
    case triggerSaved(trigger: CravingTrigger?, intensity: Int?)
    /// "Atla" and a swipe away: the entry stays as the slip sheet logged it.
    case triggerSkipped
    /// The next-stage card: opens the timeline on that stage.
    case stageTapped
    case goalTapped
    case insightsTapped
    case historyTapped
    case settingsTapped
}

/// One-shot UI work. Navigation is not here: the ViewModel navigates through the `Navigator`.
public enum SmokingMainEffect: Equatable, Sendable {
    /// A refused or failed write; the Route shows ``SmokingStrings/errorGeneric``.
    case showError
}

extension QuitSnapshot {
    /// The instant the snapshot was computed for. It carries durations rather than its own "now",
    /// and the attempt's elapsed time is `now − start`, so adding them gives it back.
    var computedAtMs: Int64 {
        attemptStartedAtMs + attemptElapsedMs
    }

    /// The instant of the last smoke, which the live counters measure the hour from.
    var lastSmokeAtMs: Int64 {
        computedAtMs - sinceLastSmokeMs
    }

    /// The attempt's elapsed time at `nowMs`.
    func liveElapsedMs(at nowMs: Int64) -> Int64 {
        max(0, nowMs - attemptStartedAtMs)
    }

    /// The time since the last smoke at `nowMs`.
    func liveSinceLastSmokeMs(at nowMs: Int64) -> Int64 {
        max(0, sinceLastSmokeMs + (nowMs - computedAtMs))
    }
}
