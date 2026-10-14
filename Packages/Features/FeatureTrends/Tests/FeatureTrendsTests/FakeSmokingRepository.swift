// Ported from the `FakeSmokingRepository` at the foot of Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/data/TrendsRepositoryTest.kt`.

import Foundation
import SalusSmoking

/// Answers one `SmokingInput` and counts how often it was asked, so the free-user test can prove the
/// smoking rows were never touched. A `nil` input is the repository's storage-failure shape: the
/// stream ends without an element.
///
/// A reference type because the repository is called across an `async` boundary; the lock is what
/// makes the `@unchecked Sendable` conformance true.
final class FakeSmokingRepository: SmokingRepository, @unchecked Sendable {
    private let input: SmokingInput?
    private let lock = NSLock()
    private var readCount = 0

    init(input: SmokingInput?) {
        self.input = input
    }

    var reads: Int {
        lock.withLock { readCount }
    }

    func observeInput() -> AsyncStream<SmokingInput> {
        lock.withLock { readCount += 1 }
        let input = input
        return AsyncStream { continuation in
            if let input {
                continuation.yield(input)
            }
            continuation.finish()
        }
    }

    /// Trends never reads the snapshot; an empty stream is the harmless answer if that ever changes.
    func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        AsyncStream { $0.finish() }
    }

    func snapshotNow() async -> SmokingSnapshot {
        .notSetUp
    }
}
