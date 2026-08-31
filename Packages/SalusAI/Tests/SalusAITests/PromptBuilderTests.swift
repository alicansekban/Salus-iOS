import SalusModel
import Testing

@testable import SalusAI

// Ported 1:1 from Android
// `core/ai/src/test/kotlin/com/alicansekban/salus/core/ai/PromptBuilderTest.kt`.

@Suite("PromptBuilder (Android parity)")
struct PromptBuilderTests {
    // --- (1) language instruction ---

    @Test("summary prompt in Turkish instructs Turkish output only")
    func summaryPromptInTurkishInstructsTurkishOutputOnly() {
        let prompt = PromptBuilder.summaryPrompt(stats(systolic: metric()), language: .tr)

        #expect(prompt.system.contains("Türkçe"))
        #expect(!prompt.system.contains("in English"))
    }

    @Test("summary prompt in English instructs English output only")
    func summaryPromptInEnglishInstructsEnglishOutputOnly() {
        let prompt = PromptBuilder.summaryPrompt(stats(systolic: metric()), language: .en)

        #expect(prompt.system.contains("in English"))
        #expect(!prompt.system.contains("Türkçe"))
    }

    @Test("doctor report prompt follows the language parameter too")
    func doctorReportPromptFollowsTheLanguageParameterToo() {
        let tr = PromptBuilder.doctorReportPrompt(stats(systolic: metric()), language: .tr)
        let en = PromptBuilder.doctorReportPrompt(stats(systolic: metric()), language: .en)

        #expect(tr.system.contains("Türkçe"))
        #expect(en.system.contains("in English"))
    }

    // --- (2) null metrics never leak into the prompt ---

    @Test("null metrics are never mentioned in Turkish user text")
    func nullMetricsAreNeverMentionedInTurkishUserText() {
        let prompt = PromptBuilder.summaryPrompt(stats(systolic: metric()), language: .tr)

        #expect(prompt.user.contains("Sistolik"))
        for label in ["Diyastolik", "Nabız", "Kan şekeri", "Kilo"] {
            #expect(!prompt.user.contains(label), "'\(label)' should not appear when its metric is null")
        }
    }

    @Test("null metrics are never mentioned in English user text")
    func nullMetricsAreNeverMentionedInEnglishUserText() {
        let prompt = PromptBuilder.summaryPrompt(stats(glucoseMgDl: metric()), language: .en)

        #expect(prompt.user.contains("Blood glucose"))
        for label in ["Systolic", "Diastolic", "Pulse", "Weight"] {
            #expect(!prompt.user.contains(label), "'\(label)' should not appear when its metric is null")
        }
    }

    @Test("user text states that no measurement exists when every metric is null")
    func userTextStatesThatNoMeasurementExistsWhenEveryMetricIsNull() {
        let tr = PromptBuilder.summaryPrompt(stats(), language: .tr)
        let en = PromptBuilder.summaryPrompt(stats(), language: .en)

        #expect(tr.user.contains("ölçüm kaydı yok"))
        #expect(en.user.contains("No numeric measurement"))
    }

    @Test("present metric is rendered with count average min max and trend")
    func presentMetricIsRenderedWithCountAverageMinMaxAndTrend() {
        let prompt = PromptBuilder.summaryPrompt(
            stats(
                systolic: MetricStats(
                    count: 6,
                    average: 128.45,
                    min: 118.0,
                    max: 140.0,
                    trend: .rising
                )
            ),
            language: .en
        )

        #expect(prompt.user.contains("6"))
        #expect(prompt.user.contains("128.5"))
        #expect(prompt.user.contains("118.0"))
        #expect(prompt.user.contains("140.0"))
        #expect(prompt.user.contains("rising"))
    }

    // --- (3) system instruction guardrails ---

    @Test("Turkish system instruction forbids diagnosis and treatment advice")
    func turkishSystemInstructionForbidsDiagnosisAndTreatmentAdvice() {
        let system = PromptBuilder.summaryPrompt(stats(), language: .tr).system

        #expect(system.contains("teşhis koyma"))
        #expect(system.contains("önerme"))
        #expect(system.contains("doktorunuzla"))
    }

