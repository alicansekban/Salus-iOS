// The settings screen's and its sheets' keys (`smoking_settings_*`), copied from
// `feature/smoking/src/main/res/values{,-en}/strings.xml` on branch `feature/m17-smoking-cessation`
// (iOS-M17 Task 14). Its own table so the screen's rows do not interleave with the others'.
//
// Java's `%1$s` / `%1$d` / `%d` are `%1$@` / `%1$lld` / `%lld` here; the settings keys have no
// plurals.

enum SmokingSettingsStringTable {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_settings_title",
            turkish: "Sigara ayarları",
            english: "Smoking settings"
        ),
        SmokingStringSample(
            key: "smoking_settings_section_habit",
            turkish: "ALIŞKANLIK & HEDEFLER",
            english: "HABIT & GOALS"
        ),
        SmokingStringSample(
            key: "smoking_settings_section_notifications",
            turkish: "BİLDİRİMLER",
            english: "NOTIFICATIONS"
        ),
        SmokingStringSample(
            key: "smoking_settings_section_mode",
            turkish: "MOD YÖNETİMİ",
            english: "MODE"
        ),
        SmokingStringSample(
            key: "smoking_settings_section_data",
            turkish: "VERİ & SIFIRLAMA",
            english: "DATA & RESET"
        ),
        SmokingStringSample(
            key: "smoking_settings_price",
            turkish: "Fiyatı güncelle",
            english: "Update price"
        ),
        SmokingStringSample(
            key: "smoking_settings_price_value",
            turkish: "%1$@ / adet",
            english: "%1$@ / unit"
        ),
        SmokingStringSample(
            key: "smoking_settings_price_value_vape",
            turkish: "%1$@ / gün",
            english: "%1$@ / day"
        ),
        SmokingStringSample(
            key: "smoking_settings_currency",
            turkish: "Para birimi",
            english: "Currency"
        ),
        SmokingStringSample(
            key: "smoking_settings_limit",
            turkish: "Günlük limit",
            english: "Daily limit"
        ),
        SmokingStringSample(
            key: "smoking_settings_limit_value",
            turkish: "%1$lld adet",
            english: "%1$lld units"
        ),
        SmokingStringSample(
            key: "smoking_settings_quit_date",
            turkish: "Bırakma tarihi",
            english: "Quit date"
        ),
        SmokingStringSample(
            key: "smoking_settings_reason",
            turkish: "Nedenim",
            english: "My reason"
        ),
        SmokingStringSample(
            key: "smoking_settings_reason_value",
            turkish: "“%1$@”",
            english: "“%1$@”"
        ),
        SmokingStringSample(
            key: "smoking_settings_reason_empty",
            turkish: "Eklenmedi",
            english: "Not added"
        ),
        SmokingStringSample(
            key: "smoking_settings_notifications",
            turkish: "Bildirimler",
            english: "Notifications"
        ),
        SmokingStringSample(
            key: "smoking_settings_notifications_desc",
            turkish: "İyileşme aşamaları ve kilometre taşları",
            english: "Recovery stages and milestones"
        ),
        SmokingStringSample(
            key: "smoking_settings_evening",
            turkish: "Akşam hatırlatması · 20:30",
            english: "Evening reminder · 20:30"
        ),
        SmokingStringSample(
            key: "smoking_settings_evening_desc",
            turkish: "Günün kaydını tutmanı hatırlatır",
            english: "Reminds you to log your day"
        ),
        SmokingStringSample(
            key: "smoking_settings_switch_to_reduce",
            turkish: "Azaltma moduna geç",
            english: "Switch to reducing"
        ),
        SmokingStringSample(
            key: "smoking_settings_switch_to_reduce_desc",
            turkish: "Bırakma denemen geçmişte kalır, kayıtların silinmez.",
            english: "Your quit attempt stays in your history and no entry is deleted."
        ),
        SmokingStringSample(
            key: "smoking_settings_switch_to_quit",
            turkish: "Bırakma moduna geç",
            english: "Switch to quitting"
        ),
        SmokingStringSample(
            key: "smoking_settings_switch_to_quit_desc",
            turkish: "Azaltma kayıtların silinmez, yeni bir deneme başlar.",
            english: "Your reducing entries are kept and a new attempt begins."
        ),
        SmokingStringSample(
            key: "smoking_settings_reset",
            turkish: "Takibi sıfırla",
            english: "Reset tracking"
        ),
        SmokingStringSample(
            key: "smoking_settings_reset_desc",
            turkish: "Tüm kayıtlar silinir ve geri alınamaz.",
            english: "Every entry is deleted and cannot be restored."
        ),
        SmokingStringSample(
            key: "smoking_settings_save",
            turkish: "Kaydet",
            english: "Save"
        ),
        SmokingStringSample(
            key: "smoking_settings_price_sheet_title",
            turkish: "Fiyatı güncelle",
            english: "Update price"
        ),
        SmokingStringSample(
            key: "smoking_settings_price_note",
            turkish: "Yeni fiyat bugünden itibaren geçerli olur. Geçmiş günler eski fiyatla hesaplanır.",
            english: "The new price applies from today. Earlier days keep the price they had."
        ),
        SmokingStringSample(
            key: "smoking_settings_limit_sheet_title",
            turkish: "Günlük limit",
            english: "Daily limit"
        ),
        SmokingStringSample(
            key: "smoking_settings_reduce_sheet_title",
            turkish: "Azaltma moduna geç",
            english: "Switch to reducing"
        ),
        SmokingStringSample(
            key: "smoking_settings_reduce_sheet_confirm",
            turkish: "Azaltmaya başla",
            english: "Start reducing"
        ),
        SmokingStringSample(
            key: "smoking_settings_currency_sheet_title",
            turkish: "Para birimi",
            english: "Currency"
        ),
        SmokingStringSample(
            key: "smoking_settings_reason_sheet_title",
            turkish: "Nedenin",
            english: "Your reason"
        ),
        SmokingStringSample(
            key: "smoking_settings_reason_label",
            turkish: "NEDENİN (İSTEĞE BAĞLI)",
            english: "YOUR REASON (OPTIONAL)"
        ),
        SmokingStringSample(
            key: "smoking_settings_reason_hint",
            turkish: "Zor anlarda sana bunu hatırlatacağız. Yalnızca bu cihazda kalır.",
            english: "We will remind you of this in hard moments. It stays on this device."
        ),
        SmokingStringSample(
            key: "smoking_settings_confirm_change",
            turkish: "Değiştir",
            english: "Change"
        ),
        SmokingStringSample(
            key: "smoking_settings_currency_confirm_title",
            turkish: "Para birimi değişsin mi?",
            english: "Change the currency?"
        ),
        SmokingStringSample(
            key: "smoking_settings_currency_confirm_message",
            turkish: "Tutarlar dönüştürülmez, yalnızca para birimi değişir. Biriktirdiğin tutar aynı sayıyla "
                + "kalır.",
            english: "Amounts are not converted, only the currency changes. The amount you saved stays the same "
                + "number."
        ),
        SmokingStringSample(
            key: "smoking_settings_quit_date_confirm_title",
            turkish: "Bırakma tarihi değişsin mi?",
            english: "Change the quit date?"
        ),
        SmokingStringSample(
            key: "smoking_settings_quit_date_confirm_message",
            turkish: "Yeni tarihten önce kaydedilmiş kaymalar bu denemeye sayılmaz.",
            english: "Slips recorded before the new date no longer count toward this attempt."
        ),
        SmokingStringSample(
            key: "smoking_settings_reset_confirm_title",
            turkish: "Takip sıfırlansın mı?",
            english: "Reset tracking?"
        ),
        SmokingStringSample(
            key: "smoking_settings_reset_confirm_message",
            turkish: "Tüm denemelerin, kayıtların ve fiyat geçmişin silinir. Bu işlem geri alınamaz.",
            english: "All your attempts, entries and price history are deleted. This cannot be undone."
        ),
        SmokingStringSample(
            key: "smoking_settings_reset_confirm",
            turkish: "Sıfırla",
            english: "Reset"
        ),
        SmokingStringSample(
            key: "smoking_settings_error_overlap",
            turkish: "Bu zaman önceki denemenle çakışıyor. Daha geç bir zaman seç.",
            english: "That time overlaps your previous attempt. Pick a later time."
        )
    ]
}
