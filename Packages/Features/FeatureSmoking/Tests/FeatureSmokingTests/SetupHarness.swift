// The state every `SmokingSetupViewModel` suite shares: one fixed clock, one fake store, one
// recording navigator and a counting id generator, rebuilt per case so nothing leaks across them.
// The two suites reach it through ``SetupSuite``, so a test body reads `store`, `clock`, `viewModel()`
// as plain members, exactly as the single Kotlin test class does.

import Foundation
import SalusCommon
import SalusModel
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

/// Counts up from `id-1`, so what a use case wrote is predictable.
final class CountingIds: IdGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var next = 0

    func newId() -> String {
        lock.withLock {
            next += 1
            return "id-\(next)"
        }
    }
}

@MainActor
struct SetupHarness {
    let zone = FixedSalusClock.defaultZone
    let nowMs: Int64 = 1_773_133_200_000 // 2026-03-10T12:00 Europe/Istanbul
    let clock = FixedSalusClock(now: Date(timeIntervalSince1970: 1_773_133_200))
    let store = FakeSmokingStore()
    let navigator = FakeNavigator()
    let ids = CountingIds()
}

@MainActor
protocol SetupSuite {
    var harness: SetupHarness { get }
}

extension SetupSuite {
    var zone: TimeZone { harness.zone }
    var nowMs: Int64 { harness.nowMs }
    var clock: FixedSalusClock { harness.clock }
    var store: FakeSmokingStore { harness.store }
    var navigator: FakeNavigator { harness.navigator }

    func viewModel(store: FakeSmokingStore? = nil) -> SmokingSetupViewModel {
        SmokingSetupViewModel(
            defaultCurrencyCode: "TRY",
            setUpSmoking: SetUpSmoking(store: store ?? harness.store, clock: harness.clock, idGenerator: harness.ids),
            clock: harness.clock,
            navigator: harness.navigator.navigator
        )
    }

    func ms(_ local: String) throws -> Int64 {
        try #require(LocalDateTime(isoLocalString: local)).instant(in: harness.zone).epochMilliseconds
    }

    /// Walks a pack-priced QUIT setup to the last step with valid answers.
    func toDetailsStep(_ vm: SmokingSetupViewModel) {
        vm.onEvent(.continueClicked) // mode -> product
        vm.onEvent(.continueClicked) // product -> amount
        vm.onEvent(.priceChanged("95"))
        vm.onEvent(.continueClicked) // amount -> details
    }
}
