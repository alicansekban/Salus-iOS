// The savings-goal card's, its sheet's and the insights teaser's keys (`smoking_goal_*`,
// `smoking_insights_*`, `smoking_premium_unlock`), copied from
// `feature/smoking/src/main/res/values{,-en}/strings.xml` on branch `feature/m17-smoking-cessation`
// (iOS-M17 Task 15). Its own table so the cards' rows do not interleave with the others'.
//
// Java's `%1$s` / `%d` are `%1$@` / `%lld` here; the one `<plurals>` (`smoking_goal_eta`) is split
// into a general key and a `_one` twin chosen by count (spec 9 (h)). `smoking_goal_sheet_keep_note`
// is the line that replaced "a new goal starts counting from zero" (contract 8.17, D-M17-ae).

enum SmokingGoalStringTable {
    static let samples: [SmokingStringSample] = [
        SmokingStringSample(
            key: "smoking_premium_unlock",
            turkish: "Premium ile aç",
            english: "Unlock with Premium"
        ),
        SmokingStringSample(
            key: "smoking_goal_overline",
            turkish: "TASARRUF HEDEFİ",
            english: "SAVINGS GOAL"
        ),
        SmokingStringSample(
            key: "smoking_goal_locked_body",
            turkish: "Biriktirdiğin parayı bir hedefe bağla ve ilerlemeni izle.",
            english: "Tie what you save to a goal and follow your progress."
        ),
        SmokingStringSample(
            key: "smoking_goal_none_title",
            turkish: "İlk tasarruf hedefini belirle",
            english: "Set your first savings goal"
        ),
        SmokingStringSample(
            key: "smoking_goal_amounts",
            turkish: "%1$@ / %2$@",
            english: "%1$@ / %2$@"
        ),
        SmokingStringSample(
            key: "smoking_goal_eta",
            turkish: "yaklaşık %lld gün",
            english: "about %lld days"
        ),
        SmokingStringSample(
            key: "smoking_goal_eta_one",
            turkish: "yaklaşık %lld gün",
            english: "about %lld day"
        ),
        SmokingStringSample(
            key: "smoking_goal_reached_title",
            turkish: "Hedefine ulaştın",
            english: "You reached your goal"
        ),
        SmokingStringSample(
            key: "smoking_goal_reached_body",
            turkish: "%1$@ · %2$@",
            english: "%1$@ · %2$@"
        ),
        SmokingStringSample(
            key: "smoking_goal_reached_action",
            turkish: "Yeni hedef belirle",
            english: "Set a new goal"
        ),
        SmokingStringSample(
            key: "smoking_insights_overline",
            turkish: "İÇGÖRÜLER",
            english: "INSIGHTS"
        ),
        SmokingStringSample(
            key: "smoking_insights_title",
            turkish: "Krizlerin en çok ne zaman geliyor?",
            english: "When do your cravings come most?"
        ),
        SmokingStringSample(
            key: "smoking_goal_sheet_title",
            turkish: "Tasarruf hedefi",
            english: "Savings goal"
        ),
        SmokingStringSample(
            key: "smoking_goal_sheet_name_label",
            turkish: "HEDEF ADI",
            english: "GOAL NAME"
        ),
        SmokingStringSample(
            key: "smoking_goal_sheet_name_placeholder",
            turkish: "Örn. Yeni bisiklet",
            english: "e.g. New bicycle"
        ),
        SmokingStringSample(
            key: "smoking_goal_sheet_amount_label",
            turkish: "HEDEF TUTARI",
            english: "TARGET AMOUNT"
        ),
        SmokingStringSample(
            key: "smoking_goal_sheet_amount_error",
            turkish: "Geçerli bir tutar gir.",
            english: "Enter a valid amount."
        ),
        SmokingStringSample(
            key: "smoking_goal_sheet_keep_note",
            turkish: "Bu hedef için biriktirdiğin tutar korunur.",
            english: "What you've saved toward this goal is kept."
        ),
        SmokingStringSample(
            key: "smoking_goal_sheet_save",
            turkish: "Kaydet",
            english: "Save"
        )
    ]
}
