// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/PromptBuilder.kt`.

import SalusModel
import SalusSmoking

/// Builds the fixed prompt templates used for AI health summaries.
///
/// The only input that ever reaches the model is `HealthPeriodStats`: aggregated numbers.
/// No name, birth date, note text or any other free-form user input is accepted or emitted,
/// and the system instruction forbids diagnosis and treatment advice in both languages.
///
/// The tobacco block exists only when `HealthPeriodStats.smoking` does, and so does the system
/// rule that goes with it: a user who never set smoking up gets the prompt they always got.
public enum PromptBuilder {
    /// Prompt asking for a short (~150-200 word) narrative summary of the period.
    public static func summaryPrompt(_ stats: HealthPeriodStats, language: AiLanguage) -> AiPrompt {
        let copy = language.promptCopy()
        return AiPrompt(system: copy.systemFor(stats), user: userMessage(stats, copy, copy.summaryTask))
    }

    /// Prompt asking for a period summary plus questions the user can ask their doctor.
    public static func doctorReportPrompt(_ stats: HealthPeriodStats, language: AiLanguage) -> AiPrompt {
        let copy = language.promptCopy()
        return AiPrompt(system: copy.systemFor(stats), user: userMessage(stats, copy, copy.doctorReportTask))
    }
}

private func userMessage(_ stats: HealthPeriodStats, _ copy: PromptCopy, _ task: String) -> String {
    var lines: [String] = []
    lines.append(copy.periodLine(stats.periodType, dayCount: stats.dayCount(), recordDays: stats.distinctRecordDays))
    lines.append("")
    lines.append(copy.measurementsHeader)
    let metricLines = metricLines(stats, copy)
    if metricLines.isEmpty {
        lines.append(copy.noMeasurements)
    } else {
        lines.append(contentsOf: metricLines)
    }
    if let percent = stats.takenPercent {
        lines.append("")
        lines.append(copy.doseRatioLine(percent: percent, taken: stats.takenDoses, logged: stats.loggedDoses))
    }
    if let smoking = stats.smoking {
        lines.append("")
        lines.append(contentsOf: copy.smokingLines(smoking))
    }
    lines.append("")
    lines.append(task)
    return lines.joined(separator: "\n")
}

extension PromptCopy {
    /// The base instruction, plus the smoking rule only when the prompt carries smoking figures.
    fileprivate func systemFor(_ stats: HealthPeriodStats) -> String {
        stats.smoking == nil ? system : "\(system)\n- \(smokingRule)"
    }
}

private func metricLines(_ stats: HealthPeriodStats, _ copy: PromptCopy) -> [String] {
    MetricKind.allCases.compactMap { kind in
        kind.valueIn(stats).map { copy.metricLine(kind, $0) }
    }
}

extension HealthPeriodStats {
    fileprivate func dayCount() -> Int {
        max(endEpochDay - startEpochDay + 1, 0)
    }
}

/// Metrics that may appear in a prompt. A metric that is `nil` is omitted entirely.
private enum MetricKind: CaseIterable {
    case systolic
    case diastolic
    case pulse
    case glucose
    case weight

    func valueIn(_ stats: HealthPeriodStats) -> MetricStats? {
        switch self {
        case .systolic: stats.systolic
        case .diastolic: stats.diastolic
        case .pulse: stats.pulse
        case .glucose: stats.glucoseMgDl
        case .weight: stats.weightKg
        }
    }
}

/// Locale-independent one-decimal rendering, so prompts stay byte-identical across devices.
private func format(_ value: Double) -> String {
    let tenths = Int64((value * tenthsScale).rounded())
    let sign = tenths < 0 ? "-" : ""
    let magnitude = abs(tenths)
    return "\(sign)\(magnitude / tenthsScaleL).\(magnitude % tenthsScaleL)"
}

