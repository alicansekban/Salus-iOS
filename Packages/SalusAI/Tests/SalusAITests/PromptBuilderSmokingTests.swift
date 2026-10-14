import SalusModel
import SalusSmoking
import SalusTesting
import Testing

@testable import SalusAI

// Twin of Android `core/ai/src/test/.../PromptBuilderSmokingTest.kt`: the tobacco block of the
// prompt (spec section 7) carries aggregates and nothing else, and a causation rule.

@Suite("PromptBuilder smoking block")
struct PromptBuilderSmokingTests {
    @Test("English prompt carries mode days slips triggers busiest band and reduction")
    func englishPromptCarriesEveryFigure() {
        let user = PromptBuilder.summaryPrompt(statsWith(reduceStats), language: .en).user

        #expect(user.contains("Tobacco use (summary figures):"))
        #expect(user.contains("- Mode: reducing"))
        #expect(user.contains("- Days tracked: 7"))
        #expect(user.contains("- Logged smoking entries: 3"))
        #expect(user.contains("- Most common triggers: coffee (2), stress (1)"))
        #expect(user.contains("- Busiest time of day: 18:00-22:00"))
        #expect(user.contains("- Average use on logged days: 30% below the usual amount"))
    }

    @Test("Turkish prompt carries the same figures")
    func turkishPromptCarriesTheSameFigures() {
        let user = PromptBuilder.summaryPrompt(statsWith(quitStats), language: .tr).user

        #expect(user.contains("Tütün kullanımı (özet sayılar):"))
        #expect(user.contains("- Mod: bırakma"))
        #expect(user.contains("- Takip edilen gün: 7"))
        #expect(user.contains("- Kaçamak sayısı: 1"))
        #expect(user.contains("- En sık tetikleyiciler: kahve (1)"))
        #expect(user.contains("- En yoğun saat aralığı: 22:00-08:00"))
    }

    @Test("a missing busiest band triggers and reduction are left out, not printed as empty")
    func missingFiguresAreLeftOut() {
        let bare = SmokingAiStats(
            mode: .quit,
            daysTracked: 4,
            slipCount: 0,
            topTriggers: [],
            busiestBand: nil,
            reductionPercent: nil
        )

        let user = PromptBuilder.summaryPrompt(statsWith(bare), language: .en).user

        #expect(user.contains("- Slips: 0"))
        #expect(!user.contains("Most common triggers"))
        #expect(!user.contains("Busiest time of day"))
        #expect(!user.contains("Average use"))
    }

    @Test("a reduction above the baseline reads as an increase and never as a negative reduction")
    func negativeReductionReadsAsIncrease() {
        let above = reduceStats.with(reductionPercent: -25)

        let en = PromptBuilder.summaryPrompt(statsWith(above), language: .en).user
        let tr = PromptBuilder.summaryPrompt(statsWith(above), language: .tr).user

        #expect(en.contains("- Average use on logged days: 25% above the usual amount"))
        #expect(tr.contains("- Kayıtlı günlerde ortalama kullanım: alışılmış miktarın %25 üzerinde"))
        #expect(!en.contains("-25"))
        #expect(!tr.contains("-25"))
    }

    @Test("a reduction of exactly zero says the average matches the usual amount")
    func zeroReductionMatchesTheUsualAmount() {
        let user = PromptBuilder.summaryPrompt(statsWith(reduceStats.with(reductionPercent: 0)), language: .en).user

        #expect(user.contains("- Average use on logged days: the same as the usual amount"))
    }

    @Test("the system instruction forbids claiming causation and smoking advice when smoking is set")
    func systemRuleWhenSmokingIsSet() {
        let en = PromptBuilder.summaryPrompt(statsWith(quitStats), language: .en).system
        let tr = PromptBuilder.summaryPrompt(statsWith(quitStats), language: .tr).system

        #expect(en.contains("Do not claim that tobacco use caused or is caused by any measurement"))
        #expect(en.contains("give no medical advice about smoking"))
        #expect(tr.contains("Tütün kullanımı ile ölçümler arasında neden-sonuç ilişkisi kurma"))
        #expect(tr.contains("sigara konusunda tıbbi tavsiye verme"))
    }

