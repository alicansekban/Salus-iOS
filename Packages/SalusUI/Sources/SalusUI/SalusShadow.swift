// `design-tokens.md` §7's translation of an elevation step into an iOS shadow, in one place.
//
// The token is the dp step and lives in `SalusDesignSystem` (`SalusElevation`); the shadow is a
// *translation* of it, which the document spells out per step and which `SalusDesignSystem`
// deliberately does not hold (it is tokens only, no views). Three components need it — the card,
// the FAB and the snackbar — so it is written once here rather than three times with three
// chances to mistype an offset.
//
// Dark mode drops the shadow entirely (opacity 0): a black shadow on a `#0A0F0C` ground is
// invisible on Android too, where the tonal tint carries the elevation instead (§7).

import SalusDesignSystem
import SwiftUI

/// The three elevation steps that are actually drawn. `SalusElevation.none` needs no shadow and so
/// needs no case.
enum SalusShadow {
    /// Every card: `radius: 2, y: 1`.
    case card
    /// Raised controls, e.g. the FAB: `radius: 4, y: 2`.
    case raised
    /// Overlays, e.g. the snackbar: `radius: 8, y: 4`.
    case overlay

    /// The radius is the dp step itself.
    var radius: CGFloat {
        switch self {
        case .card: SalusElevation.card
        case .raised: SalusElevation.raised
        case .overlay: SalusElevation.overlay
        }
    }

    var offsetY: CGFloat {
        switch self {
        case .card: 1
        case .raised: 2
        case .overlay: 4
        }
    }

    /// One opacity for every step, as §7 writes it.
    static let opacity = 0.08
}

extension View {
    /// Applies §7's shadow for `shadow`, or none at all in the dark theme.
    func salusShadow(_ shadow: SalusShadow, isDark: Bool) -> some View {
        self.shadow(
            color: .black.opacity(isDark ? 0 : SalusShadow.opacity),
            radius: shadow.radius,
            x: 0,
            y: shadow.offsetY
        )
    }
}
