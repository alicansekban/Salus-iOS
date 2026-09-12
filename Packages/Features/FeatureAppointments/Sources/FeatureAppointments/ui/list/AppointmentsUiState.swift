// Ported 1:1 from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/
// appointments/ui/list/AppointmentsUiState.kt`.
//
// `ImmutableList` is dropped rather than imitated — a Swift `Array` in a `struct` already is what
// `kotlinx.collections.immutable` promises Compose (`ChartUiModel.swift` and `VitalsUiState.swift`
// record the same ruling).
//
// M15 replaced the collapsed past section with a two-tab split, so `isPastExpanded` and the
// `togglePastSection` event leave: `selectedTab` is what the segmented tabs draw and the `TabBar`
// reads back (`AppointmentsUiState.kt:28, 34`).

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
    /// Minutes before the start; drawn as the card's reminder chips (`AppointmentsUiState.kt:14`).
    public let reminderOffsetsMinutes: [Int]

    public init(
        id: String,
        title: String,
        doctorName: String?,
        location: String?,
        startsAt: LocalDateTime,
        reminderOffsetsMinutes: [Int] = []
    ) {
        self.id = id
        self.title = title
        self.doctorName = doctorName
        self.location = location
        self.startsAt = startsAt
        self.reminderOffsetsMinutes = reminderOffsetsMinutes
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

/// The two halves of the list, shown one at a time behind the segmented tabs
/// (`AppointmentsUiState.kt:28`).
public enum AppointmentsTab: String, Equatable, Hashable, Sendable, CaseIterable {
    case upcoming
    case past
}

/// What the appointments list draws (`AppointmentsUiState.kt:30-39`).
public struct AppointmentsUiState: Equatable, Sendable {
    public var isLoading: Bool
    public var upcoming: [AppointmentDaySection]
    public var past: [AppointmentListItem]
    public var selectedTab: AppointmentsTab
    /// Lets the header read "Today"/"Tomorrow" without the UI asking for the time itself
    /// (`AppointmentsUiState.kt:36`).
    public var todayEpochDay: Int
    /// The appointment whose delete confirmation is open; nil when none is
    /// (`AppointmentsUiState.kt:38`).
    ///
    /// The row itself rather than its id, so the dialog can put the title in its question without
    /// looking the appointment up again — exactly what Kotlin's `pendingDelete` carries.
    public var pendingDelete: AppointmentListItem?

    /// `AppointmentsUiState.kt:40`.
    public var hasNothing: Bool { upcoming.isEmpty && past.isEmpty }

    /// The tab badges count appointments, not day headers (`AppointmentsUiState.kt:44-46`).
    public var upcomingCount: Int { upcoming.reduce(0) { $0 + $1.items.count } }

    /// `AppointmentsUiState.kt:48`.
    public var pastCount: Int { past.count }

    public init(
        isLoading: Bool = true,
        upcoming: [AppointmentDaySection] = [],
        past: [AppointmentListItem] = [],
        selectedTab: AppointmentsTab = .upcoming,
        todayEpochDay: Int = 0,
        pendingDelete: AppointmentListItem? = nil
    ) {
        self.isLoading = isLoading
        self.upcoming = upcoming
        self.past = past
        self.selectedTab = selectedTab
        self.todayEpochDay = todayEpochDay
        self.pendingDelete = pendingDelete
    }
}

/// Everything the screen can ask the ViewModel to do (`AppointmentsUiState.kt:51-59`).
public enum AppointmentsEvent: Equatable, Sendable {
    /// The user tapped a segmented tab (`AppointmentsUiState.kt:52`).
    case tabSelected(AppointmentsTab)

    /// Opens the confirmation for the row's trash icon; nothing is deleted until confirmed
    /// (`AppointmentsUiState.kt:54-55`).
    case deleteRequested(String)

    /// `AppointmentsUiState.kt:57`.
    case deleteDismissed

    /// `AppointmentsUiState.kt:59`.
    case deleteConfirmed
}
