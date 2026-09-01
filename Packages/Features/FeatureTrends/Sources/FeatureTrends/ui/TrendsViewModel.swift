// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/TrendsViewModel.kt`.

import Observation
import SalusCommon
import SalusPremium

/// Drives the trends screen (`TrendsViewModel.kt:33-92`).
///
/// It owns no rule about who may see what: the entitlement gate lives in `TrendsRepository`, and
/// this class only turns the one answer it gets back into a screen. Reaching the screen is
/// deliberately free — nothing here checks entitlement before showing it — so a free user lands
/// on the locked body and can see what a subscription buys.
///
/// The first load is started by the entitlement observer rather than by a separate `init` call,
/// which is also what re-arms the screen the moment a purchase completes in the paywall overlay
/// above it.
@MainActor
@Observable
public final class TrendsViewModel {
    /// The screen's state, read directly by the view — the twin of Android's `StateFlow`.
    public private(set) var state: TrendsUiState

    private let repository: any TrendsRepository
    private let paywallController: PaywallController
    private let preferences: any TrendsPreferences

    /// Held so a range switch — or a purchase — cancels the read it replaces.
    ///
    /// A `CancellationBox` rather than a stored `Task`: Swift 6.0 has no isolated `deinit`, so a
    /// `@MainActor` class cannot read its own stored properties from `deinit`. The box is
    /// `@unchecked Sendable` and cancellable from anywhere, which is what lets `deinit` cancel
    /// the load without touching main-actor state.
    private let loadBox = CancellationBox()

    /// The entitlement observation, held so `deinit` can cancel it — same reason as `loadBox`.
    private let entitlementBox = CancellationBox()

    /// The glucose-unit observation, held so `deinit` can cancel it — same reason as `loadBox`.
    private let unitBox = CancellationBox()

    public init(
        repository: any TrendsRepository,
        paywallController: PaywallController,
        premiumRepository: any PremiumRepository,
        preferences: any TrendsPreferences
    ) {
        self.repository = repository
        self.paywallController = paywallController
        self.preferences = preferences
        state = TrendsUiState()

        observeEntitlement(premiumRepository)
        observeGlucoseUnit()
    }

    deinit {
        loadBox.cancel()
        entitlementBox.cancel()
        unitBox.cancel()
    }

    public func onEvent(_ event: TrendsEvent) {
        switch event {
        case let .rangeSelected(range):
            selectRange(range)
        case .upgradeClicked:
            paywallController.show(.trends)
        // Unlike a range tap this does not go through the same-window guard: the whole point of
        // retrying is to read the window that is already selected again.
        case .retryClicked:
            load(state.range)
        }
    }

    /// Re-selecting the window already showing changes nothing and reads nothing
    /// (`TrendsViewModel.kt:77-80`).
    private func selectRange(_ range: TrendsRange) {
        guard range != state.range else { return }
        load(range)
    }

    /// The twin of the Android `loadJob` (`TrendsViewModel.kt:82-91`): sets loading, reads the
    /// window, and only ever turns `hasLoaded` on.
    ///
    /// The `Task.isCancelled` guard is the second half of `loadJob?.cancel()` — a cancelled read
    /// that nevertheless completes must not overwrite a fresher answer that replaced it.
    /// The loading state is set synchronously, exactly as Android sets `_state.value` before
    /// launching the job: a range switch shows the spinner immediately, not a frame late.
    private func load(_ range: TrendsRange) {
        state = TrendsUiState(
            isLoading: true,
            hasLoaded: state.hasLoaded,
            range: range,
            data: state.data,
            glucoseUnit: state.glucoseUnit
        )
        loadBox.replace(with: Task { [weak self] in
            guard let self else { return }
            let data = await repository.load(range: range)
            guard !Task.isCancelled else { return }
            // `hasLoaded` only ever goes true. It marks that the screen has an answer worth
            // keeping on the next reload, and a lapse or a purchase does not take that back.
            state = TrendsUiState(
                isLoading: false,
                hasLoaded: true,
                range: range,
                data: data,
                glucoseUnit: state.glucoseUnit
            )
        })
    }

    /// Re-loads the screen the moment the entitlement flips, in either direction
    /// (`TrendsViewModel.kt:47-54`).
    ///
    /// The first emission is the initial load; every later one is a purchase or a lapse, and both
    /// change what this screen is allowed to show.
    private func observeEntitlement(_ premiumRepository: any PremiumRepository) {
        entitlementBox.replace(with: Task { [weak self] in
            var last: Bool?
            for await status in premiumRepository.status {
                guard let self, !Task.isCancelled else { return }
                let entitled = status.isEntitled
                // The twin of Kotlin's `map { it.isEntitled }.distinctUntilChanged()`: only a
                // change in the entitlement reloads, so a re-emission of the same status does
                // not re-read a window that is already showing.
                guard entitled != last else { continue }
                last = entitled
                load(state.range)
            }
        })
    }

    /// Mirrors the display unit into the state without ever re-running the read
    /// (`TrendsViewModel.kt:59-63`).
    ///
    /// Collected in its own coroutine rather than combined with the entitlement flow: the unit
    /// only changes how numbers are written, so a switch must redraw the screen without
    /// cancelling or re-running the read that is in flight.
    private func observeGlucoseUnit() {
        // The stream is captured here, not read through `self` inside the task, so the weak
        // `self` below is not referenced before the `guard` that unwraps it.
        let units = preferences.glucoseUnit
        unitBox.replace(with: Task { [weak self] in
            for await unit in units {
                guard let self, !Task.isCancelled else { return }
                state = TrendsUiState(
                    isLoading: state.isLoading,
                    hasLoaded: state.hasLoaded,
                    range: state.range,
                    data: state.data,
                    glucoseUnit: unit
                )
            }
        })
    }
}
