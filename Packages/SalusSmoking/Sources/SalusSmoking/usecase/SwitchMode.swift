import SalusCommon

/// Switches the plan between QUIT and REDUCE. Nothing is deleted either way (contract §6): the
/// attempt that ends stays in the history and its events keep their links.
public struct SwitchMode: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    /// QUIT to REDUCE requires `dailyLimit` and closes the active attempt now with
    /// `SWITCHED_TO_REDUCE`. REDUCE to QUIT opens an attempt at `quitAtMs` (default now; a past
    /// instant is fine, a future one is `futureQuitDate`; one before the previous attempt's end is
    /// `invalidInput`).
    public func callAsFunction(to target: SmokingMode, dailyLimit: Int64? = nil, quitAtMs: Int64? = nil) async throws {
        let clock = clock
        let idGenerator = idGenerator
        try await store.mutate { writes in
            let input = writes.input
            let plan = try input.requirePlan()
            if plan.mode == target {
                throw SmokingError.invalidInput
            }
            let now = clock.nowEpochMilliseconds()
            switch target {
            case .reduce:
                guard let dailyLimit, dailyLimit >= 1 else { throw SmokingError.invalidInput }
                for open in input.attempts where open.endedAtMs == nil {
                    try writes.updateAttempt(open.closed(at: max(now, open.startedAtMs), reason: .switchedToReduce))
                }
                try writes.savePlan(plan.withMode(.reduce, dailyLimit: dailyLimit))

            case .quit:
                let start = quitAtMs ?? now
                if start > now {
                    throw SmokingError.futureQuitDate
                }
                try input.requireNotBeforeClosedAttempts(except: nil, startMs: start)
                let attempt = QuitAttempt(
                    id: idGenerator.newId(),
                    startedAtMs: start,
                    tzId: clock.timeZone().identifier,
                    endedAtMs: nil,
                    endReason: nil
                )
                try writes.savePlan(plan.withMode(.quit, dailyLimit: nil))
                try writes.addAttempt(attempt)
                // A back-dated start covers entries logged while REDUCE was active: they are slips now.
                try writes.rederiveEvents(attempts: input.attempts + [attempt])
            }
        }
    }
}
