// No Kotlin twin file: Android builds the `geo:` URI inline in the screen
// (`AppointmentDetailScreen.kt:369-375`) and tests nothing about it, because the row only appears
// when an installed app resolves the intent. iOS always shows the row (divergence (a)), so the
// link it opens is the whole behaviour — and one unencoded character is the difference between
// Maps searching for the clinic and Maps searching for half of its name.

import Foundation
import Testing

@testable import FeatureAppointments

@Suite("MapsLink")
struct MapsLinkTests {
    /// `Uri.encode(location)` (`AppointmentDetailScreen.kt:372`) — everything outside RFC 3986's
    /// unreserved set is percent-encoded, the non-ASCII a Turkish address is full of included.
    @Test("the maps link percent-encodes the location it searches for")
    func theMapsLinkPercentEncodesTheLocationItSearchesFor() {
        #expect(mapsURL(for: "City Clinic, Room 204")?.absoluteString == "maps://?q=City%20Clinic%2C%20Room%20204")
        #expect(
            mapsURL(for: "Kadıköy Kliniği")?.absoluteString
                == "maps://?q=Kad%C4%B1k%C3%B6y%20Klini%C4%9Fi"
        )
    }

    /// The two characters `.urlQueryAllowed` would have let through: `&` ends the `q` value, and a
    /// literal `+` is read back as a space.
    @Test("the maps link encodes the query separators a clinic name can contain")
    func theMapsLinkEncodesTheQuerySeparatorsAClinicNameCanContain() {
        #expect(mapsURL(for: "Smith & Sons Clinic")?.absoluteString == "maps://?q=Smith%20%26%20Sons%20Clinic")
        #expect(mapsURL(for: "A+ Poliklinik")?.absoluteString == "maps://?q=A%2B%20Poliklinik")
    }
}
