// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/data/TrendsRepository.kt`.

import os
import SalusCommon
import SalusPremium

/// Produces one trends screen's worth of data, and owns the rule about who may see it
/// (`TrendsRepository.kt:20-29`).
public protocol TrendsRepository: Sendable {
    /// Everything the screen shows for `range`, ending on the local day it is called on
    /// (`TrendsRepository.kt:22-27`).
    ///
    /// Never throws for a read that fails: the failure comes back as `TrendsData.failed`.
    func load(range: TrendsRange) async -> TrendsData
}

/// The trends screen's gating core (`TrendsRepository.kt:46-112`).
///
/// The entitlement check is the first statement in `load`, and that placement is the whole
/// design: an unentitled user's visit costs one `AsyncStream` read and touches no database at
/// all. The screen entry itself is deliberately *not* gated — a free user reaches this screen and
/// sees a locked body, which is what makes the feature something to subscribe for rather than
/// something invisible — so this is the only place the entitlement is enforced.
///
/// Reading a year of records is blocking work, and blocking work can fail: a corrupt database
/// throws. `load` is called from a ViewModel task with no catch around it, so an escaping
/// exception would crash the process; answering `TrendsData.failed` keeps the one "something
/// went wrong" state the screen already knows how to render, with a retry on it.
public struct TrendsRepositoryImpl: TrendsRepository {
    private let reader: any TrendsReader
    private let premiumRepository: any PremiumRepository
    private let clock: any SalusClock

    public init(
        reader: any TrendsReader,
        premiumRepository: any PremiumRepository,
        clock: any SalusClock
    ) {
        self.reader = reader
        self.premiumRepository = premiumRepository
        self.clock = clock
    }

    public func load(range: TrendsRange) async -> TrendsData {
        // Read from the repository rather than from any collected state: this must be the
        // current entitlement, not the one a screen last observed. A free user's load costs
        // this one read and nothing else.
        if await !(premiumRepository.status.firstValue()?.isEntitled ?? false) {
            return .locked
        }

        // The zone is resolved here rather than passed in: day boundaries are a property of the
        // device the records were logged on, not of the calling screen.
        let timeZone = clock.timeZone()
        let todayEpochDay = clock.todayEpochDay()
        let days = (todayEpochDay - range.days + 1) ... todayEpochDay
        // The window immediately before the one asked for, of exactly the same length. Equal
        // length is what makes the comparison a comparison: a month measured against a quarter
        // would differ by how long each was, not by how the metric moved.
        let previousDays = (days.lowerBound - range.days) ... (days.lowerBound - 1)

        do {
            let records = try await reader.records(days: days, timeZone: timeZone)
            if records.isEmpty {
                // Nothing to compare, and nobody to show a comparison to. Returning here keeps
                // an empty window at the one read it has always cost, instead of scanning a
                // second year of rows to summarise a screen that will say "nothing yet".
                return .empty
            }
            let previousRecords = try await reader.records(days: previousDays, timeZone: timeZone)
            // The analyses run here rather than in the ViewModel or the screen: they are pure
            // functions over a year of records, and the screen is handed a finished answer it
            // only has to draw.
            return .ready(
                TrendsReady(
                    timeOfDay: timeOfDayBreakdownOrNull(records.measurements),
                    overlay: metricOverlayOrNull(records.measurements, days: days),
                    doseWeeks: doseWeeksOrNull(
                        doses: records.doses,
                        measurements: records.measurements,
                        days: days
                    ),
                    // No window argument here: each list is already exactly one window's records,
                    // because each came from its own read of one.
                    summaries: metricSummariesOrNull(
                        current: records.measurements,
                        previous: previousRecords.measurements
                    )
                )
            )
        } catch is CancellationError {
            // Cancellation is the caller going away — a range switch, or a screen that was
            // closed — not a failure of ours. The ViewModel's task guard discards whatever a
            // cancelled load returns, so answering `.failed` here is never rendered as an error
            // body (the same shape `DoctorReportRepositoryImpl.generate` records).
            return .failed
        } catch {
            // The reason dies here: it is untranslated platform text, and the log is the only
            // diagnostic trail this app has by design.
            logger.warning("Trends records could not be read: \(String(describing: error), privacy: .private)")
            return .failed
        }
    }
}

/// Shared with the rest of the app's log output, so one filter catches everything.
private let logger = Logger(subsystem: "com.alicansekban.salus", category: "trends")

extension AsyncStream {
    /// The stream's current value — the twin of `StateFlow.value`, read once.
    fileprivate func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}
