// Twin of `core/smoking/.../repository/{SmokingRepository,SmokingError}.kt` (Android branch
// `feature/m17-smoking-cessation`) and of contract §6.
//
// One deliberate shape difference: Kotlin's `Flow` may throw to its collector, and the brief fixes
// these as non-throwing `AsyncStream`s. A storage failure therefore ends the stream (and makes
// `snapshotNow()` answer `.notSetUp`) after being logged, instead of reaching the screen.

/// The read side of the smoking feature; every write is a use case in `usecase/`.
public protocol SmokingRepository: Sendable {
    /// The raw rows as the calculators read them. A QUIT plan without an attempt is repaired first.
    ///
    /// Every element is one consistent read of all five tables, so an observer never sees a plan
    /// from one commit next to attempts from another.
    func observeInput() -> AsyncStream<SmokingInput>

    /// ``observeInput()`` folded into a snapshot, recomputed at the top of every minute.
    func observeSnapshot() -> AsyncStream<SmokingSnapshot>

    func snapshotNow() async -> SmokingSnapshot
}

/// Told after every committed smoking write so the reminder plan can be rebuilt. Called on the
/// writing task: hand off, don't block. With none registered everything still works.
public protocol SmokingChangeListener: Sendable {
    func smokingDataChanged()
}

/// Why a use case refused (contract §6). Anything else a use case throws is a storage failure the
/// screen reports generically.
public enum SmokingError: Error, Equatable, Sendable {
    /// A quit date after "now".
    case futureQuitDate
    /// The use case needs a plan and none exists.
    case notSetUp
    /// An argument or the current state does not allow the action.
    case invalidInput
}
