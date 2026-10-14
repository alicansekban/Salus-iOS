// ``HomeSmoking`` over the shared smoking core (`SmokingCoreModule`): the repository's snapshot
// stream and the two use cases the card's "+1" and its undo run.
//
// `public` because the composition root — the app target — builds it from the one
// `SmokingCoreModule`, the way it builds ``PremiumRepositoryHomePremiumStatus``; the protocol stays
// feature-local.

import SalusSmoking

public struct SmokingCoreHomeSmoking: HomeSmoking {
    private let repository: any SmokingRepository
    private let logSmokedUseCase: LogSmoked
    /// Named apart from the protocol method of the same name, which would otherwise call itself.
    private let deleteEventUseCase: DeleteEvent

    public init(core: SmokingCoreModule) {
        repository = core.repository
        logSmokedUseCase = core.logSmoked
        deleteEventUseCase = core.deleteEvent
    }

    public func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        repository.observeSnapshot()
    }

    public func logOneSmoked(atMs: Int64) async throws -> String {
        try await logSmokedUseCase(units: 1, atMs: atMs)
    }

    public func deleteEvent(eventId: String) async throws {
        try await deleteEventUseCase(eventId: eventId)
    }
}
