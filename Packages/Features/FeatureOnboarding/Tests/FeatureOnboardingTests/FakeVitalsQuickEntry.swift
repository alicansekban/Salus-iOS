// Ported 1:1 from the private `FakeVitalsQuickEntry` in
// `feature/onboarding/src/test/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingViewModelTest.kt:49-60`.
//
// Kotlin's `mutableListOf<Triple<Double, Long, String>>` becomes an array of a named struct: Swift
// tuples are not `Equatable` across a `Sendable` boundary without a wrapper, and naming the three
// fields makes the assertion read as the call it records. Two shape notes:
//
//   1. `recordWeight` is `throws` here because `SalusModel.VitalsQuickEntry` declares it so
//      (`VitalsQuickEntry.swift:13`); the Kotlin `suspend fun` cannot fail. The fake never throws,
//      which is the Kotlin behaviour.
//   2. It also appends to the shared ``FinishOrderLog`` so the ordering ruling 7 fixes is testable.

import Foundation
import SalusModel

/// One `recordWeight` call — the twin of Kotlin's `Triple(kilograms, epochMs, timeZoneId)`.
struct RecordedWeight: Sendable, Equatable {
    let kilograms: Double
    let epochMs: Int64
    let timeZoneId: String
}

/// A ``VitalsQuickEntry`` that records every call instead of writing to the database
/// (`OnboardingViewModelTest.kt:49-60`).
final class FakeVitalsQuickEntry: VitalsQuickEntry, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [RecordedWeight] = []
    private let orderLog: FinishOrderLog?

    /// `OnboardingViewModelTest.kt:50` — `val recorded`.
    var recorded: [RecordedWeight] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    init(orderLog: FinishOrderLog? = nil) {
        self.orderLog = orderLog
    }

    /// `OnboardingViewModelTest.kt:52-59` — records and answers true.
    func recordWeight(kilograms: Double, epochMs: Int64, timeZoneId: String) async throws -> Bool {
        append(RecordedWeight(kilograms: kilograms, epochMs: epochMs, timeZoneId: timeZoneId))
        return true
    }

    /// The synchronous helper keeps `NSLock` out of an asynchronous context, which Swift 6
    /// disallows — the same constraint `FeatureSettings`' `FakeSettingsPreferences` satisfies.
    private func append(_ entry: RecordedWeight) {
        lock.lock()
        entries.append(entry)
        lock.unlock()
        orderLog?.record(.weight)
    }
}
