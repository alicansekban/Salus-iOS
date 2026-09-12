import Foundation
import SalusTesting
import Testing

@testable import FeatureAppointments

/// The twin of Android's `feature/appointments/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: all 54 keys and
/// both of their translations are pinned here, copied from the XML.
///
/// Two of the keys — `appointments_ok` and `appointments_cancel` — are carried even though no
/// Android code reads them. Key-set parity is what makes this table a drift detector: a key that
/// exists on one platform and not the other is exactly the difference worth failing on, and
/// dropping the unread ones — which Android's XML does declare — would make the two module
/// surfaces disagree by design. `appointments_upcoming_header` was a third such carry until
/// iOS-M16 Task 14 deleted it: Android never declared it, so it was iOS-only weight.
///
/// `appointment_detail_relative_in_days` and its `_one` twin are the one deliberate shape
/// difference: Android ships that `<plurals>` as a single resource, and this port splits it into
/// two keys with the count-selected variant (spec §9 (h), the M14 (e) precedent). Both keys are
/// pinned here and their rendered forms in `formatKeysRenderTheAndroidSentence`.
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `AppointmentsStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all,
/// so a resolved string here would only ever be the key back. The end-to-end check is the
/// simulator run.
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the values themselves, Android's own.
@Suite("FeatureAppointments strings")
struct AppointmentsStringsTests {
    /// Every key `:feature:appointments` owns, with both translations, copied from the XML. A new
    /// key there means a new row here, in the same commit — that is the whole job of this table.
    static let samples: [AppointmentStringSample] = [
        AppointmentStringSample(key: "appointments_title", turkish: "Randevular", english: "Appointments"),
        AppointmentStringSample(
            key: "appointments_empty",
            turkish: "Henüz randevu yok. İlk randevunu ekle.",
            english: "No appointments yet. Add your first appointment."
        ),
        AppointmentStringSample(
            key: "appointments_no_upcoming",
            turkish: "Yaklaşan randevu yok.",
            english: "No upcoming appointments."
        ),
        AppointmentStringSample(
            key: "appointments_no_past",
            turkish: "Geçmiş randevu yok.",
            english: "No past appointments."
        ),
        AppointmentStringSample(key: "appointments_new", turkish: "Yeni Randevu Oluştur", english: "New Appointment"),
        AppointmentStringSample(
            key: "appointments_tab_upcoming",
            turkish: "Yaklaşan (%1$lld)",
            english: "Upcoming (%1$lld)"
        ),
        AppointmentStringSample(key: "appointments_tab_past", turkish: "Geçmiş (%1$lld)", english: "Past (%1$lld)"),
        AppointmentStringSample(key: "appointments_new_title", turkish: "Yeni randevu", english: "New appointment"),
        AppointmentStringSample(
            key: "appointments_edit_title",
            turkish: "Randevuyu düzenle",
            english: "Edit appointment"
        ),
        AppointmentStringSample(key: "appointments_title_label", turkish: "Başlık", english: "Title"),
        AppointmentStringSample(
            key: "appointments_title_placeholder",
            turkish: "Örn. Kardiyoloji kontrolü",
            english: "e.g. Cardiology check-up"
        ),
        AppointmentStringSample(
            key: "appointments_doctor_label",
            turkish: "Doktor veya klinik (isteğe bağlı)",
            english: "Doctor or clinic (optional)"
        ),
        AppointmentStringSample(
            key: "appointments_doctor_placeholder",
            turkish: "Örn. Dr. Ayşe Yılmaz",
            english: "e.g. Dr. Jane Smith"
        ),
        AppointmentStringSample(
            key: "appointments_location_label",
            turkish: "Konum (isteğe bağlı)",
            english: "Location (optional)"
        ),
        AppointmentStringSample(
            key: "appointments_location_placeholder",
            turkish: "Örn. Şehir Kliniği, Oda 204",
            english: "e.g. City Clinic, Room 204"
        ),
        AppointmentStringSample(
            key: "appointments_notes_label",
            turkish: "Notlar (isteğe bağlı)",
            english: "Notes (optional)"
        ),
        AppointmentStringSample(
            key: "appointments_notes_placeholder",
            turkish: "Sormak istediklerin",
            english: "What you want to ask"
        ),
        AppointmentStringSample(key: "appointments_datetime_label", turkish: "TARİH VE SAAT", english: "DATE AND TIME"),
        AppointmentStringSample(key: "appointments_select_date", turkish: "Tarih seç", english: "Select date"),
        AppointmentStringSample(key: "appointments_select_time", turkish: "Saat seç", english: "Select time"),
        AppointmentStringSample(key: "appointments_reminders_label", turkish: "HATIRLATICILAR", english: "REMINDERS"),
        AppointmentStringSample(key: "appointments_offset_hour", turkish: "1 saat önce", english: "1 hour before"),
        AppointmentStringSample(key: "appointments_offset_day", turkish: "1 gün önce", english: "1 day before"),
        AppointmentStringSample(key: "appointments_offset_week", turkish: "1 hafta önce", english: "1 week before"),
        AppointmentStringSample(
            key: "appointments_missing_title",
            turkish: "Bir başlık gir.",
            english: "Enter a title."
        ),
        AppointmentStringSample(
            key: "appointments_missing_datetime",
            turkish: "Tarih ve saat seç.",
            english: "Select a date and time."
        ),
        AppointmentStringSample(
            key: "appointments_add_to_calendar",
            turkish: "Takvime Ekle",
            english: "Add to Calendar"
        ),
        AppointmentStringSample(key: "appointments_save", turkish: "Kaydet", english: "Save"),
        AppointmentStringSample(key: "appointments_delete", turkish: "Sil", english: "Delete"),
        AppointmentStringSample(key: "appointments_ok", turkish: "Tamam", english: "OK"),
        AppointmentStringSample(key: "appointments_cancel", turkish: "İptal", english: "Cancel"),
        AppointmentStringSample(
            key: "appointments_notification_title",
            turkish: "Randevu: %1$@",
            english: "Appointment: %1$@"
        ),
        AppointmentStringSample(
            key: "appointments_detail_tell_doctor",
            turkish: "Doktora söylenecekler",
            english: "What to tell the doctor"
        ),
        AppointmentStringSample(
            key: "appointment_detail_title",
            turkish: "Randevu detayı",
            english: "Appointment detail"
        ),
        AppointmentStringSample(
            key: "appointment_detail_missing",
            turkish: "Bu randevu artık kayıtlı değil.",
            english: "This appointment is no longer saved."
        ),
        AppointmentStringSample(key: "appointment_detail_section_details", turkish: "DETAYLAR", english: "DETAILS"),
        AppointmentStringSample(key: "appointment_detail_notes", turkish: "NOTLAR", english: "NOTES"),
        AppointmentStringSample(key: "appointment_detail_edit", turkish: "Düzenle", english: "Edit"),
        AppointmentStringSample(key: "appointment_detail_delete", turkish: "Sil", english: "Delete"),
        AppointmentStringSample(
            key: "appointment_detail_open_maps",
            turkish: "Haritalarda aç",
            english: "Open in Maps"
        ),
        AppointmentStringSample(
            key: "appointment_detail_add_doctor",
            turkish: "Doktor adı ekle",
            english: "Add doctor name"
        ),
        AppointmentStringSample(key: "appointment_detail_add_location", turkish: "Konum ekle", english: "Add location"),
        AppointmentStringSample(
            key: "appointment_detail_add_reminder",
            turkish: "Hatırlatıcı ekle",
            english: "Add reminder"
        ),
        AppointmentStringSample(key: "appointment_detail_add_note", turkish: "Not ekle", english: "Add note"),
        AppointmentStringSample(key: "appointment_detail_relative_today", turkish: "Bugün", english: "Today"),
        AppointmentStringSample(key: "appointment_detail_relative_tomorrow", turkish: "Yarın", english: "Tomorrow"),
        AppointmentStringSample(key: "appointment_detail_relative_past", turkish: "Geçti", english: "Past"),
        AppointmentStringSample(
            key: "appointment_detail_relative_in_days",
            turkish: "%1$lld gün sonra",
            english: "In %1$lld days"
        ),
        AppointmentStringSample(
            key: "appointment_detail_relative_in_days_one",
            turkish: "%1$lld gün sonra",
            english: "In %1$lld day"
        ),
        AppointmentStringSample(key: "appointments_day_today", turkish: "BUGÜN", english: "TODAY"),
        AppointmentStringSample(key: "appointments_day_tomorrow", turkish: "YARIN", english: "TOMORROW"),
        AppointmentStringSample(key: "appointment_delete_title", turkish: "%1$@ silinsin mi?", english: "Delete %1$@?"),
        AppointmentStringSample(
            key: "appointment_delete_message",
            turkish: "Randevu ve hatırlatıcıları birlikte silinir.",
            english: "The appointment and its reminders are removed together."
        ),
        AppointmentStringSample(key: "appointment_deleted", turkish: "Randevu silindi", english: "Appointment deleted")
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 54 keys :feature:appointments owns")
    func catalogHoldsExactlyTheFiftyFourKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 54)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values match res/values*/strings.xml",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: AppointmentStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `AppointmentsStrings.Key`'s raw values does not fail to compile — it
        // ships the key itself as the label. This is the check that catches it.
        #expect(Set(AppointmentsStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the format keys carry Swift specifiers and render the Android sentence")
    func formatKeysRenderTheAndroidSentence() throws {
        let catalog = try Self.loadCatalog()

        // Android's `%1$s`/`%1$d` are Java specifiers. `%s` reads a C string pointer under
        // `String(format:)` and `%d` reads 32 bits of a 64-bit Swift `Int`, so the catalog carries
        // `%1$@`/`%1$lld` instead — see the mapping table in `AppointmentsStrings.swift`. The
        // sentence around them is unchanged, and these are the assertions that say so.
        try #expect(Self.render("appointments_tab_upcoming", "tr", 3) == "Yaklaşan (3)")
        try #expect(Self.render("appointments_tab_upcoming", "en", 3) == "Upcoming (3)")
        try #expect(Self.render("appointments_tab_past", "tr", 2) == "Geçmiş (2)")
        try #expect(Self.render("appointments_tab_past", "en", 2) == "Past (2)")
        try #expect(Self.render("appointments_notification_title", "tr", "Kardiyoloji") == "Randevu: Kardiyoloji")
        try #expect(Self.render("appointments_notification_title", "en", "Cardiology") == "Appointment: Cardiology")
        try #expect(Self.render("appointment_delete_title", "tr", "Kardiyoloji") == "Kardiyoloji silinsin mi?")
        try #expect(Self.render("appointment_delete_title", "en", "Cardiology") == "Delete Cardiology?")

        // The plural pair: English distinguishes one day from several (spec §9 (h)).
        try #expect(Self.render("appointment_detail_relative_in_days", "en", 5) == "In 5 days")
        try #expect(Self.render("appointment_detail_relative_in_days_one", "en", 1) == "In 1 day")
        // Turkish has a single form, so both keys render it.
        try #expect(Self.render("appointment_detail_relative_in_days", "tr", 5) == "5 gün sonra")
        try #expect(Self.render("appointment_detail_relative_in_days_one", "tr", 1) == "1 gün sonra")

        for key in ["appointments_notification_title", "appointment_delete_title"] {
            try #expect(#require(catalog.value(of: key, in: "tr")).contains("%1$@"))
            try #expect(#require(catalog.value(of: key, in: "en")).contains("%1$@"))
        }
        for key in [
            "appointments_tab_upcoming",
            "appointments_tab_past",
            "appointment_detail_relative_in_days",
            "appointment_detail_relative_in_days_one"
        ] {
            for locale in ["tr", "en"] {
                try #expect(#require(catalog.value(of: key, in: locale)).contains("%1$lld"))
            }
        }
    }

    @Test("the catalog names nothing on the banned health-claims list")
    func theCatalogNamesNothingBanned() throws {
        // Repository-wide coverage already exists in `SalusTestingTests.BannedHealthClaimsTests`.
        // This narrower run points at this package's own catalog so the feature that introduces a
        // banned word fails in its own suite, where whoever wrote the string is already looking.
        try BannedHealthClaims.assertCatalogsNameNothingBanned(paths: [Self.catalogURL])
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // FeatureAppointmentsTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // FeatureAppointments
        .appendingPathComponent("Sources/FeatureAppointments/Resources/Localizable.xcstrings")

    static func loadCatalog() throws -> StringCatalog {
        try StringCatalogParity.load(at: catalogURL)
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct AppointmentStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
