// The wiring review focus 3 (stale notifications) depends on, proved through the real use cases:
// `makeSmokingModule` registers the resync listener on the core, every committed write asks the
// scheduler to refill the window, and the refill withdraws or moves what the write made stale.
// The listener unit test in `SmokingNotificationTextTests` calls the listener directly, so it would
// stay green if the registration line were deleted; these would not.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusNavigation
import SalusPremium
import SalusReminder
import SalusSmoking
import SalusTesting
import SalusUI
import Testing

@testable import FeatureSmoking

private final class CountingScheduler: ReminderScheduler, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var syncs: Int { lock.withLock { count } }
    func requestSync() {
        lock.withLock { count += 1 }
    }
}

/// One real core over an in-memory database and a fixed clock at the quit instant.
@MainActor
private struct RealCore {
    typealias Fix = SmokingReminderFixtures

    let clock = FixedSalusClock(now: Fix.at("2026-03-10T09:00"), timeZone: Fix.zone)
    let core: SmokingCoreModule

    init() throws {
        let clock = clock
        core = try SmokingCoreModule(
            smokingDao: SmokingDao(database: SalusDatabase.inMemory(clock: clock)),
            clock: clock,
            idGenerator: CountingIds()
        )
    }

    func setUpQuit() async throws {
        try await core.setUp(
            mode: .quit,
            productType: .cigarette,
            baselineUnitsPerDay: 20,
            price: .perUnit(1000),
            currencyCode: "TRY"
        )
    }
}

@MainActor
@Suite("Smoking reminder resync wiring")
struct SmokingReminderWiringTests {
    private typealias Fix = SmokingReminderFixtures

    @Test("module construction registers the resync: setup, switch to reduce and reset each request a sync")
    func moduleRegistersTheResync() async throws {
        let real = try RealCore()
        let scheduler = CountingScheduler()
        _ = makeSmokingModule(
            core: real.core,
            clock: real.clock,
            snackbar: SalusSnackbarController(),
            navigator: Navigator(),
            reminderScheduler: scheduler,
            reminderEnvironment: AuthorizedEnvironment(),
            premiumRepository: FakePremiumRepository(),
            paywallController: PaywallController()
        )
        #expect(scheduler.syncs == 0)

        try await real.setUpQuit()
        #expect(scheduler.syncs == 1)

        try await real.core.switchMode(to: .reduce, dailyLimit: 10)
        #expect(scheduler.syncs == 2)

        try await real.core.resetSmoking()
        #expect(scheduler.syncs == 3)
    }

    @Test("the module's craving ViewModel closes the module's own cover, not the stack under it")
    func cravingViewModelClosesTheModulesCover() async throws {
        let real = try RealCore()
        let stack = FakeNavigator()
        let module = makeSmokingModule(
            core: real.core,
            clock: real.clock,
            snackbar: SalusSnackbarController(),
            navigator: stack.navigator,
            reminderScheduler: CountingScheduler(),
            reminderEnvironment: AuthorizedEnvironment(),
            premiumRepository: FakePremiumRepository(),
            paywallController: PaywallController()
        )
        module.cravingPresenter.consume(.navigate(AnyNavKey(SmokingCravingKey(source: "main"))))
        let viewModel = module.makeCravingViewModel()

        viewModel.onEvent(.closeTapped)
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(module.cravingPresenter.presented == nil)
        #expect(stack.commandLog.isEmpty)
    }
}

/// The real synchronizer and ledger over the real core, driven by the real use cases.
@MainActor
@Suite("Smoking reminders follow the data")
struct SmokingReminderLifecycleTests {
    private typealias Fix = SmokingReminderFixtures

    private let real: RealCore
    private let dao: ReminderAlarmDao
    private let gateway = PendingCountingGateway()
    private let synchronizer: ReminderWindowSynchronizer

    init() throws {
        real = try RealCore()
        let clock = real.clock
        dao = try ReminderAlarmDao(database: SalusDatabase.inMemory(clock: clock))
        let handler = SmokingReminderHandler(
            repository: real.core.repository,
            clock: clock,
            strings: FakeSmokingNotificationStrings()
        )
        synchronizer = ReminderWindowSynchronizer(
            dao: dao,
            gateway: gateway,
            handlerRegistry: ReminderHandlerRegistry(all: [handler]),
            environment: AuthorizedEnvironment(),
            clock: clock,
            idGenerator: CountingIdGenerator(),
            config: .ios
        )
    }

    private func smokingRows() async throws -> [ReminderAlarmRecord] {
        try await dao.getScheduled().filter { $0.type == ReminderType.smoking.rawValue }
    }

    /// The ledger rows of `before`, re-read: their states now.
    private func states(of before: [ReminderAlarmRecord]) async throws -> [String] {
        var states: [String] = []
        for row in before {
            let current = try await dao.getByOccurrence(
                type: row.type,
                entityId: row.entityId,
                occurrenceKey: row.occurrenceKey
            )
            states.append(current?.state ?? "missing")
        }
        return states
    }

    @Test("a reset withdraws every pending smoking request and cancels its rows")
    func resetWithdrawsEverything() async throws {
        try await real.setUpQuit()
        await synchronizer.sync()
        let before = try await smokingRows()
        #expect(!before.isEmpty)
        #expect(await gateway.pendingRequestCodes().count == before.count)

        try await real.core.resetSmoking()
        await synchronizer.sync()

        #expect(await gateway.pendingRequestCodes().isEmpty)
        #expect(try await smokingRows().isEmpty)
        let after = try await states(of: before)
        #expect(after.allSatisfy { $0 == AlarmState.cancelled.rawValue })
    }

    @Test("switching to reduce (evening reminder off) withdraws the quit milestones")
    func switchToReduceWithdrawsTheMilestones() async throws {
        try await real.setUpQuit()
        await synchronizer.sync()
        let before = try await smokingRows()
        #expect(!before.isEmpty)

        try await real.core.switchMode(to: .reduce, dailyLimit: 10)
        await synchronizer.sync()

        #expect(await gateway.pendingRequestCodes().isEmpty)
        #expect(try await states(of: before).allSatisfy { $0 == AlarmState.cancelled.rawValue })
    }

    @Test("a slip moves the early notification to 20 minutes after it, in the same ledger row")
    func slipMovesTheEarlyKey() async throws {
        try await real.setUpQuit()
        await synchronizer.sync()
        let early = try #require(try await smokingRows().first { $0.occurrenceKey.hasSuffix(":early") })
        #expect(early.triggerAtEpochMs == Fix.ms("2026-03-10T09:20"))

        real.clock.advanceTo(Fix.at("2026-03-10T09:06"))
        try await real.core.logSmoked(units: 1, atMs: Fix.ms("2026-03-10T09:05"))
        await synchronizer.sync()

        let moved = try #require(try await smokingRows().first { $0.occurrenceKey == early.occurrenceKey })
        #expect(moved.triggerAtEpochMs == Fix.ms("2026-03-10T09:25"))
        #expect(moved.id == early.id)
        // Nothing is left pending for the old instant.
        #expect(try await gateway.pendingRequestCodes().count == (smokingRows().count))
    }
}
