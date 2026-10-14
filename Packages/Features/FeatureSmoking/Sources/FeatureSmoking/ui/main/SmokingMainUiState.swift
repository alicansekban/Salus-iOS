// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/main/
// SmokingMainUiState.kt`.
//
// Two shape differences from the Kotlin state. `liveNowMs` is gone: Android's ViewModel moves it
// between snapshots, here the view's `TimelineView` hands the counters their instant, so the state
// holds only what the screen has been told. A second: Android's `UndoOffered` effect is gone. The
// ViewModel shows the undo snackbar through the shell's controller itself (see
// `SmokingMainViewModel`), so no effect has to reach a Route that may already be off screen.

import SalusSmoking

/// What the main screen shows. `snapshot` is `nil` until the first one arrives. `isPremium` is the
/// entitlement the two premium cards read: the goal card and the insights teaser lock without it.
/// `writing` is true from the first tap of a confirm until its write ends, and disables the sheets'
/// buttons.
public struct SmokingMainUiState: Equatable, Sendable {
    public var snapshot: SmokingSnapshot?
    public var isPremium: Bool
    public var sheet: MainSheet?
    public var writing: Bool

    public init(
        snapshot: SmokingSnapshot? = nil,
        isPremium: Bool = false,
        sheet: MainSheet? = nil,
        writing: Bool = false
    ) {
        self.snapshot = snapshot
        self.isPremium = isPremium
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
    /// REDUCE "Bırakmaya hazırım": picks the instant the quit attempt starts.
    case quitDate
    /// The savings-goal sheet. `title` and `targetMinor` are the goal being edited, or empty and
    /// `nil` for a first or a next goal. `editingGoalId` is that goal's id: set, saving updates the
    /// goal and keeps its progress (contract §8.17); `nil`, saving creates a new goal that counts
    /// from now.
    case goal(title: String, targetMinor: Int64?, editingGoalId: String?)
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
    /// The goal card: the paywall when locked, otherwise the goal sheet.
    case goalTapped
    /// Save in the goal sheet; `targetMinor` is in the plan's currency.
    case goalSaved(title: String, targetMinor: Int64)
    case goalDismissed
    /// The insights teaser: the paywall when locked, otherwise Trends.
    case insightsTapped
    case historyTapped
    case settingsTapped

    // MARK: REDUCE

    /// The large "+1": one unit logged now.
    case plusOne
    /// The snackbar's "Geri al": removes the entry the +1 wrote, by id.
    case undoPlusOne(eventId: String)
    /// "Bugün hiç içmedim": writes the zero marker for today.
    case noneToday
    /// "Bırakmaya hazırım": opens the quit-date sheet; nothing is written yet.
    case readyToQuit
    case quitDateConfirmed(quitAtMs: Int64)
    case quitDateDismissed
    /// The greyed "Bıraktığında seni bekleyenler" card.
    case timelinePreviewTapped
    /// The route found no plan under it (a stale milestone notification opened the screen after
    /// "Takibi sıfırla"). The ViewModel then swaps this screen for the setup.
    case planMissing
}

/// One-shot UI work. Navigation is not here: the ViewModel navigates through the `Navigator`.
public enum SmokingMainEffect: Equatable, Sendable {
    /// A refused or failed write; the Route shows the message for the error.
    case showError(SmokingMainError)
    /// Trends belongs to another feature, so the Route asks the shell to open it.
    case openTrends
}

/// Why a write the main screen made was refused, which picks the snackbar's words.
public enum SmokingMainError: Equatable, Sendable {
    case generic
    /// A quit date before the previous attempt ended (contract §8.10).
    case quitOverlap
    /// A quit date after "now".
    case quitFuture
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
