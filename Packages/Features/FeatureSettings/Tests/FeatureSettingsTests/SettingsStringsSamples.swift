// The ported value table SettingsStringsTests pins. Moved here in M16 Task 10 so the
// suite stays under the 500-line gate; the 2026-09-13 language merge re-pinned it at 122 keys
// (`language_title`/`language_sheet_subtitle` out with the deleted `LanguageSheet`,
// `theme_section_language` in with the merged sheet's third section, `theme_sheet_title`
// re-titled).

import Foundation
import SalusTesting
import Testing

/// Every key `:feature:settings` owns today, with both translations. A new key means a new row
/// here, in the same commit — that is the whole job of this table.
///
/// Held in two dedicated file-private enums so the 114-row table does not blow the suite's own body
/// or either enum past the `type_body_length` gate.
enum SettingsSamples {
    static let all: [SettingsStringSample] = SettingsSamplesFirst.all + SettingsSamplesSecond.all
}

enum SettingsSamplesFirst {
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
                + "aboneliğinizi doğrulamak (App Store ve abonelik altyapımız RevenueCat) ve — "
                + "kullanırsanız — AI özellikleri. AI özelliklerine yalnızca anonim istatistik özetleri "
                + "gönderilir; sağlık kayıtlarınız asla gönderilmez.",
            english: "Your health records are stored only on your device and never leave it. No accounts, "
                + "no analytics, no data collection. Salus uses the network for two things: verifying "
                + "your subscription (App Store and our subscription provider, RevenueCat) and — if "
                + "you use them — the AI features. The AI features only ever receive anonymous "
                + "statistical summaries; your health records are never sent."
        ),
        SettingsStringSample(key: "about_privacy_title", turkish: "Gizlilik", english: "Privacy"),
        SettingsStringSample(key: "about_title", turkish: "Uygulama hakkında", english: "About the app"),
        SettingsStringSample(key: "about_version", turkish: "Sürüm %1$@", english: "Version %1$@"),
        SettingsStringSample(key: "about_features_title", turkish: "SALUS NE YAPAR", english: "WHAT SALUS DOES"),
        SettingsStringSample(key: "about_feature_medications", turkish: "İlaçlar", english: "Medications"),
        SettingsStringSample(
            key: "about_feature_medications_desc",
            turkish: "Hatırlatıcılı ilaç takibi",
            english: "Medication tracking with reminders"
        ),
        SettingsStringSample(key: "about_feature_appointments", turkish: "Randevular", english: "Appointments"),
        SettingsStringSample(
            key: "about_feature_appointments_desc",
            turkish: "Doktor randevuları ve hatırlatıcılar",
            english: "Doctor appointments and reminders"
        ),
        SettingsStringSample(key: "about_feature_vitals", turkish: "Sağlık ölçümleri", english: "Health measurements"),
        SettingsStringSample(
            key: "about_feature_vitals_desc",
            turkish: "Tansiyon, glukoz, kilo kaydı",
            english: "Blood pressure, glucose, weight logging"
        ),
        SettingsStringSample(key: "about_feature_cycle", turkish: "Regl takibi", english: "Cycle tracking"),
        SettingsStringSample(
            key: "about_feature_cycle_desc",
            turkish: "Takvim, tahminler ve belirtiler",
            english: "Calendar, predictions and symptoms"
        ),
        SettingsStringSample(key: "about_feature_ai", turkish: "AI Sağlık", english: "AI Health"),
        SettingsStringSample(
            key: "about_feature_ai_desc",
            turkish: "Kayıtlarınıza dair AI özetleri",
            english: "AI summaries of your records"
        ),
        SettingsStringSample(key: "about_feature_trends", turkish: "Analizler", english: "Trends"),
        SettingsStringSample(
            key: "about_feature_trends_desc",
            turkish: "Kayıtlarınızdaki örüntüler",
            english: "Patterns in your records"
        ),
        SettingsStringSample(key: "about_feature_reminders", turkish: "Hatırlatıcılar", english: "Reminders"),
        SettingsStringSample(
            key: "about_feature_reminders_desc",
            turkish: "İlaç ve ölçüm hatırlatıcıları",
            english: "Medication and measurement reminders"
        ),
        SettingsStringSample(key: "support_premium_status_title", turkish: "Abonelik", english: "Subscription"),
        SettingsStringSample(key: "support_premium_free", turkish: "Ücretsiz", english: "Free"),
        SettingsStringSample(key: "support_premium_active", turkish: "Aktif Premium", english: "Active Premium"),
        SettingsStringSample(key: "support_code", turkish: "Destek kodu", english: "Support code"),
        SettingsStringSample(
            key: "support_code_unavailable",
            turkish: "Destek kodu şu anda kullanılamıyor.",
            english: "Support code is currently unavailable."
        ),
        SettingsStringSample(key: "support_copy", turkish: "Kopyala", english: "Copy"),
        SettingsStringSample(key: "support_copied", turkish: "Kopyalandı", english: "Copied"),
        SettingsStringSample(key: "color_theme_classic", turkish: "Klasik", english: "Classic"),
        SettingsStringSample(key: "color_theme_forest", turkish: "Orman", english: "Forest"),
        SettingsStringSample(key: "color_theme_ocean", turkish: "Okyanus", english: "Ocean"),
        SettingsStringSample(key: "color_theme_sunset", turkish: "Gün batımı", english: "Sunset"),
        SettingsStringSample(key: "language_english", turkish: "English", english: "English"),
        SettingsStringSample(key: "language_system", turkish: "Sistem dili", english: "System language"),
        SettingsStringSample(key: "language_turkish", turkish: "Türkçe", english: "Türkçe"),
        SettingsStringSample(key: "more_cycle", turkish: "Regl Takibi", english: "Cycle tracking"),
        SettingsStringSample(
            key: "more_cycle_subtitle",
            turkish: "Takvim, tahminler ve belirtiler",
            english: "Calendar, predictions and symptoms"
        ),
        SettingsStringSample(
            key: "more_footer",
            turkish: "Sağlık kayıtların yalnızca bu cihazda saklanır.",
            english: "Your health records stay on this device."
        ),
        SettingsStringSample(key: "more_language", turkish: "Uygulama dili", english: "App language"),
        SettingsStringSample(key: "more_pro_badge", turkish: "PRO", english: "PRO"),
        SettingsStringSample(key: "more_premium_cta", turkish: "Premium'a geç", english: "Go Premium"),
        SettingsStringSample(
            key: "more_profile_incomplete",
            turkish: "Profilini tamamla",
            english: "Complete your profile"
        ),
        SettingsStringSample(key: "more_section_app", turkish: "UYGULAMA & BİLGİ", english: "APP & INFO"),
        SettingsStringSample(key: "more_section_appearance", turkish: "GÖRÜNÜM & TEMA", english: "APPEARANCE & THEME"),
        SettingsStringSample(key: "more_section_health", turkish: "SAĞLIK & ARAÇLAR", english: "HEALTH & TOOLS"),
        SettingsStringSample(key: "more_section_notifications", turkish: "BİLDİRİMLER", english: "NOTIFICATIONS"),
        SettingsStringSample(
            key: "more_section_security",
            turkish: "GÜVENLİK & GİZLİLİK",
            english: "SECURITY & PRIVACY"
        ),
        SettingsStringSample(key: "more_section_tracking", turkish: "TAKİP", english: "TRACKING"),
        SettingsStringSample(key: "more_theme_mode", turkish: "Tema modu", english: "Theme mode"),
        SettingsStringSample(key: "more_title", turkish: "Daha Fazla", english: "More"),
        SettingsStringSample(key: "more_trends", turkish: "Analizler & Trendler", english: "Insights & trends"),
        SettingsStringSample(
            key: "more_trends_subtitle",
            turkish: "Kayıtlarındaki örüntüler ve dönem karşılaştırmaları",
            english: "Patterns in your records and period comparisons"
        ),
        SettingsStringSample(key: "profile_birth_date", turkish: "DOĞUM TARİHİ", english: "BIRTH DATE"),
        SettingsStringSample(key: "profile_birth_date_select", turkish: "Tarih seçin", english: "Pick a date"),
        SettingsStringSample(
            key: "profile_caption_report",
            turkish: "Bu bilgiler hekim raporunda gösterilir",
            english: "These details appear in the doctor report"
        ),
        SettingsStringSample(key: "profile_health_notes", turkish: "SAĞLIK NOTLARI", english: "HEALTH NOTES"),
        SettingsStringSample(
            key: "profile_health_notes_placeholder",
            turkish: "Kronik hastalıklar, alerjiler, kullandığın ilaçlar…",
            english: "Chronic conditions, allergies, medications you take…"
        ),
        SettingsStringSample(key: "profile_height", turkish: "BOY", english: "HEIGHT"),
        SettingsStringSample(
            key: "profile_height_invalid",
            turkish: "50 ile 250 cm arasında bir değer girin.",
            english: "Enter a value between 50 and 250 cm."
        ),
        SettingsStringSample(key: "profile_height_placeholder", turkish: "Örn: 170", english: "e.g. 170"),
        SettingsStringSample(key: "profile_height_unit", turkish: "cm", english: "cm"),
        SettingsStringSample(key: "profile_name", turkish: "AD", english: "NAME"),
        SettingsStringSample(key: "profile_name_placeholder", turkish: "Örn: Ayşe", english: "e.g. Ayşe"),
        SettingsStringSample(key: "profile_save", turkish: "Kaydet", english: "Save"),
        SettingsStringSample(key: "profile_save_changes", turkish: "Değişiklikleri Kaydet", english: "Save changes"),
        SettingsStringSample(key: "profile_sex", turkish: "CİNSİYET", english: "SEX"),
        SettingsStringSample(
            key: "profile_sex_cycle_appears",
            turkish: "Regl Takibi, Daha Fazla sekmesine eklenir. Daha önce kaydettiğin regl verilerin "
                + "olduğu gibi durur.",
            english: "Cycle tracking is added to the More tab. Any cycle data you recorded before is "
                + "still there."
        )
    ]
}

