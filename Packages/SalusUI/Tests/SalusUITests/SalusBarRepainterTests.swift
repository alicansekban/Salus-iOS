import Testing

@testable import SalusUI

// The walk `SalusBarRepainter` finds the live bars with (spec §10, owner QA round 1 B3).
//
// Only the walk. `SalusLiveBarPainter`, `SalusBarProbeView` and the representable are all `UIKit`,
// and `swift test` runs on the macOS HOST (`scripts/test-packages.sh`), where none of those types
// exists — they are compiled out of this package's host build entirely, so there is nothing for a
// test to reach. Their iOS compile is `scripts/build-app.sh` and their behaviour is
// `docs/qa/m16-manual-qa.md` §5.1. That is the same asymmetry `SalusBarAppearanceTests` records,
// and the reason the walk is generic over its node in the first place: it is the half that is a
// decision rather than a spelling, so it is the half that is written where the gate can run it.

/// A view tree, minus UIKit. `UIView` is handed to the real walk as `{ $0.subviews }`.
private struct Node: Equatable {
    let name: String
    var children: [Node] = []
}

@Suite("SalusBarTree")
struct SalusBarTreeTests {
    @Test("a leaf is the whole of its own tree")
    func leaf() {
        let found = SalusBarTree.flatten(from: Node(name: "a")) { $0.children }

        #expect(found.map(\.name) == ["a"])
    }

    @Test("every node is visited, parents before their children")
    func depthFirst() {
        // window
        // ├── tabBarController
        // │   ├── navigationBar   <- the bar a pushed screen keeps
        // │   └── content
        // └── tabBar               <- the one tab bar
        let tree = Node(
            name: "window",
            children: [
                Node(
                    name: "tabBarController",
                    children: [Node(name: "navigationBar"), Node(name: "content")]
                ),
                Node(name: "tabBar")
            ]
        )

        let found = SalusBarTree.flatten(from: tree) { $0.children }

        #expect(found.map(\.name) == ["window", "tabBarController", "navigationBar", "content", "tabBar"])
    }

    @Test("a bar nested far below the root is still found")
    func deeplyNested() {
        var tree = Node(name: "navigationBar")
        for level in (1 ... 8).reversed() {
            tree = Node(name: "level\(level)", children: [tree])
        }

        let found = SalusBarTree.flatten(from: tree) { $0.children }

        #expect(found.count == 9)
        #expect(found.last?.name == "navigationBar")
    }

    @Test("a node's whole subtree is visited before its next sibling")
    func siblingsDoNotInterleave() {
        let tree = Node(
            name: "root",
            children: [
                Node(name: "first", children: [Node(name: "firstChild")]),
                Node(name: "second", children: [Node(name: "secondChild")])
            ]
        )

        let found = SalusBarTree.flatten(from: tree) { $0.children }

        #expect(found.map(\.name) == ["root", "first", "firstChild", "second", "secondChild"])
    }
}
