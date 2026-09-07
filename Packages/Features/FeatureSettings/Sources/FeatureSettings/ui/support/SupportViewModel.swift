// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/support/SupportViewModel.kt`.
//
// This is the moved-and-renamed About support work from the `feature/support-code` branch — the
// same gateway read, the same 5-tap/3 s reveal, the same "Copied" label and the same
// GRACE_PERIOD→active mapping, now owned by the Support screen. The old About twin
// (`AboutViewModel.kt`) was deleted with the About redesign (`AboutScreen.kt:46-114` carries no
// state anymore).
//
// Two shape differences from the Kotlin twin, both forced by the platform and recorded here so a
// reader sees them without leaving the file:
//
//   1. **`MutableStateFlow` → `@Observable`.** The state is a stored property SwiftUI observes
//      directly, so `_state.update { it.copy(…) }` becomes a mutation of `state`. Same UDF, same
//      single writer: nothing outside this type assigns it (`private(set)`).
//   2. **`combine(copied, idRevealed, premiumRepository.status)` → `latestOfThree`.** The two
//      `MutableStateFlow`s become ``CurrentValueStream``s the ViewModel yields into from `onEvent`,
//      and the premium status joins them through `SalusCommon`'s `latestOfThree` fold — the same
//      shape `MoreViewModel` uses for its secondary bundle. `stateIn(WhileSubscribed(5_000))` has
//      no `@Observable` twin: the observation runs from `init` to `deinit`, and the state is
//      re-seeded from the holders' current values on every re-subscribe.
//
// `viewModelScope.launch { delay(…) }` becomes an unstructured `Task` on the main actor. The type
// is `@MainActor`, so every mutation of `state` and every read of it happens there.

import Foundation
import Observation
import SalusCommon
import SalusPremium

/// Drives the Support screen's premium-status card and hidden support code
/// (`SupportViewModel.kt:17-33`).
///
/// The support code is the RevenueCat `appUserID` read straight off the gateway — the feature never
/// imports RevenueCat, only the gateway seam. The premium status comes from the shared
/// `PremiumRepository`, the same source every other settings screen reads.
///
/// The id line and copy button are hidden until the developer reveals them: five consecutive taps on
/// the screen title, each within [TAP_WINDOW_MILLIS] of the previous. The reveal is session-only —
/// nothing is persisted, so it never survives a process restart.
@MainActor
@Observable
public final class SupportViewModel {
    /// `SupportViewModel.kt:42-57` — what the screen draws.
    public private(set) var state = SupportUiState()

    // The two mutable holders the Kotlin spells as `MutableStateFlow` (divergence 2). Each is a
    // `CurrentValueStream` the ViewModel yields into from `onEvent`, and the observation folds them
    // into the state exactly as the Kotlin `combine(copied, idRevealed, …)` does. Implicitly-unwrapped
    // because they are set in `restartObservation()` (called from `init`) before any access — the
    // same shape `MoreViewModel`'s holders take.
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var copiedHolder: CurrentValueStream<Bool>!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var idRevealedHolder: CurrentValueStream<Bool>!

    /// The timestamp of the last tap, used to decide whether the next one is still "consecutive"
    /// (`SupportViewModel.kt:38-40`).
    private var lastTapMillis: Int64?
    private var tapCount = 0

    private let gateway: any PurchasesGateway
    private let premiumRepository: any PremiumRepository
    private let clock: any SalusClock

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    /// The three parameters are the three Koin resolves for `viewModelOf(::SupportViewModel)`, in
    /// the Kotlin order (`SupportViewModel.kt:29-33`).
    public init(
        gateway: any PurchasesGateway,
        premiumRepository: any PremiumRepository,
        clock: any SalusClock
    ) {
        self.gateway = gateway
        self.premiumRepository = premiumRepository
        self.clock = clock
        restartObservation()
    }

    deinit {
        observation.cancel()
    }

