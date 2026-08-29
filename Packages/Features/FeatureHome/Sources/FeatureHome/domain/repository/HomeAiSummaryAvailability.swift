// No Kotlin counterpart file, and there is a reason there is none.
//
// Android's `HomeViewModel` takes the whole `AiSummaryRepository` (`HomeViewModel.kt:18`) and reads
// one property off it — `freeSummaryAvailable` (`core/ai/.../AiSummaryRepository.kt:88`) — while
// never calling `getSummary`; `HomeViewModelTest.kt:76-80` makes that a contract by having its fake
// throw `AssertionError("Home must never request a summary")` from `getSummary`.
//
// iOS ports that contract as a type instead of as a test assertion: Home depends on the one-line
// protocol below, so "Home must never request a summary" is not something a fake has to catch — it
// is not reachable. The narrowing also keeps `SalusAI` out of `domain/`, which matters more here
// than on Android because the iOS AI package arrives in iOS-M10.
//
// `AsyncStream` rather than `AsyncThrowingStream`, and it is the same reason as
// `CycleReminderSettings.config`: the source is `AiUsageDataSource.usage` over `UserDefaults`,
// which cannot fail the way DataStore can. Promising a failure that can never arrive would give
// every collector a `catch` branch with nothing to put in it.

/// Whether the one-off free AI summary is still unspent, for the dashboard's badge
/// (`AiSummaryRepository.kt:80-88`).
///
/// This says nothing about entitlement: a premium user also reads `true` here until they happen to
/// generate one as a free user. Screens that show the badge already know the premium status and
/// decide whether the badge is worth showing.
public protocol HomeAiSummaryAvailability: Sendable {
    /// Emits the current value on subscription, then once per actual change.
    var freeSummaryAvailable: AsyncStream<Bool> { get }
}
