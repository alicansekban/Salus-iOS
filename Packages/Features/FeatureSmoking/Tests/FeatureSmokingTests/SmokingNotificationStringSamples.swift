// The milestone-notification keys (the stage titles they quote are the main screen's), copied
// from `feature/smoking/src/main/res/values{,-en}/strings.xml` on branch `feature/m17-smoking-cessation`
// (iOS-M17 Task 17). Its own table so the reminder task's rows do not interleave with the screens'.
//
// Java's `%1$s` / `%d` are `%1$@` / `%lld` here; the two `<plurals>` are split into a general key
// and a `_one` twin chosen by count (spec 9 (h), the M14 (e) precedent), so Turkish carries the same
// text in both and English tells one day from several.

enum SmokingNotificationStringTable {
    static let samples: [SmokingStringSample] = notificationStrings

    static let notificationStrings: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_notification_stage",
            turkish: "Yeni aşama: %1$@",
            english: "New stage: %1$@"
        ),
        SmokingStringSample(
            key: "smoking_notification_days",
            turkish: "%lld gün oldu!",
            english: "It's been %lld days!"
        ),
        SmokingStringSample(
            key: "smoking_notification_days_one",
            turkish: "%lld gün oldu!",
            english: "It's been %lld day!"
        ),
        SmokingStringSample(
            key: "smoking_notification_years",
            turkish: "%lld yıl oldu!",
            english: "It's been %lld years!"
        ),
        SmokingStringSample(
            key: "smoking_notification_years_one",
            turkish: "%lld yıl oldu!",
            english: "It's been %lld year!"
        ),
        SmokingStringSample(
            key: "smoking_notification_units",
            turkish: "%1$@ adet içmedin",
            english: "%1$@ units skipped"
        ),
        SmokingStringSample(
            key: "smoking_notification_money",
            turkish: "%1$@ biriktirdin",
            english: "You've saved %1$@"
        ),
        SmokingStringSample(
            key: "smoking_notification_stage_hint",
            turkish: "Takvimde görmek için dokun.",
            english: "Tap to see it on your timeline."
        ),
        SmokingStringSample(
            key: "smoking_notification_cheer",
            turkish: "Harika gidiyorsun.",
            english: "You're doing great."
        ),
        SmokingStringSample(
            key: "smoking_notification_evening_title",
            turkish: "Bugünü kaydetmek ister misin?",
            english: "Log today?"
        ),
        SmokingStringSample(
            key: "smoking_notification_evening_text",
            turkish: "Bugün kaç adet içtiğini ekleyebilirsin. Hiç içmediysen onu da kaydedebilirsin.",
            english: "Add how many you had today, or log that you had none."
        )
    ]
}
