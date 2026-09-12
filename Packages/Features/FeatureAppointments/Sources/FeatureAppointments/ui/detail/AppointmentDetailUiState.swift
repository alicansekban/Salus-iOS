// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/ui/detail/AppointmentDetailUiState.kt`.
//
// Kotlin's `Long` bounds become `Int64`: they are epoch-millisecond values, the same width the
// database columns and the backup contract carry, and `Int` would be a second width for one number.

/// How far off the appointment is, in whole calendar days, as the hero's chip says it out loud
/// (`AppointmentDetailUiState.kt:5-19`).
///
/// A day granularity on purpose: the chip names the day the appointment is on, so an appointment
/// earlier today still reads "Today" rather than flipping to "Past" at lunchtime.
public enum RelativeDay: Equatable, Hashable, Sendable {
    case today
    case tomorrow
    /// Strictly more than one day ahead; `days` is always >= 2.
    case inDays(Int)
    case past
}

/// What the detail screen draws (`AppointmentDetailUiState.kt:21-40`).
public struct AppointmentDetailUiState: Equatable, Sendable {
    public var isLoading: Bool
    /// Null once the appointment is gone — the screen says so instead of showing a blank
    /// (`AppointmentDetailUiState.kt:23`).
    public var appointment: Appointment?
    /// The profile's health notes, shown read-only as "what to tell the doctor"
    /// (`AppointmentDetailUiState.kt:25`).
    public var healthNotes: String?
    /// Display only, and nil while there is nothing to describe. Derived from the clock on every
    /// emission rather than once at construction, so a screen left open overnight stops claiming
    /// the appointment is today (`AppointmentDetailUiState.kt:27-32`).
    public var relativeDay: RelativeDay?
    /// Absolute bounds derived from the wall-clock `Appointment.startsAt` with the zone that is
    /// current now, so the calendar event lands on the right instant after a DST change
    /// (`AppointmentDetailUiState.kt:33-38`).
    public var startEpochMs: Int64
    public var endEpochMs: Int64
    public var showDeleteConfirm: Bool

    public init(
        isLoading: Bool = true,
        appointment: Appointment? = nil,
        healthNotes: String? = nil,
        relativeDay: RelativeDay? = nil,
        startEpochMs: Int64 = 0,
        endEpochMs: Int64 = 0,
        showDeleteConfirm: Bool = false
    ) {
        self.isLoading = isLoading
        self.appointment = appointment
        self.healthNotes = healthNotes
        self.relativeDay = relativeDay
        self.startEpochMs = startEpochMs
        self.endEpochMs = endEpochMs
        self.showDeleteConfirm = showDeleteConfirm
    }
}

/// Everything the screen can ask the ViewModel to do
/// (`AppointmentDetailUiState.kt:42-49`).
public enum AppointmentDetailEvent: Equatable, Sendable {
    /// Opens the confirmation; nothing is deleted until it is confirmed.
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
