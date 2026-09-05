// Ported 1:1 from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/
// HomeUiState.kt`.
//
// The three types that file declares, in its order, with the same defaults. Two shape differences,
// both the port's standing ones:
//
//   `ImmutableList<TodayDose>` / `persistentListOf()` become plain `[TodayDose]` / `[]`. Swift
//   arrays are value types, which is exactly what `kotlinx.collections.immutable` buys on Android —
//   a state a screen cannot mutate behind the ViewModel's back. Recorded so the port is not read as
//   a shortcut (research §9.5).
//
//   `sealed interface HomeEvent` with one `data class` becomes an `enum` with one `case`. The
//   Kotlin's `data class TakeDose(scheduleId, minuteOfDay)` keeps both labels here, because
//   `onEvent(.takeDose("sch-1", 480))` would leave two `Int`-ish arguments in a row unnamed at the
//   call site.
//
// **There is no `HomeEffect`, on either platform.** Home publishes nothing one-shot: every
// navigation it can start is a shell callback the screen invokes directly (research §8), so there
// is no channel to drain and no effect type to port.
//
// `cycle` and `vitals` are optional **here** while `TodayOverview`'s `vitals` is not, and that is
// Android's own asymmetry (`HomeUiState.kt:25-26` vs `TodayModels.kt:54-55`): the default state —
// the one the screen draws before the first emission — has no snapshot to carry, so the field has
// to admit nil. After loading they are always present. `cycle` is optional on both sides now: the
// repository gates it on the profile's sex, so a male profile has no cycle card at all.

/// Which half of the day the header greets in (`HomeUiState.kt:11`).
public enum HomeGreeting: Sendable {
    case morning
    case afternoon
    case evening
    case night
}

/// Everything the dashboard can ask for (`HomeUiState.kt:13-16`).
public enum HomeEvent: Equatable, Sendable {
    /// The "Al" button on a pending dose row (`HomeUiState.kt:15`).
    case takeDose(scheduleId: String, minuteOfDay: Int)
}

/// What the dashboard draws (`HomeUiState.kt:18-30`).
public struct HomeUiState: Sendable {
    public var isLoading: Bool
    /// The day the header's date is formatted from, captured when the state was built.
    public var todayEpochDay: Int
    public var greeting: HomeGreeting
    /// The default profile's display name, for the personalised greeting; nil before seeding.
    public var profileName: String?
    /// (taken + snoozed, total) for today's doses; nil when there are no doses.
    public var doseProgress: (taken: Int, total: Int)?
    public var doses: [TodayDose]
    public var appointments: [UpcomingAppointment]
    /// Non-nil once the first overview has arrived; see the file header.
    public var cycle: CycleSnapshot?
    /// Non-nil once the first overview has arrived; see the file header.
    public var vitals: VitalsSnapshot?
    /// Whether the one-off free AI summary is still unspent (`HomeUiState.kt:28`).
    public var freeAiSummaryAvailable: Bool
    /// Whether the user is entitled to premium (`HomeUiState.kt:29`). Pinned `false` until iOS-M9
    /// binds a real ``HomePremiumStatus`` — recorded divergence (d).
    public var isPremium: Bool

    public init(
        isLoading: Bool = true,
        todayEpochDay: Int = 0,
        greeting: HomeGreeting = .morning,
        profileName: String? = nil,
        doseProgress: (taken: Int, total: Int)? = nil,
        doses: [TodayDose] = [],
        appointments: [UpcomingAppointment] = [],
        cycle: CycleSnapshot? = nil,
        vitals: VitalsSnapshot? = nil,
        freeAiSummaryAvailable: Bool = false,
        isPremium: Bool = false
    ) {
        self.isLoading = isLoading
        self.todayEpochDay = todayEpochDay
        self.greeting = greeting
        self.profileName = profileName
        self.doseProgress = doseProgress
        self.doses = doses
        self.appointments = appointments
        self.cycle = cycle
        self.vitals = vitals
        self.freeAiSummaryAvailable = freeAiSummaryAvailable
        self.isPremium = isPremium
    }
}

/// `doseProgress` is a tuple, and Swift cannot synthesize `Equatable` for a stored tuple property,
/// so the conformance is written out. The tuple is the twin of Kotlin's `Pair<Int, Int>?`; the
/// comparison is field-by-field, which is what the synthesized `==` would have done for any other
/// shape.
extension HomeUiState: Equatable {
    public static func == (lhs: HomeUiState, rhs: HomeUiState) -> Bool {
        lhs.isLoading == rhs.isLoading
            && lhs.todayEpochDay == rhs.todayEpochDay
            && lhs.greeting == rhs.greeting
            && lhs.profileName == rhs.profileName
            && lhs.doseProgress?.taken == rhs.doseProgress?.taken
            && lhs.doseProgress?.total == rhs.doseProgress?.total
            && lhs.doses == rhs.doses
            && lhs.appointments == rhs.appointments
            && lhs.cycle == rhs.cycle
            && lhs.vitals == rhs.vitals
            && lhs.freeAiSummaryAvailable == rhs.freeAiSummaryAvailable
            && lhs.isPremium == rhs.isPremium
    }
}
