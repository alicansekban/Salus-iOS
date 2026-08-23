import SwiftUI
import Testing

@testable import SalusNavigation

@Suite("AnyNavKey")
struct AnyNavKeyTests {
    @Test("equal keys of the same type compare equal and hash alike")
    func sameTypeSameValue() {
        let lhs = AnyNavKey(SampleHomeKey.detail("a"))
        let rhs = AnyNavKey(SampleHomeKey.detail("a"))

        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }

    @Test("different values of the same type compare unequal")
    func sameTypeDifferentValue() {
        #expect(AnyNavKey(SampleHomeKey.detail("a")) != AnyNavKey(SampleHomeKey.detail("b")))
        #expect(AnyNavKey(SampleHomeKey.root) != AnyNavKey(SampleHomeKey.detail("a")))
    }

    /// The property the type exists for: type erasure must not erase the type.
    ///
    /// `SampleHomeKey.root` and `SampleVitalsKey.root` are spelled identically and would collide if
    /// equality were reduced to the case name. `AnyHashable` compares the dynamic type first, so
    /// they stay distinct — which is what keeps a `NavigationPath` of two features unambiguous.
    @Test("identically spelled cases of different types stay distinct")
    func differentTypesNeverCollide() {
        #expect(AnyNavKey(SampleHomeKey.root) != AnyNavKey(SampleVitalsKey.root))
        #expect(AnyNavKey(SampleHomeKey.detail("a")) != AnyNavKey(SampleVitalsKey.detail("a")))

        let keys: Set<AnyNavKey> = [
            AnyNavKey(SampleHomeKey.root),
            AnyNavKey(SampleVitalsKey.root),
            AnyNavKey(SampleHomeKey.root)
        ]
        #expect(keys.count == 2)
    }

    /// Wrapping an already-wrapped key is the identity, so a caller that hands `navigate` an
    /// `AnyNavKey` gets the same key back rather than a doubly boxed one that matches nothing.
    @Test("wrapping is idempotent")
    func wrappingIsIdempotent() {
        let once = AnyNavKey(SampleHomeKey.root)
        let twice = AnyNavKey(once)

        #expect(once == twice)
        #expect(once.hashValue == twice.hashValue)
    }

    @Test("the wrapped value can be read back at its original type")
    func baseRoundTrips() throws {
        let key = AnyNavKey(SampleHomeKey.detail("a"))

        let base = try #require(key.base as? SampleHomeKey)
        #expect(base == .detail("a"))
    }
}

// MARK: - Appending the concrete key

// The M1 review's deferred finding, closed here: a key erased all the way into the `NavigationPath`
// can only ever be matched by one central `navigationDestination(for: AnyNavKey.self)` in the app
// target, which would make the shell name every feature's keys — the opposite of what the erasure
// is for. Capturing the append at construction lets the box carry the CONCRETE value into the path,
// so a feature package registers `navigationDestination(for: ItsOwnKey.self)` inside its own
// `…Destinations()` modifier and stays invisible to the shell (Android's `vitalsEntries` shape).
//
// HOW THE TABLE SEES THE TYPE: `NavigationPath` is `Equatable` and its equality compares each entry
// at its dynamic type, so a path built from a literal `[SampleHomeKey.detail("a")]` is the exact
// reference value. `theErasedBoxIsNotTheConcreteKey` below pins that the comparison really is
// type-sensitive, so the assertions above it mean what they say rather than passing for some
// unrelated reason. (`count` cannot see this: both variants push exactly one entry.)

@Suite("AnyNavKey.append(to:)")
struct AnyNavKeyAppendTests {
    @Test("it appends the concrete key rather than the erased box")
    func appendsTheConcreteKey() {
        var path = NavigationPath()

        AnyNavKey(SampleHomeKey.detail("a")).append(to: &path)

        #expect(path == NavigationPath([SampleHomeKey.detail("a")]))
    }

    /// The negative control for the check above.
    @Test("a path holding the erased box is not a path holding the concrete key")
    func theErasedBoxIsNotTheConcreteKey() {
        var boxed = NavigationPath()
        boxed.append(AnyNavKey(SampleHomeKey.detail("a")))

        #expect(boxed != NavigationPath([SampleHomeKey.detail("a")]))
        #expect(boxed.count == NavigationPath([SampleHomeKey.detail("a")]).count)
    }

    /// The other half of the type sensitivity: two features that spell a case identically must not
    /// answer to each other's destination once the concrete value is in the path.
    @Test("an identically spelled case of another type is a different path")
    func anotherTypeIsADifferentPath() {
        var path = NavigationPath()

        AnyNavKey(SampleHomeKey.detail("a")).append(to: &path)

        #expect(path != NavigationPath([SampleVitalsKey.detail("a")]))
        #expect(path != NavigationPath([SampleHomeKey.detail("b")]))
    }

    /// Re-wrapping is the identity for equality (`wrappingIsIdempotent`), and it has to be the
    /// identity for the append too — otherwise a key handed to `navigate(_:)` already erased would
    /// push a box that no feature destination matches.
    @Test("re-wrapping an erased key still appends the concrete key")
    func reWrappingStillAppendsTheConcreteKey() {
        var path = NavigationPath()

        AnyNavKey(AnyNavKey(SampleHomeKey.root)).append(to: &path)

        #expect(path == NavigationPath([SampleHomeKey.root]))
    }

    @Test("appending twice keeps both entries, in order")
    func appendingTwiceKeepsBothInOrder() {
        var path = NavigationPath()

        AnyNavKey(SampleHomeKey.root).append(to: &path)
        AnyNavKey(SampleVitalsKey.detail("a")).append(to: &path)

        #expect(path.count == 2)
        var expected = NavigationPath([SampleHomeKey.root])
        expected.append(SampleVitalsKey.detail("a"))
        #expect(path == expected)
    }
}
