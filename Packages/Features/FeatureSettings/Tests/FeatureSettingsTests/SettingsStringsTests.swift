import Foundation
import SalusTesting
import Testing

@testable import FeatureSettings

/// The twin of Android's `feature/settings/src/main/res/values/strings.xml` (`tr`, the source
/// language) and `values-en/strings.xml`, and the drift detector between the two locales: all 88
/// keys and both of their translations are pinned here.
///
/// The 87 keys split three ways. Fifteen are the `reminder_health_*` block that shipped with
/// iOS-M3 — ten copied from the XML verbatim, five iOS-only (the Background App Refresh row and the
/// last-pass line, which answer questions Android answers with a different mechanism or not at all).
/// Seventy are the More / About / Profile / settings keys the M8 settings hub adds, copied verbatim
/// from the XML. Two (`more_cycle`, `more_cycle_subtitle`) move here from the App target's catalog
/// with M8. (The iOS-only `language_relaunch_note` of iOS-M8 T12 is gone: the language pick applies
/// live through `SalusLocalization`, so there is no launch to wait for and nothing to say.)
/// `SettingsStrings.swift`'s header carries the card-by-card mapping and the reason each
/// Android key is kept, dropped or replaced; this table is where a drift in either direction fails.
///
/// Nine Android keys are deliberately not here (see `SettingsStrings.swift`'s header): the three
/// `reminder_health_exact_*`, the three `reminder_health_battery_*`, `reminder_health_back`,
/// `settings_back` and `profile_back`. Each is a recorded divergence, not a silent drop.
///
/// The catalog is read off disk rather than through `Bundle.module`, for the two reasons
/// `VitalsStringsTests` records: `String(localized:)` answers for ONE locale, so it can never prove
/// both carry a key, and command-line `swift test` does not compile a `.xcstrings` at all.
///
/// The banned-health-claims scan is deliberately NOT here. It runs repository-wide from
/// `SalusTestingTests.BannedHealthClaimsTests`, over every `.xcstrings` under `Packages/`.
@Suite("FeatureSettings strings")
struct SettingsStringsTests {
    static let samples = SettingsSamples.all
    static let expectedKeys = Set(samples.map(\.key))

    @Test("the catalog holds exactly the 88 keys :feature:settings owns")
    func catalogHoldsExactlyTheKeys() throws {
        // Pinned as a number as well as a set: a row deleted from the table together with its key
        // from the catalog would otherwise agree with itself and pass.
        //
        // The arithmetic behind 88, re-derived at iOS-M8 T12 rather than carried from the plan:
        // Android's `feature/settings` XML holds 91 keys; nine are dropped here (the three
        // `reminder_health_exact_*`, the three `reminder_health_battery_*`, `reminder_health_back`,
        // `settings_back`, `profile_back`) → 82 carried over. Five are iOS-only: the
        // `reminder_health_*` ones that shipped with iOS-M3 (three `*_background_refresh_*`,
        // `*_last_sync`, `*_never_synced`). 91 − 9 + 5 = 87.
        #expect(Self.samples.count == 87)

        try StringCatalogParity.assertKeys(of: Self.loadCatalog(), are: Self.expectedKeys)
    }

    @Test("Turkish is the source language and every key has both tr and en (spec 6.4)")
    func everyKeyHasBothLocales() throws {
        let catalog = try Self.loadCatalog()

        try StringCatalogParity.assertSourceLanguage(of: catalog)
        try StringCatalogParity.assertEveryKeyIsLocalized(in: catalog)
    }

    @Test(
        "the values match the ported table (feature/settings/res/values*/strings.xml)",
        arguments: samples
    )
    func valuesMatchThePortedTable(sample: SettingsStringSample) throws {
        let catalog = try Self.loadCatalog()

        #expect(catalog.value(of: sample.key, in: "tr") == sample.turkish)
        #expect(catalog.value(of: sample.key, in: "en") == sample.english)
    }

    @Test("every accessor asks for a key the catalog carries")
    func everyAccessorAsksForAKeyTheCatalogCarries() throws {
        let catalog = try Self.loadCatalog()

        // A typo in one of `SettingsStrings.Key`'s raw values does not fail to compile — it ships
        // the key itself as the label. This is the check that catches it.
        #expect(Set(SettingsStrings.Key.allCases.map(\.rawValue)) == catalog.keys)
    }

