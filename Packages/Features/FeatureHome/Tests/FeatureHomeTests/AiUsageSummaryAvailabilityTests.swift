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
    /// that saw `true` must not be woken with `true` again.
    ///
    /// It asserts on the **whole collected sequence** rather than on the next element, and that is
    /// the difference between a case that proves the guard and one that only looks like it does.
    /// `.bufferingNewest(1)` means a duplicate `true` yielded by `recordCall` is overwritten by the
    /// `false` that follows it, so a consumer that only wakes at the end reads `[true, false]`
    /// whether the guard is there or not. Here a task drains every element as it arrives and
    /// `settle()` — a bounded run of the cooperative pool, `WaitUntil.swift`'s mechanism without
    /// its condition — gives it the turn it needs *between* the two writes. Verified RED by
    /// deleting `guard available != lastSent`: the middle expectation then reads `[true, true]`.
    @Test("a usage change that leaves the credit alone emits nothing", .timeLimit(.minutes(1)))
    func aUsageChangeThatLeavesTheCreditAloneEmitsNothing() async throws {
        let fixture = try Fixture()
        let collected = Collected()
        let stream = fixture.availability.freeSummaryAvailable
        let collector = Task {
            for await value in stream {
                await collected.append(value)
            }
        }
        defer { collector.cancel() }

        await settle()
        #expect(await collected.values == [true])

        fixture.aiUsage.recordCall(todayEpochDay: 20000)
        await settle()
        #expect(await collected.values == [true])

        fixture.aiUsage.markFreeSummaryUsed()
        await settle()
        #expect(await collected.values == [true, false])
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

/// Everything a collector task saw, in order.
///
/// An `actor` rather than a locked box because the only thing it has to be is safe to append to
/// from a task while the test reads it — and `await` at both ends is also the memory barrier that
/// makes the read see the writes.
private actor Collected {
    private(set) var values: [Bool] = []

    func append(_ value: Bool) {
        values.append(value)
    }
}

/// Hands the cooperative pool enough turns for everything already runnable to finish.
///
/// The same mechanism as `FeatureCycleTests/WaitUntil.swift` — `Task.yield()` in a bounded loop,
/// never wall-clock time — without its condition, because what is being asserted here is that
/// *nothing* arrives: there is no state to wait for, only a point after which "not yet" means
/// "never". The bound is far above the two hops a healthy run needs (the wrapper's task, then the
/// collector's), and it costs nothing when they are already done.
private func settle(turns: Int = 500) async {
    for _ in 0 ..< turns {
        await Task.yield()
    }
}
