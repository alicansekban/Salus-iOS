// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/timeline/
// SmokingTimelineUiState.kt`.
//
// `ImmutableList` is a plain array. Android's `@StringRes` effect payload becomes the setup
// wizard's error kind (``SmokingSetupError``): the same three refusals, the same three sentences,
// resolved by the Route.

import SalusSmoking

/// What the health timeline shows. `rows` is every catalog stage in catalog order; `totalCount` is
/// the catalog's size, never a literal, so the header cannot drift from the list.
///
/// `highlightStageId` is the stage a link asked for (a milestone notification, the main screen's
/// next-stage card). It lives here, and not in the screen, so it survives a rotation; the screen
/// reports it spent with ``SmokingTimelineEvent/highlightShown`` and it is cleared.
public struct SmokingTimelineUiState: Equatable, Sendable {
    public var mode: TimelineMode
    public var rows: [StageRow]
    public var doneCount: Int
    public var totalCount: Int
    public var nextStageId: String?
    public var highlightStageId: String?
    public var detailStageId: String?
    public var quitDateSheet: Bool
    public var initialQuitAtMs: Int64
    public var writing: Bool

    public init(
        mode: TimelineMode = .none,
        rows: [StageRow] = [],
        doneCount: Int = 0,
        totalCount: Int = MilestoneCatalog.healthStages.count,
        nextStageId: String? = nil,
        highlightStageId: String? = nil,
        detailStageId: String? = nil,
        quitDateSheet: Bool = false,
        initialQuitAtMs: Int64 = 0,
        writing: Bool = false
    ) {
        self.mode = mode
        self.rows = rows
        self.doneCount = doneCount
        self.totalCount = totalCount
        self.nextStageId = nextStageId
        self.highlightStageId = highlightStageId
        self.detailStageId = detailStageId
        self.quitDateSheet = quitDateSheet
        self.initialQuitAtMs = initialQuitAtMs
        self.writing = writing
    }

    /// The row the detail sheet describes, if it is open.
    public var detail: StageRow? {
        detailStageId.flatMap { id in rows.first { $0.stageId == id } }
    }
}

/// `none` until the first snapshot, and for a plan-less one, which this screen has nothing to say
/// about.
public enum TimelineMode: Equatable, Sendable {
    case none
    case quit
    case reduce
}

/// One stage as a row. `combustionNote` says the stage is defined for combusted tobacco while the
/// plan's product is another one; the stage stays in the list (contract §8.5).
public struct StageRow: Equatable, Sendable {
    public let stageId: String
    public let state: StageState
    public let permille: Int
    public let remainingMs: Int64
    public let countingAgain: Bool
    public let source: HealthStageSource
    public let combustionNote: Bool

    public init(
        stageId: String,
        state: StageState,
        permille: Int,
        remainingMs: Int64,
        countingAgain: Bool,
        source: HealthStageSource,
        combustionNote: Bool
    ) {
        self.stageId = stageId
        self.state = state
        self.permille = permille
        self.remainingMs = remainingMs
        self.countingAgain = countingAgain
        self.source = source
        self.combustionNote = combustionNote
    }
}

public enum SmokingTimelineEvent: Equatable, Sendable {
    case stageTapped(String)
    case detailDismissed
    /// The screen has scrolled to and pulsed the highlighted row.
    case highlightShown
    /// "Bırakma moduna geç": opens the quit-date sheet.
    case switchTapped
    case quitDateConfirmed(Int64)
    case quitDateDismissed
}

/// One-shot UI work. Navigation is not here: the system's back button is the screen's only exit.
public enum SmokingTimelineEffect: Equatable, Sendable {
    case showError(SmokingSetupError)
}

extension SmokingSnapshot {
    /// The part of the state a snapshot decides: the mode, the rows and the header's figures.
    func toTimeline(base: SmokingTimelineUiState) -> SmokingTimelineUiState {
        var state = base
        switch self {
        case let .quit(quit):
            state.mode = .quit
            state.rows = timelineRows(quit.stages, product: quit.plan.productType)
            state.doneCount = quit.stages.filter { $0.state == .done }.count
            state.nextStageId = quit.nextStage?.stageId

        // The preview is all PENDING at zero: the rows are the same, only nothing counts yet.
        case let .reduce(reduce):
            state.mode = .reduce
            state.rows = timelineRows(reduce.stagesPreview, product: reduce.plan.productType)
            state.doneCount = 0
            state.nextStageId = nil

        case .notSetUp:
            state.mode = .none
            state.rows = []
            state.doneCount = 0
            state.nextStageId = nil
        }
        return state
    }
}

/// The catalog joined to the snapshot's progress by id, in catalog order. A stage the snapshot does
/// not mention is pending rather than dropped, so the list is always the whole catalog.
private func timelineRows(_ progress: [StageProgress], product: ProductType) -> [StageRow] {
    let byId = Dictionary(progress.map { ($0.stageId, $0) }, uniquingKeysWith: { first, _ in first })
    let combustionProduct = product == .cigarette || product == .rolled
    return MilestoneCatalog.healthStages.map { stage in
        let progress = byId[stage.id]
        return StageRow(
            stageId: stage.id,
            state: progress?.state ?? .pending,
            permille: progress?.permille ?? 0,
            remainingMs: progress?.remainingMs ?? stage.thresholdMs,
            countingAgain: progress?.countingAgain ?? false,
            source: stage.source,
            combustionNote: stage.combustionOnly && !combustionProduct
        )
    }
}