    @Test("English system instruction forbids diagnosis and treatment advice")
    func englishSystemInstructionForbidsDiagnosisAndTreatmentAdvice() {
        let system = PromptBuilder.summaryPrompt(stats(), language: .en).system

        #expect(system.contains("do not diagnose"))
        #expect(system.contains("Do not recommend"))
        #expect(system.contains("doctor"))
    }

    @Test("system instruction is identical for both prompt kinds")
    func systemInstructionIsIdenticalForBothPromptKinds() {
        for language in [AiLanguage.tr, .en] {
            #expect(
                PromptBuilder.summaryPrompt(stats(), language: language).system
                    == PromptBuilder.doctorReportPrompt(stats(), language: language).system
            )
        }
    }

    // --- (4) dose ratio sentence presence ---

    @Test("no medication sentence when taken percent is null")
    func noMedicationSentenceWhenTakenPercentIsNull() {
        let tr = PromptBuilder.summaryPrompt(stats(loggedDoses: 0, takenDoses: 0), language: .tr)
        let en = PromptBuilder.summaryPrompt(stats(loggedDoses: 0, takenDoses: 0), language: .en)

        #expect(!tr.user.contains("alındı olarak işaretlendi"))
        #expect(!en.user.contains("recorded doses marked taken"))
    }

    @Test("dose ratio sentence is present when taken percent exists")
    func doseRatioSentenceIsPresentWhenTakenPercentExists() {
        let tr = PromptBuilder.summaryPrompt(stats(loggedDoses: 4, takenDoses: 3), language: .tr)
        let en = PromptBuilder.summaryPrompt(stats(loggedDoses: 4, takenDoses: 3), language: .en)

        #expect(tr.user.contains("Kaydedilen 4 dozun 3 tanesi alındı olarak işaretlendi (%75)."))
        #expect(en.user.contains("3 of 4 recorded doses marked taken (75%)"))
    }

    @Test("dose ratio sentence never claims adherence against a schedule")
    func doseRatioSentenceNeverClaimsAdherenceAgainstASchedule() {
        let tr = PromptBuilder.doctorReportPrompt(stats(loggedDoses: 4, takenDoses: 4), language: .tr)
        let en = PromptBuilder.doctorReportPrompt(stats(loggedDoses: 4, takenDoses: 4), language: .en)

        #expect(!tr.user.contains("uyum"))
        #expect(!tr.user.contains("planlanan"))
        #expect(!en.user.lowercased().contains("adherence"))
        #expect(!en.user.lowercased().contains("planned"))
    }

    @Test("system instruction forbids the model from renaming the dose ratio")
    func systemInstructionForbidsTheModelFromRenamingTheDoseRatio() {
        let tr = PromptBuilder.summaryPrompt(stats(loggedDoses: 4, takenDoses: 4), language: .tr)
        let en = PromptBuilder.summaryPrompt(stats(loggedDoses: 4, takenDoses: 4), language: .en)

        #expect(tr.system.contains("uyum"))
        #expect(tr.system.contains("planlanan doz"))
        #expect(en.system.lowercased().contains("adherence"))
        #expect(en.system.lowercased().contains("planned doses"))
    }

    // --- (5) taken percent computation ---

    @Test("taken percent is null when no dose was logged")
    func takenPercentIsNullWhenNoDoseWasLogged() {
        #expect(stats(loggedDoses: 0, takenDoses: 0).takenPercent == nil)
        #expect(stats(loggedDoses: 0, takenDoses: 2).takenPercent == nil)
    }

    @Test("taken percent is taken over logged, rounded to the nearest whole")
    func takenPercentIsTakenOverLoggedRoundedToTheNearestWhole() {
        #expect(stats(loggedDoses: 4, takenDoses: 3).takenPercent == 75)
        #expect(stats(loggedDoses: 4, takenDoses: 4).takenPercent == 100)
        #expect(stats(loggedDoses: 4, takenDoses: 0).takenPercent == 0)
        // 66.67, which reads as 67. Truncating gave 66 and under-stated every ratio that does
        // not divide evenly; the trends screen rounds the same share the same way, and one
        // number computed two ways is a bug report nobody can reproduce.
        #expect(stats(loggedDoses: 3, takenDoses: 2).takenPercent == 67)
        // Rounding down is still rounding: a third of three doses is 33, not 34.
        #expect(stats(loggedDoses: 3, takenDoses: 1).takenPercent == 33)
    }

    // --- period rendering + determinism ---

    @Test("period line reports type day count and distinct record days")
    func periodLineReportsTypeDayCountAndDistinctRecordDays() {
        let monthly = stats(
            periodType: .monthly,
            startEpochDay: 20000,
            endEpochDay: 20029,
            distinctRecordDays: 12
        )

        let tr = PromptBuilder.summaryPrompt(monthly, language: .tr).user
        let en = PromptBuilder.summaryPrompt(monthly, language: .en).user

        #expect(tr.contains("Aylık"))
        #expect(tr.contains("30 gün"))
        #expect(tr.contains("12 gün"))
        #expect(en.contains("Monthly"))
        #expect(en.contains("30 days"))
        #expect(en.contains("12 days"))
    }

    @Test("doctor report asks for the two required sections")
    func doctorReportAsksForTheTwoRequiredSections() {
        let tr = PromptBuilder.doctorReportPrompt(stats(pulse: metric()), language: .tr).user
        let en = PromptBuilder.doctorReportPrompt(stats(pulse: metric()), language: .en).user

        #expect(tr.contains("Dönem özeti"))
        #expect(tr.contains("Doktorunuza sorabilecekleriniz"))
        #expect(en.contains("Period summary"))
        #expect(en.contains("Questions you can ask your doctor"))
    }

    @Test("summary prompt asks for a 150-200 word summary")
    func summaryPromptAsksForA150To200WordSummary() {
        #expect(PromptBuilder.summaryPrompt(stats(), language: .tr).user.contains("150-200"))
        #expect(PromptBuilder.summaryPrompt(stats(), language: .en).user.contains("150-200"))
    }

    @Test("prompts are deterministic for identical stats")
    func promptsAreDeterministicForIdenticalStats() {
        let input = stats(systolic: metric(), loggedDoses: 4, takenDoses: 3)

        let firstSummary = PromptBuilder.summaryPrompt(input, language: .tr)
        let secondSummary = PromptBuilder.summaryPrompt(input, language: .tr)
        #expect(firstSummary == secondSummary)

        let firstReport = PromptBuilder.doctorReportPrompt(input, language: .en)
        let secondReport = PromptBuilder.doctorReportPrompt(input, language: .en)
        #expect(firstReport == secondReport)
    }

    @Test("prompts never contain raw epoch day values")
    func promptsNeverContainRawEpochDayValues() {
        let input = stats(startEpochDay: 20000, endEpochDay: 20006, systolic: metric())

        for language in [AiLanguage.tr, .en] {
            for prompt in [
                PromptBuilder.summaryPrompt(input, language: language),
                PromptBuilder.doctorReportPrompt(input, language: language)
            ] {
                #expect(!prompt.user.contains("20000"))
                #expect(!prompt.user.contains("20006"))
            }
        }
    }

    private func metric(
        count: Int = 5,
        average: Double = 120.0,
        min: Double = 110.0,
        max: Double = 130.0,
        trend: Trend = .stable
    ) -> MetricStats {
        MetricStats(count: count, average: average, min: min, max: max, trend: trend)
    }

    private func stats(
        periodType: SummaryPeriod = .weekly,
        startEpochDay: Int = 20000,
        endEpochDay: Int = 20006,
        distinctRecordDays: Int = 5,
        systolic: MetricStats? = nil,
        diastolic: MetricStats? = nil,
        pulse: MetricStats? = nil,
        glucoseMgDl: MetricStats? = nil,
        weightKg: MetricStats? = nil,
        loggedDoses: Int = 0,
        takenDoses: Int = 0
    ) -> HealthPeriodStats {
        HealthPeriodStats(
            periodType: periodType,
            startEpochDay: startEpochDay,
            endEpochDay: endEpochDay,
            distinctRecordDays: distinctRecordDays,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            glucoseMgDl: glucoseMgDl,
            weightKg: weightKg,
            loggedDoses: loggedDoses,
            takenDoses: takenDoses
        )
    }
}
