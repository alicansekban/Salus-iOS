// No Kotlin twin file: Android builds the `geo:` URI inline in the screen
// (`AppointmentDetailScreen.kt:369-375`) and tests nothing about it, because the row only appears
// when an installed app resolves the intent. iOS always shows the row (divergence (a)), so the
// link it opens is the whole behaviour — and an unencoded space is the difference between Maps
// searching for the clinic and Maps not opening at all.

import Foundation
import Testing

@testable import FeatureAppointments

@Suite("MapsLink")
struct MapsLinkTests {
    /// `Uri.encode(location)` (`AppointmentDetailScreen.kt:372`) — the query is percent-encoded,
    /// including the non-ASCII a Turkish address is full of.
    @Test("the maps link percent-encodes the location it searches for")
    func theMapsLinkPercentEncodesTheLocationItSearchesFor() {
        #expect(mapsURL(for: "City Clinic, Room 204")?.absoluteString == "maps://?q=City%20Clinic,%20Room%20204")
        #expect(
            mapsURL(for: "Kadıköy Kliniği")?.absoluteString
                == "maps://?q=Kad%C4%B1k%C3%B6y%20Klini%C4%9Fi"
        )
    }
}
