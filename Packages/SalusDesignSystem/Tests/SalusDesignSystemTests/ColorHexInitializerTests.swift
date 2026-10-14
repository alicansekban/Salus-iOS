import SwiftUI
import Testing

@testable import SalusDesignSystem

// Split out of `SalusDesignTokensTests.swift`, which reached SwiftLint's 500-line `file_length`
// gate when the M17 smoking accent added its pins; this suite is the one with no token table.

@Suite("Hex initializer")
struct ColorHexInitializerTests {
    /// The doc's §0 initializer: an opaque sRGB color, never Display P3.
    @Test("hex initializer produces opaque sRGB components")
    func hexComponents() {
        #expect(
            Color(hex: 0x3E7D5F)
                == Color(
                    .sRGB,
                    red: Double(0x3E) / 255,
                    green: Double(0x7D) / 255,
                    blue: Double(0x5F) / 255,
                    opacity: 1
                )
        )
        #expect(Color(hex: 0xFFFFFF) == Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1))
        #expect(Color(hex: 0x000000) == Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
    }
}
