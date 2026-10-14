// Twin of `core/smoking/.../usecase/UseCaseSupport.kt`: small pieces the use cases share. A use
// case validates by throwing a ``SmokingError``; the store rolls the transaction back.

import Foundation
import SalusCommon

extension SmokingInput {
    func requirePlan() throws -> SmokingPlan {
        guard let plan else { throw SmokingError.notSetUp }
        return plan
    }

    /// Contract §8.5: if several are open, the one with the latest start is the active attempt.
    func activeAttempt() -> QuitAttempt? {
        attempts.filter { $0.endedAtMs == nil }.max { $0.startedAtMs < $1.startedAtMs }
    }

    /// Attempts never overlap: a new start may equal the latest closed attempt's end (a restart
    /// opens exactly there) but not precede it, or slips, durations and goal money would count
    /// twice. `except` is the attempt being moved.
    func requireNotBeforeClosedAttempts(except id: String?, startMs: Int64) throws {
        let lastEnd = attempts.filter { $0.id != id }.compactMap(\.endedAtMs).max()
        if let lastEnd, startMs < lastEnd {
            throw SmokingError.invalidInput
        }
    }

    /// The attempt an entry at `atMs` joins when it is logged against this input.
    func attemptId(at atMs: Int64) -> String? {
        SalusSmoking.attemptId(at: atMs, in: attempts)
    }
}

func requireIntensity(_ intensity: Int?) throws {
    if let intensity, !(1 ... 5).contains(intensity) {
        throw SmokingError.invalidInput
    }
}

/// An ISO 4217 code, trimmed and upper-cased; anything else is invalid input.
func normalizedCurrency(_ code: String) throws -> String {
    let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard normalized.count == 3, normalized.unicodeScalars.allSatisfy({ ("A" ... "Z").contains($0) }) else {
        throw SmokingError.invalidInput
    }
    return normalized
}

/// A blank reason is no reason.
func normalizedReason(_ reason: String?) -> String? {
    let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
}

extension SalusClock {
    var smokingTodayEpochDay: Int64 {
        Int64(todayEpochDay())
    }
}

/// What a logging use case knows about the entry it is about to write.
struct EventDraft {
    let id: String
    let type: SmokingEventType
    let atMs: Int64
    let units: Int64?
    let trigger: CravingTrigger?
    let intensity: Int?
    let attemptId: String?
}

/// A new event in the clock's current zone. `epochDay` is computed here, once, from that zone
/// (contract §1) and never reinterpreted afterwards.
func newEvent(_ draft: EventDraft, clock: any SalusClock, plan: SmokingPlan) -> SmokingEvent {
    let zone = clock.timeZone()
    return SmokingEvent(
        id: draft.id,
        type: draft.type,
        occurredAtMs: draft.atMs,
        tzId: zone.identifier,
        epochDay: epochDay(of: draft.atMs, in: zone),
        units: draft.units,
        trigger: draft.trigger,
        intensity: draft.intensity,
        productType: plan.productType,
        attemptId: draft.attemptId
    )
}

extension SmokingWrites {
    /// Writes the events whose attempt link changes when the attempts become `attempts` (contract
    /// §3.3 and §8.1: the stored link is authoritative, so any write that moves a window or an
    /// instant re-derives it). `events` is the event list as it will be after the block, e.g. with
    /// one event edited or removed; it defaults to the rows as they are now.
    func rederiveEvents(attempts: [QuitAttempt], events: [SmokingEvent]? = nil) throws {
        let after = events ?? input.events
        for event in changedEvents(from: input.events, to: reattach(after, to: attempts)) {
            try updateEvent(event)
        }
    }
}