    @Test("the format keys carry the Swift specifier and render their sentence")
    func theFormatKeyRendersItsSentence() throws {
        let catalog = try Self.loadCatalog()

        // Java's `%1$s` reads a C string pointer under `String(format:)`; `%1$@` is the object
        // form — see the mapping table in `SettingsStrings.swift`.
        try #expect(#require(catalog.value(of: "reminder_health_last_sync", in: "tr")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "reminder_health_last_sync", in: "en")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "about_version", in: "tr")).contains("%1$@"))
        try #expect(#require(catalog.value(of: "about_version", in: "en")).contains("%1$@"))

        try #expect(
            Self.render("reminder_health_last_sync", "tr", "23 Ağu 2026 14:05")
                == "Son hatırlatıcı taraması: 23 Ağu 2026 14:05"
        )
        try #expect(
            Self.render("reminder_health_last_sync", "en", "23 Aug 2026 14:05")
                == "Last reminder pass: 23 Aug 2026 14:05"
        )
        try #expect(Self.render("about_version", "tr", "1.0.0") == "Sürüm 1.0.0")
        try #expect(Self.render("about_version", "en", "1.0.0") == "Version 1.0.0")
    }

    /// One catalog value with its single argument substituted, formatted locale-independently so
    /// the expected sentence does not depend on where the test ran.
    static func render(_ key: String, _ locale: String, _ argument: CVarArg) throws -> String {
        let format = try #require(loadCatalog().value(of: key, in: locale))
        return String(format: format, locale: nil, argument)
    }

    /// The catalog file itself, read from the package tree relative to this test.
    static func loadCatalog() throws -> StringCatalog {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FeatureSettingsTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FeatureSettings
        return try StringCatalogParity.load(
            at: packageRoot.appendingPathComponent("Sources/FeatureSettings/Resources/Localizable.xcstrings")
        )
    }
}