/// The band as a clock range, locale-free like every other number in a prompt. The ranges mirror
/// the contract's `HourBand` rows (`h22_08` is 22:00-07:59, so it reads 22:00-08:00).
private func bandRange(_ band: HourBand) -> String {
    switch band {
    case .h08_10: "08:00-10:00"
    case .h10_12: "10:00-12:00"
    case .h12_14: "12:00-14:00"
    case .h14_16: "14:00-16:00"
    case .h16_18: "16:00-18:00"
    case .h18_22: "18:00-22:00"
    case .h22_08: "22:00-08:00"
    }
}

private let tenthsScale = 10.0
private let tenthsScaleL: Int64 = 10

extension AiLanguage {
    fileprivate func promptCopy() -> PromptCopy {
        switch self {
        case .tr: TurkishCopy()
        case .en: EnglishCopy()
        }
    }
}

/// Every user-visible string of a prompt, per language.
private protocol PromptCopy {
    var system: String { get }
    var measurementsHeader: String { get }
    var noMeasurements: String { get }
    var summaryTask: String { get }
    var doctorReportTask: String { get }
    func periodLine(_ period: SummaryPeriod, dayCount: Int, recordDays: Int) -> String
    func metricLine(_ kind: MetricKind, _ stats: MetricStats) -> String

    /// States the mechanism rather than naming it adherence: the denominator is the doses the
    /// user recorded, not the doses the schedule called for, so calling this "adherence" would
    /// overstate it for anyone who only logs the doses they take.
    func doseRatioLine(percent: Int, taken: Int, logged: Int) -> String

    /// Added to the system rules when the prompt has a tobacco block: no causal claim between
    /// tobacco use and a measurement, and no advice about smoking itself.
    var smokingRule: String { get }

    /// The tobacco block: a header and one line per figure the stats actually carry.
    func smokingLines(_ stats: SmokingAiStats) -> [String]
}

private struct TurkishCopy: PromptCopy {
    let system = """
    Sen bir sağlık verisi gözlemcisisin. Sana yalnızca sayısal ölçüm özetleri verilir ve bu özetleri yorumlarsın.

    Kurallar:
    - Yalnızca gözlem ve eğilim anlat; hastalık adı verme, teşhis koyma.
    - Tedavi, ilaç, doz veya takviye önerme.
    - Endişe verici görünen değerlerde "değerlerinizi doktorunuzla paylaşın" yönlendirmesini yap.
    - Sana verilen sayıların dışına çıkma; veri olmayan konuda tahmin yürütme.
    - Doz oranını yeniden adlandırma: "uyum", "uyum oranı", "tedaviye uyum" veya "planlanan doz" \
    yazma. Bu oran yalnızca kaydedilen dozların ne kadarının alındı işaretlendiğini gösterir; hiç \
    kaydedilmemiş dozlar bu sayının içinde yoktur. Doz cümlesini sana verildiği anlamda, "kaydedilen doz" \
    ifadesiyle kur.
    - Yanıtını Türkçe yaz.
    - Düz metin kullan; markdown yazma. Yıldız (*), alt çizgi (_), ters tırnak (`) ve başlık \
    işareti (#) kullanma; kalın veya italik yapmaya çalışma.
    - Kısa bölümler halinde yaz; her maddeye satır başında "- " koy.
    """

    let measurementsHeader = "Ölçümler:"

    let noMeasurements = "Bu dönemde sayısal ölçüm kaydı yok."

    let summaryTask =
        "Görev: Yukarıdaki verilere dayanarak yaklaşık 150-200 kelimelik bir özet yaz. "
            + "Gözlemleri ve eğilimleri anlat, veri bulunmayan konulara girme."

    let doctorReportTask = """
    Görev: Yukarıdaki verilere dayanarak iki bölüm yaz.
    1) "Dönem özeti": verilerdeki gözlemler ve eğilimler.
    2) "Doktorunuza sorabilecekleriniz": 3-5 madde halinde soru önerisi; her soruyu yukarıdaki sayılara dayandır.
    """

