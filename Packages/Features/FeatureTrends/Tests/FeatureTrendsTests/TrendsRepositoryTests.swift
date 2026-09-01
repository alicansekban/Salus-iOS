// Ported from Android
// `feature/trends/src/test/kotlin/com/alicansekban/salus/feature/trends/data/TrendsRepositoryTest.kt`.
//
// The trends gate. Every rule about who may see an analysis lives here rather than in the
// ViewModel, so these are the tests that keep a free user out of the database.
//
// The Android suite carries cases for the four analyses (time-of-day, overlay, dose weeks,
// summaries); those arrive with the tasks that implement them (Tasks 2-5) and are not ported
// here. This file holds the Task-1 cases that do not need an analysis: the gate, the empty/ready
// split, the day window, and the failure half.
//
// RecordingReader answers one read (no previous-period read until Task 5), so `requestedZones`
// records one zone rather than the two the Android suite asserts. The case comment says so.

import Foundation
import SalusCommon
import SalusModel
import SalusPremium
import SalusTesting
import Testing

@testable import FeatureTrends

@Suite("TrendsRepository")
struct TrendsRepositoryTests {
    /// 2026-08-20, the day the Android fixture fixes `today` to.
    private static let today = 20685
    private let clock = FixedSalusClock(
        now: Date(timeIntervalSince1970: 20685 * 86400 + 12 * 3600),
        timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt
    )

    // MARK: - The gate

    /// A free user is answered locked without one record being read.
    ///
    /// The reader throws when touched, so this passing is the proof: the gate returns before any
    /// read, and an unentitled visit costs one `AsyncStream` lookup.
    @Test("a free user is answered locked without one record being read")
    func freeUserAnsweredLockedWithoutRead() async {
        let repository = repository(reader: ExplodingReader(), premium: .free)

        #expect(await repository.load(range: .quarter) == .locked)
    }

    /// A free user's load reads no window at all — not the window asked for, not any other.
    @Test("a free user's load reads no window")
    func freeUserLoadReadsNoWindow() async {
        let reader = RecordingReader(records: recordsWithOneMeasurement)
        let repository = repository(reader: reader, premium: .free)

        _ = await repository.load(range: .quarter)

        #expect(reader.requestedWindows.isEmpty)
    }

    // MARK: - The empty / ready split

    @Test("an entitled user with no records at all is answered empty")
    func entitledNoRecordsIsEmpty() async {
        let reader = RecordingReader(records: TrendsRecords(measurements: [], doses: []))

        let result = await repository(reader: reader, premium: .premium).load(range: .quarter)

        #expect(result == .empty)
    }

    /// Empty means empty: someone who only logs medication still has a window worth opening.
    @Test("doses alone are enough to have something to analyse")
    func dosesAloneAreReady() async {
        let reader = RecordingReader(
            records: TrendsRecords(measurements: [], doses: [TrendDose(epochDay: Self.today, taken: true)])
        )

        let result = await repository(reader: reader, premium: .premium).load(range: .quarter)

        guard case .ready = result else {
            Issue.record("expected .ready, got \(result)")
            return
        }
    }

    @Test("an entitled user with records is answered ready")
    func entitledWithRecordsIsReady() async {
        let reader = RecordingReader(records: recordsWithOneMeasurement)

        let result = await repository(reader: reader, premium: .premium).load(range: .year)

        guard case .ready = result else {
            Issue.record("expected .ready, got \(result)")
            return
        }
    }

    /// An empty window stays empty and does not read a second window — there is nothing to
    /// compare a blank to, so a second scan of a year of rows would buy nothing (Task 5 opens
    /// the previous-period read only for a non-empty window).
    @Test("an empty window is answered empty without extra reads")
    func emptyWindowReadsOnce() async {
        let reader = RecordingReader(records: TrendsRecords(measurements: [], doses: []))

        let result = await repository(reader: reader, premium: .premium).load(range: .quarter)

        #expect(result == .empty)
        #expect(reader.requestedWindows.count == 1)
    }

    // MARK: - The day window

    /// The window is the range's days, inclusive, ending on the caller's today.
    @Test("the window is the range's days, inclusive, ending on today")
    func windowIsTheRangeDaysEndingOnToday() async {
        let reader = RecordingReader(records: recordsWithOneMeasurement)

        _ = await repository(reader: reader, premium: .premium).load(range: .month)

        // 30 days ending on today means today - 29 .. today, not today - 30.
        #expect(reader.requestedWindows == [(Self.today - 29) ... Self.today])
        // The zone comes from the clock, never from the caller: day boundaries belong to the
        // device the records were logged on.
        #expect(reader.requestedZones == [TimeZone(secondsFromGMT: 0) ?? .gmt])
    }

