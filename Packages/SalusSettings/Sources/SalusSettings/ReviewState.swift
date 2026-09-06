// Twin of `core/model/.../ReviewState.kt` (in-app review spec §1). It lives in `SalusSettings`
// rather than `SalusModel` because it is read by exactly one consumer, through this package's
// data source; nothing in the domain layer names it.

public struct ReviewState: Equatable, Sendable {
    public let homeOpenCount: Int
    public let lastRequestedEpochMs: Int64?

    public init(homeOpenCount: Int = 0, lastRequestedEpochMs: Int64? = nil) {
        self.homeOpenCount = homeOpenCount
        self.lastRequestedEpochMs = lastRequestedEpochMs
    }
}
