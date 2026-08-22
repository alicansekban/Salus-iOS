import Testing

@testable import SalusCommon

// Pinning tests for the id generator, ported from
// `salus-android/core/common/src/main/.../IdGenerator.kt:9-11`.
//
// Android has no test of its own here — `UUID.randomUUID().toString()` is the JDK's contract. On
// this side the contract has to be pinned, because Foundation spells the same value differently:
// `UUID.uuidString` is UPPERCASE, and a backup written by iOS with uppercase ids would not match
// the same row written by Android (`docs/contracts/backup-format-v1.md`). The `lowercased()` in
// `UUIDIdGenerator` is the whole port, so it is what these tests guard.

@Suite("UUIDIdGenerator (Android parity)")
struct UUIDIdGeneratorTests {
    /// Every character Java's `UUID.toString()` can produce: lowercase hex and the separator.
    static let allowedCharacters = Set("0123456789abcdef-")

    /// The 8-4-4-4-12 grouping, which is also where the four hyphens are.
    static let groupLengths = [8, 4, 4, 4, 12]

    @Test("an id is spelled the way Java's UUID.toString spells it")
    func idsAreSpelledLikeJava() {
        let generator = UUIDIdGenerator()

        for _ in 0 ..< 100 {
            let id = generator.newId()
            #expect(id.count == 36, "\(id) is not 36 characters long")
            #expect(id.allSatisfy { Self.allowedCharacters.contains($0) }, "\(id) is not lowercase hex")
            #expect(id.split(separator: "-", omittingEmptySubsequences: false).map(\.count) == Self.groupLengths)
        }
    }

    @Test("ids do not repeat")
    func idsDoNotRepeat() {
        let generator = UUIDIdGenerator()
        let ids = Set((0 ..< 1000).map { _ in generator.newId() })

        #expect(ids.count == 1000)
    }
}
