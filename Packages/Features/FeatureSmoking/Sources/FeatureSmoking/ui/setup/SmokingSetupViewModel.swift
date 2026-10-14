// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/setup/
// SmokingSetupViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place;
// `viewModelScope.launch` becomes a `Task` inside a `@MainActor` type. The buffered `Channel` of
// effects becomes `pendingEffects` + `consumeEffects()` (`MoreViewModel`'s shape): nothing is
// dropped while the Route is not looking.

import Foundation
import Observation
import SalusCommon
import SalusNavigation
import SalusSmoking

/// The setup wizard. Nothing is written until the last page's "Başla": back at any point, from the
/// first page too, leaves the database as it was.
///
/// `defaultCurrencyCode` comes from the locale, which only the view layer can read
/// (`@Environment(\.locale)`), so the Route passes it in.
@MainActor
@Observable
public final class SmokingSetupViewModel {
    public private(set) var state: SmokingSetupUiState

    /// Errors waiting for the Route to show them, oldest first.
    public private(set) var pendingEffects: [SmokingSetupEffect] = []

    private let setUpSmoking: SetUpSmoking
    private let clock: any SalusClock
    private let navigator: Navigator

    public init(
        defaultCurrencyCode: String,
        setUpSmoking: SetUpSmoking,
        clock: any SalusClock,
        navigator: Navigator
    ) {
        self.setUpSmoking = setUpSmoking
        self.clock = clock
        self.navigator = navigator
        state = SmokingSetupUiState(
            currencyCode: defaultCurrencyCode,
            quitAtMs: clock.nowEpochMilliseconds(),
            todayEpochDay: Int64(clock.todayEpochDay()),
            zoneId: clock.timeZone().identifier
        )
    }

    /// Drains the queued effects in order, leaving the queue empty.
    @discardableResult
    public func consumeEffects() -> [SmokingSetupEffect] {
        let drained = pendingEffects
        pendingEffects.removeAll()
        return drained
    }

    // One case per event, as in the Kotlin `when`; the arms are one-liners.
    // swiftlint:disable:next cyclomatic_complexity
    public func onEvent(_ event: SmokingSetupEvent) {
        switch event {
        case let .modeSelected(mode):
            state.mode = mode

        case let .productSelected(product):
            state = state.withProduct(product)

        case let .unitsPerDayChanged(units):
            state.unitsPerDay = units.clamped(to: 1 ... SetupDefaults.maxUnits)

        case let .unitsPerPackChanged(units):
            state.unitsPerPack = units.clamped(to: 1 ... SetupDefaults.maxUnits)

        case let .priceChanged(text):
            state.priceText = String(text.prefix(Self.maxPriceLength))

        case let .priceQuickAdded(wholeUnits):
            state = state.withQuickAdd(wholeUnits)

        case let .currencySelected(code):
            state.currencyCode = code

        case let .quitAtChanged(epochMs):
            setQuitAt(epochMs)

        case .quitNowClicked:
            state.quitAtMs = nowMs()
            state.quitAtEdited = false

        case let .reasonChanged(text):
            state.reason = String(text.prefix(Self.maxReasonLength))

        case let .dailyLimitChanged(limit):
            state.dailyLimitOverride = limit.clamped(to: 1 ... SetupDefaults.maxUnits)

        case .changeProductClicked:
            state.step = .product

        case .continueClicked:
            continueOrStart()

        case .backClicked:
            back()

        case let .stepSelected(step):
            // Only a step already passed reopens, and never mid-write.
            guard !state.isSaving, step.rawValue < state.step.rawValue else { return }
            state.step = step
        }
    }

    private func setQuitAt(_ epochMs: Int64) {
        // The sheet rejects a future moment inline; this is the state's own guard, so a value that
        // slips past it can never reach the use case as a quit date.
        guard epochMs <= nowMs() else {
            pendingEffects.append(.showError(.futureDate))
            return
        }
        state.quitAtMs = epochMs
        state.quitAtEdited = true
    }

    private func back() {
        guard !state.isSaving else { return }
        if state.step == .mode {
            navigator.pop()
        } else if let previous = SetupStep(rawValue: state.step.rawValue - 1) {
            state.step = previous
        }
    }

    private func continueOrStart() {
        guard state.canContinue else { return }
        if state.step == .details {
            start(state)
        } else if let next = SetupStep(rawValue: state.step.rawValue + 1) {
            state.step = next
        }
    }

    private func start(_ current: SmokingSetupUiState) {
        guard let price = current.price else { return }
        // Set before the write and kept after a success, so a second tap while the screen is
        // leaving cannot write twice.
        state.isSaving = true
        let quit = current.mode == .quit
        let quitAtMs = quit ? (current.quitAtEdited ? current.quitAtMs : nowMs()) : nil
        let reason = current.reason.isEmpty ? nil : current.reason
        Task { [weak self, setUpSmoking] in
            do {
                try await setUpSmoking(
                    mode: current.mode,
                    productType: current.product,
                    baselineUnitsPerDay: Int64(current.baselineUnitsPerDay),
                    price: price,
                    currencyCode: current.currencyCode,
                    dailyLimit: quit ? nil : Int64(current.dailyLimit),
                    reason: reason,
                    quitAtMs: quitAtMs
                )
                // The setup is replaced by the main screen: popping first leaves More under it, so
                // back from the main screen never returns into a finished wizard.
                self?.navigator.pop()
                self?.navigator.navigate(SmokingKey())
            } catch {
                // A refusal (`SmokingError`) and a storage fault both end the same way: the wizard
                // stays on its last page with the button live again, and the person is told. A
                // store that cannot be read at all reaches here as a write failure — it never
                // pushes the main screen, so the More row cannot loop through it.
                self?.state.isSaving = false
                self?.pendingEffects.append(.showError(error.setupError))
            }
        }
    }

    private func nowMs() -> Int64 {
        clock.nowEpochMilliseconds()
    }

    private static let maxPriceLength = 12
    private static let maxReasonLength = 200
}

/// Another product asks another question (weekly spend instead of a pack price), so a price typed
/// for the old kind is dropped rather than reread as the new one.
extension SmokingSetupUiState {
    fileprivate func withProduct(_ newProduct: ProductType) -> SmokingSetupUiState {
        var copy = self
        copy.product = newProduct
        if (newProduct == .vape) != isVape {
            copy.priceText = ""
        }
        return copy
    }

    fileprivate func withQuickAdd(_ wholeUnits: Int) -> SmokingSetupUiState {
        var copy = self
        let raised = (priceMinor ?? 0) + Int64(wholeUnits) * pow10(fractionDigits)
        copy.priceText = plainAmount(minor: raised, fractionDigits: fractionDigits)
        return copy
    }
}

extension Error {
    fileprivate var setupError: SmokingSetupError {
        switch self as? SmokingError {
        case .futureQuitDate: .futureDate
        case .invalidInput, .notSetUp: .invalid
        case nil: .generic
        }
    }
}

extension Int {
    fileprivate func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
