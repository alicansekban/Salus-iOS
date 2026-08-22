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
