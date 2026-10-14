// No Kotlin twin: Android pushes the craving screen onto its one back stack. On iOS the craving flow
// is a full-screen cover, and the shell is the only thing that applies navigation commands, so the
// shell hands each command to this presenter first — `consume` says whether it took it.

import SalusNavigation
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingCravingPresenter")
struct SmokingCravingPresenterTests {
    @Test("navigating to the craving key presents the cover and consumes the command")
    func cravingKeyPresents() {
        let presenter = SmokingCravingPresenter()

        let consumed = presenter.consume(.navigate(AnyNavKey(SmokingCravingKey(source: "home"))))

        #expect(consumed)
        #expect(presenter.presented == SmokingCravingKey(source: "home"))
    }

    @Test("any other key is left for the shell's back stack")
    func otherKeysPass() {
        let presenter = SmokingCravingPresenter()

        let consumed = presenter.consume(.navigate(AnyNavKey(SmokingKey())))

        #expect(!consumed)
        #expect(presenter.presented == nil)
    }

    @Test("a pop dismisses the cover while it is up")
    func popDismisses() {
        let presenter = SmokingCravingPresenter()
        presenter.consume(.navigate(AnyNavKey(SmokingCravingKey())))

        let consumed = presenter.consume(.pop)

        #expect(consumed)
        #expect(presenter.presented == nil)
    }

    @Test("a pop with no cover up is left for the shell's back stack")
    func popPasses() {
        let presenter = SmokingCravingPresenter()

        #expect(!presenter.consume(.pop))
    }

    @Test("a second craving key while the cover is up changes nothing")
    func secondKeyIsIgnored() {
        let presenter = SmokingCravingPresenter()
        presenter.consume(.navigate(AnyNavKey(SmokingCravingKey(source: "main"))))

        let consumed = presenter.consume(.navigate(AnyNavKey(SmokingCravingKey(source: "home"))))

        #expect(consumed, "swallowed, not pushed under the cover")
        #expect(presenter.presented == SmokingCravingKey(source: "main"))
    }

    @Test("the cover can be dismissed from the presentation side")
    func dismissFromThePresentation() {
        let presenter = SmokingCravingPresenter()
        presenter.consume(.navigate(AnyNavKey(SmokingCravingKey())))

        presenter.dismiss()

        #expect(presenter.presented == nil)
        #expect(!presenter.consume(.pop), "the next pop is the back stack's again")
    }
}
