import SwiftUI
import Testing

@testable import SalusNavigation

/// A stand-in for the app's `RootTab`: `TabBackStacks` is generic precisely so the shell's tab
/// enum — which lives in the app target, where there is no test bundle — does not have to be
/// visible here for the semantics to be tested.
enum SampleTab: Hashable, CaseIterable, Sendable {
    case home
    case vitals
    case more
}

/// One step of a back-stack script.
enum TabBackStackStep: Sendable {
    case select(SampleTab)
    case push(String)
    case pop
}

/// One row of the switch/push/pop/reselect table.
struct TabBackStackCase: Sendable, CustomTestStringConvertible {
    let name: String
    let steps: [TabBackStackStep]
    let expectedSelection: SampleTab
    let expectedDepths: [SampleTab: Int]

    var testDescription: String { name }
}

/// The behaviour table, read against `TopLevelBackStack.kt:30-55` row by row.
///
/// At file scope rather than inside the suite because swift-testing evaluates `arguments:` outside
/// the suite's `@MainActor` isolation.
let tabBackStackCases: [TabBackStackCase] = [
    TabBackStackCase(
        name: "fresh holder starts on its initial tab with every stack at its root",
        steps: [],
        expectedSelection: .home,
        expectedDepths: [.home: 0, .vitals: 0, .more: 0]
    ),
    TabBackStackCase(
        name: "push lands on the selected tab only",
        steps: [.push("a"), .push("b")],
        expectedSelection: .home,
        expectedDepths: [.home: 2, .vitals: 0, .more: 0]
    ),
    TabBackStackCase(
        name: "switching tabs preserves the stack left behind",
        steps: [.push("a"), .select(.vitals), .push("b")],
        expectedSelection: .vitals,
        expectedDepths: [.home: 1, .vitals: 1, .more: 0]
    ),
    TabBackStackCase(
        name: "switching back restores the earlier stack untouched",
        steps: [.push("a"), .push("b"), .select(.more), .select(.home)],
        expectedSelection: .home,
        expectedDepths: [.home: 2, .vitals: 0, .more: 0]
    ),
    TabBackStackCase(
        name: "re-selecting the current tab is a no-op — its stack survives",
        steps: [.push("a"), .push("b"), .select(.home)],
        expectedSelection: .home,
        expectedDepths: [.home: 2, .vitals: 0, .more: 0]
    ),
    TabBackStackCase(
        name: "re-selecting a tab leaves every stack, its own included, untouched",
        steps: [.push("a"), .select(.vitals), .push("b"), .select(.vitals)],
        expectedSelection: .vitals,
        expectedDepths: [.home: 1, .vitals: 1, .more: 0]
    ),
    TabBackStackCase(
        name: "pop removes one entry from the selected tab",
        steps: [.push("a"), .push("b"), .pop],
        expectedSelection: .home,
        expectedDepths: [.home: 1, .vitals: 0, .more: 0]
    ),
    TabBackStackCase(
        name: "pop at the root is a no-op — the last stack never empties past its root",
        steps: [.pop, .pop],
        expectedSelection: .home,
        expectedDepths: [.home: 0, .vitals: 0, .more: 0]
    ),
    TabBackStackCase(
        name: "pop applies to the selected tab, not the one it was pushed on",
        steps: [.push("a"), .select(.more), .pop],
        expectedSelection: .more,
        expectedDepths: [.home: 1, .vitals: 0, .more: 0]
    )
]

@Suite("TabBackStacks")
@MainActor
struct TabBackStacksTests {
    @Test("switch / push / pop / reselect table", arguments: tabBackStackCases)
    func table(testCase: TabBackStackCase) {
        let stacks = TabBackStacks<SampleTab>(initial: .home)

        for step in testCase.steps {
            switch step {
            case let .select(tab): stacks.switchTopLevel(tab)
            case let .push(value): stacks.push(AnyNavKey(SampleHomeKey.detail(value)))
            case .pop: stacks.pop()
            }
        }

        #expect(stacks.selection == testCase.expectedSelection)
        for (tab, depth) in testCase.expectedDepths {
            #expect(stacks.path(for: tab).count == depth, "stack depth for \(tab)")
        }
    }

