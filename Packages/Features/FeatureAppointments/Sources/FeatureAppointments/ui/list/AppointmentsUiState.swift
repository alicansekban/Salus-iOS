// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/ui/list/AppointmentsUiState.kt`.
//
// `ImmutableList` is dropped rather than imitated — a Swift `Array` in a `struct` already is what
// `kotlinx.collections.immutable` promises Compose (`ChartUiModel.swift` and `VitalsUiState.swift`
// record the same ruling).

import SalusModel

/// One row of the agenda (`AppointmentsUiState.kt:7-13`).
///
/// `Identifiable` is what `items(items = section.items, key = { it.id })`
/// (`AppointmentsScreen.kt:170`) asks for on Android; `ForEach` asks for it here.
public struct AppointmentListItem: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let doctorName: String?
    public let location: String?
    public let startsAt: LocalDateTime

    public init(
        id: String,
        title: String,
        doctorName: String?,
        location: String?,
        startsAt: LocalDateTime
    ) {
        self.id = id
        self.title = title
        self.doctorName = doctorName
        self.location = location
        self.startsAt = startsAt
    }
}

/// Upcoming appointments grouped by calendar day (`AppointmentsUiState.kt:15-23`).
///
/// A month grid would be mostly empty cells for the handful of appointments a personal health app
/// holds; an agenda is the shape that matches the data.
///
/// `Identifiable` on the day is Kotlin's `stickyHeader(key = "header-${section.epochDay}")`
/// (`AppointmentsScreen.kt:163`): the day is what makes a section unique on both platforms.
public struct AppointmentDaySection: Equatable, Hashable, Sendable, Identifiable {
    public let epochDay: Int
    public let items: [AppointmentListItem]

    public var id: Int { epochDay }

    public init(epochDay: Int, items: [AppointmentListItem]) {
        self.epochDay = epochDay
        self.items = items
    }
}

/// What the appointments list draws (`AppointmentsUiState.kt:25-36`).
public struct AppointmentsUiState: Equatable, Sendable {
    public var isLoading: Bool
    public var upcoming: [AppointmentDaySection]
    public var past: [AppointmentListItem]
    public var isPastExpanded: Bool
    /// Lets the header read "Today"/"Tomorrow" without the UI asking for the time itself
    /// (`AppointmentsUiState.kt:31`).
    public var todayEpochDay: Int
    /// The appointment whose delete confirmation is open; nil when none is
    /// (`AppointmentsUiState.kt:33`).
    ///
    /// The row itself rather than its id, so the dialog can put the title in its question without
    /// looking the appointment up again — exactly what Kotlin's `pendingDelete` carries.
    public var pendingDelete: AppointmentListItem?

    /// `AppointmentsUiState.kt:35`.
    public var hasNothing: Bool { upcoming.isEmpty && past.isEmpty }

    public init(
        isLoading: Bool = true,
        upcoming: [AppointmentDaySection] = [],
        past: [AppointmentListItem] = [],
        isPastExpanded: Bool = false,
        todayEpochDay: Int = 0,
        pendingDelete: AppointmentListItem? = nil
    ) {
        self.isLoading = isLoading
        self.upcoming = upcoming
        self.past = past
        self.isPastExpanded = isPastExpanded
        self.todayEpochDay = todayEpochDay
        self.pendingDelete = pendingDelete
    }
}

/// Everything the screen can ask the ViewModel to do (`AppointmentsUiState.kt:38-47`).
public enum AppointmentsEvent: Equatable, Sendable {
    case togglePastSection

    /// Opens the confirmation for the row's trash icon; nothing is deleted until confirmed
    /// (`AppointmentsUiState.kt:41-42`).
    case deleteRequested(String)

    /// `AppointmentsUiState.kt:44`.
    case deleteDismissed

    /// `AppointmentsUiState.kt:46`.
    case deleteConfirmed
}
