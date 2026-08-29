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
// `cycle` and `vitals` are optional **here** while `TodayOverview`'s are not, and that is Android's
// own asymmetry (`HomeUiState.kt:19-20` vs `TodayModels.kt:54-55`): the default state — the one the
// screen draws before the first emission — has no snapshot to carry, so the field has to admit nil.
// After loading they are always present.

/// Which half of the day the header greets in (`HomeUiState.kt:5`).
public enum HomeGreeting: Sendable {
    case morning
    case afternoon
    case evening
    case night
}

/// Everything the dashboard can ask for (`HomeUiState.kt:7-9`).
public enum HomeEvent: Equatable, Sendable {
    /// The "Al" button on a pending dose row (`HomeUiState.kt:8`).
    case takeDose(scheduleId: String, minuteOfDay: Int)
}

/// What the dashboard draws (`HomeUiState.kt:11-21`).
public struct HomeUiState: Equatable, Sendable {
    public var isLoading: Bool
    /// The day the header's date is formatted from, captured when the state was built.
    public var todayEpochDay: Int
    public var greeting: HomeGreeting
    public var doses: [TodayDose]
    public var appointments: [UpcomingAppointment]
    /// Non-nil once the first overview has arrived; see the file header.
    public var cycle: CycleSnapshot?
    /// Non-nil once the first overview has arrived; see the file header.
    public var vitals: VitalsSnapshot?
    /// Whether the one-off free AI summary is still unspent (`HomeUiState.kt:19`).
    public var freeAiSummaryAvailable: Bool
    /// Whether the user is entitled to premium (`HomeUiState.kt:20`). Pinned `false` until iOS-M9
    /// binds a real ``HomePremiumStatus`` — recorded divergence (d).
    public var isPremium: Bool

    public init(
        isLoading: Bool = true,
        todayEpochDay: Int = 0,
        greeting: HomeGreeting = .morning,
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
        self.doses = doses
        self.appointments = appointments
        self.cycle = cycle
        self.vitals = vitals
        self.freeAiSummaryAvailable = freeAiSummaryAvailable
        self.isPremium = isPremium
    }
}