    /// `SupportViewModel.kt:59-73`.
    public func onEvent(_ event: SupportEvent) {
        switch event {
        case .titleTapped:
            onTitleTapped()

        case .copySupportCode:
            // The screen performs the actual clipboard write; the ViewModel only flips the brief
            // "Copied" label so the state stays the single source of truth
            // (`SupportViewModel.kt:63-71`).
            copiedHolder.send(true)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Constants.copiedLabelMillis) * 1_000_000)
                self?.copiedHolder.send(false)
            }
        }
    }

    /// Re-runs the whole join, which re-seeds the two holders from the values the VM is currently
    /// holding — the `@Observable` twin of `stateIn(WhileSubscribed(5_000))` re-subscribing
    /// (divergence 2). The previous collection is cancelled and the state is left standing until the
    /// new one emits, so a returning screen never flashes its initial value.
    public func restartObservation() {
        observation.cancel()

        let previousCopied = copiedHolder?.current ?? false
        let previousIdRevealed = idRevealedHolder?.current ?? false
        copiedHolder = CurrentValueStream(previousCopied)
        idRevealedHolder = CurrentValueStream(previousIdRevealed)

        // `SupportViewModel.kt:42-57` — the three-source combine. The two holders and the premium
        // status stream are re-typed so they can join in `latestOfThree`.
        let combined = latestOfThree(
            throwingStream(over: copiedHolder.stream),
            throwingStream(over: idRevealedHolder.stream),
            throwingStream(over: premiumRepository.status)
        )

        observation.replace(with: Task { [weak self] in
            do {
                for try await (copied, idRevealed, premiumStatus) in combined {
                    guard let self, !Task.isCancelled else { return }
                    state = SupportUiState(
                        appUserID: gateway.appUserID,
                        premiumStatus: premiumStatus,
                        idRevealed: idRevealed,
                        copied: copied
                    )
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever
                // it last drew; the same happens here, and it is this port's house pattern — there
                // is no retry affordance on either platform, so there is nothing the user could act
                // on.
            }
        })
    }

    /// Counts taps toward the reveal. A tap more than [TAP_WINDOW_MILLIS] after the previous one
    /// restarts the count; five taps within the window reveal the support code for the session
    /// (`SupportViewModel.kt:75-88`).
    private func onTitleTapped() {
        if idRevealedHolder.current {
            return
        }
        let now = clock.nowEpochMilliseconds()
        let last = lastTapMillis
        if let last, now - last <= Constants.tapWindowMillis {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapMillis = now
        if tapCount >= Constants.revealTaps {
            idRevealedHolder.send(true)
        }
    }

    private enum Constants {
        /// How long the button reads "Copied" before reverting to "Copy" (`SupportViewModel.kt:92`).
        static let copiedLabelMillis: Int64 = 2000
        /// A tap more than this after the previous one restarts the reveal count (`SupportViewModel.kt:95`).
        static let tapWindowMillis: Int64 = 3000
        /// Consecutive taps needed to reveal the support code (`SupportViewModel.kt:98`).
        static let revealTaps = 5
    }
}

/// A `MutableStateFlow`'s twin for the two values the ViewModel needs to yield into from `onEvent`
/// and fold into the combine (divergence 2). Emits the current value on subscription, then once per
/// `send(_:)`, and never finishes — the same contract `FakePremiumRepository` keeps and the Kotlin
/// `MutableStateFlow` keeps. `@unchecked Sendable` over a lock because the value is mutable state
/// shared between the `onEvent` caller (main actor) and the observation's child tasks.
private final class CurrentValueStream<Value: Sendable & Equatable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    /// The stream the combine folds. Built fresh per call so a re-subscribe (`restartObservation`)
    /// re-seeds from the current value rather than re-using a drained iterator.
    var stream: AsyncStream<Value> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = value
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    /// The latest value, read synchronously — used by `restartObservation` to re-seed the next
    /// holder from the previous one's last value.
    var current: Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    init(_ value: Value) {
        self.value = value
    }

    /// Updates the value and pushes it to every open stream — the twin of `MutableStateFlow.value =`.
    func send(_ newValue: Value) {
        lock.lock()
        value = newValue
        let pending = Array(continuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(newValue)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