    func periodLine(_ period: SummaryPeriod, dayCount: Int, recordDays: Int) -> String {
        "Dönem: \(periodName(period)) — \(dayCount) gün; \(recordDays) günde kayıt var."
    }

    func metricLine(_ kind: MetricKind, _ stats: MetricStats) -> String {
        "- \(label(kind)): \(stats.count) ölçüm, ortalama \(format(stats.average)), "
            + "en düşük \(format(stats.min)), en yüksek \(format(stats.max)), eğilim: \(trendName(stats.trend))"
    }

    func doseRatioLine(percent: Int, taken: Int, logged: Int) -> String {
        "Kaydedilen \(logged) dozun \(taken) tanesi alındı olarak işaretlendi (%\(percent))."
    }

    let smokingRule =
        "Tütün kullanımı ile ölçümler arasında neden-sonuç ilişkisi kurma; tütün rakamlarını olduğu gibi "
            + "anlat ve sigara konusunda tıbbi tavsiye verme (bırakma yöntemi, ürün veya ilaç önerme)."

    func smokingLines(_ stats: SmokingAiStats) -> [String] {
        var lines = ["Tütün kullanımı (özet sayılar):"]
        lines.append("- Mod: \(stats.mode == .quit ? "bırakma" : "azaltma")")
        lines.append("- Takip edilen gün: \(stats.daysTracked)")
        lines.append(
            stats.mode == .quit
                ? "- Kaçamak sayısı: \(stats.slipCount)"
                : "- Kayıtlı sigara içme sayısı: \(stats.slipCount)"
        )
        if !stats.topTriggers.isEmpty {
            let triggers = stats.topTriggers.map { "\(triggerName($0.trigger)) (\($0.count))" }
            lines.append("- En sık tetikleyiciler: " + triggers.joined(separator: ", "))
        }
        if let band = stats.busiestBand {
            lines.append("- En yoğun saat aralığı: \(bandRange(band))")
        }
        if let percent = stats.reductionPercent {
            let amount = if percent > 0 {
                "alışılmış miktarın %\(percent) altında"
            } else if percent < 0 {
                "alışılmış miktarın %\(-percent) üzerinde"
            } else {
                "alışılmış miktarla aynı"
            }
            lines.append("- Kayıtlı günlerde ortalama kullanım: " + amount)
        }
        return lines
    }

    private func triggerName(_ trigger: CravingTrigger) -> String {
        switch trigger {
        case .coffee: "kahve"
        case .stress: "stres"
        case .alcohol: "alkol"
        case .afterMeal: "yemek sonrası"
        case .social: "sosyal ortamlar"
        case .boredom: "can sıkıntısı"
        case .other: "diğer"
        }
    }

    private func periodName(_ period: SummaryPeriod) -> String {
        switch period {
        case .weekly: "Haftalık"
        case .monthly: "Aylık"
        }
    }

    private func label(_ kind: MetricKind) -> String {
        switch kind {
        case .systolic: "Sistolik kan basıncı (mmHg)"
        case .diastolic: "Diyastolik kan basıncı (mmHg)"
        case .pulse: "Nabız (atım/dk)"
        case .glucose: "Kan şekeri (mg/dL)"
        case .weight: "Kilo (kg)"
        }
    }

    private func trendName(_ trend: Trend) -> String {
        switch trend {
        case .rising: "yükseliyor"
        case .falling: "düşüyor"
        case .stable: "sabit"
        }
    }
}

