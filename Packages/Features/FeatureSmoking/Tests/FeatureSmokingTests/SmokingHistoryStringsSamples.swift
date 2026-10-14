// The history screen's keys (`smoking_history_*`), copied from
// `feature/smoking/src/main/res/values{,-en}/strings.xml` on branch `feature/m17-smoking-cessation`
// (iOS-M17 Task 14). Its own table so the screen's rows do not interleave with the others'.
//
// Java's `%1$s` / `%1$d` / `%d` are `%1$@` / `%1$lld` / `%lld` here; the four `<plurals>` are split
// into a general key and a `_one` twin chosen by count (spec 9 (h)), so Turkish carries the same
// text in both and English tells one day from several.

enum SmokingHistoryStringTable {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_history_title",
            turkish: "Geçmiş",
            english: "History"
        ),
        SmokingStringSample(
            key: "smoking_history_journey_overline",
            turkish: "TOPLAM YOLCULUK",
            english: "TOTAL JOURNEY"
        ),
        SmokingStringSample(
            key: "smoking_history_attempts_title",
            turkish: "Denemeler",
            english: "Attempts"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_title",
            turkish: "%1$lld. deneme",
            english: "Attempt %1$lld"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_active",
            turkish: "Devam ediyor",
            english: "In progress"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_longest",
            turkish: "En uzun seri",
            english: "Longest streak"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_under_day",
            turkish: "1 günden kısa",
            english: "Under a day"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_range",
            turkish: "%1$@ – %2$@",
            english: "%1$@ – %2$@"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_range_open",
            turkish: "%1$@ – şimdi",
            english: "%1$@ – now"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_no_slips",
            turkish: "Kayma yok",
            english: "No slips"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_saved",
            turkish: "Biriken: %1$@",
            english: "Saved: %1$@"
        ),
        SmokingStringSample(
            key: "smoking_history_support_title",
            turkish: "Yolculuk düz bir çizgi değil",
            english: "A journey is not a straight line"
        ),
        SmokingStringSample(
            key: "smoking_history_support_body",
            turkish: "Bir duraksama, daha önce geçirdiğin günleri silmez. Kaldığın yerden devam edebilirsin.",
            english: "A pause does not erase the days you had before it. You can pick up from where you are."
        ),
        SmokingStringSample(
            key: "smoking_history_log_title",
            turkish: "Günlük kayıtlar",
            english: "Daily log"
        ),
        SmokingStringSample(
            key: "smoking_history_day_today",
            turkish: "Bugün",
            english: "Today"
        ),
        SmokingStringSample(
            key: "smoking_history_day_yesterday",
            turkish: "Dün",
            english: "Yesterday"
        ),
        SmokingStringSample(
            key: "smoking_history_row_smoked",
            turkish: "%1$lld adet içildi",
            english: "%1$lld smoked"
        ),
        SmokingStringSample(
            key: "smoking_history_row_none",
            turkish: "Hiç içilmedi",
            english: "None smoked"
        ),
        SmokingStringSample(
            key: "smoking_history_row_craving",
            turkish: "Kriz atlatıldı",
            english: "Craving resisted"
        ),
        SmokingStringSample(
            key: "smoking_history_row_intensity",
            turkish: "Şiddet %1$lld/5",
            english: "Intensity %1$lld/5"
        ),
        SmokingStringSample(
            key: "smoking_history_empty_title",
            turkish: "Henüz bir kayıt yok",
            english: "No entries yet"
        ),
        SmokingStringSample(
            key: "smoking_history_empty_body",
            turkish: "Atlattığın krizler ve içtiğin sigaralar burada zaman sırasıyla listelenir. Yolculuğun ilk "
                + "anındasın.",
            english: "The cravings you beat and the cigarettes you smoke are listed here in time order. You are "
                + "at the very start of your journey."
        ),
        SmokingStringSample(
            key: "smoking_history_empty_how_title",
            turkish: "Kayıt nasıl oluşur?",
            english: "How do entries appear?"
        ),
        SmokingStringSample(
            key: "smoking_history_empty_how_craving",
            turkish: "Kriz ekranında “Geçti”ye bastığında bir kriz kaydı eklenir.",
            english: "Tapping “It passed” on the craving screen adds a craving entry."
        ),
        SmokingStringSample(
            key: "smoking_history_empty_how_smoked",
            turkish: "İçtiğin sigaraları ana ekrandan ekleyebilirsin.",
            english: "You can add the cigarettes you smoke from the main screen."
        ),
        SmokingStringSample(
            key: "smoking_history_empty_back",
            turkish: "Ana ekrana dön",
            english: "Back to the main screen"
        ),
        SmokingStringSample(
            key: "smoking_history_edit_title",
            turkish: "Kaydı düzenle",
            english: "Edit entry"
        ),
        SmokingStringSample(
            key: "smoking_history_edit_time",
            turkish: "Saat",
            english: "Time"
        ),
        SmokingStringSample(
            key: "smoking_history_edit_marker_hint",
            turkish: "0, o gün hiç içilmediği anlamına gelir.",
            english: "0 means nothing was smoked that day."
        ),
        SmokingStringSample(
            key: "smoking_history_edit_delete",
            turkish: "Kaydı sil",
            english: "Delete entry"
        ),
        SmokingStringSample(
            key: "smoking_history_delete_title",
            turkish: "Bu kayıt silinsin mi?",
            english: "Delete this entry?"
        ),
        SmokingStringSample(
            key: "smoking_history_delete_message",
            turkish: "Silinen kayıt geri alınamaz. Hesaplar buna göre güncellenir.",
            english: "A deleted entry cannot be restored. Your figures update to match."
        ),
        SmokingStringSample(
            key: "smoking_history_error_future",
            turkish: "Kayıt zamanı şu andan ileride olamaz.",
            english: "The entry time cannot be in the future."
        ),
        SmokingStringSample(
            key: "smoking_history_error_invalid",
            turkish: "Bu değişiklik kaydedilemedi. Bilgileri kontrol edip tekrar dene.",
            english: "That change could not be saved. Check the details and try again."
        ),
        SmokingStringSample(
            key: "smoking_history_journey_days",
            turkish: "%lld günlük süreç",
            english: "%lld-day journey"
        ),
        SmokingStringSample(
            key: "smoking_history_journey_days_one",
            turkish: "%lld günlük süreç",
            english: "%lld-day journey"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_days",
            turkish: "%lld gün",
            english: "%lld days"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_days_one",
            turkish: "%lld gün",
            english: "%lld day"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_slips",
            turkish: "%lld kayma",
            english: "%lld slips"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_slips_one",
            turkish: "%lld kayma",
            english: "%lld slip"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_cravings",
            turkish: "%lld kriz atlatıldı",
            english: "%lld cravings resisted"
        ),
        SmokingStringSample(
            key: "smoking_history_attempt_cravings_one",
            turkish: "%lld kriz atlatıldı",
            english: "%lld craving resisted"
        )
    ]
}
