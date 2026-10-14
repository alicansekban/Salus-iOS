// The REDUCE main screen's keys (plus the quit-date refusal it shows), copied from
// `feature/smoking/src/main/res/values{,-en}/strings.xml` on branch `feature/m17-smoking-cessation`
// (iOS-M17 Task 11), in the placeholder mapping `SmokingStringsTests` documents. Its own table so
// this task's rows do not interleave with the other screens'.

enum SmokingReduceStringTable {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_quit_error_overlap",
            turkish: "Bu zaman, önceki denemenin bittiği andan önce olamaz.",
            english: "That time can't be before your previous attempt ended."
        ),
        SmokingStringSample(
            key: "smoking_reduce_added",
            turkish: "1 adet eklendi",
            english: "1 added"
        ),
        SmokingStringSample(
            key: "smoking_reduce_at_body",
            turkish: "Bugünkü kotanı tamamladın. Bir sonraki istekte “Canım çekti”ye dokunup "
                + "birkaç dakika bekleyebilirsin.",
            english: "You've used today's allowance. When the next urge comes, tap \"I have a craving\" "
                + "and give it a few minutes."
        ),
        SmokingStringSample(
            key: "smoking_reduce_at_title",
            turkish: "Günü limitinde tuttun",
            english: "Right at your limit"
        ),
        SmokingStringSample(
            key: "smoking_reduce_chart_baseline",
            turkish: "Eski ortalaman: %lld",
            english: "Your old average: %lld"
        ),
        SmokingStringSample(
            key: "smoking_reduce_chart_cd",
            turkish: "Son 7 günün günlük adetleri: %1$@",
            english: "Daily counts for the last 7 days: %1$@"
        ),
        SmokingStringSample(
            key: "smoking_reduce_chart_day_value",
            turkish: "%1$@ %2$@",
            english: "%1$@ %2$@"
        ),
        SmokingStringSample(
            key: "smoking_reduce_chart_no_data",
            turkish: "veri yok",
            english: "no data"
        ),
        SmokingStringSample(
            key: "smoking_reduce_chart_title",
            turkish: "Son 7 gün",
            english: "Last 7 days"
        ),
        SmokingStringSample(
            key: "smoking_reduce_empty_body",
            turkish: "Bugün henüz kayıt yok. Günlük limitin %lld adet.",
            english: "Nothing logged yet today. Your daily limit is %lld."
        ),
        SmokingStringSample(
            key: "smoking_reduce_empty_title",
            turkish: "Hafif ve temiz",
            english: "Light and clean"
        ),
        SmokingStringSample(
            key: "smoking_reduce_none_today",
            turkish: "Bugün hiç içmedim",
            english: "I had none today"
        ),
        SmokingStringSample(
            key: "smoking_reduce_over_baseline",
            turkish: "Eski ortalamana göre hâlâ %lld adet daha azsın.",
            english: "You're still %lld below your old average."
        ),
        SmokingStringSample(
            key: "smoking_reduce_over_body",
            turkish: "Limitin %lld adet üzerindesin, ama moral bozmaya gerek yok. "
                + "Küçük sapmalar sürecin doğal bir parçası.",
            english: "You're %lld over your limit, and that's okay. Small slips are a normal part of the process."
        ),
        SmokingStringSample(
            key: "smoking_reduce_over_chip",
            turkish: "+%lld",
            english: "+%lld"
        ),
        SmokingStringSample(
            key: "smoking_reduce_over_chip_cd",
            turkish: "Limitin %lld adet üzerinde",
            english: "%lld over the limit"
        ),
        SmokingStringSample(
            key: "smoking_reduce_over_title",
            turkish: "Bugün biraz fazla oldu",
            english: "A bit more than planned today"
        ),
        SmokingStringSample(
            key: "smoking_reduce_overline",
            turkish: "BUGÜN",
            english: "TODAY"
        ),
        SmokingStringSample(
            key: "smoking_reduce_plus_one",
            turkish: "+1",
            english: "+1"
        ),
        SmokingStringSample(
            key: "smoking_reduce_plus_one_cd",
            turkish: "1 adet ekle",
            english: "Add one"
        ),
        SmokingStringSample(
            key: "smoking_reduce_ready",
            turkish: "Bırakmaya hazırım",
            english: "I'm ready to quit"
        ),
        SmokingStringSample(
            key: "smoking_reduce_ring_limit",
            turkish: " / %lld",
            english: " / %lld"
        ),
        SmokingStringSample(
            key: "smoking_reduce_ring_semantics",
            turkish: "Bugün %1$lld adet, limit %2$lld",
            english: "Today %1$lld, limit %2$lld"
        ),
        SmokingStringSample(
            key: "smoking_reduce_timeline_body",
            turkish: "Bu aşamalar, bıraktığın andan itibaren saymaya başlar.",
            english: "These stages start counting from the moment you quit."
        ),
        SmokingStringSample(
            key: "smoking_reduce_timeline_title",
            turkish: "Bıraktığında seni bekleyenler",
            english: "What's waiting for you when you quit"
        ),
        SmokingStringSample(
            key: "smoking_reduce_under_body",
            turkish: "Bugün için %lld adetlik hakkın kaldı.",
            english: "%lld left for today."
        ),
        SmokingStringSample(
            key: "smoking_reduce_under_title",
            turkish: "Limitin içindesin",
            english: "You're within your limit"
        ),
        SmokingStringSample(
            key: "smoking_reduce_week_full",
            turkish: "Bu hafta %1$lld adet daha az · %2$@ cebinde kaldı",
            english: "%1$lld fewer this week · %2$@ stays in your pocket"
        ),
        SmokingStringSample(
            key: "smoking_reduce_week_money",
            turkish: "Bu hafta %@ cebinde kaldı",
            english: "%@ stays in your pocket this week"
        ),
        SmokingStringSample(
            key: "smoking_reduce_week_none",
            turkish: "Bu hafta henüz gösterecek bir azalma yok",
            english: "No reduction to show for this week yet"
        )
    ]
}
