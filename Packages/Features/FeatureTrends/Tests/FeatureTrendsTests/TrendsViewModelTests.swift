// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/ui/TrendsViewModelTest.kt`.
//
// The screen's side of trends. Nothing about *entitlement* is decided here — the gate lives in
// `TrendsRepository`, and this class is only allowed to turn one answer into one screen.
//
// That is also why there is no test for "a free user is kept off the screen": reaching it is
// deliberately free, and the lock is something the user is shown rather than something that stops
// them.
//
// `advanceUntilIdle()` becomes `waitUntil`, for the reason `AiSummaryViewModelTests` records: the
// ViewModel's work is on the main actor's cooperative queue rather than on a virtual scheduler.

import Foundation
import Observation
import SalusModel
import SalusPremium
import Testing

@testable import FeatureTrends

@Suite("TrendsViewModel")
@MainActor
struct TrendsViewModelTests {
    private let repository = FakeTrendsRepository()
    private let premium = FakePremiumRepository()
    private let paywall = PaywallController()
    private let preferences = FakeTrendsPreferences()

    /// `TrendsViewModelTest.kt` — the screen opens on the quarter, loading.
    @Test("the screen opens on the quarter, loading")
    func screenOpensOnQuarterLoading() {
        let viewModel = viewModel()

        // Before anything has answered: the default window, and a spinner rather than a lock.
        #expect(viewModel.state.range == .quarter)
        #expect(viewModel.state.isLoading)
        #expect(!viewModel.state.hasLoaded)
    }

    /// `TrendsViewModelTest.kt` — opening the screen loads the default window once.
    @Test("opening the screen loads the default window once")
    func openingLoadsTheDefaultWindowOnce() async {
        let viewModel = viewModel()

        await waitUntil("the first load to answer") { !viewModel.state.isLoading }

        #expect(repository.requests == [.quarter])
        #expect(viewModel.state.data == .locked)
        #expect(viewModel.state.hasLoaded)
    }

    /// `TrendsViewModelTest.kt` — `hasLoaded` stays false until the first load answers, then never
    /// goes back.
    @Test("hasLoaded stays false until the first load answers, then never goes back")
    func hasLoadedStaysFalseUntilFirstLoadThenNeverBack() async {
        let viewModel = viewModel()

        #expect(!viewModel.state.hasLoaded)

        await waitUntil("the first load to answer") { viewModel.state.hasLoaded }

        // A later load dims the body it is replacing instead of taking it away, so the flag marks
        // "there is an answer on screen" rather than "nothing is in flight".
        viewModel.onEvent(.rangeSelected(.year))
        #expect(viewModel.state.isLoading)
        #expect(viewModel.state.hasLoaded)
    }

    /// `TrendsViewModelTest.kt` — selecting a window reloads with it.
    @Test("selecting a window reloads with it")
    func selectingAWindowReloadsWithIt() async {
        let viewModel = viewModel()
        await waitUntil("the first load to answer") { !viewModel.state.isLoading }

        viewModel.onEvent(.rangeSelected(.year))
        await waitUntil("the selected window to load") { !viewModel.state.isLoading }

        #expect(repository.requests == [.quarter, .year])
        #expect(viewModel.state.range == .year)
    }

    /// `TrendsViewModelTest.kt` — re-selecting the window already showing reads nothing.
    @Test("re-selecting the window already showing reads nothing")
    func reselectingTheWindowReadsNothing() async {
        let viewModel = viewModel()
        await waitUntil("the first load to answer") { !viewModel.state.isLoading }

        viewModel.onEvent(.rangeSelected(.quarter))
        await waitUntil("no further load to happen") { repository.requests.count == 1 }

        #expect(repository.requests == [.quarter])
    }

    /// `TrendsViewModelTest.kt` — the upgrade button opens the paywall from the trends source.
    @Test("the upgrade button opens the paywall from the trends source")
    func upgradeButtonOpensThePaywall() async {
        let viewModel = viewModel()
        await waitUntil("the first load to answer") { !viewModel.state.isLoading }

        viewModel.onEvent(.upgradeClicked)

        #expect(paywall.request?.source == .trends)
        // Nothing else moves: the button asks for the sheet and does not navigate or reload.
        #expect(repository.requests == [.quarter])
    }

    /// `TrendsViewModelTest.kt` — landing on the locked screen does not open the paywall by itself.
    @Test("landing on the locked screen does not open the paywall by itself")
    func landingOnLockedDoesNotOpenThePaywall() async {
        let viewModel = viewModel()
        await waitUntil("the first load to answer") { !viewModel.state.isLoading }

        #expect(paywall.request == nil)
    }

