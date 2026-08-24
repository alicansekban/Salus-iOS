// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/ui/detail/AppointmentDetailUiState.kt`.
//
// Kotlin's `Long` bounds become `Int64`: they are epoch-millisecond values, the same width the
// database columns and the backup contract carry, and `Int` would be a second width for one number.

/// What the detail screen draws (`AppointmentDetailUiState.kt:5-19`).
public struct AppointmentDetailUiState: Equatable, Sendable {
    public var isLoading: Bool
    /// Null once the appointment is gone — the screen says so instead of showing a blank
    /// (`AppointmentDetailUiState.kt:7`).
    public var appointment: Appointment?
    /// The profile's health notes, shown read-only as "what to tell the doctor"
    /// (`AppointmentDetailUiState.kt:9`).
    public var healthNotes: String?
    /// Absolute bounds derived from the wall-clock `Appointment.startsAt` with the zone that is
    /// current now, so the calendar event lands on the right instant after a DST change
    /// (`AppointmentDetailUiState.kt:11-15`).
    public var startEpochMs: Int64
    public var endEpochMs: Int64
    public var showDeleteConfirm: Bool

    public init(
        isLoading: Bool = true,
        appointment: Appointment? = nil,
        healthNotes: String? = nil,
        startEpochMs: Int64 = 0,
        endEpochMs: Int64 = 0,
        showDeleteConfirm: Bool = false
    ) {
        self.isLoading = isLoading
        self.appointment = appointment
        self.healthNotes = healthNotes
        self.startEpochMs = startEpochMs
        self.endEpochMs = endEpochMs
        self.showDeleteConfirm = showDeleteConfirm
    }
}

/// Everything the screen can ask the ViewModel to do
/// (`AppointmentDetailUiState.kt:21-29`).
public enum AppointmentDetailEvent: Equatable, Sendable {
    /// Opens the confirmation; nothing is deleted until it is confirmed.
    case deleteClicked
    case deleteDismissed
    case deleteConfirmed
}
