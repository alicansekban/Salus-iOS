// The twin of the `@Preview` list at the foot of `SmokingSettingsScreen.kt`: the QUIT list, the
// REDUCE list with its evening reminder, a vape's per-day price and the reset confirmation — light
// and dark across the palettes (`SalusPreviewPalettes`), plus one Dynamic Type `.accessibility3`
// render. The sheets' own previews are beside each sheet.

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
        TimeZone(identifier: PreviewDefaults.zoneId) ?? .gmt
    }
}

private enum PreviewDefaults {
    static let zoneId = "Europe/Istanbul"
    /// 2026-02-02 around noon.
    static let quitAtMs: Int64 = 1_770_000_000_000
    /// A panel is a whole screen, so the palette stack gives each one a screen's height.
    static let panelHeight: CGFloat = 900
}

private func previewState(
    _ mode: SettingsMode,
    product: ProductType = .cigarette,
    reason: String? = "Kızım için",
    notifications: Bool = true,
    evening: Bool = false,
    confirm: SettingsConfirm? = nil
) -> SmokingSettingsUiState {
    SmokingSettingsUiState(
        loaded: true,
        mode: mode,
        productType: product,
        baselineUnitsPerDay: 20,
        zoneId: PreviewDefaults.zoneId,
        currencyCode: "TRY",
        unitCostMinor: 475,
        dailyLimit: mode == .reduce ? 10 : nil,
        quitAtMs: mode == .quit ? PreviewDefaults.quitAtMs : nil,
        reason: reason,
        notificationsEnabled: notifications,
        eveningReminderEnabled: evening,
        confirm: confirm
    )
}

private struct SettingsPreview: View {
    let state: SmokingSettingsUiState

    var body: some View {
        NavigationStack {
            SmokingSettingsScreen(state: state, onEvent: { _ in }, clock: PreviewClock())
        }
        .frame(height: PreviewDefaults.panelHeight)
    }
}

#Preview("Settings — QUIT") {
    SalusPreviewPalettes { SettingsPreview(state: previewState(.quit)) }
}

#Preview("Settings — REDUCE") {
    SalusPreviewPalettes {
        SettingsPreview(state: previewState(.reduce, reason: nil, evening: true))
    }
}

// A vape counts days of use: the price row says "/ gün".
#Preview("Settings — vape") {
    SalusPreviewPalettes {
        SettingsPreview(state: previewState(.quit, product: .vape, notifications: false))
    }
}

// The reset confirmation, the one destructive dialog of the feature.
#Preview("Settings — reset confirmation") {
    SettingsPreview(state: previewState(.quit, confirm: .reset))
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("Settings — accessibility3") {
    SettingsPreview(state: previewState(.reduce, evening: true))
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
        .dynamicTypeSize(.accessibility3)
}
