/// Deletes every row of the five smoking tables ("Takibi sıfırla"). The screen confirms first.
public struct ResetSmoking: Sendable {
    private let store: any SmokingStore

    public init(store: any SmokingStore) {
        self.store = store
    }

    public func callAsFunction() async throws {
        try await store.mutate { writes in try writes.resetAll() }
    }
}
