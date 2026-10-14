// Twin of `core/smoking/.../repository/AttemptMembership.kt`: which attempt a logged event belongs
// to, as the use cases store it (contract §3.3, §6, §8.1, §8.10). The calculator trusts the stored
// `attemptId`, so every write that can change membership recomputes it here.

import Foundation
import SalusCommon

/// The attempt whose window holds `atMs`, or nil when none does (a back-dated entry before the
/// start is not a slip).
///
/// The end of a closed attempt is **inclusive**: the entry that restarted it is stored at exactly
/// its `endedAtMs`, which is also the next attempt's start, and it must stay on the attempt it
/// ended (§8.1). On such a tie the earlier attempt wins.
func attemptId(at atMs: Int64, in attempts: [QuitAttempt]) -> String? {
    attempts
        .filter { atMs >= $0.startedAtMs && ($0.endedAtMs.map { atMs <= $0 } ?? true) }
        .min { $0.startedAtMs < $1.startedAtMs }?
        .id
}

/// `events` with `attemptId` recomputed against `attempts`. A "none today" marker (`units == 0`)
/// never belongs to an attempt: it is not a slip.
func reattach(_ events: [SmokingEvent], to attempts: [QuitAttempt]) -> [SmokingEvent] {
    events.map { event in
        let wanted = event.units == 0 ? nil : attemptId(at: event.occurredAtMs, in: attempts)
        return wanted == event.attemptId ? event : event.withAttemptId(wanted)
    }
}

/// The events whose stored form differs between `before` and `after`, matched by id.
func changedEvents(from before: [SmokingEvent], to after: [SmokingEvent]) -> [SmokingEvent] {
    let old = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    return after.filter { old[$0.id] != $0 }
}

/// The local calendar day of `atMs` in `tzId`; an event's `epochDay` is computed once, with this.
/// Nil for a zone identifier this device does not know.
func eventEpochDay(atMs: Int64, tzId: String) -> Int64? {
    TimeZone(identifier: tzId).map { epochDay(of: atMs, in: $0) }
}
