// The twin of `Context.geoIntentOrNull` (`AppointmentDetailScreen.kt:369-375`), and the place
// divergence (a) lives.
//
// Android asks the package manager whether anything answers `geo:` and hides the button when
// nothing does. iOS has no equivalent question a sandboxed app may ask — `canOpenURL` needs the
// scheme declared in `LSApplicationQueriesSchemes` and answers for one scheme at a time — and Maps
// is not removable on iOS the way a calendar or maps app is on Android, so the row is always shown
// when the location is non-blank. The URL is therefore always built, and it is a `URL?` only
// because `URL(string:)` is.
//
// A separate file rather than a private helper in the screen: it is the one piece of that screen a
// test can actually assert on, and `@testable` does not reach a `private` function.

import Foundation

/// The Apple Maps search link for a free-text location (`AppointmentDetailScreen.kt:371-373`).
///
/// `maps://?q=…` is the twin of `geo:0,0?q=…`: no coordinates, just the text the map app searches
/// for.
func mapsURL(for location: String) -> URL? {
    guard let query = location.addingPercentEncoding(withAllowedCharacters: .salusUriEncodeAllowed) else {
        return nil
    }
    return URL(string: "maps://?q=" + query)
}

extension CharacterSet {
    /// What `Uri.encode(_:)` leaves alone: the unreserved characters of RFC 3986, and nothing else.
    ///
    /// **Not `.urlQueryAllowed`**, which is the set of characters legal *anywhere* in a query
    /// string rather than inside one of its values — it permits `& + = ? ; / ,`, so a clinic named
    /// "Smith & Sons" would end the `q` value at the ampersand and "A+ Poliklinik" would reach Maps
    /// as "A Poliklinik", the `+` read as a space. Percent-encoding a *value* has to be stricter
    /// than the syntax allows, which is exactly the line Android's `Uri.encode` draws.
    static let salusUriEncodeAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
}
