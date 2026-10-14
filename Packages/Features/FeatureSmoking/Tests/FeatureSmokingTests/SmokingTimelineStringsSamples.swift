// The health timeline's keys (`smoking_timeline_*`), copied from
// `feature/smoking/src/main/res/values{,-en}/strings.xml` on branch `feature/m17-smoking-cessation`
// (iOS-M17 Task 13). Its own table so the screen's rows do not interleave with the others'.
//
// Java's `%1$d` is `%1$lld` here. The fixed strings (disclaimer, "counting again", the combustion
// note) and the two attributions are the words of `docs/contracts/smoking-health-stages.md`, which
// both platforms ship verbatim; the ten stage titles and statements are pinned in
// ``SmokingMainStringTable``.

enum SmokingTimelineStringTable {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_timeline_title",
            turkish: "Sağlık takvimi",
            english: "Health timeline"
        ),
        SmokingStringSample(
            key: "smoking_timeline_overline",
            turkish: "VÜCUDUNUN İYİLEŞME TAKVİMİ",
            english: "YOUR BODY'S RECOVERY TIMELINE"
        ),
        SmokingStringSample(
            key: "smoking_timeline_reduce_title",
            turkish: "Bıraktığında seni bekleyenler",
            english: "What's waiting for you when you quit"
        ),
        SmokingStringSample(
            key: "smoking_timeline_done_label",
            turkish: "TAMAMLANAN",
            english: "COMPLETED"
        ),
        SmokingStringSample(
            key: "smoking_timeline_next_label",
            turkish: "SIRADAKİ EŞİK",
            english: "NEXT THRESHOLD"
        ),
        SmokingStringSample(
            key: "smoking_timeline_count",
            turkish: "%1$lld / %2$lld",
            english: "%1$lld / %2$lld"
        ),
        SmokingStringSample(
            key: "smoking_timeline_switch",
            turkish: "Bırakma moduna geç",
            english: "Switch to quit mode"
        ),
        SmokingStringSample(
            key: "smoking_timeline_counting_again",
            turkish: "Yeniden sayılıyor",
            english: "Counting again"
        ),
        SmokingStringSample(
            key: "smoking_timeline_combustion_only",
            turkish: "Yanmalı tütün için tanımlıdır",
            english: "Defined for combustible tobacco"
        ),
        SmokingStringSample(
            key: "smoking_timeline_disclaimer",
            turkish: "Bu bilgiler genel sağlık verilerine dayanır, tıbbi tavsiye değildir. "
                + "Bırakma sürecinde hekiminize danışın.",
            english: "This information is based on general public-health data and is not medical advice. "
                + "Talk to your doctor about quitting."
        ),
        SmokingStringSample(
            key: "smoking_timeline_source_who",
            turkish: "WHO",
            english: "WHO"
        ),
        SmokingStringSample(
            key: "smoking_timeline_source_nhs",
            turkish: "NHS",
            english: "NHS"
        ),
        SmokingStringSample(
            key: "smoking_timeline_attribution_who",
            turkish: "Kaynak: Dünya Sağlık Örgütü (WHO), Tütün: sigarayı bırakmanın sağlık yararları "
                + "(Tobacco: Health benefits of smoking cessation), 2020.",
            english: "Source: World Health Organization (WHO), Tobacco: Health benefits of smoking cessation, 2020."
        ),
        SmokingStringSample(
            key: "smoking_timeline_attribution_nhs",
            turkish: "Kaynak: NHS (Birleşik Krallık Ulusal Sağlık Hizmeti), Quit smoking, Better Health, 2026.",
            english: "Source: NHS, Quit smoking, Better Health, 2026."
        ),
        SmokingStringSample(
            key: "smoking_timeline_state_done",
            turkish: "Tamamlandı",
            english: "Completed"
        ),
        SmokingStringSample(
            key: "smoking_timeline_state_in_progress",
            turkish: "Sürüyor",
            english: "In progress"
        ),
        SmokingStringSample(
            key: "smoking_timeline_state_pending",
            turkish: "Bekliyor",
            english: "Waiting"
        )
    ]
}
