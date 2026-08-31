import Testing

@testable import SalusPremium

// Ported 1:1 from `PaywallControllerTest.kt` (4 cases). Case names are the Kotlin
// backtick names in camelCase.

@Suite("PaywallController (Android parity)")
@MainActor
struct PaywallControllerTests {
    @Test("the paywall starts closed")
    func thePaywallStartsClosed() {
        let controller = PaywallController()

        #expect(controller.request == nil)
    }

    @Test("show publishes a request carrying the source that asked for it")
    func showPublishesARequestCarryingTheSourceThatAskedForIt() {
        let controller = PaywallController()

        controller.show(.themes)

        #expect(controller.request == PaywallRequest(source: .themes))
    }

    @Test("dismiss closes the paywall")
    func dismissClosesThePaywall() {
        let controller = PaywallController()
        controller.show(.settings)

        controller.dismiss()

        #expect(controller.request == nil)
    }

    @Test("showing again while open replaces the source")
    func showingAgainWhileOpenReplacesTheSource() {
        let controller = PaywallController()
        controller.show(.onboarding)

        controller.show(.trends)

        #expect(controller.request == PaywallRequest(source: .trends))
    }
}
