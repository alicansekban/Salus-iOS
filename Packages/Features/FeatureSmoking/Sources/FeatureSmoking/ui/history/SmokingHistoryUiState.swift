// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/history/
// SmokingHistoryUiState.kt`.
//
// Shape differences from the Kotlin state: `ImmutableList` is a plain array, and the effect's
// `@StringRes` is a kind the Route turns into the sentence (`SmokingSetupError`'s shape). Days
// and instants stay 64-bit (`epochDay`, `*Ms`); counts and unit counts are `Int`.

import SalusSmoking

/// What the history screen shows: the journey so far, one card per attempt and the day-by-day log.
///
/// `loaded` is false until the first rows arrive, so "no entries yet" is never claimed over a
/// screen that has simply not read them. The open editor and its delete confirmation live here, and
/// not in the screen, so a rotation keeps them; the editor is looked up by id, so an entry that
/// disappears underneath it (an undo elsewhere) closes it.
public struct SmokingHistoryUiState: Equatable, Sendable {
    public var loaded: Bool
    public var journeyDays: Int64
    public var currencyCode: String
    public var attempts: [AttemptCardUi]
    public var days: [DayGroupUi]
    public var todayEpochDay: Int64
    /// The clock's zone: what an entry or attempt whose own zone id is unknown is shown in.
    public var zoneId: String
    public var editingId: String?
    public var deleteConfirm: Bool
    public var writing: Bool

    public init(
        loaded: Bool = false,
        journeyDays: Int64 = 0,
        currencyCode: String = "",
        attempts: [AttemptCardUi] = [],
        days: [DayGroupUi] = [],
        todayEpochDay: Int64 = 0,
        zoneId: String = "UTC",
        editingId: String? = nil,
        deleteConfirm: Bool = false,
        writing: Bool = false
    ) {
        self.loaded = loaded
        self.journeyDays = journeyDays
        self.currencyCode = currencyCode
        self.attempts = attempts
        self.days = days
        self.todayEpochDay = todayEpochDay
        self.zoneId = zoneId
        self.editingId = editingId
        self.deleteConfirm = deleteConfirm
        self.writing = writing
    }

    /// Nothing to show at all: no entries and no attempt either. A running attempt keeps its screen.
    public var isEmpty: Bool {
        loaded && days.isEmpty && attempts.isEmpty
    }

    /// The "how entries appear" explainer stands in for a log that has no entries yet.
    public var showHowTo: Bool {
        loaded && days.isEmpty
    }

    /// The row the editor sheet works on, while it is open and the entry still exists.
    public var editing: EventRowUi? {
        guard let editingId else { return nil }
        return days.lazy.flatMap(\.rows).first { $0.id == editingId }
    }
}

/// One attempt. `savedMinor` and `cravingsBeaten` are the snapshot's figures for it and are `nil`
/// for an attempt the snapshot does not describe (a closed one seen from a REDUCE plan), which
/// then shows only what the stored rows say: the span, the slips and whether it was the longest.
public struct AttemptCardUi: Equatable, Sendable {
    public let id: String
    public let ordinal: Int
    public let startedAtMs: Int64
    public let endedAtMs: Int64?
    public let durationMs: Int64
    public let slipCount: Int
    public let isLongest: Bool
    public let savedMinor: Int64?
    public let cravingsBeaten: Int?
    public let tzId: String

    public init(
        id: String,
        ordinal: Int,
        startedAtMs: Int64,
        endedAtMs: Int64?,
        durationMs: Int64,
        slipCount: Int,
        isLongest: Bool,
        savedMinor: Int64?,
        cravingsBeaten: Int?,
        tzId: String
    ) {
        self.id = id
        self.ordinal = ordinal
        self.startedAtMs = startedAtMs
        self.endedAtMs = endedAtMs
        self.durationMs = durationMs
        self.slipCount = slipCount
        self.isLongest = isLongest
        self.savedMinor = savedMinor
        self.cravingsBeaten = cravingsBeaten
        self.tzId = tzId
    }

    public var isActive: Bool {
        endedAtMs == nil
    }
}

/// The entries of one stored calendar day, newest first.
public struct DayGroupUi: Equatable, Sendable {
    public let epochDay: Int64
    public let rows: [EventRowUi]

    public init(epochDay: Int64, rows: [EventRowUi]) {
        self.epochDay = epochDay
        self.rows = rows
    }
}

/// One log row. `units` is `nil` for a craving and 0 for the REDUCE "none today" marker
/// (``isMarker``). The time is shown in the entry's own zone (`tzId`), the one its day was
/// bucketed in.
public struct EventRowUi: Equatable, Sendable {
    public let id: String
    public let type: SmokingEventType
    public let atMs: Int64
    public let tzId: String
    public let units: Int?
    public let trigger: CravingTrigger?
    public let intensity: Int?

    public init(
        id: String,
        type: SmokingEventType,
        atMs: Int64,
        tzId: String,
        units: Int?,
        trigger: CravingTrigger?,
        intensity: Int?
    ) {
        self.id = id
        self.type = type
        self.atMs = atMs
        self.tzId = tzId
        self.units = units
        self.trigger = trigger
        self.intensity = intensity
    }

    public var isMarker: Bool {
        type == .smoked && units == 0
    }
}

public enum SmokingHistoryEvent: Equatable, Sendable {
    case rowTapped(String)
    case editDismissed
    /// "Kaydet" in the editor.
    case editSaved(EventEdit)
    case deleteTapped
    case deleteConfirmed
    case deleteDismissed
}

/// What the editor hands out: the entry and every field it may have changed. `units` is read for
/// a smoked entry only.
public struct EventEdit: Equatable, Sendable {
    public let eventId: String
    public let atMs: Int64
    public let units: Int?
    public let trigger: CravingTrigger?
    public let intensity: Int?

    public init(eventId: String, atMs: Int64, units: Int?, trigger: CravingTrigger?, intensity: Int?) {
        self.eventId = eventId
        self.atMs = atMs
        self.units = units
        self.trigger = trigger
        self.intensity = intensity
    }
}

/// Why a history write was refused, as a kind the Route turns into the right sentence.
public enum SmokingHistoryError: Equatable, Sendable {
    case future
    case invalid
    case generic
}

/// One-shot UI work. Navigation is not here: the system's back button is the exit.
public enum SmokingHistoryEffect: Equatable, Sendable {
    case showError(SmokingHistoryError)
}
