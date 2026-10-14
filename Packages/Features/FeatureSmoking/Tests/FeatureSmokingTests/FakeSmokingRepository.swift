// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/
// FakeSmokingRepository.kt`.
//
// The real calculator over a ``FakeSmokingStore``'s rows: every committed write is folded into a
// fresh snapshot at the clock's current instant, which is what the GRDB-backed repository does
// (minus its minute tick, which the main screen's counters no longer depend on: the view's
// `TimelineView` moves them).

import SalusCommon
import SalusSmoking

struct FakeSmokingRepository: SmokingRepository {
    let store: FakeSmokingStore
    let clock: any SalusClock

    func observeInput() -> AsyncStream<SmokingInput> {
        store.inputStream()
    }

    func observeSnapshot() -> AsyncStream<SmokingSnapshot> {
        let inputs = store.inputStream()
        let clock = clock
        return AsyncStream { continuation in
            let task = Task {
                for await input in inputs {
                    continuation.yield(
                        SmokingStatsCalculator.snapshot(
                            input,
                            nowMs: clock.nowEpochMilliseconds(),
                            zone: clock.timeZone()
                        )
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func snapshotNow() async -> SmokingSnapshot {
        SmokingStatsCalculator.snapshot(store.input, nowMs: clock.nowEpochMilliseconds(), zone: clock.timeZone())
    }
}