    @Test("the doctor report prompt gets the same block and rule")
    func doctorReportPromptGetsTheBlockAndRule() {
        let prompt = PromptBuilder.doctorReportPrompt(statsWith(reduceStats), language: .en)

        #expect(prompt.user.contains("Tobacco use (summary figures):"))
        #expect(prompt.system.contains("give no medical advice about smoking"))
    }

    @Test("a prompt without smoking is exactly the prompt it was before the feature")
    func promptWithoutSmokingIsUnchanged() {
        let plain = statsWith(nil)

        for language in [AiLanguage.tr, .en] {
            let summary = PromptBuilder.summaryPrompt(plain, language: language)
            let report = PromptBuilder.doctorReportPrompt(plain, language: language)
            for text in [summary.system, summary.user, report.system, report.user] {
                let lower = text.lowercased()
                #expect(!(lower.contains("tobacco") || lower.contains("smok")))
                #expect(!(lower.contains("tütün") || lower.contains("sigara")))
            }
        }
        // The pre-feature user text for these stats, character for character.
        #expect(
            PromptBuilder.summaryPrompt(plain, language: .en).user
                == "Period: Weekly — 7 days; records on 5 days.\n\nMeasurements:\n"
                + "No numeric measurement was recorded in this period.\n\n"
                + "Task: Write an approximately 150-200 word summary based on the data above. "
                + "Describe observations and trends, and stay silent about anything the data does not cover."
        )
    }

    @Test("the tobacco copy stays clear of the banned health-claims vocabulary")
    func tobaccoCopyIsClearOfBannedVocabulary() {
        for language in [AiLanguage.tr, .en] {
            let prompt = PromptBuilder.summaryPrompt(statsWith(reduceStats), language: language)
            // The base system text names the banned words on purpose (it forbids the model from
            // using them), so only the smoking rule - the system's last line - is scanned.
            let lines = prompt.system.split(separator: "\n", omittingEmptySubsequences: false)
            let rule = lines.last.map(String.init) ?? ""
            let text = (rule + "\n" + prompt.user).lowercased()
            for stem in BannedHealthClaims.stems {
                #expect(!text.contains(stem), "\(language) prompt contains banned stem '\(stem)'")
            }
        }
    }

    // MARK: - Fixtures

    private func statsWith(_ smoking: SmokingAiStats?) -> HealthPeriodStats {
        HealthPeriodStats(
            periodType: .weekly,
            startEpochDay: 20000,
            endEpochDay: 20006,
            distinctRecordDays: 5,
            systolic: nil,
            diastolic: nil,
            pulse: nil,
            glucoseMgDl: nil,
            weightKg: nil,
            loggedDoses: 0,
            takenDoses: 0,
            smoking: smoking
        )
    }

    private let reduceStats = SmokingAiStats(
        mode: .reduce,
        daysTracked: 7,
        slipCount: 3,
        topTriggers: [
            TriggerShare(trigger: .coffee, count: 2, permille: 666),
            TriggerShare(trigger: .stress, count: 1, permille: 333)
        ],
        busiestBand: .h18_22,
        reductionPercent: 30
    )

    private let quitStats = SmokingAiStats(
        mode: .quit,
        daysTracked: 7,
        slipCount: 1,
        topTriggers: [TriggerShare(trigger: .coffee, count: 1, permille: 1000)],
        busiestBand: .h22_08,
        reductionPercent: nil
    )
}

extension SmokingAiStats {
    fileprivate func with(reductionPercent: Int?) -> SmokingAiStats {
        SmokingAiStats(
            mode: mode,
            daysTracked: daysTracked,
            slipCount: slipCount,
            topTriggers: topTriggers,
            busiestBand: busiestBand,
            reductionPercent: reductionPercent
        )
    }
}
