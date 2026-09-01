// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/ui/TrendsUiState.kt`.

import SalusModel

/// The trends screen (`TrendsUiState.kt:29-35`).
///
/// `range` is held next to `data` rather than inside it, so the filter chips keep their selection
/// while the next window is being read.
///
/// The initial `data` is `TrendsData.locked` and not a fourth "unknown" member: until the store
/// has answered, nobody is entitled, so the state the screen starts from is the one a free user
/// ends on. `hasLoaded` covers the difference — the locked body is only drawn once the first
/// load has answered, so an entitled user never sees a frame of it.
///
/// `isLoading` and `hasLoaded` are two different questions and the screen answers them
/// differently. Before the first load answers there is nothing on screen worth keeping, so the
/// whole body is a spinner. Afterwards `data` always holds the last answer, and a reload dims it
/// rather than replacing it — switching a range must not make the cards flash away and back.
///
/// `glucoseUnit` is a display setting, not an input to any analysis: glucose is stored, read and
/// analysed in canonical mg/dL, and this is the unit those numbers are *written* in. It lives on
/// the state rather than being read inside a composable so that a change to it redraws the
/// screen the same way any other state change does. The default matches the store's own default,
/// so the first frame is never in the wrong unit.
public struct TrendsUiState: Equatable, Sendable {
    public var isLoading: Bool
    public var hasLoaded: Bool
    public var range: TrendsRange
    public var data: TrendsData
    public var glucoseUnit: GlucoseUnit

    public init(
        isLoading: Bool = true,
        hasLoaded: Bool = false,
        range: TrendsRange = .quarter,
        data: TrendsData = .locked,
        glucoseUnit: GlucoseUnit = .default
    ) {
        self.isLoading = isLoading
        self.hasLoaded = hasLoaded
        self.range = range
        self.data = data
        self.glucoseUnit = glucoseUnit
    }
}

/// User intents on the trends screen (`TrendsUiState.kt:37-46`).
public enum TrendsEvent: Equatable, Sendable {
    case rangeSelected(TrendsRange)

    /// The button on the locked body — the only thing on this screen that opens the paywall.
    case upgradeClicked

    /// The button on the error body. Re-reads the window that is already selected.
    case retryClicked
}
