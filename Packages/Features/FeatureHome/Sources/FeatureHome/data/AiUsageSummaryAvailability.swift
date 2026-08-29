// The Home-shaped port of `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/
// AiSummaryRepository.kt:137-139`:
//
//     override val freeSummaryAvailable: Flow<Boolean> = usageDataSource.usage
//         .map { !it.freeSummaryUsed }
//         .distinctUntilChanged()
//
// Three lines on Android because they sit inside `AiSummaryRepositoryImpl`, which iOS does not
// have until iOS-M10. The expression is the same one, moved to the only consumer that exists now;
// when the AI feature lands it takes this over and Home keeps depending on
// ``HomeAiSummaryAvailability`` rather than on the repository (see that file for why).
//
// Rebuilt as an `AsyncStream` rather than mapped in place: `AsyncStream.map` answers an
// `AsyncMapSequence`, and the protocol promises the concrete type. `.bufferingNewest(1)` is the
// conflation `DefaultsValueStream` already applies to the source, restated because rebuilding the
// stream is what mapping it costs — `SalusCommon.mapped`'s note, for the non-throwing case.
//
// **This one deduplicates and `CycleReminderSettingsImpl.config` does not**, and the difference is
// the Kotlin's: `AiSummaryRepositoryImpl` chains `distinctUntilChanged` and
// `CycleReminderSettingsImpl` does not. It matters here because the source carries the AI call
// counter as well: `recordCall` changes `AiUsage` on every generated summary without touching the
// free credit, and without the guard each of those would wake the dashboard with a boolean it
// already has.

import SalusSettings

/// ``HomeAiSummaryAvailability`` over the real usage store (`AiSummaryRepository.kt:137-139`).
struct AiUsageSummaryAvailability: HomeAiSummaryAvailability {
    private let aiUsage: AiUsageDataSource

    init(aiUsage: AiUsageDataSource) {
        self.aiUsage = aiUsage
    }

    var freeSummaryAvailable: AsyncStream<Bool> {
        // Read before the stream is built: `makeStream()` registers the subscription and buffers
        // the current value there and then, so nothing written between here and the first
        // iteration is missed.
        let usage = aiUsage.usage
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                var lastSent: Bool?
                for await value in usage {
                    let available = !value.freeSummaryUsed
                    guard available != lastSent else { continue }
                    lastSent = available
                    continuation.yield(available)
                }
                continuation.finish()
            }
            // A consumer that stops reading must stop the underlying subscription too.
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
