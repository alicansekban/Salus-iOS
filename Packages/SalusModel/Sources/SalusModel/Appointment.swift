// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Appointment.kt`.

/// Where an appointment stands.
///
/// Raw values are the Kotlin constant names (`Appointment.kt:3-7`), which is what is persisted.
public enum AppointmentStatus: String, CaseIterable, Equatable, Hashable, Sendable {
    case scheduled = "SCHEDULED"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
}
