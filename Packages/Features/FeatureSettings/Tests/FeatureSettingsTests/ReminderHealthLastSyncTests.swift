// No Android twin: WorkManager keeps its own run history and Android's Reminder Health reads the
// last successful run out of it, so there is no Kotlin formatter to port. This is the iOS side of
// `ReminderSyncStateStore` — the stamp turned into the line the screen draws.

import Foundation
import SalusTesting
import Testing

@testable import FeatureSettings

@Suite("ReminderHealthLastSync")
struct ReminderHealthLastSyncTests {
    /// 2025-08-12T12:00:00Z.
    private static let instant = Date(timeIntervalSince1970: 1_755_000_000)

    /// `en_US_POSIX` so the month name and the digit shapes do not depend on where the test ran;
    /// production passes `Locale.current`, which is what Android's `Locale.getDefault()` is.
    private static let locale = Locale(identifier: "en_US_POSIX")

    @Test("the stamp is read in the clock's zone, not the host's")
    func theStampIsReadInTheClocksZone() throws {
        let istanbul = FixedSalusClock.defaultZone
        let utc = TimeZone.gmt
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))

        #expect(
            ReminderHealthLastSync.timestamp(Self.instant, in: istanbul, locale: Self.locale)
                == "12 Aug 2025 15:00"
        )
        #expect(
            ReminderHealthLastSync.timestamp(Self.instant, in: utc, locale: Self.locale)
                == "12 Aug 2025 12:00"
        )
        #expect(
            ReminderHealthLastSync.timestamp(Self.instant, in: losAngeles, locale: Self.locale)
                == "12 Aug 2025 05:00"
        )
    }

    /// The pattern is fixed rather than templated, exactly as every other formatter in this port:
    /// `setLocalizedDateFormatFromTemplate` reorders the components per region, which would make
    /// the two platforms draw different lines from the same instant.
    @Test("the pattern does not reorder itself per region")
    func thePatternDoesNotReorderItselfPerRegion() {
        let zone = FixedSalusClock.defaultZone
        let american = Locale(identifier: "en_US")
        let turkish = Locale(identifier: "tr_TR")

        // Day-first in both, where a templated pattern would produce "Aug 12" for `en_US`.
        #expect(
            ReminderHealthLastSync.timestamp(Self.instant, in: zone, locale: american)
                .hasPrefix("12 ")
        )
        #expect(
            ReminderHealthLastSync.timestamp(Self.instant, in: zone, locale: turkish)
                .hasPrefix("12 ")
        )
    }

    /// An install where the engine has never completed a pass says so, rather than reading 1970.
    ///
    /// Both branches are asserted against the accessor rather than against a sentence: a
    /// `.xcstrings` is not compiled by `swift test`, so `SettingsStrings` answers the key here. The
    /// sentences themselves are pinned in `SettingsStringsTests`.
    @Test("a never-synced install gets the never-synced line, not a 1970 timestamp")
    func aNeverSyncedInstallGetsTheNeverSyncedLine() {
        let line = ReminderHealthLastSync.line(for: nil, in: .gmt, locale: Self.locale)

        #expect(line == SettingsStrings.reminderHealthNeverSynced)
        #expect(!line.contains("1970"))
    }

    @Test("a stamped install gets the last-pass line around its timestamp")
    func aStampedInstallGetsTheLastPassLine() {
        let timestamp = ReminderHealthLastSync.timestamp(Self.instant, in: .gmt, locale: Self.locale)
        let line = ReminderHealthLastSync.line(for: Self.instant, in: .gmt, locale: Self.locale)

        #expect(line == SettingsStrings.reminderHealthLastSync(timestamp))
    }
}
