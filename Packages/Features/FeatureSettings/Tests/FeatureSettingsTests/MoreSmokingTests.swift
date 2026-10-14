// Ported from the "Smoking" region of `feature/settings/src/test/kotlin/com/alicansekban/salus/
// feature/settings/ui/more/MoreViewModelTest.kt` (branch `feature/m17-smoking-cessation`): the
// chip's mode follows the plan, and the row opens setup or the main screen from what the
// repository says at the tap. Kept apart from `MoreViewModelTests`, which stays the ported
// pre-M17 table.

import Foundation
import SalusPremium
import SalusSmoking
import Testing

@testable import FeatureSettings

/// A ``SmokingRepository`` whose snapshot a test sets and re-emits — `FakeSmokingRepository` in the
/// Kotlin test. Push-capable so the chip can be seen following the plan.
final class FakeSmokingRepository: SmokingRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var current: SmokingSnapshot
    private var continuations: [UUID: AsyncStream<SmokingSnapshot>.Continuation] = [:]

    init(snapshot: SmokingSnapshot = .notSetUp) {
        current = snapshot
    }

    func set(_ snapshot: SmokingSnapshot) {
        let live = lock.withLock {
            current = snapshot
            return Array(continuations.values)
        }
        for continuation in live {
            continuation.yield(snapshot)
        }
    }

    func observeInput() -> AsyncStream<SmokingInput> {
        AsyncStream { $0.finish() }
    }

    func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            let snapshot = lock.withLock {
                continuations[id] = continuation
                return current
            }
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.continuations[id] = nil }
            }
        }
    }

    func snapshotNow() async -> SmokingSnapshot {
        lock.withLock { current }
    }
}

enum SmokingFixtures {
    static func plan(_ mode: SmokingMode) -> SmokingPlan {
        SmokingPlan(
            id: "plan",
            mode: mode,
            productType: .cigarette,
            baselineUnitsPerDay: 20,
            dailyLimit: mode == .reduce ? 16 : nil,
            currencyCode: "TRY",
            reason: nil,
            notificationsEnabled: true,
            eveningReminderEnabled: false,
            createdAtMs: 0,
            tzId: "Europe/Istanbul"
        )
    }

    static func quit() -> SmokingSnapshot {
        .quit(
            QuitSnapshot(
                plan: plan(.quit),
                attemptId: "a1",
                attemptStartedAtMs: 0,
                attemptElapsedMs: 0,
                sinceLastSmokeMs: 0,
                slipCount: 0,
                unitsNotSmoked: 0,
                unitsNotSmokedToday: 0,
                savedMinor: 0,
                timeRegainedMinutes: 0,
                cravingsBeaten: 0,
                cravingsBeatenAllTime: 0,
                stages: [],
                nextStage: nil,
                attempts: [],
                goal: nil
            )
        )
    }

    static func reduce() -> SmokingSnapshot {
        .reduce(
            ReduceSnapshot(
                plan: plan(.reduce),
                todayEpochDay: 0,
                todayUnits: 0,
                todayHasEntry: false,
                dailyLimit: 16,
                last7Days: [],
                weekReductionUnits: 0,
                weekSavedMinor: 0,
                savedSinceSetupMinor: 0,
                cravingsBeatenAllTime: 0,
                stagesPreview: [],
                goal: nil
            )
        )
    }
}

@Suite("MoreViewModel smoking")
@MainActor
struct MoreSmokingTests {
    private func makeViewModel(_ smoking: FakeSmokingRepository) -> MoreViewModel {
        MoreViewModel(
            profileRepository: FakeProfileRepository(),
            premiumRepository: FakePremiumRepository(value: .free),
            preferences: FakeSettingsPreferences(),
            localeController: FakeAppLocaleController(),
            paywallController: PaywallController(),
            smokingRepository: smoking
        )
    }

    @Test("smoking mode is nil until a plan exists and then follows the plan's mode")
    func smokingModeFollowsThePlan() async {
        let smoking = FakeSmokingRepository()
        let vm = makeViewModel(smoking)
        await waitUntil("the first state") { !vm.state.isLoading }
        #expect(vm.state.smokingMode == nil)

        smoking.set(SmokingFixtures.quit())
        await waitUntil("the quit chip") { vm.state.smokingMode == .quit }

        smoking.set(SmokingFixtures.reduce())
        await waitUntil("the reduce chip") { vm.state.smokingMode == .reduce }

        smoking.set(.notSetUp)
        await waitUntil("the chip to go") { vm.state.smokingMode == nil }
    }

    @Test("the smoking row opens setup while nothing is set up")
    func rowOpensSetupWhileNothingIsSetUp() async {
        let vm = makeViewModel(FakeSmokingRepository())

        vm.onEvent(.smokingClicked)
        await waitUntil("the effect") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.openSmoking(isSetUp: false)])
    }

    @Test("the smoking row opens the main screen once a plan exists")
    func rowOpensTheMainScreenOnceAPlanExists() async {
        let smoking = FakeSmokingRepository()
        let vm = makeViewModel(smoking)

        smoking.set(SmokingFixtures.reduce())
        vm.onEvent(.smokingClicked)
        await waitUntil("the reduce effect") { !vm.pendingEffects.isEmpty }
        #expect(vm.consumeEffects() == [.openSmoking(isSetUp: true)])

        smoking.set(SmokingFixtures.quit())
        vm.onEvent(.smokingClicked)
        await waitUntil("the quit effect") { !vm.pendingEffects.isEmpty }
        #expect(vm.consumeEffects() == [.openSmoking(isSetUp: true)])
    }
}
