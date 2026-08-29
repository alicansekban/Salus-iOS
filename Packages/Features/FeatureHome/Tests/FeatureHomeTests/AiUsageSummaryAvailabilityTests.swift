// Covers `data/AiUsageSummaryAvailability.swift`.
//
// There is no Kotlin test file to port: Android's twin is the three-line
// `AiSummaryRepositoryImpl.freeSummaryAvailable` (`core/ai/.../AiSummaryRepository.kt:137-139`) and
// it is covered from `AiSummaryRepositoryTest.kt:534-551` (`freeSummaryAvailable follows the stored
// usage`), a file that belongs to `:core:ai` rather than to Home. So every case here is iOS-only,
// and what they pin is exactly what that Kotlin case pins plus the `distinctUntilChanged` the
// Kotlin chains after the `map`.
//
// Each test gets its own throwaway `UserDefaults` suite, the shape `SalusSettingsTests`'
// `TestUserDefaults` set: Swift Testing runs suites in parallel, so a shared domain would let one
// test read another's writes.

import Foundation
import SalusSettings
import Testing

@testable import FeatureHome

@Suite("AiUsageSummaryAvailability")
struct AiUsageSummaryAvailabilityTests {
    /// The unspent credit is what the badge is for: nothing stored means the free summary is still
    /// available (`AiSummaryRepositoryTest.kt:536-537`).
    @Test("an unspent free summary reads as available", .timeLimit(.minutes(1)))
    func anUnspentFreeSummaryReadsAsAvailable() async throws {
        let fixture = try Fixture()

        var iterator = fixture.availability.freeSummaryAvailable.makeAsyncIterator()

        #expect(await iterator.next() == true)
    }

    /// Spending the credit reaches a live collector (`AiSummaryRepositoryTest.kt:539-541`).
    @Test("spending the free summary flips a live collector to unavailable", .timeLimit(.minutes(1)))
    func spendingTheFreeSummaryFlipsALiveCollectorToUnavailable() async throws {
        let fixture = try Fixture()
        var iterator = fixture.availability.freeSummaryAvailable.makeAsyncIterator()
        #expect(await iterator.next() == true)

        fixture.aiUsage.markFreeSummaryUsed()

        #expect(await iterator.next() == false)
    }

    /// The `distinctUntilChanged` half of `AiSummaryRepository.kt:137-139`. `recordCall` changes
    /// the usage — a different day and count — without touching the free credit, so a collector
    /// that saw `true` must not be woken with `true` again. Awaiting the *next* element and finding
    /// `false` is what proves the repeat was dropped rather than merely reordered.
    @Test("a usage change that leaves the credit alone emits nothing", .timeLimit(.minutes(1)))
    func aUsageChangeThatLeavesTheCreditAloneEmitsNothing() async throws {
        let fixture = try Fixture()
        var iterator = fixture.availability.freeSummaryAvailable.makeAsyncIterator()
        #expect(await iterator.next() == true)

        fixture.aiUsage.recordCall(todayEpochDay: 20000)
        fixture.aiUsage.markFreeSummaryUsed()

        #expect(await iterator.next() == false)
    }

    /// A throwaway suite plus the availability over it. A class rather than a struct because
    /// `deinit` is the only teardown hook that fires whether the test passed, failed or threw —
    /// `CycleReminderSettingsImplTests`' `Fixture`, and `TestUserDefaults`' reason.
    private final class Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let aiUsage: AiUsageDataSource
        let availability: AiUsageSummaryAvailability

        init() throws {
            let suiteName = "salus-home-test-\(UUID().uuidString)"
            self.suiteName = suiteName
            defaults = try #require(
                UserDefaults(suiteName: suiteName),
                "UserDefaults refused the suite name \(suiteName)"
            )
            let aiUsage = AiUsageDataSource(defaults: defaults)
            self.aiUsage = aiUsage
            availability = AiUsageSummaryAvailability(aiUsage: aiUsage)
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}