    /// The `Binding` the shell hands each `NavigationStack`: SwiftUI writes the whole path back
    /// when the user swipes a screen away, so the write has to land on the tab it came from.
    @Test("the per-tab binding reads and writes that tab's path")
    func bindingRoundTrips() {
        let stacks = TabBackStacks<SampleTab>(initial: .home)
        let binding = stacks.binding(for: .vitals)

        #expect(binding.wrappedValue.isEmpty)

        stacks.switchTopLevel(.vitals)
        stacks.push(AnyNavKey(SampleVitalsKey.root))
        #expect(binding.wrappedValue.count == 1)

        binding.wrappedValue.removeLast()
        #expect(stacks.path(for: .vitals).isEmpty)
        #expect(stacks.path(for: .home).isEmpty)
    }
}

/// The push has to carry the key's concrete type into the tab's `NavigationPath`, or the
/// `navigationDestination(for:)` a feature registers for its own key type never matches. Same
/// type-sensitive `NavigationPath` equality as `AnyNavKeyAppendTests`, one level up.
@Suite("TabBackStacks — pushing a concrete key")
@MainActor
struct TabBackStacksPushTests {
    @Test("push puts the concrete key on the selected tab's path, not the erased box")
    func pushPutsTheConcreteKeyOnThePath() {
        let stacks = TabBackStacks<SampleTab>(initial: .home)

        stacks.push(AnyNavKey(SampleHomeKey.detail("a")))

        #expect(stacks.path(for: .home) == NavigationPath([SampleHomeKey.detail("a")]))
    }

    @Test("a key pushed on one tab does not reach another tab's path")
    func pushDoesNotReachAnotherTab() {
        let stacks = TabBackStacks<SampleTab>(initial: .home)

        stacks.switchTopLevel(.vitals)
        stacks.push(AnyNavKey(SampleVitalsKey.root))

        #expect(stacks.path(for: .vitals) == NavigationPath([SampleVitalsKey.root]))
        #expect(stacks.path(for: .home) == NavigationPath())
    }
}

/// The predicate behind the shell's tab-bar rule — the twin of Android's `showBottomBar`
/// (`SalusApp.kt:133-136`): the bar is drawn only while the selected tab sits at its root.
@Suite("TabBackStacks — isAtRoot")
@MainActor
struct TabBackStacksIsAtRootTests {
    @Test("every tab is at its root on a fresh holder")
    func freshHolderIsAtRootEverywhere() {
        let stacks = TabBackStacks<SampleTab>(initial: .home)

        for tab in SampleTab.allCases {
            #expect(stacks.isAtRoot(tab), "at root for \(tab)")
        }
    }

    @Test("a push leaves the pushed-on tab off its root and every other tab at its root")
    func pushLeavesOnlyThePushedTabOffItsRoot() {
        let stacks = TabBackStacks<SampleTab>(initial: .home)

        stacks.push(AnyNavKey(SampleHomeKey.detail("a")))

        #expect(!stacks.isAtRoot(.home))
        #expect(stacks.isAtRoot(.vitals))
        #expect(stacks.isAtRoot(.more))
    }

    @Test("switching tabs answers for the tab asked about, not the selected one")
    func answersPerTabRatherThanForTheSelection() {
        let stacks = TabBackStacks<SampleTab>(initial: .home)

        stacks.push(AnyNavKey(SampleHomeKey.detail("a")))
        stacks.switchTopLevel(.vitals)

        #expect(!stacks.isAtRoot(.home), "home keeps what was pushed onto it")
        #expect(stacks.isAtRoot(.vitals))
    }

    @Test("popping back to the root makes the tab at-root again")
    func popRestoresTheRoot() {
        let stacks = TabBackStacks<SampleTab>(initial: .home)

        stacks.push(AnyNavKey(SampleHomeKey.detail("a")))
        stacks.push(AnyNavKey(SampleHomeKey.detail("b")))
        #expect(!stacks.isAtRoot(.home))

        stacks.pop()
        #expect(!stacks.isAtRoot(.home), "still one screen deep")

        stacks.pop()
        #expect(stacks.isAtRoot(.home))
    }
}
