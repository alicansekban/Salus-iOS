// The twin of the `@Preview` list at the foot of `CravingScreen.kt`: the running flow, the same
// without a reason, reduced motion, the timer run out, the craving logged, a write in flight — each
// in light and dark across the palettes (`SalusPreviewPalettes`) — and one Dynamic Type
// `.accessibility3` render per state. The state is built by hand, so a picture does not depend on a
// clock.

import SalusDesignSystem
import SalusUI
import SwiftUI

private enum CravingPreviewDefaults {
    /// A panel is a whole screen, so the palette stack gives each one a screen's height.
    static let panelHeight: CGFloat = 820
    static let reason = "Kızımın mezuniyetinde temiz bir nefesle yanında olmak için"
}

private let previewLines: [CravingLine] = [
    .smokeFreeDays(42),
    .saved(minor: 315_000, currencyCode: "TRY"),
    .nextStage(stageId: "h_1mo"),
    .focus
]

private func previewState(
    elapsedMs: Int64,
    reason: String? = CravingPreviewDefaults.reason,
    logged: Bool = false,
    loggedCount: Int? = nil,
    writing: Bool = false
) -> CravingUiState {
    var state = CravingUiState()
    state.elapsedMs = elapsedMs
    state.mode = .quit
    state.lines = previewLines
    state.reason = reason
    state.logged = logged
    state.loggedCount = loggedCount
    state.writing = writing
    return state
}

private struct CravingPreview: View {
    let state: CravingUiState
    var reduceMotion = false

    var body: some View {
        NavigationStack {
            CravingScreen(state: state, reduceMotion: reduceMotion, onEvent: { _ in })
        }
        .frame(height: CravingPreviewDefaults.panelHeight)
    }
}

// Mid-way through the held breath.
#Preview("Craving — running") {
    SalusPreviewPalettes { CravingPreview(state: previewState(elapsedMs: 109_000)) }
}

// The out-breath, no reason set, the line on savings.
#Preview("Craving — running, no reason") {
    SalusPreviewPalettes { CravingPreview(state: previewState(elapsedMs: 26000, reason: nil)) }
}

// Reduced motion: the ring and the line stand still, the chip and the label carry the rhythm.
#Preview("Craving — reduce motion") {
    SalusPreviewPalettes { CravingPreview(state: previewState(elapsedMs: 61000), reduceMotion: true) }
}

// The five minutes ran out: completed to look at, nothing written yet, "Geçti" still waiting.
#Preview("Craving — timer done") {
    SalusPreviewPalettes { CravingPreview(state: previewState(elapsedMs: cravingDurationMs + 12000)) }
}

// "Geçti" was tapped and written: the count and "Devam".
#Preview("Craving — completed") {
    SalusPreviewPalettes {
        CravingPreview(state: previewState(elapsedMs: 191_000, logged: true, loggedCount: 18))
    }
}

// Completed, reduced motion: the same screen, nothing moving.
#Preview("Craving — completed, reduce motion") {
    SalusPreviewPalettes {
        CravingPreview(state: previewState(elapsedMs: 191_000, logged: true, loggedCount: 18), reduceMotion: true)
    }
}

// A write in flight: both buttons are off.
#Preview("Craving — writing") {
    SalusPreviewPalettes { CravingPreview(state: previewState(elapsedMs: 30000, writing: true)) }
}

// The system font scale is the axis a card layout cannot control; the busiest state has to survive it.
#Preview("Craving — running, accessibility3") {
    CravingPreview(state: previewState(elapsedMs: 75000))
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}

#Preview("Craving — completed, accessibility3") {
    CravingPreview(state: previewState(elapsedMs: 191_000, logged: true, loggedCount: 18))
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}
