// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/setup/
// SmokingSetupUiState.kt`.
//
// Money is `Int64` minor units and a count of cigarettes is an `Int`; the use case takes both as
// `Int64`, and the conversion happens once, in the ViewModel's `start`. Kotlin's `@StringRes` on
// the effect becomes a small error kind: the Route turns it into a string, so a test asserts the
// kind and never a localised sentence.

import SalusSmoking

/// The four pages of the wizard, in order; the position shown as "n/4" is `rawValue + 1`.
public enum SetupStep: Int, CaseIterable, Sendable {
    case mode
    case product
    case amount
    case details
}

/// What the amount step's live card says, in minor units; formatting happens on screen.
public enum SetupSummary: Equatable, Sendable {
    /// A pack-priced product: a day of it and a year of days.
    case daily(dailyMinor: Int64, yearlyMinor: Int64)
    /// A vape is priced weekly: a week and fifty-two of them.
    case weekly(weeklyMinor: Int64, yearlyMinor: Int64)
}

/// Everything the wizard shows. `priceText` is what the person typed — the pack price, the pouch
/// price or, for a vape, the weekly spend — and `priceMinor` is that text read in the currency's
/// own decimals, `nil` while it is not a valid amount. `quitAtMs` is only the shown quit moment;
/// `quitAtEdited == false` means "now", which the start resolves at the tap rather than at the
/// moment the wizard opened.
public struct SmokingSetupUiState: Equatable, Sendable {
    public var currencyCode: String
    public var quitAtMs: Int64
    public var todayEpochDay: Int64
    public var zoneId: String
    public var step: SetupStep
    public var mode: SmokingMode
    public var product: ProductType
    public var unitsPerDay: Int
    public var unitsPerPack: Int
    public var priceText: String
    public var quitAtEdited: Bool
    public var reason: String
    /// A limit the person chose; `nil` means "the suggestion", which follows the baseline.
    public var dailyLimitOverride: Int?
    public var isSaving: Bool

    public init(
        currencyCode: String,
        quitAtMs: Int64,
        todayEpochDay: Int64,
        zoneId: String,
        step: SetupStep = .mode,
        mode: SmokingMode = .quit,
        product: ProductType = .cigarette,
        unitsPerDay: Int = SetupDefaults.unitsPerDay,
        unitsPerPack: Int = SetupDefaults.unitsPerPack,
        priceText: String = "",
        quitAtEdited: Bool = false,
        reason: String = "",
        dailyLimitOverride: Int? = nil,
        isSaving: Bool = false
    ) {
        self.currencyCode = currencyCode
        self.quitAtMs = quitAtMs
        self.todayEpochDay = todayEpochDay
        self.zoneId = zoneId
        self.step = step
        self.mode = mode
        self.product = product
        self.unitsPerDay = unitsPerDay
        self.unitsPerPack = unitsPerPack
        self.priceText = priceText
        self.quitAtEdited = quitAtEdited
        self.reason = reason
        self.dailyLimitOverride = dailyLimitOverride
        self.isSaving = isSaving
    }

    public var stepNumber: Int {
        step.rawValue + 1
    }

    public var stepCount: Int {
        SetupStep.allCases.count
    }

    public var isVape: Bool {
        product == .vape
    }

    public var fractionDigits: Int {
        FeatureSmoking.fractionDigits(ofCurrency: currencyCode)
    }

    public var priceMinor: Int64? {
        parseMinorUnits(priceText, fractionDigits: fractionDigits)
    }

    /// The price as the use case takes it: per unit for a pack, weekly for a vape. A pack price is
    /// divided by its size rounded half up, like the vape's weekly seven (contract §6, §8.11): the one
    /// rule is `unitCostFromPackPrice`, shared with the settings price sheet.
    public var price: SmokingPrice? {
        guard let minor = priceMinor, minor > 0 else { return nil }
        if isVape {
            return .weeklySpend(minor)
        }
        return .perUnit(unitCostFromPackPrice(priceMinor: minor, unitsPerPack: unitsPerPack))
    }

    /// What one cigarette, stick or rolled cigarette — or a vape's day — costs, once stored.
    public var unitCostMinor: Int64? {
        price?.unitCostMinor
    }

    public var summary: SetupSummary? {
        guard let priced = price else { return nil }
        if isVape {
            return .weekly(weeklyMinor: priced.minor, yearlyMinor: priced.minor * SetupDefaults.weeksPerYear)
        }
        let daily = Int64(unitsPerDay) * priced.unitCostMinor
        return .daily(dailyMinor: daily, yearlyMinor: daily * SetupDefaults.daysPerYear)
    }

    /// The baseline the plan will store: a vape is always one (contract §6), whatever the hidden
    /// per-day stepper holds, so nothing derived from the baseline may read `unitsPerDay` for it.
    public var baselineUnitsPerDay: Int {
        isVape ? 1 : unitsPerDay
    }

    /// 80 % of the baseline, rounded down, never below one (spec §5.1).
    public var suggestedLimit: Int {
        suggestedDailyLimit(baselineUnitsPerDay: baselineUnitsPerDay)
    }

    public var dailyLimit: Int {
        dailyLimitOverride ?? suggestedLimit
    }

    public var canContinue: Bool {
        guard !isSaving else { return false }
        switch step {
        case .mode, .product:
            return true
        case .amount:
            return price != nil && (isVape || (unitsPerDay >= 1 && unitsPerPack >= 1))
        case .details:
            return mode == .quit || dailyLimit >= 1
        }
    }
}

func suggestedDailyLimit(baselineUnitsPerDay: Int) -> Int {
    max(1, baselineUnitsPerDay * SetupDefaults.suggestionPercent / 100)
}

/// The wizard's starting answers and bounds (`SmokingSetupUiState.kt` constants).
public enum SetupDefaults {
    public static let unitsPerDay = 20
    public static let unitsPerPack = 20
    public static let maxUnits = 200
    static let suggestionPercent = 80
    static let weeksPerYear: Int64 = 52
    static let daysPerYear: Int64 = 365
}

public enum SmokingSetupEvent: Equatable, Sendable {
    case modeSelected(SmokingMode)
    case productSelected(ProductType)
    case unitsPerDayChanged(Int)
    case unitsPerPackChanged(Int)
    case priceChanged(String)
    /// The "+₺50" / "+₺100" chips: raises the weekly spend by `wholeUnits` of the currency.
    case priceQuickAdded(wholeUnits: Int)
    case currencySelected(String)
    case quitAtChanged(Int64)
    /// "Şimdi bıraktım": the quit moment is the moment of the start.
    case quitNowClicked
    case reasonChanged(String)
    case dailyLimitChanged(Int)
    /// The "Değiştir" link on the vape variant: back to the product tiles.
    case changeProductClicked
    /// "Devam" on every page but the last, "Başla" on the last.
    case continueClicked
    /// The previous page, or out of the wizard from the first. Android's bar arrow and system back;
    /// iOS cannot intercept its system back button, so the screen has no caller for this today and
    /// the case stays for parity and for tests.
    case backClicked
    /// A finished segment of the step bar, tapped: reopens that page. Only an earlier page opens —
    /// no Kotlin twin, it stands in for stepping back with the system button (see the Screen).
    case stepSelected(SetupStep)
}

/// Why a setup was refused, as a kind the Route turns into the right sentence.
public enum SmokingSetupError: Equatable, Sendable {
    case futureDate
    case invalid
    case generic
}

/// One-shot UI work. Navigation is not here: the ViewModel navigates through the `Navigator`.
public enum SmokingSetupEffect: Equatable, Sendable {
    case showError(SmokingSetupError)
}
