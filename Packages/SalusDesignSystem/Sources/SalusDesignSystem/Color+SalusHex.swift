import SwiftUI

// Mirrors `salus-android/docs/design/design-tokens.md` §0.

extension Color {
    /// Builds an opaque sRGB color from a 24-bit `0xRRGGBB` literal.
    ///
    /// Every Salus color is an 8-digit `0xAARRGGBB` Compose literal with a fully opaque `FF`
    /// alpha, so the 6-digit RGB hex the design doc lists is lossless. `.sRGB` is pinned
    /// explicitly rather than letting SwiftUI pick Display P3, so `Color(hex: 0x3E7D5F)` and
    /// Compose's `Color(0xFF3E7D5F)` land on the same value.
    ///
    /// Never inline a hex literal at a call site — go through the token types in this package.
    ///
    /// Deliberately `package`, not `public`: exporting the literal constructor would let every
    /// feature package mint a color that no line of `design-tokens.md` backs, and the token
    /// count would never notice. Outside `SalusDesignSystem` there is no way to spell a color
    /// except a token. The tests reach it because they live in this package.
    package init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
