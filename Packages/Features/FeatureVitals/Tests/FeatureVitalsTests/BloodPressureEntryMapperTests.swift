// Ported 1:1 from `feature/vitals/src/test/kotlin/com/alicansekban/salus/feature/vitals/
// data/BloodPressureEntryMapperTest.kt`.
//
// Four cases, in the Kotlin order, with the Kotlin inputs and the Kotlin expectations. The only
// wording change is `null` → `nil`; "entity" stays as Kotlin spells it, because the name is the
// drift detector and the iOS type it refers to (`VitalsMeasurementRecord`) is named in the body.

import Foundation
import SalusCommon
import SalusDatabase
import SalusModel
import SalusTesting
import Testing

@testable import FeatureVitals

@Suite("BloodPressureEntryMapper")
struct BloodPressureEntryMapperTests {
    /// `BloodPressureEntryMapperTest.kt:18` — 1_750_000_000_000 ms.
    private static let measuredAt = Date(epochMilliseconds: 1_750_000_000_000)
    /// `BloodPressureEntryMapperTest.kt:19` — `TimeZone.of("Europe/Istanbul")`.
    private static let zone = FixedSalusClock.defaultZone

    /// `BloodPressureEntryMapperTest.kt:16-24`.
    private static let entry = BloodPressureEntry(
        id: "bp-1",
        measuredAt: measuredAt,
        timeZone: zone,
        systolic: 120.0,
        diastolic: 80.0,
        pulse: 62.0,
        note: "after workout"
    )

    /// `BloodPressureEntryMapperTest.kt:26-41`.
    @Test("domain to entity maps type unit and value slots")
    func domainToEntityMapsTypeUnitAndValueSlots() {
        let record = Self.entry.toRecord(profileId: "profile-1")

        #expect(record.id == "bp-1")
        #expect(record.profileId == "profile-1")
        #expect(record.type == VitalType.bloodPressure.rawValue)
        #expect(record.measuredAtEpochMs == 1_750_000_000_000)
        #expect(record.timeZoneId == "Europe/Istanbul")
        #expect(record.valuePrimary == 120.0)
        #expect(record.valueSecondary == 80.0)
        #expect(record.valueTertiary == 62.0)
        #expect(record.unit == bloodPressureUnit)
        #expect(record.measurementContext == nil)
        #expect(record.note == "after workout")
    }

    /// `BloodPressureEntryMapperTest.kt:43-48`.
    @Test("entity to domain round trip preserves all fields")
    func entityToDomainRoundTripPreservesAllFields() throws {
        let roundTrip = try Self.entry.toRecord(profileId: "profile-1").toBloodPressureEntry()

        #expect(roundTrip == Self.entry)
    }

    /// `BloodPressureEntryMapperTest.kt:50-57` — `null pulse survives the round trip`.
    @Test("nil pulse survives the round trip")
    func nilPulseSurvivesTheRoundTrip() throws {
        let withoutPulse = BloodPressureEntry(
            id: Self.entry.id,
            measuredAt: Self.entry.measuredAt,
            timeZone: Self.entry.timeZone,
            systolic: Self.entry.systolic,
            diastolic: Self.entry.diastolic,
            pulse: nil,
            note: nil
        )

        let roundTrip = try withoutPulse.toRecord(profileId: "profile-1").toBloodPressureEntry()

        #expect(roundTrip == withoutPulse)
    }

    /// `BloodPressureEntryMapperTest.kt:59-76` — `valueSecondary ?: MISSING_DIASTOLIC`. The DAO
    /// always writes a secondary value for this type; the fallback is what keeps the mapper total.
    @Test("missing secondary value falls back to zero diastolic")
    func missingSecondaryValueFallsBackToZeroDiastolic() throws {
        let record = Self.record(valueSecondary: nil)

        #expect(try record.toBloodPressureEntry().diastolic == 0.0)
    }

    /// iOS-only, and deliberately not one of the four Kotlin cases: `TimeZone.of` throws on an
    /// identifier this platform cannot resolve (`BloodPressureEntryMapper.kt:18`), and so does
    /// this — the branch `WeightEntryMapperTests` already pins for weight, restated because it is
    /// a *new* branch in a *new* mapper. Substituting a zone silently would move a reading to
    /// another hour of the day with nothing to show for it.
    @Test("an unresolvable stored time zone id throws")
    func anUnresolvableStoredTimeZoneIdThrows() {
        let record = Self.record(timeZoneId: "Mars/Olympus_Mons")

        #expect(throws: IllegalTimeZoneError.unknownTimeZone("Mars/Olympus_Mons")) {
            try record.toBloodPressureEntry()
        }
    }

    /// `BloodPressureEntryMapperTest.kt:61-73`, with the two columns the cases above vary.
    private static func record(
        valueSecondary: Double? = 80.0,
        timeZoneId: String = "Europe/Istanbul"
    ) -> VitalsMeasurementRecord {
        VitalsMeasurementRecord(
            id: "bp-2",
            profileId: "profile-1",
            type: VitalType.bloodPressure.rawValue,
            measuredAtEpochMs: 1_750_000_000_000,
            timeZoneId: timeZoneId,
            valuePrimary: 120.0,
            valueSecondary: valueSecondary,
            valueTertiary: nil,
            unit: bloodPressureUnit,
            measurementContext: nil,
            note: nil
        )
    }
}
