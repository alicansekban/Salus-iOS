// iOS-M17 Task 8, design review R2 (`../salus-android/docs/design/m17-stitch-review.md`).
//
// Over a limit the ring and the bar do not change colour: the amber accent collides with the
// `warning` token, so a colour change would be invisible, and the owner ruled out red and pink
// outright. They stay full in their own colour and the excess is drawn as a second, neutral lap
// (`outlineVariant`) from the start of the track. Meaning is carried by text — the feature adds the
// "+n" chip and the supportive copy — never by the hue.

import SwiftUI

/// The one number the ring and the bar share: how much of the track the overflow lap covers.
enum SalusProgressOverflow {
    /// `overflowPermille` (the contract's `permille: Int`) as a 0...1 share of the circumference or
    /// the track. A negative value is no overflow; more than one full lap is capped at one, so a
    /// 20-over-10 day cannot draw past the shape.
    nonisolated static func fraction(forPermille permille: Int) -> Double {
        let lap = SalusProgressOverflowDefaults.fullLapPermille
        return Double(min(max(permille, 0), lap)) / Double(lap)
    }
}

enum SalusProgressOverflowDefaults {
    /// One full lap, in the contract's permille unit (§2).
    static let fullLapPermille = 1000
}
