// Ported 1:1 from Android
// `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/domain/repository/
// TodayRepository.kt`.
//
// Kotlin's `Flow<T>` becomes `AsyncThrowingStream<T, any Error>`, the shape every database-backed
// observation in the tree uses (`CycleRepository.swift`'s note): the overview is a join over four
// DAOs, so a query failure has to be able to reach its collector instead of ending the stream
// quietly and leaving an empty dashboard behind.
//
// There are no use cases in Home's `domain/` — this one protocol and the models beside it are the
// whole layer, exactly as on Android. All of the logic lives in `data/`.

/// Everything the dashboard shows, already joined and status-resolved (`TodayRepository.kt:6-11`).
///
/// **Read-only**: mutations — taking a dose, editing an entry — belong to the owning features.
public protocol TodayRepository: Sendable {
    /// `TodayRepository.kt:10`.
    ///
    /// "Today" and "now" are captured when the stream is *created*, not per emission, so a
    /// collector that has been running since yesterday still reports yesterday. Re-subscribing is
    /// what re-captures them; see `TodayRepositoryImpl.observeTodayOverview()`.
    func observeTodayOverview() -> AsyncThrowingStream<TodayOverview, any Error>
}
