// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// data/GlucoseEntryMapperTest.kt`.
//
// Three cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. The only
// wording change is `null` → `nil`; "entity" stays as Kotlin spells it, because the name is the
// drift detector and the iOS type it refers to (`VitalsMeasurementRecord`) is named in the body.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("GlucoseEntryMapper")
struct GlucoseEntryMapperTests {
    /// `GlucoseEntryMapperTest.kt:18` — 1_750_000_000_000 ms.
    private static let measuredAt = Date(epochMilliseconds: 1_750_000_000_000)
    /// `GlucoseEntryMapperTest.kt:19` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone

    /// `GlucoseEntryMapperTest.kt:16-23`.
    private static let entry = GlucoseEntry(
        id: "glucose-1",
        measuredAt: measuredAt,
        timeZone: zone,
        mgDl: 110.0,
        measurementContext: .fasting,
        note: "before breakfast"
    )

    /// `GlucoseEntryMapperTest.kt:25-40`.
    @Test("domain to entity stores canonical mg dL unit and context name")
    func domainToEntityStoresCanonicalMgDlUnitAndContextName() {
        let record = Self.entry.toRecord(profileId: "profile-1")

        #expect(record.id == "glucose-1")
        #expect(record.profileId == "profile-1")
        #expect(record.type == VitalType.bloodGlucose.rawValue)
        #expect(record.measuredAtEpochMs == 1_750_000_000_000)
        #expect(record.timeZoneId == "Europe/Istanbul")
        #expect(record.valuePrimary == 110.0)
        #expect(record.valueSecondary == nil)
        #expect(record.valueTertiary == nil)
        #expect(record.unit == glucoseStorageUnit)
        #expect(record.measurementContext == MeasurementContext.fasting.rawValue)
        #expect(record.note == "before breakfast")
    }

    /// `GlucoseEntryMapperTest.kt:42-47`.
    @Test("entity to domain round trip preserves all fields")
    func entityToDomainRoundTripPreservesAllFields() throws {
        let roundTrip = try Self.entry.toRecord(profileId: "profile-1").toGlucoseEntry()

        #expect(roundTrip == Self.entry)
    }

    /// `GlucoseEntryMapperTest.kt:49-56` — `null context and unknown stored context map to null`.
    /// A context this build does not know is read back as no context rather than as a failure: the
    /// reading itself is still a reading, and Kotlin's `firstOrNull { it.name == stored }` answers
    /// null for the same input.
    @Test("nil context and unknown stored context map to nil")
    func nilContextAndUnknownStoredContextMapToNil() throws {
        let withoutContext = GlucoseEntry(
            id: Self.entry.id,
            measuredAt: Self.entry.measuredAt,
            timeZone: Self.entry.timeZone,
            mgDl: Self.entry.mgDl,
            measurementContext: nil,
            note: nil
        )
        #expect(try withoutContext.toRecord(profileId: "profile-1").toGlucoseEntry() == withoutContext)

        let unknownContext = Self.record(measurementContext: "LEGACY_VALUE")

        #expect(try unknownContext.toGlucoseEntry().measurementContext == nil)
    }

    /// iOS-only, and deliberately not one of the three Kotlin cases: `TimeZone.of` throws on an
    /// identifier this platform cannot resolve (`GlucoseEntryMapper.kt:17`), and so does this —
    /// the branch `WeightEntryMapperTests` already pins for weight, restated because it is a *new*
    /// branch in a *new* mapper.
    @Test("an unresolvable stored time zone id throws")
    func anUnresolvableStoredTimeZoneIdThrows() {
        let record = Self.record(timeZoneId: "Mars/Olympus_Mons")

        #expect(throws: IllegalTimeZoneError.unknownTimeZone("Mars/Olympus_Mons")) {
            try record.toGlucoseEntry()
        }
    }

    /// The row `entry.toEntity(...)` produces, with the two columns the cases above vary.
    private static func record(
        measurementContext: String? = MeasurementContext.fasting.rawValue,
        timeZoneId: String = "Europe/Istanbul"
    ) -> VitalsMeasurementRecord {
        VitalsMeasurementRecord(
            id: "glucose-1",
            profileId: "profile-1",
            type: VitalType.bloodGlucose.rawValue,
            measuredAtEpochMs: 1_750_000_000_000,
            timeZoneId: timeZoneId,
            valuePrimary: 110.0,
            valueSecondary: nil,
            valueTertiary: nil,
            unit: glucoseStorageUnit,
            measurementContext: measurementContext,
            note: "before breakfast"
        )
    }
}
