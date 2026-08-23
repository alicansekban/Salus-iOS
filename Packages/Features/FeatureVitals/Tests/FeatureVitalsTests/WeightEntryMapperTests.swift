// Covers `data/WeightEntryMapper.swift`, the port of
// `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/data/WeightEntryMapper.kt`.
//
// There is no Android twin for this table today (tracked as spec §11 A8, so Android gets the same
// one). It exists here because the mapper is the only place a stored row becomes a domain entry:
// the `WEIGHT` discriminator, the `kg` unit and the three columns weight leaves empty are all
// decided here, and every one of them is read back by the other platform out of a backup archive.
// A round trip plus a pin on those constants is what stops a rename from becoming a silent
// cross-platform mismatch.

import Foundation
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("WeightEntryMapper")
struct WeightEntryMapperTests {
    private static let measuredAtEpochMs: Int64 = 1_750_000_000_123
    private static let zone = FixedSalusClock.defaultZone

    /// `WeightEntryMapper.kt:13-19`.
    @Test("a record becomes the domain entry, column for column")
    func aRecordBecomesTheDomainEntry() {
        let entry = Self.record(note: "after breakfast").toWeightEntry()

        #expect(entry.id == "w1")
        #expect(entry.measuredAt == Date(epochMilliseconds: Self.measuredAtEpochMs))
        #expect(entry.timeZone == Self.zone)
        #expect(entry.kilograms == 82.5)
        #expect(entry.note == "after breakfast")
    }

    /// `WeightEntryMapper.kt:10` and `:22-33` — the two constants the other platform reads back,
    /// plus the three columns a weight row leaves empty.
    @Test("an entry becomes a WEIGHT row measured in kg, with the other value columns empty")
    func anEntryBecomesAWeightRowMeasuredInKilograms() {
        let record = Self.entry(note: "after breakfast").toRecord(profileId: "profile-1")

        #expect(record.type == "WEIGHT")
        #expect(record.type == VitalType.weight.rawValue)
        #expect(record.unit == "kg")
        #expect(record.profileId == "profile-1")
        #expect(record.valuePrimary == 82.5)
        #expect(record.valueSecondary == nil)
        #expect(record.valueTertiary == nil)
        #expect(record.measurementContext == nil)
        #expect(record.timeZoneId == Self.zone.identifier)
        #expect(record.measuredAtEpochMs == Self.measuredAtEpochMs)
    }

    /// The whole point of a mapper pair: neither direction may lose anything. The millisecond
    /// value deliberately ends in `123` rather than in three zeros, so the sub-second part is
    /// carried by the `Double` a `Date` holds and not by an integer that happens to survive.
    @Test("record → entry → record round trips")
    func recordToEntryToRecordRoundTrips() {
        let original = Self.record(note: "after breakfast")

        let mapped = original.toWeightEntry().toRecord(profileId: original.profileId)

        #expect(mapped == original)
    }

    /// The other direction of the same round trip, including the note-less row.
    @Test("entry → record → entry round trips, with and without a note")
    func entryToRecordToEntryRoundTrips() {
        let notes: [String?] = ["after breakfast", nil]
        for note in notes {
            let original = Self.entry(note: note)

            let mapped = original.toRecord(profileId: "profile-1").toWeightEntry()

            #expect(mapped == original)
        }
    }

    /// A stored identifier Foundation cannot resolve — a zone retired from the database, or one
    /// written by an Android build with a newer tzdb. Kotlin's `TimeZone.of` throws here; the port
    /// degrades to GMT instead, the way `ProfileMappers` degrades an unknown `sex` to nil, so one
    /// unreadable row cannot take the history list down with it.
    @Test("an unresolvable stored time zone id degrades to GMT")
    func anUnresolvableStoredTimeZoneIdDegradesToGmt() {
        let entry = Self.record(note: nil, timeZoneId: "Mars/Olympus_Mons").toWeightEntry()

        #expect(entry.timeZone == .gmt)
    }

    private static func record(note: String?, timeZoneId: String? = nil) -> VitalsMeasurementRecord {
        VitalsMeasurementRecord(
            id: "w1",
            profileId: "profile-1",
            type: VitalType.weight.rawValue,
            measuredAtEpochMs: measuredAtEpochMs,
            timeZoneId: timeZoneId ?? zone.identifier,
            valuePrimary: 82.5,
            valueSecondary: nil,
            valueTertiary: nil,
            unit: "kg",
            measurementContext: nil,
            note: note
        )
    }

    private static func entry(note: String?) -> WeightEntry {
        WeightEntry(
            id: "w1",
            measuredAt: Date(epochMilliseconds: measuredAtEpochMs),
            timeZone: zone,
            kilograms: 82.5,
            note: note
        )
    }
}