    /// `TrendsViewModelTest.kt` — becoming entitled reloads the screen without a tap.
    @Test("becoming entitled reloads the screen without a tap")
    func becomingEntitledReloadsWithoutATap() async {
        let viewModel = viewModel()
        // Wait for the initial load to both issue and finish — the state opens on `.locked`, so
        // waiting on `data` alone would return before the entitlement observer ever subscribed.
        await waitUntil("the first load to issue and finish") {
            repository.requests == [.quarter] && !viewModel.state.isLoading
        }
        repository.answer = .empty

        premium.set(.premium)
        // Two loads: the initial free one, then the auto-reload once entitled.
        await waitUntil("the reload after entitlement to answer") {
            repository.requests == [.quarter, .quarter] && !viewModel.state.isLoading
        }

        #expect(viewModel.state.data == .empty)
        #expect(!viewModel.state.isLoading)
        #expect(repository.requests == [.quarter, .quarter])
    }

    /// `TrendsViewModelTest.kt` — the reload after a purchase keeps the window the user had chosen.
    @Test("the reload after a purchase keeps the chosen window")
    func reloadAfterPurchaseKeepsTheChosenWindow() async {
        repository.answer = .empty
        let viewModel = viewModel()
        await waitUntil("the first load to answer") { !viewModel.state.isLoading }
        viewModel.onEvent(.rangeSelected(.halfYear))
        await waitUntil("the half-year window to load") { !viewModel.state.isLoading }

        premium.set(.premium)
        await waitUntil("the entitlement reload to fire") { repository.requests.count == 3 }

        #expect(repository.requests == [.quarter, .halfYear, .halfYear])
    }

    /// The retry button reads the window already selected again, bypassing the same-window guard.
    @Test("a failed load carries to the screen, and retry reads the same window again")
    func failedLoadThenRetryReadsTheSameWindow() async {
        repository.answer = .failed
        let viewModel = viewModel()
        await waitUntil("the failed load to answer") { viewModel.state.data == .failed }

        repository.answer = .empty
        viewModel.onEvent(.retryClicked)
        await waitUntil("the retry to answer") { viewModel.state.data == .empty }

        // Retry bypasses the same-window guard a range tap goes through.
        #expect(repository.requests == [.quarter, .quarter])
        #expect(!viewModel.state.isLoading)
    }

    /// `TrendsViewModelTest.kt` — the unit arrives in the state.
    @Test("the screen starts on the reader's unit and redraws on change")
    func theScreenCarriesTheGlucoseUnit() async {
        preferences.unit = .mmolL
        let viewModel = viewModel()

        await waitUntil("the unit to reach the state and the first load to run") {
            viewModel.state.glucoseUnit == .mmolL && repository.requests == [.quarter]
        }

        #expect(viewModel.state.glucoseUnit == .mmolL)
        // The unit only changes how numbers are written; it never re-reads the window.
        #expect(repository.requests == [.quarter])
    }

    private func viewModel() -> TrendsViewModel {
        TrendsViewModel(
            repository: repository,
            paywallController: paywall,
            premiumRepository: premium,
            preferences: preferences
        )
    }
}

/// A repository whose answer a test sets by hand, and which records the ranges it was asked for.
private final class FakeTrendsRepository: TrendsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [TrendsRange] = []
    var answer: TrendsData = .locked

    /// The ranges each load was asked for, in order.
    var requests: [TrendsRange] {
        lock.withLock { recorded }
    }

    func load(range: TrendsRange) async -> TrendsData {
        lock.withLock { recorded.append(range) }
        return lock.withLock { answer }
    }
}

/// A preferences object whose unit a test sets by hand.
private final class FakeTrendsPreferences: TrendsPreferences, @unchecked Sendable {
    private let lock = NSLock()
    private var current: GlucoseUnit
    private var continuations: [UUID: AsyncStream<GlucoseUnit>.Continuation] = [:]

    init() {
        current = .default
    }

    var unit: GlucoseUnit {
        get { lock.withLock { current } }
        set {
            lock.lock()
            current = newValue
            let continuations = Array(continuations.values)
            lock.unlock()
            for continuation in continuations {
                continuation.yield(newValue)
            }
        }
    }

    var glucoseUnit: AsyncStream<GlucoseUnit> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let value = current
            lock.unlock()
            continuation.yield(value)
            continuation.onTermination = { [weak self] _ in
                self?.remove(id)
            }
        }
    }

    private func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}

/// A `PremiumRepository` whose status a test sets by hand.
private final class FakePremiumRepository: PremiumRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var current: PremiumStatus
    private var continuations: [UUID: AsyncStream<PremiumStatus>.Continuation] = [:]

    init(status: PremiumStatus = .free) {
        current = status
    }

    var status: AsyncStream<PremiumStatus> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let value = current
            lock.unlock()
            continuation.yield(value)
            continuation.onTermination = { [weak self] _ in
                self?.remove(id)
            }
        }
    }

    func set(_ newStatus: PremiumStatus) {
        lock.lock()
        current = newStatus
        let continuations = Array(continuations.values)
        lock.unlock()
        for continuation in continuations {
            continuation.yield(newStatus)
        }
    }

    func refresh() async {}

    private func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
