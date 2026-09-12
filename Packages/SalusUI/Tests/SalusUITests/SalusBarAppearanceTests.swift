import Foundation
import SalusDesignSystem
import SalusModel
import SwiftUI
import Testing

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@testable import SalusUI

// The colour half of the painted system bars (spec §2.1, §2.2). `SalusBarAppearance` answers two
// questions and this suite pins both:
//
//   1. **Which token goes where** — `SalusBarAppearance.colors(for:)`, a pure function of the
//      resolved theme, is the whole mapping. It is platform-neutral on purpose: `swift test` runs
//      on the macOS HOST (see `scripts/test-packages.sh`), where `UITabBarAppearance` does not
//      exist, so a mapping expressed only inside `#if canImport(UIKit)` would be untested on the
//      one platform the gate can run. Everything the Kotlin bars decide is decided here.
//   2. **How that mapping is spelled to UIKit** — the two builder cases below, which can only
//      compile and run where UIKit does. On the macOS host they are compiled out; the iOS
//      compile of the same source is covered by `scripts/build-app.sh`, which links `SalusUI`
//      into the app. That asymmetry is recorded in the task report rather than hidden.
//
// Colours are compared on their sRGB components within 0.01 rather than by `Color` equality:
// `Color` compares its *description*, so two colours built the same way from different token
// paths can fail an `==` that a device would never notice.

/// The sRGB components of an opaque `SwiftUI.Color`. Every Salus colour is authored through
/// `Color(hex:)` in sRGB, so resolving through the platform's native colour is lossless.
private func components(_ color: Color) -> (red: Double, green: Double, blue: Double) {
    #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    #else
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        return (Double(resolved.redComponent), Double(resolved.greenComponent), Double(resolved.blueComponent))
    #endif
}

/// Asserts two colours land on the same sRGB point, within the 0.01 the spec's §2.5 names.
private func expectSameColor(
    _ actual: Color?,
    _ expected: Color,
    _ what: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let actual else {
        Issue.record("\(what): expected a colour, got nil", sourceLocation: sourceLocation)
        return
    }
    let lhs = components(actual)
    let rhs = components(expected)
    #expect(abs(lhs.red - rhs.red) < 0.01, "\(what): red", sourceLocation: sourceLocation)
    #expect(abs(lhs.green - rhs.green) < 0.01, "\(what): green", sourceLocation: sourceLocation)
    #expect(abs(lhs.blue - rhs.blue) < 0.01, "\(what): blue", sourceLocation: sourceLocation)
}

@Suite("Bar appearance maps the resolved theme onto the system bars")
struct SalusBarAppearanceTests {
    private static let classicDark = SalusTheme.resolve(premiumTheme: .classic, systemIsDark: true)
    private static let classicLight = SalusTheme.resolve(premiumTheme: .classic, systemIsDark: false)

    // MARK: - The tab bar (`SalusBottomBar.kt:225-237`, `:313-319`)

    @Test("dark: the bar ground is surfaceContainerLow, carried by the cardBorder hairline")
    func darkTabBarGroundAndShadow() {
        let colors = SalusBarAppearance.colors(for: Self.classicDark)

        expectSameColor(colors.tabBarGround, Self.classicDark.colorScheme.surfaceContainerLow, "dark ground")
        expectSameColor(colors.tabBarShadow, Self.classicDark.extendedColors.cardBorder, "dark hairline")
    }

    @Test("light: the bar ground is surfaceContainerLowest and the hairline stays the system's")
    func lightTabBarGroundAndShadow() {
        let colors = SalusBarAppearance.colors(for: Self.classicLight)

        expectSameColor(
            colors.tabBarGround,
            Self.classicLight.colorScheme.surfaceContainerLowest,
            "light ground"
        )
        // `null` border on Android, where the light bar is told apart by its 8 dp shadow
        // (`SalusBottomBar.kt:234-237`). iOS has no shadow knob on a bar appearance, so the
        // system hairline is what stands in — and `nil` is how this asks for it.
        #expect(colors.tabBarShadow == nil, "the light bar keeps the platform hairline")
    }

