import Foundation
import SalusTesting
import Testing

@testable import FeatureHome

/// The twin of Android's `feature/home/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between them: the 42 ported keys
/// and both of their translations are pinned here, copied from the XML.
///
/// **M16 moved the table from 34 to 42**, mirroring Android's M15 sweep (`3391896..529a30f`):
/// nine keys added, one deleted (`home_ai_summary_free_credit`) and three re-valued under the same
/// name (`home_view_details` in Turkish only, `today_appointments_title` and `home_take_dose` in
/// both). The re-valued three show up as `-` lines in the XML diff without being keys that left,
/// which is the trap this table exists to catch.
///
/// **42 on both sides now.** iOS deliberately never ported `home_title` and `home_settings`,
/// which Android declared and read nowhere; Android has since deleted them itself (`aebb056`), so
/// the two catalogs finally hold the same key set. The disjointness assertion below stays as the
/// guard it always was — if either key ever comes back, it comes back on both sides on purpose or
/// not at all.
///
/// The catalog is read off disk rather than through `Bundle.module`. Android's own parity checks
/// read the XML for the first reason: `String(localized:)` answers for ONE locale — the host's —
/// so it can never prove that both locales carry a key. The second is the toolchain note in
/// `HomeStrings.swift`: command-line `swift test` does not compile a `.xcstrings` at all, so a
/// resolved string here would only ever be the key back. The end-to-end check is the simulator
/// run.
///
/// The parity mechanics — loading, the key-set pin, the locale check — live in
/// `SalusTesting.StringCatalogParity`, so this suite is only this feature's application of them
/// plus the half no shared helper can own: the values themselves, Android's own, verbatim.
@Suite("FeatureHome strings")
struct HomeStringsTests {
    /// Every key `:feature:home` owns and iOS ports, with both translations, copied from the XML.
    /// A new key there means a new row here, in the same commit — that is the whole job of this
    /// table. The rows follow the XML's order, grouped by the card that reads them.
    static let samples: [HomeStringSample] = [
        // The hero band (10).
        HomeStringSample(key: "home_overline_today", turkish: "BUGÜN", english: "TODAY"),
        HomeStringSample(key: "home_greeting_morning", turkish: "Günaydın, %1$@", english: "Good morning, %1$@"),
        HomeStringSample(key: "home_greeting_afternoon", turkish: "İyi günler, %1$@", english: "Good afternoon, %1$@"),
        HomeStringSample(key: "home_greeting_evening", turkish: "İyi akşamlar, %1$@", english: "Good evening, %1$@"),
        HomeStringSample(key: "home_greeting_night", turkish: "İyi geceler, %1$@", english: "Good night, %1$@"),
        HomeStringSample(key: "home_greeting_morning_plain", turkish: "Günaydın", english: "Good morning"),
        HomeStringSample(key: "home_greeting_afternoon_plain", turkish: "İyi günler", english: "Good afternoon"),
        HomeStringSample(key: "home_greeting_evening_plain", turkish: "İyi akşamlar", english: "Good evening"),
        HomeStringSample(key: "home_greeting_night_plain", turkish: "İyi geceler", english: "Good night"),
        HomeStringSample(
            key: "home_dose_progress",
            turkish: "Bugünün ilerlemesi %1$lld/%2$lld",
            english: "Today's progress %1$lld/%2$lld"
        ),
        // Carried for key parity, read by nothing on iOS (1).
        HomeStringSample(key: "home_view_details", turkish: "Detaylı İncele", english: "View details"),
        // The reminder readiness card (2).
        HomeStringSample(
            key: "home_reminders_broken_title",
            turkish: "Alarmlar çalışmayacak",
            english: "Alarms will not fire"
        ),
        HomeStringSample(
            key: "home_reminders_degraded_title",
            turkish: "Alarmlar gecikebilir",
            english: "Alarms may be late"
        ),
        // The AI summary card (3).
        HomeStringSample(key: "home_ai_summary_title", turkish: "Yapay zekâ özeti", english: "AI summary"),
        HomeStringSample(
            key: "home_ai_summary_description",
            turkish: "Kayıtlarından haftalık ya da aylık bir sağlık özeti çıkar.",
            english: "Turn your records into a weekly or monthly health summary."
        ),
        HomeStringSample(key: "home_ai_new_summary", turkish: "Yeni Özet", english: "New summary"),
        // The doses page (10).
        HomeStringSample(key: "today_doses_title", turkish: "Bugünün dozları", english: "Today's doses"),
        HomeStringSample(
            key: "today_doses_empty",
            turkish: "Bugün için planlı doz yok.",
            english: "No doses scheduled for today."
        ),
        HomeStringSample(key: "dose_status_taken", turkish: "İçildi", english: "Taken"),
        HomeStringSample(key: "dose_status_snoozed", turkish: "Ertelendi", english: "Snoozed"),
        HomeStringSample(key: "dose_status_pending", turkish: "Bekliyor", english: "Pending"),
        HomeStringSample(key: "dose_status_missed", turkish: "Kaçırıldı", english: "Missed"),
        HomeStringSample(key: "home_take_dose", turkish: "Alındı", english: "Taken"),
        HomeStringSample(key: "home_next_dose", turkish: "Sıradaki: %1$@ · %2$@", english: "Next: %1$@ · %2$@"),
        HomeStringSample(
            key: "home_next_dose_none",
            turkish: "Bugün bekleyen doz kalmadı.",
            english: "Nothing left to take today."
        ),
        HomeStringSample(key: "home_last_dose", turkish: "SON DOZ", english: "LAST DOSE"),
        // The appointments section (3).
        HomeStringSample(
            key: "today_appointments_title",
            turkish: "YAKLAŞAN RANDEVULAR",
            english: "UPCOMING APPOINTMENTS"
        ),
        HomeStringSample(
            key: "today_appointments_empty",
            turkish: "Yaklaşan randevu yok.",
            english: "No upcoming appointments."
        ),
        HomeStringSample(key: "home_see_all", turkish: "Tümünü Gör", english: "See all"),
        // The pager page labels (3).
        HomeStringSample(key: "home_pager_doses", turkish: "Bugünün dozları kartı", english: "Today's doses card"),
        HomeStringSample(key: "home_pager_vitals", turkish: "Ölçümler kartı", english: "Measurements card"),
        HomeStringSample(key: "home_pager_cycle", turkish: "Döngü kartı", english: "Cycle card"),
        // The cycle page (4).
        HomeStringSample(key: "today_cycle_title", turkish: "Döngü", english: "Cycle"),
        HomeStringSample(key: "today_cycle_empty", turkish: "Henüz dönem kaydı yok.", english: "No period logged yet."),
        HomeStringSample(key: "today_cycle_day", turkish: "Döngünün %1$lld. günü", english: "Cycle day %1$lld"),
        HomeStringSample(key: "today_cycle_period_ongoing", turkish: "Dönem devam ediyor", english: "Period ongoing"),
        // The vitals page (6).
        HomeStringSample(key: "today_vitals_title", turkish: "Ölçümler", english: "Measurements"),
        HomeStringSample(key: "today_vitals_empty", turkish: "Henüz ölçüm yok.", english: "No measurements yet."),
        HomeStringSample(key: "today_vitals_weight", turkish: "Kilo: %1$@ kg", english: "Weight: %1$@ kg"),
        HomeStringSample(
            key: "today_vitals_bp",
            turkish: "Tansiyon: %1$@/%2$@ mmHg",
            english: "Blood pressure: %1$@/%2$@ mmHg"
        ),
        HomeStringSample(
            key: "today_vitals_glucose_mgdl",
            turkish: "Kan şekeri: %1$@ mg/dL",
            english: "Blood glucose: %1$@ mg/dL"
        ),
        HomeStringSample(
            key: "today_vitals_glucose_mmol",
            turkish: "Kan şekeri: %1$@ mmol/L",
            english: "Blood glucose: %1$@ mmol/L"
        )
    ]

