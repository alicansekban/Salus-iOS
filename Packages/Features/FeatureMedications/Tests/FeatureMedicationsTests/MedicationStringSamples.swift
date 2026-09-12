// The 113-row string table `MedicationsStringsTests` pins, lifted out of the suite so the type
// stays under SwiftLint's 300-line body limit. Nothing else moved: the rows are the ones that were
// in the suite, in the same order, and every assertion still reads them from here.
//
// A `enum` namespace rather than loose file-scope constants, and `MedicationStringSample` is the
// same `Sendable` row type `@Test(arguments:)` needs.

/// Every key `:feature:medications` owns, with both translations, copied from the XML. A new key
/// there means a new row here, in the same commit — that is the whole job of this table. The rows
/// follow the XML's order, grouped by the screen that reads them.
enum MedicationStringSamples {
    static let all: [MedicationStringSample] = [
        // The list screen (14).
        // THE ONE KEY M15 RETIRED ON ANDROID THAT IS KEPT HERE. The system navigation bar labels a
        // pushed screen's back button with the previous screen's `.navigationTitle`, and it is what
        // VoiceOver reads for the root; Compose's custom top bar had no such need, which is why
        // Android could drop the key when the title moved into the content (iOS-M16 Task 7).
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
        MedicationStringSample(key: "medications_no_schedule", turkish: "Plan yok", english: "No schedule"),
        // The M15 header block and its three metric tiles. The overline is stored upper-case and is
        // never `uppercased()` at runtime (spec §6).
        MedicationStringSample(
            key: "medications_overline_today",
            turkish: "BUGÜN • %1$@",
            english: "TODAY • %1$@"
        ),
        MedicationStringSample(
            key: "medications_title_routine",
            turkish: "Tedavi & Rutin",
            english: "Treatment & Routine"
        ),
        MedicationStringSample(
            key: "medications_metric_active",
            turkish: "Aktif ilaç",
            english: "Active medications"
        ),
        MedicationStringSample(
            key: "medications_metric_recorded",
            turkish: "Kaydedilen doz",
            english: "Recorded doses"
        ),
        MedicationStringSample(key: "medications_metric_next", turkish: "Sıradaki doz", english: "Next dose"),
        MedicationStringSample(key: "medications_metric_none", turkish: "—", english: "—"),
        MedicationStringSample(key: "medications_take_now", turkish: "Hemen Al", english: "Take now"),
        MedicationStringSample(
            key: "medications_fab_add",
            turkish: "Yeni İlaç Ekle",
            english: "Add new medication"
        ),
        MedicationStringSample(
            key: "medications_status_as_needed",
            turkish: "İhtiyaç halinde",
            english: "As needed"
        ),
        MedicationStringSample(key: "medications_stock_left", turkish: "Stok: %1$@", english: "Stock: %1$@"),
        // The editor (38).
        MedicationStringSample(key: "editor_title_new", turkish: "Yeni ilaç", english: "New medication"),
        MedicationStringSample(key: "editor_title_edit", turkish: "İlacı düzenle", english: "Edit medication"),
        MedicationStringSample(
            key: "editor_subtitle_new",
            turkish: "Doz saatlerini, tarihleri ve stoğu ayarla",
            english: "Set the dose times, the dates and the stock"
        ),
        MedicationStringSample(
            key: "editor_subtitle_edit",
            turkish: "Doz saatlerini, tarihleri ve stoğu güncelle",
            english: "Update the dose times, the dates and the stock"
        ),
        MedicationStringSample(
            key: "editor_section_basics",
            turkish: "İlaç bilgileri",
            english: "Medication details"
        ),
        MedicationStringSample(key: "editor_section_dates", turkish: "Tarihler", english: "Dates"),
        MedicationStringSample(key: "editor_section_stock", turkish: "Stok takibi", english: "Stock tracking"),
        MedicationStringSample(
            key: "editor_stock_tracking_desc",
            turkish: "Kalan adedi say, azalınca uyar",
            english: "Count what is left and warn when it runs low"
        ),
        MedicationStringSample(key: "editor_name_placeholder", turkish: "örn. Metformin", english: "e.g. Metformin"),
        MedicationStringSample(key: "editor_strength_placeholder", turkish: "örn. 500", english: "e.g. 500"),
        MedicationStringSample(key: "editor_strength_unit_placeholder", turkish: "mg", english: "mg"),
        MedicationStringSample(
            key: "editor_instructions_placeholder",
            turkish: "örn. yemeklerden sonra",
            english: "e.g. after meals"
        ),
        MedicationStringSample(key: "editor_stock_placeholder", turkish: "örn. 30", english: "e.g. 30"),
        MedicationStringSample(key: "editor_stock_threshold_placeholder", turkish: "örn. 10", english: "e.g. 10"),
        MedicationStringSample(key: "editor_start_date_label", turkish: "Başlangıç", english: "Start"),
        MedicationStringSample(key: "editor_end_date_label", turkish: "Bitiş", english: "End"),
        MedicationStringSample(key: "editor_start_date_placeholder", turkish: "Bugün", english: "Today"),
        MedicationStringSample(
            key: "medications_add_dose_time",
            turkish: "Yeni doz saati ekle",
            english: "Add another dose time"
        ),
        MedicationStringSample(key: "editor_save", turkish: "Kaydet", english: "Save"),
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
        // The recurrence kinds (6).
        MedicationStringSample(key: "recurrence_daily", turkish: "Her gün", english: "Every day"),
        MedicationStringSample(key: "recurrence_days_of_week", turkish: "Haftanın günleri", english: "Days of week"),
        // The two short labels the M15 segmented control needs; the long names stay on the cards.
        MedicationStringSample(key: "recurrence_tab_days", turkish: "Belirli günler", english: "Set days"),
        MedicationStringSample(key: "recurrence_tab_interval", turkish: "Aralıklı", english: "Interval"),
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
        // The detail screen (21).
        MedicationStringSample(key: "medication_detail_title", turkish: "İlaç detayı", english: "Medication detail"),
        MedicationStringSample(
            key: "medication_detail_missing",
            turkish: "Bu ilaç artık kayıtlı değil.",
            english: "This medication is no longer saved."
        ),
        MedicationStringSample(key: "medication_detail_instructions", turkish: "Talimatlar", english: "Instructions"),
        MedicationStringSample(key: "medication_detail_stock", turkish: "Kalan", english: "Remaining"),
        MedicationStringSample(key: "medication_detail_history", turkish: "Son 30 gün", english: "Last 30 days"),
        MedicationStringSample(
            key: "medication_detail_history_empty",
            turkish: "Bu ilaç için henüz kayıt yok.",
            english: "No records for this medication yet."
        ),
        MedicationStringSample(key: "medication_detail_edit", turkish: "Düzenle", english: "Edit"),
        MedicationStringSample(
            key: "medication_detail_active_tracking",
            turkish: "Aktif Takip",
            english: "Active tracking"
        ),
        MedicationStringSample(key: "medication_detail_plan", turkish: "Kullanım Planı", english: "Usage plan"),
        MedicationStringSample(
            key: "medication_detail_supply_title",
            turkish: "Kutu & Stok",
            english: "Box & stock"
        ),
        MedicationStringSample(key: "medication_detail_metric_time", turkish: "Doz saati", english: "Dose time"),
        MedicationStringSample(key: "medication_detail_metric_amount", turkish: "Miktar", english: "Amount"),
        MedicationStringSample(key: "medication_detail_rhythm", turkish: "SON 7 GÜN", english: "LAST 7 DAYS"),
        MedicationStringSample(key: "medication_detail_rhythm_none", turkish: "Kayıt yok", english: "No record"),
        MedicationStringSample(
            key: "medication_detail_threshold",
            turkish: "Uyarı eşiği: %1$@",
            english: "Alert at: %1$@"
        ),
        MedicationStringSample(
            key: "medication_detail_record_now",
            turkish: "Dozu Şimdi Kaydet (%1$@)",
            english: "Record dose now (%1$@)"
        ),
        MedicationStringSample(
            key: "medication_detail_delete_medication",
            turkish: "İlacı Sil",
            english: "Delete medication"
        ),
        MedicationStringSample(
            key: "medications_detail_days_of_supply",
            turkish: "≈ %1$lld gün yetecek",
            english: "≈ %1$lld day(s) left"
        ),
        MedicationStringSample(
            key: "medications_detail_per_day",
            turkish: "Günde %1$lld kez",
            english: "%1$lld time(s) a day"
        ),
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
        // The per-medication reminder toggle (3).
        MedicationStringSample(key: "medication_reminders_title", turkish: "Hatırlatıcılar", english: "Reminders"),
        MedicationStringSample(
            key: "medication_reminders_off_desc",
            turkish: "Bildirim gelmez; dozlar Ana Sayfa'da görünmeye ve işaretlenmeye devam eder.",
            english: "No notifications; doses still show on Home and can still be marked."
        ),
        MedicationStringSample(
            key: "medication_reminders_off",
            turkish: "Hatırlatıcılar kapalı",
            english: "Reminders off"
        ),
        // M15 replaced `medication_reminders_on_desc` with this shorter "on" subtitle; the "off"
        // one above is unchanged and still says the doses stay on Home.
        MedicationStringSample(
            key: "medications_detail_reminder_subtitle",
            turkish: "Doz vaktinde hatırlat",
            english: "Remind me at each dose time"
        ),
        // The post-save reminder warning (1).
        MedicationStringSample(
            key: "medication_saved_reminders_blocked_title",
            turkish: "Kaydedildi, ama alarmlar çalışmayabilir",
            english: "Saved, but alarms may not fire"
        )
    ]
}

/// One row of the ported string table: a key and the two translations Android ships for it.
///
/// Flat rather than nested so it can back a `@Test(arguments:)` table, which requires a `Sendable`
/// element type.
struct MedicationStringSample: Sendable {
    let key: String
    let turkish: String
    let english: String
}
