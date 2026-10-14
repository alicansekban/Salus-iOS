// The twin of the `@Preview` list at the foot of `SmokingTimelineScreen.kt` and
// `StageDetailSheet.kt`: the QUIT list in progress, in its first hour, after a slip ("counting
// again"), with the combustion note, with everything done, the REDUCE preview, a highlighted stage
// and the stage sheet in each state — light and dark across the palettes (`SalusPreviewPalettes`),
// plus one Dynamic Type `.accessibility3` render of each screen. The highlight pulse is a motion,
// not a picture: its preview only shows the row it will land on.

import Foundation
import SalusCommon
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

private struct PreviewClock: SalusClock {
    /// 2026-03-10T12:00 Europe/Istanbul.
    static let nowMs: Int64 = 1_773_133_200_000

    func now() -> Date {
        Date(epochMilliseconds: Self.nowMs)
    }

    func timeZone() -> TimeZone {
        TimeZone(identifier: "Europe/Istanbul") ?? .gmt
    }
}

private enum TimelinePreviewDefaults {
    static let minuteMs: Int64 = 60 * 1000
    static let dayMs: Int64 = 24 * 60 * minuteMs
    static let inProgressPermille = 640
    /// A panel is a whole screen, so the palette stack gives each one a screen's height.
    static let panelHeight: CGFloat = 820
}

/// Rows of the catalog in a given state of progress: stages before `done` are done, that one is
/// being counted, the rest are pending.
private func previewRows(
    done: Int,
    inProgressPermille: Int = TimelinePreviewDefaults.inProgressPermille,
    rewound: Set<String> = [],
    noteProduct: Bool = false
) -> [StageRow] {
    MilestoneCatalog.healthStages.enumerated().map { index, stage in
        let state: StageState = index < done ? .done : (index == done ? .inProgress : .pending)
        let permille = switch state {
        case .done: 1000
        case .inProgress: inProgressPermille
        case .pending: 0
        }
        return StageRow(
            stageId: stage.id,
            state: state,
            permille: permille,
            remainingMs: state == .done
                ? 0
                : max(TimelinePreviewDefaults.minuteMs, stage.thresholdMs * Int64(1000 - inProgressPermille) / 1000),
            countingAgain: state != .done && rewound.contains(stage.id),
            source: stage.source,
            combustionNote: stage.combustionOnly && noteProduct
        )
    }
}

private func previewState(
    _ mode: TimelineMode,
    rows: [StageRow],
    highlight: String? = nil,
    detail: String? = nil
) -> SmokingTimelineUiState {
    SmokingTimelineUiState(
        mode: mode,
        rows: rows,
        doneCount: rows.filter { $0.state == .done }.count,
        nextStageId: rows.first { $0.state == .inProgress }?.stageId,
        highlightStageId: highlight,
        detailStageId: detail
    )
}

private struct TimelinePreview: View {
    let state: SmokingTimelineUiState

    var body: some View {
        NavigationStack {
            SmokingTimelineScreen(state: state, onEvent: { _ in }, clock: PreviewClock())
        }
        .frame(height: TimelinePreviewDefaults.panelHeight)
    }
}

#Preview("Timeline — in progress") {
    SalusPreviewPalettes { TimelinePreview(state: previewState(.quit, rows: previewRows(done: 5))) }
}

// The first hour: nothing is done yet, the first stage is the one being counted.
#Preview("Timeline — first hour") {
    SalusPreviewPalettes {
        TimelinePreview(state: previewState(.quit, rows: previewRows(done: 0, inProgressPermille: 250)))
    }
}

// After a slip: the long stages the attempt had unlocked are counted again.
#Preview("Timeline — counting again") {
    SalusPreviewPalettes {
        TimelinePreview(
            state: previewState(.quit, rows: previewRows(done: 2, rewound: ["h_2w", "h_1mo", "h_1y"]))
        )
    }
}

// Heated tobacco or a vape: the combustion-only stages carry their note.
#Preview("Timeline — combustion note") {
    SalusPreviewPalettes {
        TimelinePreview(state: previewState(.quit, rows: previewRows(done: 1, noteProduct: true)))
    }
}

// Everything unlocked: the header has no next threshold.
#Preview("Timeline — all done") {
    SalusPreviewPalettes {
        TimelinePreview(state: previewState(.quit, rows: previewRows(done: MilestoneCatalog.healthStages.count)))
    }
}

// A link named a stage: the list opens on it (the pulse itself is a motion, not a picture).
#Preview("Timeline — highlighted stage") {
    SalusPreviewPalettes {
        TimelinePreview(state: previewState(.quit, rows: previewRows(done: 5), highlight: "h_1y"))
    }
}

// REDUCE: every row greyed, "what's waiting" header and the switch button pinned below.
#Preview("Timeline — REDUCE preview") {
    SalusPreviewPalettes {
        TimelinePreview(state: previewState(.reduce, rows: previewRows(done: -1)))
    }
}

// The busiest list at the largest text size; REDUCE below it, the other long-header case.
#Preview("Timeline — accessibility3") {
    TimelinePreview(
        state: previewState(
            .quit,
            rows: previewRows(done: 3, rewound: ["h_1mo"], noteProduct: true),
            highlight: "h_1mo"
        )
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}

#Preview("Timeline — REDUCE, accessibility3") {
    TimelinePreview(state: previewState(.reduce, rows: previewRows(done: -1)))
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}

// MARK: - Stage sheet

private func sheetRow(
    _ id: String,
    _ state: StageState,
    permille: Int,
    remainingDays: Int64 = 0,
    countingAgain: Bool = false,
    combustionNote: Bool = false
) -> StageRow {
    StageRow(
        stageId: id,
        state: state,
        permille: permille,
        remainingMs: remainingDays * TimelinePreviewDefaults.dayMs,
        countingAgain: countingAgain,
        source: MilestoneCatalog.healthStages.first { $0.id == id }?.source ?? .who,
        combustionNote: combustionNote
    )
}

#Preview("Stage sheet — in progress") {
    SalusPreviewPalettes { StageDetailContent(row: sheetRow("h_1mo", .inProgress, permille: 640, remainingDays: 11)) }
}

#Preview("Stage sheet — done") {
    SalusPreviewPalettes { StageDetailContent(row: sheetRow("h_72h", .done, permille: 1000)) }
}

// A stage a slip rewound, for a product it is not defined for: both notes at once.
#Preview("Stage sheet — both notes") {
    SalusPreviewPalettes {
        StageDetailContent(
            row: sheetRow("h_48h", .pending, permille: 0, remainingDays: 2, countingAgain: true, combustionNote: true)
        )
    }
}

#Preview("Stage sheet — accessibility3") {
    StageDetailContent(row: sheetRow("h_5y", .pending, permille: 0, remainingDays: 900, countingAgain: true))
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}
