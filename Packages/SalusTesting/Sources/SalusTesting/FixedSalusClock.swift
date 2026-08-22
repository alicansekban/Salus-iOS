// The fixed clock every test in the tree injects, ported 1:1 from Android
// `core/testing/src/main/kotlin/com/alicansekban/salus/core/testing/FixedSalusClock.kt`.

import Foundation
import SalusCommon

/// A `SalusClock` that stays where it is put.
///
/// Ported from `FixedSalusClock.kt:9-25`. Kotlin's two `private var` constructor parameters are
/// stored properties here, and the class is `@unchecked Sendable` for one reason: `SalusClock` is
/// `Sendable`, and a clock that can be moved is mutable state. The lock is what makes the
/// unchecked promise true. An `actor` would satisfy the compiler without any of this, but it would
/// also make `now()` and `timeZone()` `async` — and they are the two calls the protocol declares
/// synchronous, because production code reads the time in the middle of a calculation.
public final class FixedSalusClock: SalusClock, @unchecked Sendable {
    /// `Europe/Istanbul`, the zone the Android fixture defaults to (`FixedSalusClock.kt:11`).
    ///
    /// The identifier lookup is failable and this package's sources carry no force unwrap
    /// (`CLAUDE.md`). Turkey has been on a permanent UTC+03 with no daylight saving since 2016,
    /// so the fallback carries the same offset and a host with an incomplete time-zone database
    /// still reads the fixture's instants correctly. `FixedSalusClockTests` pins the identifier,
    /// so the fallback cannot go unnoticed either.
    public static let defaultZone = TimeZone(identifier: "Europe/Istanbul")
        ?? TimeZone(secondsFromGMT: 3 * 60 * 60)
        ?? .gmt

    private let lock = NSLock()
    private var instant: Date
    private var zone: TimeZone

    public init(now: Date, timeZone: TimeZone = FixedSalusClock.defaultZone) {
        instant = now
        zone = timeZone
    }

    public func now() -> Date {
        lock.withLock { instant }
    }

    public func timeZone() -> TimeZone {
        lock.withLock { zone }
    }

    /// Moves the clock to `newInstant` (`FixedSalusClock.kt:18-20`).
    public func advanceTo(_ newInstant: Date) {
        lock.withLock { instant = newInstant }
    }

    /// Reads the same instant in `newZone` (`FixedSalusClock.kt:22-24`).
    public func moveToZone(_ newZone: TimeZone) {
        lock.withLock { zone = newZone }
    }
}
