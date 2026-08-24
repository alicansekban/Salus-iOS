// No Kotlin twin file: `takeIf { it.isNotBlank() }` is standard-library Kotlin, and this package
// asks for it in two layers — the detail ViewModel filters the profile's health notes, the detail
// screen filters the location, the doctor, the specialty and the appointment's notes. It lives
// beside `AppointmentFormatting` rather than in either of them so the two spellings cannot drift.
//
// Not extended onto `String`: an extension would be package API for a four-line need, and
// `isNotBlank` sitting next to `isEmpty` on every string in the feature is exactly the confusion
// the shared spelling is meant to prevent.

import Foundation

/// Kotlin's `takeIf { it.isNotBlank() }`.
///
/// `isBlank()` is "empty, or every character is whitespace" — line breaks included, which a
/// multi-line notes field produces, hence `.whitespacesAndNewlines` and not `.whitespaces`.
func nonBlank(_ text: String?) -> String? {
    guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return text
}
