import Testing

@testable import SalusSmoking

@Suite("SetUpSmoking", .timeLimit(.minutes(1)))
struct SetUpSmokingTests {
    private let env: SmokingTestEnv

    init() throws {
        env = try SmokingTestEnv()
    }

    @Test("QUIT writes the plan, today's first price and an attempt at the quit instant")
    func quitWritesThreeRows() async throws {
        let quitAt = ms("2026-03-09T08:30")

        try await env.module.setUp(
            mode: .quit,
            productType: .rolled,
            baselineUnitsPerDay: 12,
            price: .perUnit(450),
            currencyCode: " try ",
            reason: "  for my kids ",
            quitAtMs: quitAt,
            notificationsEnabled: false
        )

        let input = try await env.input()
        let plan = try #require(input.plan)
        #expect(plan.mode == .quit)
        #expect(plan.productType == .rolled)
        #expect(plan.baselineUnitsPerDay == 12)
        #expect(plan.dailyLimit == nil)
        #expect(plan.currencyCode == "TRY")
        #expect(plan.reason == "for my kids")
        #expect(plan.notificationsEnabled == false)
        #expect(plan.eveningReminderEnabled == false)
        #expect(plan.createdAtMs == ms("2026-03-10T12:00"))
        #expect(plan.tzId == "Europe/Istanbul")
        #expect(input.prices == [PricePeriod(
            id: input.prices.first?.id ?? "",
            effectiveFromEpochDay: day("2026-03-10"),
            unitCostMinor: 450
        )])
        let attempt = try #require(input.attempts.first)
        #expect(input.attempts.count == 1)
        #expect(attempt.startedAtMs == quitAt)
        #expect(attempt.endedAtMs == nil)
        #expect(attempt.tzId == "Europe/Istanbul")
    }

    @Test("QUIT without a quit instant starts the attempt now")
    func quitDefaultsToNow() async throws {
        try await env.module.setUp(
            mode: .quit,
            productType: .cigarette,
            baselineUnitsPerDay: 10,
            price: .perUnit(5000),
            currencyCode: "TRY"
        )

        #expect(try await env.input().attempts.first?.startedAtMs == ms("2026-03-10T12:00"))
    }

    @Test("REDUCE stores the limit and opens no attempt")
    func reduceStoresTheLimit() async throws {
        try await env.reduceSetUp()

        let input = try await env.input()
        #expect(input.plan?.mode == .reduce)
        #expect(input.plan?.dailyLimit == 8)
        #expect(input.attempts.isEmpty)
    }

    @Test("a vape stores the weekly spend over seven rounded half up, and a baseline of one")
    func vapeWeeklySpend() async throws {
        try await env.module.setUp(
            mode: .quit,
            productType: .vape,
            baselineUnitsPerDay: 99,
            price: .weeklySpend(1000),
            currencyCode: "EUR"
        )

        let input = try await env.input()
        #expect(input.plan?.baselineUnitsPerDay == 1)
        // 1000 / 7 = 142.857 -> 143
        #expect(input.prices.first?.unitCostMinor == 143)
    }

    @Test("weekly spend rounds half up at the seven-day boundaries", arguments: [
        (0, 0), (1, 0), (3, 0), (4, 1), (7, 1), (10, 1), (11, 2), (1000, 143), (10500, 1500)
    ] as [(Int64, Int64)])
    func weeklySpendRounding(weekly: Int64, expected: Int64) {
        #expect(SmokingPrice.weeklySpend(weekly).unitCostMinor == expected)
    }

    @Test("a weekly spend near Int64.max does not overflow")
    func weeklySpendHuge() {
        #expect(SmokingPrice.weeklySpend(Int64.max).unitCostMinor == Int64.max / 7)
    }

    @Test("the price kind has to match the product")
    func priceKindMatchesProduct() async {
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.setUp(
                mode: .quit,
                productType: .vape,
                baselineUnitsPerDay: 1,
                price: .perUnit(100),
                currencyCode: "TRY"
            )
        }
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.setUp(
                mode: .quit,
                productType: .cigarette,
                baselineUnitsPerDay: 5,
                price: .weeklySpend(700),
                currencyCode: "TRY"
            )
        }
    }

    @Test("a future quit instant fails with futureQuitDate and writes nothing")
    func futureQuitDate() async throws {
        await #expect(throws: SmokingError.futureQuitDate) {
            try await env.module.setUp(
                mode: .quit,
                productType: .cigarette,
                baselineUnitsPerDay: 10,
                price: .perUnit(5000),
                currencyCode: "TRY",
                quitAtMs: ms("2026-03-10T12:00") + 1
            )
        }

        #expect(try await env.input().plan == nil)
    }

    @Test("invalid answers are refused", arguments: [
        SetUpCase(baseline: 0, price: 100, currency: "TRY", limit: nil, mode: .quit),
        SetUpCase(baseline: 10, price: -1, currency: "TRY", limit: nil, mode: .quit),
        SetUpCase(baseline: 10, price: 100, currency: "TR", limit: nil, mode: .quit),
        SetUpCase(baseline: 10, price: 100, currency: "T3Y", limit: nil, mode: .quit),
        SetUpCase(baseline: 10, price: 100, currency: "TRY", limit: nil, mode: .reduce),
        SetUpCase(baseline: 10, price: 100, currency: "TRY", limit: 0, mode: .reduce)
    ])
    func invalidAnswers(_ answer: SetUpCase) async throws {
        await #expect(throws: SmokingError.invalidInput) {
            try await env.module.setUp(
                mode: answer.mode,
                productType: .cigarette,
                baselineUnitsPerDay: answer.baseline,
                price: .perUnit(answer.price),
                currencyCode: answer.currency,
                dailyLimit: answer.limit
            )
        }
        #expect(try await env.input().plan == nil)
    }

    @Test("setting up again while a plan exists is invalid")
    func setUpTwice() async throws {
        try await env.quitSetUp()

        await #expect(throws: SmokingError.invalidInput) {
            try await env.quitSetUp()
        }
    }

    @Test("a blank reason is stored as none, and the listener hears of the setup once")
    func blankReasonAndNotification() async throws {
        try await env.module.setUp(
            mode: .quit,
            productType: .cigarette,
            baselineUnitsPerDay: 10,
            price: .perUnit(5000),
            currencyCode: "TRY",
            reason: "   "
        )

        #expect(try await env.input().plan?.reason == nil)
        #expect(env.notifications.value == 1)
    }
}

struct SetUpCase: Sendable, CustomTestStringConvertible {
    let baseline: Int64
    let price: Int64
    let currency: String
    let limit: Int64?
    let mode: SmokingMode

    var testDescription: String {
        "\(mode) baseline \(baseline) price \(price) currency \(currency) limit \(String(describing: limit))"
    }
}
