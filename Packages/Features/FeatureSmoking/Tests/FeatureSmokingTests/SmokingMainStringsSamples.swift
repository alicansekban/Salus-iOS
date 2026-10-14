// The main screen's, the slip sheet's, the trigger sheet's and the health stages' keys, with both
// translations, copied from the XML on branch `feature/m17-smoking-cessation`
// (`feature/smoking/src/main/res/values{,-en}/strings.xml`), in the same placeholder mapping
// `SmokingStringsTests` documents. Android's two `<plurals>` (`smoking_hero_days`, `smoking_slips`)
// are each a pair here: the general key carries the `other` item, the `_one` key the `one` item
// (spec §9 (h)). A new key there means a new row here, in the same commit.
//
// Two types, split on the key order, for the reason `SmokingStringTableTail` is: 78 rows put one
// type past SwiftLint's 300-line `type_body_length`.

enum SmokingMainStringTable {
    static let samples: [SmokingStringSample] = first + SmokingMainStringTableTail.samples

    private static let first: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_action_craving",
            turkish: "Canım çekti",
            english: "I have a craving"
        ),
        SmokingStringSample(
            key: "smoking_action_smoked",
            turkish: "Sigara içtim",
            english: "I smoked"
        ),
        SmokingStringSample(
            key: "smoking_caption_cravings",
            turkish: "İstek geldiğinde buradayız",
            english: "We're here when a craving comes"
        ),
        SmokingStringSample(
            key: "smoking_caption_not_smoked",
            turkish: "İlk sigara pas geçilmek üzere",
            english: "Your first one is about to be skipped"
        ),
        SmokingStringSample(
            key: "smoking_caption_regained",
            turkish: "Her dakika sayılıyor",
            english: "Every minute counts"
        ),
        SmokingStringSample(
            key: "smoking_caption_saved",
            turkish: "Birikim yeni başlıyor",
            english: "Your savings are just starting"
        ),
        SmokingStringSample(
            key: "smoking_hero_days",
            turkish: "%lld gün",
            english: "%lld days"
        ),
        SmokingStringSample(
            key: "smoking_hero_days_one",
            turkish: "%lld gün",
            english: "%lld day"
        ),
        SmokingStringSample(
            key: "smoking_hero_hours",
            turkish: "%lld saat",
            english: "%lld h"
        ),
        SmokingStringSample(
            key: "smoking_hero_hours_minutes",
            turkish: "%1$lld saat · %2$lld dakika",
            english: "%1$lld h · %2$lld min"
        ),
        SmokingStringSample(
            key: "smoking_hero_min_sec",
            turkish: "%1$lld dk %2$lld sn",
            english: "%1$lld min %2$lld s"
        ),
        SmokingStringSample(
            key: "smoking_hero_minutes",
            turkish: "%lld dakika",
            english: "%lld min"
        ),
        SmokingStringSample(
            key: "smoking_hero_overline",
            turkish: "SİGARASIZ",
            english: "SMOKE-FREE"
        ),
        SmokingStringSample(
            key: "smoking_hero_semantics",
            turkish: "%1$@ sigarasız",
            english: "%1$@ smoke-free"
        ),
        SmokingStringSample(
            key: "smoking_main_history_cd",
            turkish: "Geçmiş",
            english: "History"
        ),
        SmokingStringSample(
            key: "smoking_main_settings_cd",
            turkish: "Ayarlar",
            english: "Settings"
        ),
        SmokingStringSample(
            key: "smoking_metric_cravings",
            turkish: "atlatılan kriz",
            english: "cravings beaten"
        ),
        SmokingStringSample(
            key: "smoking_metric_none",
            turkish: "—",
            english: "—"
        ),
        SmokingStringSample(
            key: "smoking_metric_not_smoked",
            turkish: "içilmeyen sigara",
            english: "cigarettes not smoked"
        ),
        SmokingStringSample(
            key: "smoking_metric_not_smoked_heated",
            turkish: "içilmeyen stick",
            english: "sticks not used"
        ),
        SmokingStringSample(
            key: "smoking_metric_not_smoked_vape",
            turkish: "içilmeyen gün",
            english: "days without"
        ),
        SmokingStringSample(
            key: "smoking_metric_regained",
            turkish: "geri kazanılan süre",
            english: "time regained"
        ),
        SmokingStringSample(
            key: "smoking_metric_saved",
            turkish: "biriktirdin",
            english: "saved"
        ),
        SmokingStringSample(
            key: "smoking_metric_today",
            turkish: "+%lld bugün",
            english: "+%lld today"
        ),
        SmokingStringSample(
            key: "smoking_regained_days_hours",
            turkish: "%1$lld gün %2$lld saat",
            english: "%1$lld d %2$lld h"
        ),
        SmokingStringSample(
            key: "smoking_regained_hours_minutes",
            turkish: "%1$lld saat %2$lld dk",
            english: "%1$lld h %2$lld min"
        ),
        SmokingStringSample(
            key: "smoking_regained_minutes",
            turkish: "%lld dk",
            english: "%lld min"
        ),
        SmokingStringSample(
            key: "smoking_since_last",
            turkish: "Son sigaradan beri %1$@",
            english: "Since your last smoke: %1$@"
        ),
        SmokingStringSample(
            key: "smoking_slip_body",
            turkish: "Tek bir sigara, kat ettiğin yolu silmez.",
            english: "One cigarette does not erase the road you have covered."
        ),
        SmokingStringSample(
            key: "smoking_slip_confirm",
            turkish: "Devam et",
            english: "Continue"
        ),
        SmokingStringSample(
            key: "smoking_slip_continue",
            turkish: "Kaymaydı, devam ediyorum",
            english: "It was a slip — I'm continuing"
        ),
        SmokingStringSample(
            key: "smoking_slip_continue_desc",
            turkish: "Sayacın korunur",
            english: "Your counter is kept"
        ),
        SmokingStringSample(
            key: "smoking_slip_dismiss",
            turkish: "Şimdilik kapat",
            english: "Not now"
        ),
        SmokingStringSample(
            key: "smoking_slip_restart",
            turkish: "Yeniden başlıyorum",
            english: "I'm starting over"
        ),
        SmokingStringSample(
            key: "smoking_slip_restart_desc",
            turkish: "Bu deneme geçmişe kaydedilir",
            english: "This attempt is saved to your history"
        ),
        SmokingStringSample(
            key: "smoking_slip_title",
            turkish: "Olur böyle şeyler",
            english: "These things happen"
        ),
        SmokingStringSample(
            key: "smoking_slip_units_label",
            turkish: "Kaç adet?",
            english: "How many?"
        ),
        SmokingStringSample(
            key: "smoking_slip_units_unit",
            turkish: "adet",
            english: "pcs"
        ),
        SmokingStringSample(
            key: "smoking_slips",
            turkish: "%lld kayma",
            english: "%lld slips"
        )
    ]
}

