import SwiftUI
import Testing

@testable import SalusDesignSystem

@Suite("Salus theme environment")
@MainActor
struct SalusThemeEnvironmentTests {
    /// A view rendered outside any `salusTheme(_:)` must still get real Salus tokens — the light,
    /// classic pair `SalusTheme.resolve` itself defaults to — rather than an empty or crashing key.
    @Test("the default value is the light classic theme")
    func defaultIsLightClassic() {
        let environment = EnvironmentValues()

        #expect(environment.salusTheme == SalusTheme.resolve(systemIsDark: false))
        #expect(environment.salusTheme.isDark == false)
    }

    @Test("a written theme reads back")
    func writeReadRoundTrip() {
        var environment = EnvironmentValues()
        let dark = SalusTheme.resolve(mode: .dark, systemIsDark: false)

        environment.salusTheme = dark

        #expect(environment.salusTheme == dark)
        #expect(environment.salusTheme.isDark)
    }
}
