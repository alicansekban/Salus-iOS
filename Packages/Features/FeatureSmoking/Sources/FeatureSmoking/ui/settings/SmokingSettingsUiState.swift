// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/settings/
// SmokingSettingsUiState.kt`.
//
// The effect's `@StringRes` is a kind the Route turns into the sentence (`SmokingSetupError`'s
// shape). The quit date and the amounts stay 64-bit; the limit and the baseline are `Int`.

import SalusSmoking

/// What the settings screen shows, read off the plan. `mode` is ``SettingsMode/none`` until the
/// first snapshot, and for a plan-less one, which this screen has nothing to say about.
///
/// `sheet` and `confirm` are the open editor and the open confirmation. They live here so a
/// rotation keeps them, and they are separate because one follows the other: a currency or a quit
/// date is chosen in a sheet and then confirmed, because both change what the figures mean.
public struct SmokingSettingsUiState: Equatable, Sendable {
    public var loaded: Bool
    public var mode: SettingsMode
    public var productType: ProductType
    public var baselineUnitsPerDay: Int
    /// The clock's zone, which the quit date is shown in.
    public var zoneId: String
    public var currencyCode: String
    public var unitCostMinor: Int64
    public var dailyLimit: Int?
    public var quitAtMs: Int64?
    public var reason: String?
    public var notificationsEnabled: Bool
    public var eveningReminderEnabled: Bool
    public var sheet: SettingsSheet
    public var confirm: SettingsConfirm?
    public var writing: Bool

    public init(
        loaded: Bool = false,
        mode: SettingsMode = .none,
        productType: ProductType = .cigarette,
        baselineUnitsPerDay: Int = 0,
        zoneId: String = "UTC",
        currencyCode: String = "",
        unitCostMinor: Int64 = 0,
        dailyLimit: Int? = nil,
        quitAtMs: Int64? = nil,
        reason: String? = nil,
        notificationsEnabled: Bool = false,
        eveningReminderEnabled: Bool = false,
        sheet: SettingsSheet = .none,
        confirm: SettingsConfirm? = nil,
        writing: Bool = false
    ) {
        self.loaded = loaded
        self.mode = mode
        self.productType = productType
        self.baselineUnitsPerDay = baselineUnitsPerDay
        self.zoneId = zoneId
        self.currencyCode = currencyCode
        self.unitCostMinor = unitCostMinor
        self.dailyLimit = dailyLimit
        self.quitAtMs = quitAtMs
        self.reason = reason
        self.notificationsEnabled = notificationsEnabled
        self.eveningReminderEnabled = eveningReminderEnabled
        self.sheet = sheet
        self.confirm = confirm
        self.writing = writing
    }

    /// The evening reminder asks the person to log their day, which only REDUCE has (review R10).
    public var showEveningReminder: Bool {
        mode == .reduce
    }

    public var showLimit: Bool {
        mode == .reduce
    }

    public var showQuitDate: Bool {
        mode == .quit && quitAtMs != nil
    }
}

public enum SettingsMode: Equatable, Sendable {
    case none
    case quit
    case reduce
}

/// The editor that is open, with the value it opens at when that is not already in the state.
public enum SettingsSheet: Equatable, Sendable {
    case none
    case price
    case limit
    case currency
    case reason
    /// Correcting the start of the current attempt.
    case quitDate(initialMs: Int64)
    /// QUIT to REDUCE asks for a limit; `suggestedLimit` is 80 % of the baseline, as in the setup.
    case switchToReduce(suggestedLimit: Int)
    /// REDUCE to QUIT asks for the quit time, now by default.
    case switchToQuit(initialMs: Int64)
}

/// The question the open dialog asks; accepting it is the only thing that writes.
public enum SettingsConfirm: Equatable, Sendable {
    case currency(String)
    case quitDate(Int64)
    case reset
}

public enum SmokingSettingsEvent: Equatable, Sendable {
    case priceTapped
    case currencyTapped
    case limitTapped
    case quitDateTapped
    case reasonTapped
    case switchModeTapped
    case resetTapped
    case sheetDismissed
    case priceSaved(unitCostMinor: Int64)
    case limitSaved(Int)
    case currencyPicked(String)
    case quitDatePicked(Int64)
    case reasonSaved(String)
    case switchToReduceConfirmed(limit: Int)
    case switchToQuitConfirmed(quitAtMs: Int64)
    case confirmAccepted
    case confirmDismissed
    case notificationsToggled(Bool)
    case eveningToggled(Bool)
}

/// Why a settings write was refused, as a kind the Route turns into the right sentence.
public enum SmokingSettingsError: Equatable, Sendable {
    case futureDate
    case invalid
    /// A quit time earlier than the previous attempt's end (contract §8.10).
    case overlap
    case generic
}

/// One-shot UI work. Navigation is not here: a reset pops through the `Navigator`.
public enum SmokingSettingsEffect: Equatable, Sendable {
    case showError(SmokingSettingsError)
    /// A switch was turned on while the system would not show the notification.
    case openReminderHealth
}
