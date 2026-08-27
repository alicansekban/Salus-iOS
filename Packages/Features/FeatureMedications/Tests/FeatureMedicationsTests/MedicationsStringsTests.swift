import Foundation
import SalusTesting
import Testing

@testable import FeatureMedications

/// The twin of Android's `feature/medications/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: all 86 keys and
/// both of their translations are pinned here, copied from the XML — apart from the one recorded
/// divergence, `medications_recorded_doses`, whose row below carries the reason it differs.
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `MedicationsStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all,
/// so a resolved string here would only ever be the key back. The end-to-end check is the
/// simulator run.
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the values themselves, Android's own apart from the
/// one recorded divergence.
@Suite("FeatureMedications strings")
struct MedicationsStringsTests {
    /// Every key `:feature:medications` owns, with both translations, copied from the XML. A new
    /// key there means a new row here, in the same commit — that is the whole job of this table.
    /// The rows follow the XML's order, grouped by the screen that reads them.
    static let samples: [MedicationStringSample] = [
        // The list screen (7).
        MedicationStringSample(key: "medications_title", turkish: "İlaçlar", english: "Medications"),
        MedicationStringSample(key: "medications_add", turkish: "İlaç ekle", english: "Add medication"),
        MedicationStringSample(
            key: "medications_empty_title",
            turkish: "Henüz ilaç yok",
            english: "No medications yet"
        ),
        MedicationStringSample(
            key: "medications_empty_body",
            turkish: "Doz hatırlatıcıları almak ve kullanımını takip etmek için bir ilaç ekle.",
            english: "Add a medication to get dose reminders and track your intake."
        ),
        // THE ONE ROW THAT IS NOT ANDROID-VERBATIM, key and copy alike, and the reason is
        // recorded here on purpose. Android names this key and this sentence after a word on
        // `BannedHealthClaims.stems` (CLAUDE.md, "Copy and localisation rules"): no `MISSED` dose
        // row is ever written, so the seven-day figure describes the doses that WERE recorded and
        // nothing more. Naming it otherwise turns a fact about records into a claim about someone's
        // treatment. The replacement says exactly what the number is. Android owes the mirror edit;
        // until it lands this row is a recorded, deliberate divergence, and restoring the Android
        // key here turns the repo-wide scan red.
        MedicationStringSample(
            key: "medications_recorded_doses",
            turkish: "Son 7 gün kaydedilen doz %%%1$lld",
            english: "Recorded doses, last 7 days: %1$lld%%"
        ),
        MedicationStringSample(
            key: "medications_low_stock",
            turkish: "Stok azaldı: %1$@ kaldı",
            english: "Low stock: %1$@ left"
        ),
        MedicationStringSample(key: "medications_no_schedule", turkish: "Plan yok", english: "No schedule"),
        // The editor (29).
        MedicationStringSample(key: "editor_title_new", turkish: "Yeni ilaç", english: "New medication"),
        MedicationStringSample(key: "editor_title_edit", turkish: "İlacı düzenle", english: "Edit medication"),
        MedicationStringSample(key: "editor_back", turkish: "Geri", english: "Back"),
        MedicationStringSample(key: "editor_save", turkish: "Kaydet", english: "Save"),
        MedicationStringSample(key: "editor_delete", turkish: "Sil", english: "Delete"),
        MedicationStringSample(key: "editor_name", turkish: "Ad", english: "Name"),
        MedicationStringSample(key: "editor_form", turkish: "Form", english: "Form"),
        MedicationStringSample(key: "editor_strength", turkish: "Doz gücü", english: "Strength"),
        MedicationStringSample(key: "editor_strength_unit", turkish: "Birim (örn. mg)", english: "Unit (e.g. mg)"),
        MedicationStringSample(
            key: "editor_instructions",
            turkish: "Talimatlar (örn. yemeklerden sonra)",
            english: "Instructions (e.g. after meals)"
        ),
        MedicationStringSample(key: "editor_stock", turkish: "Stok adedi", english: "Stock count"),
        MedicationStringSample(
            key: "editor_stock_threshold",
            turkish: "Stok uyarı eşiği",
            english: "Low stock alert at"
        ),
        MedicationStringSample(key: "editor_start_date", turkish: "%1$@ tarihinden itibaren", english: "From %1$@"),
        MedicationStringSample(key: "editor_end_date", turkish: "%1$@ tarihine kadar", english: "Until %1$@"),
        MedicationStringSample(key: "editor_no_end_date", turkish: "Bitiş tarihi yok", english: "No end date"),
        MedicationStringSample(
            key: "editor_clear_end_date",
            turkish: "Bitiş tarihini kaldır",
            english: "Clear end date"
        ),
        MedicationStringSample(key: "editor_schedule_section", turkish: "Plan", english: "Schedule"),
        MedicationStringSample(key: "editor_times_section", turkish: "Doz saatleri", english: "Dose times"),
        MedicationStringSample(key: "editor_interval_days", turkish: "Kaç günde bir", english: "Every N days"),
        MedicationStringSample(key: "editor_dose_amount", turkish: "Miktar", english: "Amount"),
        MedicationStringSample(key: "editor_add_time", turkish: "Saat ekle", english: "Add time"),
        MedicationStringSample(key: "editor_remove_time", turkish: "Saati kaldır", english: "Remove time"),
        MedicationStringSample(key: "editor_confirm", turkish: "Tamam", english: "OK"),
        MedicationStringSample(key: "editor_cancel", turkish: "İptal", english: "Cancel"),
        MedicationStringSample(
            key: "editor_error_empty_name",
            turkish: "Lütfen bir ad gir.",
            english: "Please enter a name."
        ),
        MedicationStringSample(
            key: "editor_error_no_times",
            turkish: "En az bir doz saati ekle.",
            english: "Add at least one dose time."
        ),
        MedicationStringSample(
            key: "editor_error_invalid_interval",
            turkish: "Gün aralığı en az 1 olmalı.",
            english: "The day interval must be at least 1."
        ),
        MedicationStringSample(
            key: "editor_error_no_days",
            turkish: "Haftanın en az bir gününü seç.",
            english: "Select at least one day of the week."
        ),
        MedicationStringSample(
            key: "editor_error_end_before_start",
            turkish: "Bitiş tarihi başlangıç tarihinden önce.",
            english: "The end date is before the start date."
        ),
        // The dosage forms (8).
        MedicationStringSample(key: "form_tablet", turkish: "Tablet", english: "Tablet"),
        MedicationStringSample(key: "form_capsule", turkish: "Kapsül", english: "Capsule"),
        MedicationStringSample(key: "form_syrup", turkish: "Şurup", english: "Syrup"),
        MedicationStringSample(key: "form_injection", turkish: "Enjeksiyon", english: "Injection"),
        MedicationStringSample(key: "form_drop", turkish: "Damla", english: "Drops"),
        MedicationStringSample(key: "form_inhaler", turkish: "İnhaler", english: "Inhaler"),
        MedicationStringSample(key: "form_cream", turkish: "Krem", english: "Cream"),
        MedicationStringSample(key: "form_other", turkish: "Diğer", english: "Other"),
        // The recurrence kinds (5).
        MedicationStringSample(key: "recurrence_daily", turkish: "Her gün", english: "Every day"),
        MedicationStringSample(key: "recurrence_days_of_week", turkish: "Haftanın günleri", english: "Days of week"),
        MedicationStringSample(key: "recurrence_interval", turkish: "Gün aralıklı", english: "Every N days"),
        MedicationStringSample(
            key: "recurrence_every_n_days",
            turkish: "%1$lld günde bir",
            english: "Every %1$lld days"
        ),
        MedicationStringSample(key: "recurrence_as_needed", turkish: "Gerektiğinde", english: "As needed"),
        // The weekday abbreviations (7).
        MedicationStringSample(key: "day_mon", turkish: "Pzt", english: "Mon"),
        MedicationStringSample(key: "day_tue", turkish: "Sal", english: "Tue"),
        MedicationStringSample(key: "day_wed", turkish: "Çar", english: "Wed"),
        MedicationStringSample(key: "day_thu", turkish: "Per", english: "Thu"),
        MedicationStringSample(key: "day_fri", turkish: "Cum", english: "Fri"),
        MedicationStringSample(key: "day_sat", turkish: "Cmt", english: "Sat"),
        MedicationStringSample(key: "day_sun", turkish: "Paz", english: "Sun"),
        // The dose notification (5).
        MedicationStringSample(key: "notification_dose_title", turkish: "%1$@ zamanı", english: "Time for %1$@"),
        MedicationStringSample(key: "notification_dose_text", turkish: "%1$@ × %2$@ al", english: "Take %1$@ × %2$@"),
        MedicationStringSample(
            key: "notification_dose_text_plain",
            turkish: "%1$@ doz al",
            english: "Take %1$@ dose(s)"
        ),
        MedicationStringSample(key: "notification_action_taken", turkish: "İçtim", english: "Taken"),
        MedicationStringSample(key: "notification_action_snooze", turkish: "10 dk ertele", english: "Snooze 10 min"),
        // The detail screen (13).
        MedicationStringSample(key: "medication_detail_title", turkish: "İlaç detayı", english: "Medication detail"),
        MedicationStringSample(
            key: "medication_detail_missing",
            turkish: "Bu ilaç artık kayıtlı değil.",
            english: "This medication is no longer saved."
        ),
        MedicationStringSample(key: "medication_detail_schedule", turkish: "Kullanım", english: "Schedule"),
        MedicationStringSample(key: "medication_detail_when", turkish: "Ne zaman", english: "When"),
        MedicationStringSample(key: "medication_detail_dose", turkish: "Doz", english: "Dose"),
        MedicationStringSample(key: "medication_detail_dose_value", turkish: "%1$@ birim", english: "%1$@ unit(s)"),
        MedicationStringSample(key: "medication_detail_instructions", turkish: "Talimatlar", english: "Instructions"),
        MedicationStringSample(key: "medication_detail_supply", turkish: "Stok", english: "Supply"),
        MedicationStringSample(key: "medication_detail_stock", turkish: "Kalan", english: "Remaining"),
        MedicationStringSample(key: "medication_detail_history", turkish: "Son 30 gün", english: "Last 30 days"),
        MedicationStringSample(
            key: "medication_detail_history_empty",
            turkish: "Bu ilaç için henüz kayıt yok.",
            english: "No records for this medication yet."
        ),
        MedicationStringSample(key: "medication_detail_edit", turkish: "Düzenle", english: "Edit"),
        MedicationStringSample(key: "medication_detail_delete", turkish: "Sil", english: "Delete"),
        // The intake statuses (4).
        MedicationStringSample(key: "intake_status_taken", turkish: "Alındı", english: "Taken"),
        MedicationStringSample(key: "intake_status_skipped", turkish: "Atlandı", english: "Skipped"),
        MedicationStringSample(key: "intake_status_missed", turkish: "Kaçırıldı", english: "Missed"),
        MedicationStringSample(key: "intake_status_pending", turkish: "Bekliyor", english: "Pending"),
        // Delete and its undo snackbar (4).
        MedicationStringSample(key: "medication_delete_title", turkish: "%1$@ silinsin mi?", english: "Delete %1$@?"),
        MedicationStringSample(
            key: "medication_delete_message",
            turkish: "Kullanım planı ve alım geçmişi de birlikte silinir.",
            english: "Its schedule and intake history are removed with it."
        ),
        MedicationStringSample(key: "medication_deleted", turkish: "İlaç silindi", english: "Medication deleted"),
        MedicationStringSample(key: "medications_delete", turkish: "Sil", english: "Delete"),
        // The per-medication reminder toggle (4).
        MedicationStringSample(key: "medication_reminders_title", turkish: "Hatırlatıcılar", english: "Reminders"),
        MedicationStringSample(
            key: "medication_reminders_on_desc",
            turkish: "Doz saatlerinde bildirim gelir.",
            english: "You get a notification at each dose time."
        ),
        MedicationStringSample(
            key: "medication_reminders_off_desc",
            turkish: "Bildirim gelmez; dozlar Ana Sayfa'da görünmeye ve işaretlenmeye devam eder.",
            english: "No notifications; doses still show on Home and can still be marked."
        ),
        MedicationStringSample(
            key: "medication_reminders_off",
            turkish: "Hatırlatıcılar kapalı",
            english: "Reminders off"
        )
    ]

    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 86 keys :feature:medications owns")
    func catalogHoldsExactlyTheEightySixKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 86)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values match res/values*/strings.xml, apart from the one recorded divergence",
        arguments: samples
    )
    func valuesAreAndroidVerbatim(sample: MedicationStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `MedicationsStrings.Key`'s raw values does not fail to compile — it
        // ships the key itself as the label. This is the check that catches it.
        #expect(Set(MedicationsStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the ten format keys carry Swift specifiers and render the Android sentence")
    func formatKeysRenderTheAndroidSentence() throws {
        // Android's `%1$s`/`%1$d` are Java specifiers. `%s` reads a C string pointer under
        // `String(format:)` and `%d` reads 32 bits of a 64-bit Swift `Int`, so the catalog carries
        // `%1$@`/`%1$lld` instead — see the mapping table in `MedicationsStrings.swift`. The
        // sentence around them is unchanged, and these are the assertions that say so. A literal
        // `%%` is neither, and stays as it is: `String(format:)` prints it as one `%`.
        try #expect(Self.render("medications_recorded_doses", "tr", 82) == "Son 7 gün kaydedilen doz %82")
        try #expect(Self.render("medications_recorded_doses", "en", 82) == "Recorded doses, last 7 days: 82%")
        try #expect(Self.render("medications_low_stock", "tr", "4") == "Stok azaldı: 4 kaldı")
        try #expect(Self.render("medications_low_stock", "en", "4") == "Low stock: 4 left")
        try #expect(Self.render("editor_start_date", "tr", "1 Eylül") == "1 Eylül tarihinden itibaren")
        try #expect(Self.render("editor_start_date", "en", "1 September") == "From 1 September")
        try #expect(Self.render("editor_end_date", "tr", "1 Eylül") == "1 Eylül tarihine kadar")
        try #expect(Self.render("editor_end_date", "en", "1 September") == "Until 1 September")
        try #expect(Self.render("recurrence_every_n_days", "tr", 3) == "3 günde bir")
        try #expect(Self.render("recurrence_every_n_days", "en", 3) == "Every 3 days")
        try #expect(Self.render("notification_dose_title", "tr", "Aspirin") == "Aspirin zamanı")
        try #expect(Self.render("notification_dose_title", "en", "Aspirin") == "Time for Aspirin")
        try #expect(Self.render("notification_dose_text_plain", "tr", "2") == "2 doz al")
        try #expect(Self.render("notification_dose_text_plain", "en", "2") == "Take 2 dose(s)")
        try #expect(Self.render("medication_detail_dose_value", "tr", "1,5") == "1,5 birim")
        try #expect(Self.render("medication_detail_dose_value", "en", "1.5") == "1.5 unit(s)")
        try #expect(Self.render("medication_delete_title", "tr", "Aspirin") == "Aspirin silinsin mi?")
        try #expect(Self.render("medication_delete_title", "en", "Aspirin") == "Delete Aspirin?")

        // The one two-argument key: the dose amount, then the strength.
        try #expect(Self.render2("notification_dose_text", "tr", "2", "500 mg") == "2 × 500 mg al")
        try #expect(Self.render2("notification_dose_text", "en", "2", "500 mg") == "Take 2 × 500 mg")

        try Self.assertSpecifiers()
    }

    @Test("the catalog names nothing on the banned health-claims list")
    func theCatalogNamesNothingBanned() throws {
        // Repository-wide coverage already exists in `SalusTestingTests.BannedHealthClaimsTests`.
        // This narrower run points at this package's own catalog so the feature that introduces a
        // banned word fails in its own suite, where whoever wrote the string is already looking.
        try BannedHealthClaims.assertCatalogsNameNothingBanned(paths: [Self.catalogURL])
    }

    /// Every format key carries the Swift specifier in both languages, not only in the one the
    /// rendering assertions above happened to exercise.
    static func assertSpecifiers() throws {
        let catalog = try loadCatalog()
        let objectKeys = [
            "medications_low_stock",
            "editor_start_date",
            "editor_end_date",
            "notification_dose_title",
            "notification_dose_text",
            "notification_dose_text_plain",
            "medication_detail_dose_value",
            "medication_delete_title"
        ]
        let integerKeys = ["medications_recorded_doses", "recurrence_every_n_days"]

        for locale in ["tr", "en"] {
            for key in objectKeys {
                try #expect(#require(catalog.value(of: key, in: locale)).contains("%1$@"))
            }
            for key in integerKeys {
                try #expect(#require(catalog.value(of: key, in: locale)).contains("%1$lld"))
            }
            try #expect(#require(catalog.value(of: "notification_dose_text", in: locale)).contains("%2$@"))
        }
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The same, for `notification_dose_text` — the only key that carries two arguments.
    static func render2(_ key: String, _ locale: String, _ first: CVarArg, _ second: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, first, second)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // FeatureMedicationsTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // FeatureMedications
        .appendingPathComponent("Sources/FeatureMedications/Resources/Localizable.xcstrings")

    static func loadCatalog() throws -> StringCatalog {
        try StringCatalogParity.load(at: catalogURL)
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct MedicationStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