enum SmokingMainStringTableTail {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_slips_one",
            turkish: "%lld kayma",
            english: "%lld slip"
        ),
        SmokingStringSample(
            key: "smoking_stage_card_overline",
            turkish: "SIRADAKİ AŞAMA",
            english: "NEXT STAGE"
        ),
        SmokingStringSample(
            key: "smoking_stage_card_percent",
            turkish: "%%%lld",
            english: "%lld%%"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_10y_statement",
            turkish: "Akciğer kanseri riski, sigara içen bir kişininkinin yaklaşık yarısına düşer.",
            english: "The risk of lung cancer falls to about half that of a person who smokes."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_10y_title",
            turkish: "10 yıl · Akciğer kanseri riski",
            english: "10 years · Lung cancer risk"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_12h_statement",
            turkish: "Kandaki karbonmonoksit düzeyi normale iner.",
            english: "The carbon monoxide level in the blood drops to normal."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_12h_title",
            turkish: "12 saat · Kandaki karbonmonoksit",
            english: "12 hours · Blood carbon monoxide"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_15y_statement",
            turkish: "Koroner kalp hastalığı riski, sigara içmeyen bir kişininkiyle aynı düzeydedir.",
            english: "The risk of coronary heart disease is that of a non-smoker."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_15y_title",
            turkish: "15 yıl · Koroner kalp hastalığı riski",
            english: "15 years · Coronary heart disease risk"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_1mo_statement",
            turkish: "Öksürük ve nefes darlığı azalır (1–9 ay).",
            english: "Coughing and shortness of breath decrease (1–9 months)."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_1mo_title",
            turkish: "1 ay · Öksürük ve nefes darlığı",
            english: "1 month · Cough and shortness of breath"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_1y_statement",
            turkish: "Koroner kalp hastalığı riski, sigara içen bir kişininkinin yaklaşık yarısıdır.",
            english: "The risk of coronary heart disease is about half that of a person who smokes."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_1y_title",
            turkish: "1 yıl · Koroner kalp hastalığı riski",
            english: "1 year · Coronary heart disease risk"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_20m_statement",
            turkish: "Nabız ve tansiyon düşer.",
            english: "Heart rate and blood pressure drop."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_20m_title",
            turkish: "20 dakika · Nabız ve tansiyon",
            english: "20 minutes · Heart rate and blood pressure"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_2w_statement",
            turkish: "Dolaşım düzelir ve akciğer işlevi artar (2–12 hafta).",
            english: "Circulation improves and lung function increases (2–12 weeks)."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_2w_title",
            turkish: "2 hafta · Dolaşım ve akciğer işlevi",
            english: "2 weeks · Circulation and lung function"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_48h_statement",
            turkish: "Akciğerlerdeki balgam temizlenir, tat ve koku duyuları gelişir.",
            english: "The lungs clear out mucus, and the senses of taste and smell improve."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_48h_title",
            turkish: "48 saat · Tat ve koku",
            english: "48 hours · Taste and smell"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_5y_statement",
            turkish: "İnme riski, bırakmanın üzerinden 5 ila 15 yıl geçtikten "
                + "sonra sigara içmeyen bir kişininkine düşer.",
            english: "Stroke risk is reduced to that of a non-smoker 5 to 15 years after quitting."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_5y_title",
            turkish: "5 yıl · İnme riski",
            english: "5 years · Stroke risk"
        ),
        SmokingStringSample(
            key: "smoking_stage_h_72h_statement",
            turkish: "Bronşlar gevşemeye başladıkça nefes almak kolaylaşabilir.",
            english: "Breathing can feel easier as the bronchial tubes begin to relax."
        ),
        SmokingStringSample(
            key: "smoking_stage_h_72h_title",
            turkish: "72 saat · Nefes alma",
            english: "72 hours · Breathing"
        ),
        SmokingStringSample(
            key: "smoking_stage_remaining_days",
            turkish: "%lld gün kaldı",
            english: "%lld days left"
        ),
        SmokingStringSample(
            key: "smoking_stage_remaining_days_one",
            turkish: "%lld gün kaldı",
            english: "%lld day left"
        ),
        SmokingStringSample(
            key: "smoking_stage_remaining_hours",
            turkish: "%lld saat kaldı",
            english: "%lld h left"
        ),
        SmokingStringSample(
            key: "smoking_stage_remaining_minutes",
            turkish: "%lld dk kaldı",
            english: "%lld min left"
        ),
        SmokingStringSample(
            key: "smoking_trigger_after_meal",
            turkish: "Yemek sonrası",
            english: "After a meal"
        ),
        SmokingStringSample(
            key: "smoking_trigger_alcohol",
            turkish: "Alkol",
            english: "Alcohol"
        ),
        SmokingStringSample(
            key: "smoking_trigger_boredom",
            turkish: "Can sıkıntısı",
            english: "Boredom"
        ),
        SmokingStringSample(
            key: "smoking_trigger_coffee",
            turkish: "Kahve",
            english: "Coffee"
        ),
        SmokingStringSample(
            key: "smoking_trigger_intensity",
            turkish: "Ne kadar şiddetliydi?",
            english: "How strong was it?"
        ),
        SmokingStringSample(
            key: "smoking_trigger_intensity_high",
            turkish: "Çok güçlü",
            english: "Very strong"
        ),
        SmokingStringSample(
            key: "smoking_trigger_intensity_low",
            turkish: "Hafif",
            english: "Mild"
        ),
        SmokingStringSample(
            key: "smoking_trigger_other",
            turkish: "Diğer",
            english: "Other"
        ),
        SmokingStringSample(
            key: "smoking_trigger_save",
            turkish: "Kaydet",
            english: "Save"
        ),
        SmokingStringSample(
            key: "smoking_trigger_skip",
            turkish: "Atla",
            english: "Skip"
        ),
        SmokingStringSample(
            key: "smoking_trigger_social",
            turkish: "Sosyal ortam",
            english: "Social setting"
        ),
        SmokingStringSample(
            key: "smoking_trigger_stress",
            turkish: "Stres",
            english: "Stress"
        ),
        SmokingStringSample(
            key: "smoking_trigger_title",
            turkish: "Ne tetikledi?",
            english: "What triggered it?"
        )
    ]
}