/// Every key `:feature:settings` owns today, with both translations. A new key means a new row
/// here, in the same commit — that is the whole job of this table.
///
/// Held in a dedicated file-private enum so the 88-row table does not blow the suite's own body
/// past the `type_body_length` gate.
private enum SettingsSamples {
    static let all: [SettingsStringSample] = [
        SettingsStringSample(key: "about_app_name", turkish: "Salus", english: "Salus"),
        SettingsStringSample(
            key: "about_description",
            turkish: "Salus; randevularınızı, ilaçlarınızı, döngünüzü ve sağlık ölçümlerinizi tek bir yerden "
                + "takip etmenize yardımcı olan cihaz öncelikli bir sağlık asistanıdır.",
            english: "Salus is a device-first health companion that helps you track your appointments, "
                + "medications, cycle, and health measurements in one place."
        ),
        SettingsStringSample(
            key: "about_privacy_body",
            turkish: "Sağlık kayıtlarınız yalnızca cihazınızda saklanır ve cihazınızdan asla çıkmaz. Hesap "
                + "yoktur, analitik yoktur, veri toplanmaz. Salus ağı yalnızca iki şey için kullanır: "
                + "aboneliğinizi doğrulamak (Google Play ve abonelik altyapımız RevenueCat) ve — "
                + "kullanırsanız — AI özellikleri. AI özelliklerine yalnızca anonim istatistik özetleri "
                + "gönderilir; sağlık kayıtlarınız asla gönderilmez.",
            english: "Your health records are stored only on your device and never leave it. No accounts, "
                + "no analytics, no data collection. Salus uses the network for two things: verifying "
                + "your subscription (Google Play and our subscription provider, RevenueCat) and — if "
                + "you use them — the AI features. The AI features only ever receive anonymous "
                + "statistical summaries; your health records are never sent."
        ),
        SettingsStringSample(key: "about_privacy_title", turkish: "Gizlilik", english: "Privacy"),
        SettingsStringSample(key: "about_title", turkish: "Uygulama hakkında", english: "About the app"),
        SettingsStringSample(key: "about_version", turkish: "Sürüm %1$@", english: "Version %1$@"),
        SettingsStringSample(key: "color_theme_classic", turkish: "Klasik", english: "Classic"),
        SettingsStringSample(key: "color_theme_forest", turkish: "Orman", english: "Forest"),
        SettingsStringSample(key: "color_theme_ocean", turkish: "Okyanus", english: "Ocean"),
        SettingsStringSample(key: "color_theme_sunset", turkish: "Gün batımı", english: "Sunset"),
        SettingsStringSample(key: "language_english", turkish: "English", english: "English"),
        SettingsStringSample(key: "language_system", turkish: "Sistem dili", english: "System language"),
        SettingsStringSample(key: "language_title", turkish: "Dil", english: "Language"),
        SettingsStringSample(key: "language_turkish", turkish: "Türkçe", english: "Türkçe"),
        SettingsStringSample(key: "more_cycle", turkish: "Regl Takibi", english: "Cycle tracking"),
        SettingsStringSample(
            key: "more_cycle_subtitle",
            turkish: "Takvim, tahminler ve belirtiler",
            english: "Calendar, predictions and symptoms"
        ),
        SettingsStringSample(key: "more_profile", turkish: "Profil", english: "Profile"),
        SettingsStringSample(
            key: "more_profile_incomplete",
            turkish: "Profilini tamamla",
            english: "Complete your profile"
        ),
        SettingsStringSample(key: "more_section_tracking", turkish: "Takip", english: "Tracking"),
        SettingsStringSample(key: "more_title", turkish: "Daha Fazla", english: "More"),
        SettingsStringSample(key: "more_trends", turkish: "Analizler", english: "Trends"),
        SettingsStringSample(
            key: "more_trends_subtitle",
            turkish: "Kayıtlarındaki örüntüler ve dönem karşılaştırmaları",
            english: "Patterns in your records and period comparisons"
        ),
        SettingsStringSample(key: "profile_birth_date", turkish: "Doğum Tarihi", english: "Date of birth"),
        SettingsStringSample(key: "profile_birth_date_select", turkish: "Tarih seçin", english: "Pick a date"),
        SettingsStringSample(key: "profile_health_notes", turkish: "Sağlık Notları", english: "Health notes"),
        SettingsStringSample(
            key: "profile_health_notes_placeholder",
            turkish: "Kronik hastalıklar, alerjiler, kullandığın ilaçlar…",
            english: "Chronic conditions, allergies, medications you take…"
        ),
        SettingsStringSample(key: "profile_height", turkish: "Boy", english: "Height"),
        SettingsStringSample(
            key: "profile_height_invalid",
            turkish: "50 ile 250 cm arasında bir değer girin.",
            english: "Enter a value between 50 and 250 cm."
        ),
        SettingsStringSample(key: "profile_height_placeholder", turkish: "Örn: 170", english: "e.g. 170"),
        SettingsStringSample(key: "profile_name", turkish: "Ad", english: "Name"),
        SettingsStringSample(key: "profile_name_placeholder", turkish: "Örn: Ayşe", english: "e.g. Ayşe"),
        SettingsStringSample(key: "profile_save", turkish: "Kaydet", english: "Save"),
        SettingsStringSample(key: "profile_sex", turkish: "Cinsiyet", english: "Sex"),
        SettingsStringSample(
            key: "profile_sex_cycle_appears",
            turkish: "Regl Takibi, Daha Fazla sekmesine eklenir. Daha önce kaydettiğin regl verilerin "
                + "olduğu gibi durur.",
            english: "Cycle tracking is added to the More tab. Any cycle data you recorded before is "
                + "still there."
        ),
        SettingsStringSample(
            key: "profile_sex_cycle_disappears",
            turkish: "Regl Takibi, Daha Fazla sekmesinden kaldırılır. Kayıtlı regl verilerin silinmez; "
                + "seçimi geri aldığında geri gelir.",
            english: "Cycle tracking is removed from the More tab. Your recorded cycle data is not "
                + "deleted and comes back if you change this again."
        ),
        SettingsStringSample(
            key: "profile_sex_confirm_body",
            turkish: "Bu seçimle Regl Takibi, Daha Fazla sekmesinden kaldırılır. Kayıtlı regl verilerin "
                + "silinmez; seçimi geri aldığında geri gelir.",
            english: "This removes Cycle tracking from the More tab. Your recorded cycle data is not "
                + "deleted and comes back if you change this again."
        ),
        SettingsStringSample(key: "profile_sex_confirm_cancel", turkish: "Vazgeç", english: "Cancel"),
        SettingsStringSample(key: "profile_sex_confirm_ok", turkish: "Kaydet", english: "Save"),
        SettingsStringSample(
            key: "profile_sex_confirm_title",
            turkish: "Regl Takibi kaldırılsın mı?",
            english: "Remove Cycle tracking?"
        ),
        SettingsStringSample(key: "profile_sex_female", turkish: "Kadın", english: "Female"),
        SettingsStringSample(key: "profile_sex_male", turkish: "Erkek", english: "Male"),
        SettingsStringSample(key: "profile_sex_other", turkish: "Diğer", english: "Other"),
        SettingsStringSample(key: "profile_title", turkish: "Profil", english: "Profile"),
        SettingsStringSample(
            key: "reminder_health_title",
            turkish: "Hatırlatıcı sağlığı",
            english: "Reminder health"
        ),
        SettingsStringSample(
            key: "reminder_health_intro",
            turkish: "Hatırlatıcıların zamanında gelmesi için Salus'un aşağıdaki ayarlara ihtiyacı var. "
                + "Tüm kontroller yalnızca bu cihazda çalışır — hiçbir veri dışarı çıkmaz.",
            english: "For reminders to arrive on time, Salus needs the settings below. "
                + "All checks run on this device only — nothing leaves it."
        ),
        SettingsStringSample(
            key: "reminder_health_all_ok",
            turkish: "Her şey yolunda görünüyor — hatırlatıcılar zamanında gelecektir.",
            english: "Everything looks good — reminders should arrive on time."
        ),
        SettingsStringSample(key: "reminder_health_fix", turkish: "Düzelt", english: "Fix"),
        SettingsStringSample(
            key: "reminder_health_notifications_title",
            turkish: "Bildirimler",
            english: "Notifications"
        ),
        SettingsStringSample(
            key: "reminder_health_notifications_ok",
            turkish: "Bildirimler açık.",
            english: "Notifications are enabled."
        ),
        SettingsStringSample(
            key: "reminder_health_notifications_problem",
            turkish: "Bildirimler kapalı — hatırlatıcılar gösterilemez.",
            english: "Notifications are off — reminders cannot be shown."
        ),
        SettingsStringSample(
            key: "reminder_health_full_screen_title",
            turkish: "Tam ekran ilaç alarmları",
            english: "Full-screen medication alarms"
        ),
        SettingsStringSample(
            key: "reminder_health_full_screen_ok",
            turkish: "İlaç alarmları kilit ekranını kaplayarak çalacak.",
            english: "Medication alarms will take over the lock screen."
        ),
        SettingsStringSample(
            key: "reminder_health_full_screen_problem",
            turkish: "İlaç alarmları ekranı kaplayamıyor — doz saati geldiğinde sesli bildirim gelir, "
                + "ama kilit ekranında alarm açılmaz.",
            english: "Medication alarms cannot take over the screen — a dose still arrives as a "
                + "notification with sound, but no alarm opens on the lock screen."
        ),
        SettingsStringSample(
            key: "reminder_health_background_refresh_title",
            turkish: "Arka plan yenilemesi",
            english: "Background App Refresh"
        ),
        SettingsStringSample(
            key: "reminder_health_background_refresh_ok",
            turkish: "Salus hatırlatıcı listesini arka planda tazeleyebiliyor.",
            english: "Salus can refresh the reminder list in the background."
        ),
        SettingsStringSample(
            key: "reminder_health_background_refresh_problem",
            turkish: "Arka plan yenilemesi kapalı — hatırlatıcı listesi yalnızca uygulamayı "
                + "açtığınızda tazelenir.",
            english: "Background App Refresh is off — the reminder list is only refreshed while "
                + "the app is open."
        ),
        SettingsStringSample(
            key: "reminder_health_last_sync",
            turkish: "Son hatırlatıcı taraması: %1$@",
            english: "Last reminder pass: %1$@"
        ),
        SettingsStringSample(
            key: "reminder_health_never_synced",
            turkish: "Hatırlatıcı taraması bu cihazda henüz çalışmadı.",
            english: "The reminder pass has not run on this device yet."
        ),
        SettingsStringSample(
            key: "settings_about",
            turkish: "Uygulama hakkında",
            english: "About the app"
        ),
        SettingsStringSample(
            key: "settings_about_desc",
            turkish: "Sürüm ve uygulama bilgileri",
            english: "Version and app info"
        ),
        SettingsStringSample(key: "settings_app_lock", turkish: "Uygulama kilidi", english: "App lock"),
        SettingsStringSample(
            key: "settings_app_lock_confirm_title",
            turkish: "Uygulama kilidini etkinleştir",
            english: "Enable app lock"
        ),
        SettingsStringSample(
            key: "settings_app_lock_desc",
            turkish: "30 sn arka planda kaldıktan sonra biyometri veya cihaz kilidi iste",
            english: "Require biometrics or device credential after 30 s in the background"
        ),
        SettingsStringSample(
            key: "settings_app_lock_unavailable",
            turkish: "Bu cihazda ekran kilidi tanımlı değil",
            english: "No screen lock is set up on this device"
        ),
        SettingsStringSample(key: "settings_cancel", turkish: "Vazgeç", english: "Cancel"),
        SettingsStringSample(key: "settings_color_theme", turkish: "Renk teması", english: "Color theme"),
        SettingsStringSample(
            key: "settings_doctor_report",
            turkish: "Doktor Raporu (PDF)",
            english: "Doctor report (PDF)"
        ),
        SettingsStringSample(
            key: "settings_doctor_report_desc",
            turkish: "Kayıtlarını PDF olarak dışa aktar ve paylaş",
            english: "Export your records as a PDF and share them"
        ),
        SettingsStringSample(key: "settings_language", turkish: "Dil", english: "Language"),
        SettingsStringSample(
            key: "settings_notifications",
            turkish: "Bildirim ayarları",
            english: "Notification settings"
        ),
        SettingsStringSample(
            key: "settings_notifications_desc",
            turkish: "Kanal, ses ve titreşimi sistem ayarlarından yönet",
            english: "Manage channels, sound and vibration in system settings"
        ),
        SettingsStringSample(key: "settings_premium", turkish: "Salus Premium", english: "Salus Premium"),
        SettingsStringSample(
            key: "settings_premium_active",
            turkish: "Premium üyesin",
            english: "You are a Premium member"
        ),
        SettingsStringSample(
            key: "settings_premium_promo",
            turkish: "AI özetleri, gelişmiş trendler ve daha fazlası",
            english: "AI summaries, advanced trends and more"
        ),
        SettingsStringSample(key: "settings_reminders", turkish: "Hatırlatıcılar", english: "Reminders"),
        SettingsStringSample(
            key: "settings_reminders_desc",
            turkish: "Hatırlatıcıların çalışma durumunu incele",
            english: "Review how reminders are running"
        ),
        SettingsStringSample(key: "settings_section_app", turkish: "Uygulama", english: "App"),
        SettingsStringSample(key: "settings_section_appearance", turkish: "Görünüm", english: "Appearance"),
        SettingsStringSample(
            key: "settings_section_notifications",
            turkish: "Bildirimler",
            english: "Notifications"
        ),
        SettingsStringSample(key: "settings_section_security", turkish: "Güvenlik", english: "Security"),
        SettingsStringSample(
            key: "settings_secure_screen",
            turkish: "Ekran görüntüsünü engelle",
            english: "Block screenshots"
        ),
        SettingsStringSample(
            key: "settings_secure_screen_desc",
            turkish: "Ekran görüntülerini ve son uygulamalar önizlemesini gizler",
            english: "Hides screenshots and the recents preview"
        ),
        SettingsStringSample(key: "settings_theme", turkish: "Tema", english: "Theme"),
        SettingsStringSample(key: "theme_dark", turkish: "Koyu", english: "Dark"),
        SettingsStringSample(key: "theme_light", turkish: "Açık", english: "Light"),
        SettingsStringSample(key: "theme_system", turkish: "Sistem varsayılanı", english: "System default"),
        SettingsStringSample(key: "theme_title", turkish: "Tema", english: "Theme")
    ]
}

/// One row of the ported string table: a key and the two translations the app ships for it.
///
/// Flat rather than nested in the suite so it can be a `@Test(arguments:)` table, which requires
/// a `Sendable` element type.
struct SettingsStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
