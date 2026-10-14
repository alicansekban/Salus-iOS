// Money milestones in major currency units (`smoking-domain-contract.md` §4). A currency is never
// converted (contract §6, `UpdateCurrency`), so the steps only follow its rough magnitude: the four
// currencies whose unit buys a lot get the small steps, every other code the large ones. Twin of
// Android's `MoneySteps.kt`.

public enum MoneySteps {
    private static let smallStepCurrencies: Set = ["EUR", "USD", "GBP", "CHF"]
    private static let smallSteps: [Int64] = [50, 100, 250, 500, 1000, 2500, 5000, 10000]
    private static let largeSteps: [Int64] = [500, 1000, 2500, 5000, 10000, 25000, 50000, 100_000]

    /// The ascending steps, in major units, for an ISO 4217 code. The code is matched as stored
    /// (upper-case), exactly as Android does.
    public static func forCurrency(_ code: String) -> [Int64] {
        smallStepCurrencies.contains(code) ? smallSteps : largeSteps
    }
}