    @Test("the selected item is primary and the unselected one onSurfaceVariant, in both modes")
    func itemColors() {
        for (theme, name) in [(Self.classicDark, "dark"), (Self.classicLight, "light")] {
            let colors = SalusBarAppearance.colors(for: theme)

            expectSameColor(colors.selectedItem, theme.colorScheme.primary, "\(name) selected")
            expectSameColor(colors.unselectedItem, theme.colorScheme.onSurfaceVariant, "\(name) unselected")
        }
    }

    // MARK: - The navigation bar (`SalusTopBar.kt:125`, `:154`)

    @Test("the navigation bar sits on background with an onSurface title, in both modes")
    func navigationBarColors() {
        for (theme, name) in [(Self.classicDark, "dark"), (Self.classicLight, "light")] {
            let colors = SalusBarAppearance.colors(for: theme)

            expectSameColor(colors.navigationBarGround, theme.colorScheme.background, "\(name) nav ground")
            expectSameColor(colors.navigationBarTitle, theme.colorScheme.onSurface, "\(name) nav title")
        }
    }

    // MARK: - The palette actually reaches the bars

    @Test("a premium palette repaints the selected item, because primary is one of its roles")
    func premiumPaletteMovesTheSelectedItem() {
        let ocean = SalusTheme.resolve(premiumTheme: .ocean, systemIsDark: true)

        expectSameColor(
            SalusBarAppearance.colors(for: ocean).selectedItem,
            ocean.colorScheme.primary,
            "OCEAN selected"
        )
        // The guard that makes the line above mean something: OCEAN's primary is not CLASSIC's,
        // so a mapping that had hard-coded the emerald would fail here rather than pass twice.
        #expect(ocean.colorScheme.primary != Self.classicDark.colorScheme.primary)
    }

    @Test("the surface ladder is palette-independent, so both palettes share a bar ground")
    func paletteLeavesTheGroundAlone() {
        let forest = SalusTheme.resolve(premiumTheme: .forest, systemIsDark: true)

        expectSameColor(
            SalusBarAppearance.colors(for: forest).tabBarGround,
            Self.classicDark.colorScheme.surfaceContainerLow,
            "FOREST ground"
        )
    }

    // MARK: - The UIKit spelling

    #if canImport(UIKit)
        @Test("the UITabBarAppearance carries the ground and both item colours")
        @MainActor
        func tabBarAppearanceCarriesTheColors() {
            let appearance = SalusBarAppearance.tabBar(for: Self.classicDark)
            let items = appearance.stackedLayoutAppearance

            expectSameColor(
                appearance.backgroundColor.map(Color.init),
                Self.classicDark.colorScheme.surfaceContainerLow,
                "tab bar ground"
            )
            expectSameColor(
                items.selected.iconColor.map(Color.init),
                Self.classicDark.colorScheme.primary,
                "selected icon"
            )
            expectSameColor(
                items.normal.iconColor.map(Color.init),
                Self.classicDark.colorScheme.onSurfaceVariant,
                "unselected icon"
            )
            // The three layouts are set together: a phone in landscape uses `inlineLayoutAppearance`
            // and an iPad `compactInlineLayoutAppearance`, so painting only the stacked one would
            // leave the bar emerald-less on a rotation.
            expectSameColor(
                appearance.inlineLayoutAppearance.normal.iconColor.map(Color.init),
                Self.classicDark.colorScheme.onSurfaceVariant,
                "inline unselected icon"
            )
        }

        @Test("the UINavigationBarAppearance carries the ground and the title colour")
        @MainActor
        func navigationBarAppearanceCarriesTheColors() {
            let appearance = SalusBarAppearance.navigationBar(for: Self.classicLight)

            expectSameColor(
                appearance.backgroundColor.map(Color.init),
                Self.classicLight.colorScheme.background,
                "nav bar ground"
            )
            expectSameColor(
                (appearance.titleTextAttributes[.foregroundColor] as? UIColor).map(Color.init),
                Self.classicLight.colorScheme.onSurface,
                "nav bar title"
            )
            // Large titles are off everywhere (spec §2.2), so nothing should be reading the
            // large-title attributes — but if something does, it must not draw a stale colour.
            #expect(appearance.largeTitleTextAttributes[.foregroundColor] != nil)
        }
    #endif
}