    // MARK: - Failure

    /// A read that throws is answered `failed` instead of escaping.
    ///
    /// `load` is called from a ViewModel task with no catch around it, so an escaping exception
    /// would be a process crash on a screen the user reached by tapping a row.
    @Test("a read that throws is answered failed")
    func throwingReadIsFailed() async {
        let reader = ThrowingReader(IllegalArgumentException())

        #expect(await repository(reader: reader, premium: .premium).load(range: .quarter) == .failed)
    }

    /// A cancelled read is the caller going away — a range switch, or a closed screen — and must
    /// not surface as an error body.
    ///
    /// Android *rethrows* `CancellationException` out of `load`; the non-throwing iOS `load`
    /// cannot, so (as `DoctorReportRepositoryImpl` records for the same Android rethrow) it
    /// answers `.failed` and relies on the ViewModel's `Task.isCancelled` guard to discard the
    /// result before it is ever painted.
    @Test("a cancelled read never surfaces as an error body")
    func cancelledReadIsFailedButDiscarded() async {
        let reader = ThrowingReader(CancellationError())

        #expect(await repository(reader: reader, premium: .premium).load(range: .quarter) == .failed)
    }

    // MARK: - Fixtures

    private func repository(reader: any TrendsReader, premium: PremiumStatus) -> any TrendsRepository {
        TrendsRepositoryImpl(
            reader: reader,
            premiumRepository: FakePremiumRepository(status: premium),
            clock: clock
        )
    }

    private var recordsWithOneMeasurement: TrendsRecords {
        TrendsRecords(
            measurements: [
                TrendMeasurement(
                    type: .weight,
                    epochDay: Self.today,
                    minuteOfDay: 8 * 60,
                    primary: 72.5,
                    secondary: nil,
                    tertiary: nil
                )
            ],
            doses: []
        )
    }
}

/// Fails the moment it is touched: the free-user test passes only because it never is.
private struct ExplodingReader: TrendsReader {
    func records(days: ClosedRange<Int>, timeZone: TimeZone) async throws -> TrendsRecords {
        throw IllegalState()
    }
}

/// Records every window it is asked for, and the zone each was cut on.
///
/// A reference type because the reader is called across an `async` boundary and the harness has
/// no shared mutable `self` to reach otherwise — the lock is what makes the `@unchecked Sendable`
/// conformance true.
private final class RecordingReader: TrendsReader, @unchecked Sendable {
    private let records: TrendsRecords
    private let lock = NSLock()
    private var recordedWindows: [ClosedRange<Int>] = []
    private var recordedZones: [TimeZone] = []

    init(records: TrendsRecords) {
        self.records = records
    }

    var requestedWindows: [ClosedRange<Int>] {
        lock.withLock { recordedWindows }
    }

    var requestedZones: [TimeZone] {
        lock.withLock { recordedZones }
    }

    func records(days: ClosedRange<Int>, timeZone: TimeZone) async throws -> TrendsRecords {
        lock.withLock {
            recordedWindows.append(days)
            recordedZones.append(timeZone)
        }
        return records
    }
}

/// Stands in for Room throwing on a corrupt database.
private final class ThrowingReader: TrendsReader, @unchecked Sendable {
    private let failure: any Error

    init(_ failure: any Error) {
        self.failure = failure
    }

    func records(days: ClosedRange<Int>, timeZone: TimeZone) async throws -> TrendsRecords {
        throw failure
    }
}

/// Throwable stand-ins — the test harness carries no force-try, so a plain `Error` is enough.
private struct IllegalState: Error, Equatable {}
private struct IllegalArgumentException: Error, Equatable {}

private final class FakePremiumRepository: PremiumRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let current: PremiumStatus
    private var continuations: [UUID: AsyncStream<PremiumStatus>.Continuation] = [:]

    init(status: PremiumStatus) {
        current = status
    }

    var status: AsyncStream<PremiumStatus> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let value = current
            lock.unlock()
            continuation.yield(value)
            continuation.onTermination = { [weak self] _ in
                self?.remove(id)
            }
        }
    }

    func refresh() async {}

    private func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