private struct EnglishCopy: PromptCopy {
    let system = """
    You are a health data observer. You are given only numeric measurement summaries and you interpret them.

    Rules:
    - Describe observations and trends only; do not diagnose and do not name any illness.
    - Do not recommend treatment, medication, dosage or supplements.
    - When a value looks concerning, tell the reader to talk to your doctor and share these values.
    - Never go beyond the numbers you are given; do not speculate where data is missing.
    - Do not rename the dose ratio: never write "adherence", "compliance" or "planned doses". \
    It reports only how many of the *recorded* doses were marked taken; doses that were never logged \
    are absent from it. Phrase the sentence the way it was given to you, in terms of recorded doses.
    - Write your answer in English.
    - Use plain text, not markdown. Never write asterisks (*), underscores (_), backticks (`) \
    or heading marks (#), and do not attempt bold or italics.
    - Write short sections; start each list item with "- " at the beginning of the line.
    """

    let measurementsHeader = "Measurements:"

    let noMeasurements = "No numeric measurement was recorded in this period."

    let summaryTask =
        "Task: Write an approximately 150-200 word summary based on the data above. "
            + "Describe observations and trends, and stay silent about anything the data does not cover."

    let doctorReportTask = """
    Task: Write two sections based on the data above.
    1) "Period summary": observations and trends in the data.
    2) "Questions you can ask your doctor": 3-5 bulleted suggestions, each grounded in the numbers above.
    """

    func periodLine(_ period: SummaryPeriod, dayCount: Int, recordDays: Int) -> String {
        "Period: \(periodName(period)) — \(dayCount) days; records on \(recordDays) days."
    }

    func metricLine(_ kind: MetricKind, _ stats: MetricStats) -> String {
        "- \(label(kind)): \(stats.count) measurements, average \(format(stats.average)), "
            + "min \(format(stats.min)), max \(format(stats.max)), trend \(trendName(stats.trend))"
    }

    func doseRatioLine(percent: Int, taken: Int, logged: Int) -> String {
        "\(taken) of \(logged) recorded doses marked taken (\(percent)%)"
    }

    let smokingRule =
        "Do not claim that tobacco use caused or is caused by any measurement; describe the tobacco "
            + "figures as they are and give no medical advice about smoking (no quitting methods, "
            + "products or medication)."

    func smokingLines(_ stats: SmokingAiStats) -> [String] {
        var lines = ["Tobacco use (summary figures):"]
        lines.append("- Mode: \(stats.mode == .quit ? "quitting" : "reducing")")
        lines.append("- Days tracked: \(stats.daysTracked)")
        lines.append(
            stats.mode == .quit
                ? "- Slips: \(stats.slipCount)"
                : "- Logged smoking entries: \(stats.slipCount)"
        )
        if !stats.topTriggers.isEmpty {
            let triggers = stats.topTriggers.map { "\(triggerName($0.trigger)) (\($0.count))" }
            lines.append("- Most common triggers: " + triggers.joined(separator: ", "))
        }
        if let band = stats.busiestBand {
            lines.append("- Busiest time of day: \(bandRange(band))")
        }
        if let percent = stats.reductionPercent {
            let amount = if percent > 0 {
                "\(percent)% below the usual amount"
            } else if percent < 0 {
                "\(-percent)% above the usual amount"
            } else {
                "the same as the usual amount"
            }
            lines.append("- Average use on logged days: " + amount)
        }
        return lines
    }

    private func triggerName(_ trigger: CravingTrigger) -> String {
        switch trigger {
        case .coffee: "coffee"
        case .stress: "stress"
        case .alcohol: "alcohol"
        case .afterMeal: "after meals"
        case .social: "social settings"
        case .boredom: "boredom"
        case .other: "other"
        }
    }

    private func periodName(_ period: SummaryPeriod) -> String {
        switch period {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    private func label(_ kind: MetricKind) -> String {
        switch kind {
        case .systolic: "Systolic blood pressure (mmHg)"
        case .diastolic: "Diastolic blood pressure (mmHg)"
        case .pulse: "Pulse (bpm)"
        case .glucose: "Blood glucose (mg/dL)"
        case .weight: "Weight (kg)"
        }
    }

    private func trendName(_ trend: Trend) -> String {
        switch trend {
        case .rising: "rising"
        case .falling: "falling"
        case .stable: "stable"
        }
    }
}