enum SettingsSamplesSecond {
    static let all: [SettingsStringSample] = [
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
        SettingsStringSample(key: "reminder_health_title", turkish: "Hatırlatıcı sağlığı", english: "Reminder health"),
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
        SettingsStringSample(key: "settings_about", turkish: "Uygulama hakkında", english: "About the app"),
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
        SettingsStringSample(key: "settings_rate_us", turkish: "Bizi değerlendirin", english: "Rate Salus"),
        SettingsStringSample(
            key: "settings_rate_us_desc",
            turkish: "Görüşünüz Salus'un gelişmesine yardımcı olur",
            english: "Your feedback helps Salus improve"
        ),
        SettingsStringSample(
            key: "settings_reminders_desc",
            turkish: "Hatırlatıcıların çalışma durumunu incele",
            english: "Review how reminders are running"
        ),
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
        SettingsStringSample(key: "theme_dark", turkish: "Koyu", english: "Dark"),
        SettingsStringSample(key: "theme_default_badge", turkish: "Varsayılan", english: "Default"),
        SettingsStringSample(key: "theme_light", turkish: "Açık", english: "Light"),
        SettingsStringSample(key: "theme_section_mode", turkish: "ARAYÜZ MODU", english: "INTERFACE MODE"),
        SettingsStringSample(
            key: "theme_section_palette",
            turkish: "VURGU & RENK PALETİ",
            english: "ACCENT & COLOR PALETTE"
        ),
        SettingsStringSample(
            key: "theme_section_language",
            turkish: "UYGULAMA DİLİ",
            english: "APP LANGUAGE"
        ),
        SettingsStringSample(
            key: "theme_sheet_subtitle",
            turkish: "Seçimler anında uygulanır",
            english: "Choices apply right away"
        ),
        SettingsStringSample(
            key: "theme_sheet_title",
            turkish: "Görünüm ve Dil",
            english: "Appearance and Language"
        ),
        SettingsStringSample(key: "theme_system", turkish: "Sistem", english: "System"),
        SettingsStringSample(key: "reminder_health_status_error", turkish: "Engelli", english: "Blocked"),
        SettingsStringSample(key: "reminder_health_status_ok", turkish: "Tamam", english: "OK"),
        SettingsStringSample(key: "reminder_health_status_warning", turkish: "Sınırlı", english: "Limited")
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
