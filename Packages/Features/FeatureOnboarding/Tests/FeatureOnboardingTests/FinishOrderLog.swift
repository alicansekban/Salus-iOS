// No Android twin. The Kotlin `OnboardingViewModelTest` asserts *what* `finish()` wrote but not the
// order it wrote it in; ruling 7 makes the order binding ("profile write first and the completion
// flag last, so a process death midway replays the flow"), so the three fakes share this recorder
// and `finishingWritesTheProfileTheFirstWeightAndTheCompletionFlag` pins the sequence.
//
// `@unchecked Sendable` over a lock for `FakeProfileRepository`'s reason: the fakes are reached from
// the ViewModel's detached write task, so the log is shared mutable state and the lock is what makes
// the promise true.

import Foundation

/// The three writes `OnboardingViewModel.finish()` performs, in the order ruling 7 fixes.
enum FinishWrite: String, Sendable, Equatable {
    case profile
    case weight
    case completionFlag
}

/// Append-only record of the writes `finish()` performed, shared by the three fakes.
final class FinishOrderLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [FinishWrite] = []

    /// What was written, in order.
    var writes: [FinishWrite] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func record(_ write: FinishWrite) {
        lock.lock()
        entries.append(write)
        lock.unlock()
    }
}
