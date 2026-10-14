// Twin of `core/smoking/.../usecase/SetUpSmoking.kt` (contract §6).

import SalusCommon

/// What the user typed for the price step; the use case turns it into one unit cost.
public enum SmokingPrice: Sendable, Equatable {
    /// The cost of one cigarette, stick or rolled cigarette, in minor currency units.
    case perUnit(Int64)
    /// A vape has no countable unit: the weekly spend over seven, rounded half up, is its daily cost.
    case weeklySpend(Int64)

    public var minor: Int64 {
        switch self {
        case let .perUnit(minor), let .weeklySpend(minor):
            minor
        }
    }

    public var unitCostMinor: Int64 {
        switch self {
        case let .perUnit(minor):
            return minor
        case let .weeklySpend(minor):
            // Kotlin spells half-up `floor((2w + 7) / 14)`; splitting off the whole sevens gives the
            // same integer without the `2w` that would overflow near `Int64.max`.
            let (whole, remainder) = (minor / 7, minor % 7)
            return whole + (2 * remainder + 7) / 14
        }
    }
}

/// Writes the plan, the first price period (effective on the setup day) and, for QUIT, the first
/// attempt, in one transaction.
public struct SetUpSmoking: Sendable {
    private let store: any SmokingStore
    private let clock: any SalusClock
    private let idGenerator: any IdGenerator

    public init(store: any SmokingStore, clock: any SalusClock, idGenerator: any IdGenerator) {
        self.store = store
        self.clock = clock
        self.idGenerator = idGenerator
    }

    /// `baselineUnitsPerDay` is ignored for a VAPE (stored as 1). `quitAtMs` is QUIT only and
    /// defaults to now; `dailyLimit` is REDUCE only and required there.
    public func callAsFunction(
        mode: SmokingMode,
        productType: ProductType,
        baselineUnitsPerDay: Int64,
        price: SmokingPrice,
        currencyCode: String,
        dailyLimit: Int64? = nil,
        reason: String? = nil,
        quitAtMs: Int64? = nil,
        notificationsEnabled: Bool = true
    ) async throws {
        let answers = SetUpAnswers(
            mode: mode,
            productType: productType,
            baselineUnitsPerDay: baselineUnitsPerDay,
            price: price,
            currencyCode: currencyCode,
            dailyLimit: dailyLimit,
            reason: reason,
            quitAtMs: quitAtMs,
            notificationsEnabled: notificationsEnabled
        )
        let clock = clock
        let idGenerator = idGenerator
        try await store.mutate { writes in
            let now = clock.nowEpochMilliseconds()
            let currency = try answers.validatedCurrency(nowMs: now)
            if writes.input.plan != nil {
                throw SmokingError.invalidInput
            }

            let tzId = clock.timeZone().identifier
            try writes.savePlan(answers.plan(id: idGenerator.newId(), currency: currency, nowMs: now, tzId: tzId))
            try writes.addPricePeriod(
                PricePeriod(
                    id: idGenerator.newId(),
                    effectiveFromEpochDay: clock.smokingTodayEpochDay,
                    unitCostMinor: price.unitCostMinor
                )
            )
            if mode == .quit {
                try writes.addAttempt(
                    QuitAttempt(
                        id: idGenerator.newId(),
                        startedAtMs: answers.quitAtMs ?? now,
                        tzId: tzId,
                        endedAtMs: nil,
                        endReason: nil
                    )
                )
            }
        }
    }
}

/// The setup wizard's whole answer set, checked and turned into the plan row.
private struct SetUpAnswers {
    let mode: SmokingMode
    let productType: ProductType
    let baselineUnitsPerDay: Int64
    let price: SmokingPrice
    let currencyCode: String
    let dailyLimit: Int64?
    let reason: String?
    let quitAtMs: Int64?
    let notificationsEnabled: Bool

    private var isVape: Bool {
        productType == .vape
    }

    /// Refuses an inconsistent answer set; returns the normalised currency code.
    func validatedCurrency(nowMs: Int64) throws -> String {
        // The price kind has to match the product: a vape is priced weekly, nothing else is.
        var weekly = false
        if case .weeklySpend = price {
            weekly = true
        }
        if isVape != weekly || price.minor < 0 || (!isVape && baselineUnitsPerDay < 1) {
            throw SmokingError.invalidInput
        }
        let currency = try normalizedCurrency(currencyCode)
        if mode == .reduce, (dailyLimit ?? 0) < 1 {
            throw SmokingError.invalidInput
        }
        if mode == .quit, (quitAtMs ?? nowMs) > nowMs {
            throw SmokingError.futureQuitDate
        }
        return currency
    }

    func plan(id: String, currency: String, nowMs: Int64, tzId: String) -> SmokingPlan {
        SmokingPlan(
            id: id,
            mode: mode,
            productType: productType,
            baselineUnitsPerDay: isVape ? 1 : baselineUnitsPerDay,
            dailyLimit: mode == .reduce ? dailyLimit : nil,
            currencyCode: currency,
            reason: normalizedReason(reason),
            notificationsEnabled: notificationsEnabled,
            eveningReminderEnabled: false,
            createdAtMs: nowMs,
            tzId: tzId
        )
    }
}
