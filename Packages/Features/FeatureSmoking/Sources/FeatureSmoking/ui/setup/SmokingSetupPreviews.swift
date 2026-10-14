// The twin of the `@Preview` list at the foot of `SmokingSetupScreen.kt:170-241`: every page and the
// two variants of the amount and details pages, in light and dark across the palettes
// (`SalusPreviewPalettes`), plus one Dynamic Type `.accessibility3` render of the longest page.
// `PreviewClock` stands in for the app's clock — `FixedSalusClock` lives in the test-only
// `SalusTesting`, which the library target must never link.

import Foundation
import SalusCommon
import SalusDesignSystem
import SalusModel
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

private enum SetupPreviewDefaults {
    /// A panel is a whole screen, so the palette stack gives each one a screen's height.
    static let panelHeight: CGFloat = 760
    static let epochDay: Int64 = 20522
}

private func previewState(
    _ step: SetupStep,
    mode: SmokingMode = .quit,
    product: ProductType = .cigarette,
    priceText: String = "95"
) -> SmokingSetupUiState {
    SmokingSetupUiState(
        currencyCode: "TRY",
        quitAtMs: PreviewClock.nowMs,
        todayEpochDay: SetupPreviewDefaults.epochDay,
        zoneId: "Europe/Istanbul",
        step: step,
        mode: mode,
        product: product,
        priceText: priceText,
        reason: "Kızım için"
    )
}

private struct SetupPreview: View {
    let state: SmokingSetupUiState

    var body: some View {
        SmokingSetupScreen(state: state, onEvent: { _ in }, clock: PreviewClock())
            .frame(height: SetupPreviewDefaults.panelHeight)
    }
}

#Preview("Setup 1/4 — mode") {
    SalusPreviewPalettes { SetupPreview(state: previewState(.mode)) }
}

#Preview("Setup 2/4 — product") {
    SalusPreviewPalettes { SetupPreview(state: previewState(.product, product: .heated)) }
}

#Preview("Setup 3/4 — amount, pack") {
    SalusPreviewPalettes { SetupPreview(state: previewState(.amount)) }
}

#Preview("Setup 3/4 — amount, rolled") {
    SalusPreviewPalettes { SetupPreview(state: previewState(.amount, product: .rolled)) }
}

#Preview("Setup 3/4 — amount, vape") {
    SalusPreviewPalettes {
        SetupPreview(state: previewState(.amount, product: .vape, priceText: "400"))
    }
}

#Preview("Setup 3/4 — amount, empty price") {
    SalusPreviewPalettes { SetupPreview(state: previewState(.amount, priceText: "")) }
}

#Preview("Setup 4/4 — quit date and reason") {
    SalusPreviewPalettes { SetupPreview(state: previewState(.details)) }
}

#Preview("Setup 4/4 — reduce limit") {
    SalusPreviewPalettes { SetupPreview(state: previewState(.details, mode: .reduce)) }
}

#Preview("Setup 4/4 — saving") {
    SalusPreviewPalettes {
        SetupPreview(
            state: {
                var state = previewState(.details)
                state.isSaving = true
                return state
            }()
        )
    }
}

// The system font scale is the axis a form cannot control; the longest page has to survive it.
#Preview("Setup — amount, accessibility3") {
    SetupPreview(state: previewState(.amount))
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}
