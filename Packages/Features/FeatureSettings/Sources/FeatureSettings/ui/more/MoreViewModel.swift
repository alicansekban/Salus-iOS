// Ported 1:1 from
// `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/ui/more/MoreViewModel.kt`.
//
// The hub state, the five event gates and the buffered effects. Four divergences from the Kotlin
// twin, all forced by the platform and recorded here so a reader sees them without leaving the file:
//
//   1. **`appStoreSubscriptionsUrl`.** Kotlin sends an entitled user to Play's account-level
//      subscription page (`PLAY_SUBSCRIPTIONS_URL`,
//      `https://play.google.com/store/account/subscriptions`). iOS sends them to the App Store's
//      (`https://apps.apple.com/account/subscriptions`) — the platform-mapped twin.
//   2. **`Channel.BUFFERED` → `pendingEffects` array.** Kotlin's buffered `Channel<MoreEffect>`
//      never drops an effect fired while the screen is off-screen. iOS has no `Channel` and
//      `@Observable` has no subscription-count hook, so the effects accumulate in
//      ``pendingEffects`` and ``consumeEffects()`` drains them in order — nothing dropped, the
//      array grows until consumed. The single-effect `ReminderHealthViewModel.pendingEffect` /
//      `consumeEffect()` shape (M7) is the precedent, generalised to a queue because the More tab
//      can fire two effects back-to-back (e.g. an entitled user tapping premium then trends).
//   3. **`stateIn(WhileSubscribed(5_000))` → `restartObservation()`.** `@Observable` has no
//      subscription-count hook, so the collection runs from `init` to `deinit` and
//      ``restartObservation()`` re-runs it. `MoreRoute`'s `.task` calls the latter on every
//      appearance (plan ruling 3, the `VitalsViewModel.restartHistoryObservation()` precedent). The
//      half of `WhileSubscribed` that is **behavioural here** is re-capturing the profile stream —
//      which, like `TodayRepositoryImpl.observeTodayOverview()`, fixes its read once at creation —
//      so a returning screen re-reads rather than drawing a stale snapshot. Divergence: Android
//      re-captures after a five-second unsubscribed grace, iOS on every appearance.
//   4. **Stream combine.** Kotlin `combine(profile, themeMode, appLock, secureScreen, secondaryState)`
//      where `secondaryState = combine(language, activeDialog, premiumRepository.status,
//      preferences.premiumTheme)`. `combine`'s typed overloads stop at five, so the four "secondary"
//      values are folded into one before joining the rest. iOS spells each combine as a `latestOf*`
//      fold from `SalusCommon`, and the two mutable holders (`language`, `activeDialog`) — Kotlin's
//      `MutableStateFlow`s — are ``CurrentValueStream``s: `AsyncStream`s with a stored continuation
//      the ViewModel yields into, the same shape `FakePremiumRepository` uses for its test fake.
//      `throwingStream(over:)` re-types the non-throwing `AsyncStream`s so they can join the
//      throwing `profileRepository.observeProfile()` in `latestOfFive`.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusPremium
import SalusProfile

/// Drives the More tab (`MoreViewModel.kt:26-145`).
@MainActor
@Observable
public final class MoreViewModel {
    /// `MoreViewModel.kt:53-78` — what the screen draws.
    public private(set) var state = MoreUiState()

    /// `Channel.BUFFERED`'s twin (divergence 2): the effects fired while the screen was off-screen,
    /// waiting for ``consumeEffects()`` to drain them in order. Nothing is dropped.
    public private(set) var pendingEffects: [MoreEffect] = []

    // The two mutable holders the Kotlin spells as `MutableStateFlow` (divergence 4). Each is a
    // `CurrentValueStream` the ViewModel yields into from `onEvent`, and the observation folds them
    // into the `secondaryState` bundle exactly as the Kotlin `combine(language, activeDialog, …)`
    // does. Re-created on every `restartObservation()`, so a re-subscribe re-seeds them from the
    // current values held on the VM. Implicitly-unwrapped because they are set in
    // `restartObservation()` (called from `init`) before any access — the same shape
    // `HomeViewModel`'s `observation` would take if it were re-created on restart.
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var languageHolder: CurrentValueStream<AppLanguage>!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var activeDialogHolder: CurrentValueStream<MoreDialog?>!
    /// The freshest entitlement the stream has produced, read by `onEvent`'s gates exactly as the
    /// Kotlin reads `premiumRepository.status.value`. Updated atomically inside the
    /// fold so a gate between two emissions reads the latest value, not the one state last showed.
    private var latestPremiumStatus: PremiumStatus = .free

    private let profileRepository: any ProfileRepository
    private let premiumRepository: any PremiumRepository
    private let preferences: any SettingsPreferences
    private let localeController: any AppLocaleController
    private let paywallController: PaywallController

    /// The collection. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let observation = CancellationBox()

