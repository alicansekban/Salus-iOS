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