    static let expectedKeys = Set(samples.map(\.key))

    /// The two keys Android used to declare and nobody read. Named here so the omission stays a
    /// pinned decision rather than something that looks like a forgotten row.
    static let deadAndroidKeys: Set = ["home_title", "home_settings"]

    @Test("the catalog holds exactly the 42 keys ported from :feature:home")
    func catalogHoldsExactlyTheFortyTwoKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        #expect(Self.samples.count == 42)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Android's two dead keys are deliberately absent")
    func androidsDeadKeysAreAbsent() throws {
        // `home_title` (the shell owns the title) and `home_settings` (the settings gear Android's
        // M9 removed) were declared in both `values/` and `values-en/` and read by no `R.string.*`
        // in `HomeScreen.kt`. iOS never ported them; Android has since deleted them itself
        // (`aebb056`), so both XMLs hold 42 `<string>` entries today — the same count as this
        // catalog, with neither dead key on either side.
        //
        // Only assertions that can fail live here. A third line used to pin
        // `expectedKeys.count + deadAndroidKeys.count == 36` and claim the XML declared 36: it was
        // 34 + 2 over two constants of this file, true whatever either catalog holds, and the
        // claim was wrong besides.
        let catalog = try Self.loadCatalog()

        #expect(catalog.keys.isDisjoint(with: Self.deadAndroidKeys))
        #expect(Self.expectedKeys.isDisjoint(with: Self.deadAndroidKeys))
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test("the values match res/values*/strings.xml", arguments: samples)
    func valuesAreAndroidVerbatim(sample: HomeStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `HomeStrings.Key`'s raw values does not fail to compile — it ships the
        // key itself as the label. This is the check that catches it.
        #expect(Set(HomeStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the ten format keys carry Swift specifiers and render the Android sentence")
    func formatKeysRenderTheAndroidSentence() throws {
        // Android's `%1$s`/`%1$d` are Java specifiers. `%s` reads a C string pointer under
        // `String(format:)` and `%d` reads 32 bits of a 64-bit Swift `Int`, so the catalog carries
        // `%1$@`/`%1$lld` instead — see the mapping table in `HomeStrings.swift`. The sentence
        // around them is unchanged, and these are the assertions that say so.
        try #expect(Self.render("today_cycle_day", "tr", 14) == "Döngünün 14. günü")
        try #expect(Self.render("today_cycle_day", "en", 14) == "Cycle day 14")
        try #expect(Self.render("home_dose_progress", "tr", 3, 5) == "Bugünün ilerlemesi 3/5")
        try #expect(Self.render("home_dose_progress", "en", 3, 5) == "Today's progress 3/5")
        try #expect(Self.render("home_greeting_morning", "tr", "Alican") == "Günaydın, Alican")
        try #expect(Self.render("home_greeting_morning", "en", "Alican") == "Good morning, Alican")
        try #expect(Self.render("home_greeting_afternoon", "tr", "Alican") == "İyi günler, Alican")
        try #expect(Self.render("home_greeting_afternoon", "en", "Alican") == "Good afternoon, Alican")
        try #expect(Self.render("home_greeting_evening", "tr", "Alican") == "İyi akşamlar, Alican")
        try #expect(Self.render("home_greeting_evening", "en", "Alican") == "Good evening, Alican")
        try #expect(Self.render("home_greeting_night", "tr", "Alican") == "İyi geceler, Alican")
        try #expect(Self.render("home_greeting_night", "en", "Alican") == "Good night, Alican")
        try #expect(Self.render("today_vitals_weight", "tr", "72,5") == "Kilo: 72,5 kg")
        try #expect(Self.render("today_vitals_weight", "en", "72.5") == "Weight: 72.5 kg")
        try #expect(Self.render("today_vitals_glucose_mgdl", "tr", "110") == "Kan şekeri: 110 mg/dL")
        try #expect(Self.render("today_vitals_glucose_mgdl", "en", "110") == "Blood glucose: 110 mg/dL")
        try #expect(Self.render("today_vitals_glucose_mmol", "tr", "6,1") == "Kan şekeri: 6,1 mmol/L")
        try #expect(Self.render("today_vitals_glucose_mmol", "en", "6.1") == "Blood glucose: 6.1 mmol/L")
        try #expect(Self.render("today_vitals_bp", "tr", "120", "80") == "Tansiyon: 120/80 mmHg")
        try #expect(Self.render("today_vitals_bp", "en", "120", "80") == "Blood pressure: 120/80 mmHg")
        try #expect(Self.render("home_next_dose", "tr", "Metformin", "08:00") == "Sıradaki: Metformin · 08:00")
        try #expect(Self.render("home_next_dose", "en", "Metformin", "08:00") == "Next: Metformin · 08:00")

        try Self.assertSpecifiers()
    }

    @Test("the catalog names nothing on the banned health-claims list")
    func theCatalogNamesNothingBanned() throws {
        // Repository-wide coverage already exists in `SalusTestingTests.BannedHealthClaimsTests`.
        // This narrower run points at this package's own catalog so the feature that introduces a
        // banned word fails in its own suite, where whoever wrote the string is already looking.
        //
        // The near-miss to keep an eye on is `today_doses_empty` — Turkish "Bugün için planlı
        // doz yok.": `planlı` is one letter short of a stem the scan rejects, so it passes. Never
        // lengthen that word.
        try BannedHealthClaims.assertCatalogsNameNothingBanned(paths: [Self.catalogURL])
    }

    /// Every format key carries the Swift specifier in both languages, not only in the one the
    /// rendering assertions above happened to exercise.
    static func assertSpecifiers() throws {
        let catalog = try loadCatalog()
        let stringKeys = [
            "today_vitals_weight",
            "today_vitals_bp",
            "today_vitals_glucose_mgdl",
            "today_vitals_glucose_mmol",
            "home_greeting_morning",
            "home_greeting_afternoon",
            "home_greeting_evening",
            "home_greeting_night",
            "home_next_dose"
        ]

        for locale in ["tr", "en"] {
            // The two `%1$d` on the Android side, and so the two `%1$lld` here.
            try #expect(#require(catalog.value(of: "today_cycle_day", in: locale)).contains("%1$lld"))
            try #expect(#require(catalog.value(of: "home_dose_progress", in: locale)).contains("%1$lld"))
            try #expect(#require(catalog.value(of: "home_dose_progress", in: locale)).contains("%2$lld"))

            for key in stringKeys {
                try #expect(#require(catalog.value(of: key, in: locale)).contains("%1$@"))
            }

            // Blood pressure and the next dose are the two keys with a second `%1$@`-style
            // argument.
            try #expect(#require(catalog.value(of: "today_vitals_bp", in: locale)).contains("%2$@"))
            try #expect(#require(catalog.value(of: "home_next_dose", in: locale)).contains("%2$@"))
        }
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The two-argument form, for `today_vitals_bp`.
    static func render(_ key: String, _ locale: String, _ first: CVarArg, _ second: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, first, second)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // FeatureHomeTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // FeatureHome
        .appendingPathComponent("Sources/FeatureHome/Resources/Localizable.xcstrings")

    static func loadCatalog() throws -> StringCatalog {
        try StringCatalogParity.load(at: catalogURL)
    }
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct HomeStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