    /// The five parameters are the five Koin resolves for `viewModelOf(::MoreViewModel)`, in the
    /// Kotlin order (`MoreViewModel.kt:26-32`).
    public init(
        profileRepository: any ProfileRepository,
        premiumRepository: any PremiumRepository,
        preferences: any SettingsPreferences,
        localeController: any AppLocaleController,
        paywallController: PaywallController
    ) {
        self.profileRepository = profileRepository
        self.premiumRepository = premiumRepository
        self.preferences = preferences
        self.localeController = localeController
        self.paywallController = paywallController
        restartObservation()
    }

    deinit {
        observation.cancel()
    }

    // `MoreViewModel.kt:80-145`.
    // swiftlint:disable:next cyclomatic_complexity
    public func onEvent(_ event: MoreEvent) {
        // The two holders are implicitly-unwrapped optionals (set in `restartObservation`), so a
        // capture list sees them as optional. Bind them to non-optional locals once per call so the
        // bodies below read the same way the Kotlin reads its `MutableStateFlow`s.
        let language: CurrentValueStream<AppLanguage> = languageHolder
        let activeDialog: CurrentValueStream<MoreDialog?> = activeDialogHolder

        switch event {
        case let .dialogRequested(dialog):
            activeDialog.send(dialog)

        case .dialogDismissed:
            activeDialog.send(nil)

        case let .selectTheme(mode):
            Task { [preferences, activeDialog] in
                await preferences.setThemeMode(mode)
                activeDialog.send(nil)
            }

        case let .colorThemeSelected(theme):
            // Spec section 3: the gate is here, not in the screen. A free user may open the picker
            // and tap any palette — the tap opens the paywall and nothing is written, so an
            // unentitled selection can never reach the store and be restored on next launch. The
            // gate reads the held entitlement, not `state.premiumStatus`, which is
            // only current while the observation is mid-emission — the same reason the Kotlin reads
            // `premiumRepository.status.value`.
            if latestPremiumStatus.isEntitled {
                Task { [preferences, activeDialog] in
                    await preferences.setPremiumTheme(theme)
                    activeDialog.send(nil)
                }
            } else {
                activeDialog.send(nil)
                paywallController.show(.themes)
            }

        case let .selectLanguage(languageEvent):
            // The locale lives with appcompat/UIApplication rather than in the DataStore, so it is
            // read once and tracked in the `languageHolder` rather than observed — the same comment
            // the Kotlin makes (`MoreViewModel.kt:34-35`). `apply` is called exactly once.
            localeController.apply(languageEvent)
            language.send(languageEvent)
            activeDialog.send(nil)

        case let .setAppLock(enabled):
            Task { [preferences] in
                await preferences.setAppLockEnabled(enabled)
            }

        case let .setSecureScreen(enabled):
            Task { [preferences] in
                await preferences.setSecureScreenEnabled(enabled)
            }

        case .premiumClicked:
            // Someone who already pays has nothing to buy here: the row takes them to the store's
            // own subscription management, where cancelling and switching plans actually live. The
            // gate reads the held entitlement, not `state`.
            if latestPremiumStatus.isEntitled {
                pendingEffects.append(.openUrl(Self.appStoreSubscriptionsUrl))
            } else {
                paywallController.show(.settings)
            }

        case .doctorReportClicked:
            // The doctor report is premium in full — there is no free credit for it, so an
            // unentitled tap never reaches the screen. The gate reads the held entitlement, not
            // `state`.
            if latestPremiumStatus.isEntitled {
                pendingEffects.append(.openDoctorReport)
            } else {
                paywallController.show(.doctorReport)
            }

        case .trendsClicked:
            // No gate on purpose. The trends screen shows its own locked body and offers the paywall
            // from there, so a free user gets to see what the feature is before being asked to pay
            // for it — the opposite trade-off from the doctor report above, which has nothing to
            // show until it is generated.
            pendingEffects.append(.openTrends)
        }
    }

