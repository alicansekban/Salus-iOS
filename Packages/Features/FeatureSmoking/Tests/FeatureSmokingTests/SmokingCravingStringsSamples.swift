// The craving flow's keys (`smoking_craving_*`), copied from
// `feature/smoking/src/main/res/values{,-en}/strings.xml` on branch `feature/m17-smoking-cessation`
// (iOS-M17 Task 12). Its own table so the screen's rows do not interleave with the others'.
//
// Java's `%1$s` / `%1$d` are `%1$@` / `%1$lld` here, and the one `<plurals>` (`smoking_craving_line_days`)
// is split into a general key carrying the `other` item and a `_one` key carrying the `one` item
// (spec §9 (h)): Turkish reads the same in both, English differs. The screen reuses four keys that
// other tables already pin: `smoking_action_craving` (the title), `smoking_action_smoked`,
// `smoking_hero_min_sec` (the spoken time) and `smoking_error_generic`.

enum SmokingCravingStringTable {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_craving_headline",
            turkish: "Bu his 3–5 dakikada geçecek.",
            english: "This feeling passes in 3–5 minutes."
        ),
        SmokingStringSample(
            key: "smoking_craving_phase_in",
            turkish: "Nefes al",
            english: "Breathe in"
        ),
        SmokingStringSample(
            key: "smoking_craving_phase_hold",
            turkish: "Tut",
            english: "Hold"
        ),
        SmokingStringSample(
            key: "smoking_craving_phase_out",
            turkish: "Ver",
            english: "Breathe out"
        ),
        SmokingStringSample(
            key: "smoking_craving_chip_in",
            turkish: "Nefes al · 4 sn",
            english: "Breathe in · 4 s"
        ),
        SmokingStringSample(
            key: "smoking_craving_chip_hold",
            turkish: "Tut · 4 sn",
            english: "Hold · 4 s"
        ),
        SmokingStringSample(
            key: "smoking_craving_chip_out",
            turkish: "Ver · 6 sn",
            english: "Breathe out · 6 s"
        ),
        SmokingStringSample(
            key: "smoking_craving_timer_semantics",
            turkish: "Kalan süre %1$@. %2$@",
            english: "%1$@ left. %2$@"
        ),
        SmokingStringSample(
            key: "smoking_craving_line_days",
            turkish: "%lld gündür sigarasızsın",
            english: "%lld days smoke-free"
        ),
        SmokingStringSample(
            key: "smoking_craving_line_days_one",
            turkish: "%lld gündür sigarasızsın",
            english: "%lld day smoke-free"
        ),
        SmokingStringSample(
            key: "smoking_craving_line_saved",
            turkish: "Şimdiye kadar %1$@ biriktirdin",
            english: "You have saved %1$@ so far"
        ),
        SmokingStringSample(
            key: "smoking_craving_line_stage",
            turkish: "Sıradaki aşama: %1$@",
            english: "Next stage: %1$@"
        ),
        SmokingStringSample(
            key: "smoking_craving_line_focus",
            turkish: "Sadece nefesine odaklan.",
            english: "Just focus on your breath."
        ),
        SmokingStringSample(
            key: "smoking_craving_reason",
            turkish: "“%1$@”",
            english: "“%1$@”"
        ),
        SmokingStringSample(
            key: "smoking_craving_passed",
            turkish: "Geçti",
            english: "It passed"
        ),
        SmokingStringSample(
            key: "smoking_craving_done_title",
            turkish: "Başardın",
            english: "You did it"
        ),
        SmokingStringSample(
            key: "smoking_craving_done_count",
            turkish: "%1$lld. krizi atlattın",
            english: "Craving #%1$lld beaten"
        ),
        SmokingStringSample(
            key: "smoking_craving_done_timer",
            turkish: "Beş dakika doldu. Geçtiyse işaretleyebilirsin.",
            english: "Five minutes are up. If it passed, you can mark it."
        ),
        SmokingStringSample(
            key: "smoking_craving_done_semantics",
            turkish: "Beş dakika doldu",
            english: "Five minutes are up"
        ),
        SmokingStringSample(
            key: "smoking_craving_continue",
            turkish: "Devam",
            english: "Continue"
        )
    ]
}