    /// Drains the buffered effects in order, leaving the queue empty — the twin of collecting
    /// Kotlin's `Channel<MoreEffect>` until it suspends. The screen calls this when it is ready to
    /// perform the one-shot work, the same way `ReminderHealthViewModel.consumeEffect()` is called.
    @discardableResult
    public func consumeEffects() -> [MoreEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    /// Re-runs the whole join, which re-captures the profile stream (plan ruling 3, divergence 3).
    ///
    /// **Why this is public.** `ProfileRepository.observeProfile()` is a fresh stream per access
    /// that re-runs its query on invalidation; `@Observable` has no subscription-count hook, so
    /// `MoreRoute` calls this from its `.task`, which SwiftUI re-runs on every appearance — the
    /// same precedent `HomeViewModel.restartObservation()` sets. The previous collection is
    /// cancelled and the state is **left standing** until the new one emits, which is what
    /// `stateIn` holds on to across a restart, so a returning screen never flashes its spinner.
    public func restartObservation() {
        observation.cancel()

        // Re-seed the two mutable holders from the values the VM is currently holding. The Kotlin
        // `MutableStateFlow`s survive a re-subscribe because they live on the ViewModel, not the
        // stream; the `CurrentValueStream`s are per-observation, so they are rebuilt here with the
        // last values the previous holders saw — `language` from the locale controller's current
        // answer (the holder only ever mirrors `apply`), `activeDialog` from the last event.
        let previousLanguage = languageHolder?.current ?? localeController.current()
        let previousDialog: MoreDialog? = activeDialogHolder?.current
        languageHolder = CurrentValueStream(previousLanguage)
        activeDialogHolder = CurrentValueStream(previousDialog)

        // `MoreViewModel.kt:46-51` — the four values the top-level combine has no argument slots
        // for, folded into one `SecondaryState` before joining the rest. `throwingStream(over:)`
        // re-types the non-throwing `AsyncStream`s so they can join the throwing premium stream in
        // `latestOfFour`. The combinator takes no transform, so the Kotlin lambda that builds the
        // `SecondaryState` becomes a `mapped` step here.
        let secondaryState = mapped(
            latestOfFour(
                throwingStream(over: languageHolder.stream),
                throwingStream(over: activeDialogHolder.stream),
                throwingStream(over: premiumRepository.status),
                throwingStream(over: preferences.premiumTheme)
            )
        ) { SecondaryState($0, $1, $2, $3) }

        // `MoreViewModel.kt:53-73` — the top-level combine. `profileRepository.observeProfile()`
        // is already throwing; the three preference streams are re-typed.
        let combined = latestOfFive(
            profileRepository.observeProfile(),
            throwingStream(over: preferences.themeMode),
            throwingStream(over: preferences.appLockEnabled),
            throwingStream(over: preferences.secureScreenEnabled),
            secondaryState
        )

        observation.replace(with: Task { [weak self] in
            do {
                for try await (profile, themeMode, appLock, secureScreen, secondary) in combined {
                    guard let self, !Task.isCancelled else { return }
                    publish(
                        profile: profile,
                        themeMode: themeMode,
                        appLock: appLock,
                        secureScreen: secureScreen,
                        secondary: secondary
                    )
                }
            } catch {
                // A failing `Flow` cancels its collector on Android and the screen keeps whatever
                // it last drew; the same happens here, and it is this port's house pattern — there
                // is no retry affordance on either platform, so there is nothing the user could act
                // on. A failure before the first emission leaves `isLoading` true and the screen
                // spinning, which is what Android's `stateIn` initial value does too.
            }
        })
    }

    /// `combine`'s lambda (`MoreViewModel.kt:60-73`). The secondary bundle is destructured here so
    /// the top-level fold stays the one place the state is assembled.
    private func publish(
        profile: Profile?,
        themeMode: ThemeMode,
        appLock: Bool,
        secureScreen: Bool,
        secondary: SecondaryState
    ) {
        latestPremiumStatus = secondary.premiumStatus
        state = MoreUiState(
            isLoading: false,
            profileName: profile?.displayName ?? "",
            // Only an explicit MALE hides cycle tracking: a profile that skipped the question keeps
            // the feature visible rather than losing it silently (`MoreViewModel.kt:64-65`).
            showCycle: profile != nil && profile?.sex != .male,
            themeMode: themeMode,
            premiumTheme: secondary.premiumTheme,
            language: secondary.language,
            premiumStatus: secondary.premiumStatus,
            appLockEnabled: appLock,
            secureScreenEnabled: secureScreen,
            activeDialog: secondary.activeDialog
        )
    }

    /// The App Store's account-level subscription page — the platform-mapped twin of Kotlin's
    /// `PLAY_SUBSCRIPTIONS_URL` (divergence 1).
    private static let appStoreSubscriptionsUrl = "https://apps.apple.com/account/subscriptions"
}

/// The values the top-level combine has no argument slots left for, joined into one
/// (`MoreViewModel.kt:151-157`). `Sendable` so it can travel through the throwing combinator under
/// Swift 6 strict concurrency.
private struct SecondaryState: Sendable, Equatable {
    let language: AppLanguage
    let activeDialog: MoreDialog?
    let premiumStatus: PremiumStatus
    let premiumTheme: PremiumTheme

    init(
        _ language: AppLanguage,
        _ activeDialog: MoreDialog?,
        _ premiumStatus: PremiumStatus,
        _ premiumTheme: PremiumTheme
    ) {
        self.language = language
        self.activeDialog = activeDialog
        self.premiumStatus = premiumStatus
        self.premiumTheme = premiumTheme
    }
}

/// A `MutableStateFlow`'s twin for the two values the ViewModel needs to yield into from `onEvent`
/// and fold into the combine (divergence 4). Emits the current value on subscription, then once per
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
