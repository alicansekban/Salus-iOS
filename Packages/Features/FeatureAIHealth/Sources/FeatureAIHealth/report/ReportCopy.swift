// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/report/
// ReportCopy.kt`.

import SalusAI
import SalusModel
import SalusSmoking

/// Every fixed string the PDF prints, per language.
///
/// **Deliberately Swift copy rather than `Localizable.xcstrings` resources**, and this is the one
/// place in the app where that is true. A resource is resolved against the device configuration at
/// the moment it is read; this document is generated for an explicit `AiLanguage` and then lives
/// on as a file the user shares days later. Resolving through resources would let a language switch
/// change what a previously generated report *claims* to say next time something re-reads it,
/// and would make the footer disclaimer a second definition of a sentence `SalusAI` already owns.
/// `PromptBuilder` keys its copy the same way and for the same reason.
///
/// Screen copy is the opposite case and stays in the string catalog: it is read live, in the
/// configuration the user is looking at.
protocol ReportCopy {
    var documentTitle: String { get }
    var measurementsHeading: String { get }
    var noMeasurements: String { get }
    var bloodPressureHeading: String { get }
    var bloodPressureColumns: [String] { get }
    var glucoseHeading: String { get }
    var glucoseColumns: [String] { get }
    var weightHeading: String { get }
    var weightColumns: [String] { get }
    var medicationHeading: String { get }
    var noDoses: String { get }
    var tobaccoHeading: String { get }
    var narrativeHeading: String { get }
    var narrativeUnavailable: String { get }

    func periodRange(startEpochDay: Int, endEpochDay: Int) -> String

    func generatedOn(date: LocalDate) -> String

    /// States the mechanism instead of naming it adherence: the denominator is the doses the
    /// user recorded, not the doses the schedule called for. See `HealthPeriodStats.takenPercent`.
    func loggedDoseLine(percent: Int, taken: Int, logged: Int) -> String

    func contextLabel(context: MeasurementContext) -> String

    func tobaccoStatus(mode: SmokingMode) -> String

    func quitDateLine(epochDay: Int) -> String

    func quitDurationLine(days: Int) -> String

    func slipsLine(count: Int) -> String

    /// `average` is already formatted, one decimal, no locale.
    func dailyAverageLine(average: String) -> String

    func date(epochDay: Int) -> String
}

extension ReportCopy {
    func date(epochDay: Int) -> String {
        formatReportDate(epochDay: epochDay)
    }
}

extension AiLanguage {
    func reportCopy() -> ReportCopy {
        switch self {
        case .tr: TurkishReportCopy()
        case .en: EnglishReportCopy()
        }
    }
}

private struct TurkishReportCopy: ReportCopy {
    let documentTitle = "Salus Sağlık Raporu"
    let measurementsHeading = "Ölçümler"
    let noMeasurements = "Bu dönemde ölçüm kaydı bulunmuyor."
    let bloodPressureHeading = "Tansiyon kayıtları"
    let bloodPressureColumns = ["Tarih", "Sistolik/Diyastolik (mmHg)", "Nabız (atım/dk)"]
    let glucoseHeading = "Kan şekeri kayıtları"
    let glucoseColumns = ["Tarih", "mg/dL", "Bağlam"]
    let weightHeading = "Kilo kayıtları"
    let weightColumns = ["Tarih", "Kilo (kg)"]
    let medicationHeading = "İlaç kaydı özeti"
    let noDoses = "Bu dönemde ilaç dozu kaydedilmemiş."
    let tobaccoHeading = "Tütün kullanımı"
    let narrativeHeading = "Yapay zekâ değerlendirmesi"
    let narrativeUnavailable = "AI özeti bu raporda üretilemedi."

    func periodRange(startEpochDay: Int, endEpochDay: Int) -> String {
        "Dönem: \(formatReportDate(epochDay: startEpochDay)) – \(formatReportDate(epochDay: endEpochDay))"
    }

    func generatedOn(date: LocalDate) -> String {
        "Oluşturulma tarihi: \(formatReportDate(epochDay: date.epochDay))"
    }

    func loggedDoseLine(percent: Int, taken: Int, logged: Int) -> String {
        "Kaydedilen \(logged) dozun \(taken) tanesi alındı olarak işaretlendi (%\(percent))."
    }

    func contextLabel(context: MeasurementContext) -> String {
        switch context {
        case .fasting: "Açlık"
        case .postMeal: "Tokluk"
        case .bedtime: "Gece yatarken"
        case .random: "Rastgele"
        }
    }

    func tobaccoStatus(mode: SmokingMode) -> String {
        switch mode {
        case .quit: "Durum: bırakma sürecinde"
        case .reduce: "Durum: azaltma sürecinde"
        }
    }

    func quitDateLine(epochDay: Int) -> String {
        "Bırakma tarihi: \(formatReportDate(epochDay: epochDay))"
    }

    func quitDurationLine(days: Int) -> String {
        "Bırakma tarihinden bu yana: \(days) gün"
    }

    func slipsLine(count: Int) -> String {
        "Bu denemedeki kaçamak sayısı: \(count)"
    }

    func dailyAverageLine(average: String) -> String {
        "Günlük ortalama (son 7 günün kayıtlı günleri): \(average)"
    }
}

private struct EnglishReportCopy: ReportCopy {
    let documentTitle = "Salus Health Report"
    let measurementsHeading = "Measurements"
    let noMeasurements = "No measurement was recorded in this period."
    let bloodPressureHeading = "Blood pressure records"
    let bloodPressureColumns = ["Date", "Systolic/Diastolic (mmHg)", "Pulse (bpm)"]
    let glucoseHeading = "Blood glucose records"
    let glucoseColumns = ["Date", "mg/dL", "Context"]
    let weightHeading = "Weight records"
    let weightColumns = ["Date", "Weight (kg)"]
    let medicationHeading = "Recorded dose summary"
    let noDoses = "No medication dose was recorded in this period."
    let tobaccoHeading = "Tobacco use"
    let narrativeHeading = "AI assessment"
    let narrativeUnavailable = "The AI summary could not be produced for this report."

    func periodRange(startEpochDay: Int, endEpochDay: Int) -> String {
        "Period: \(formatReportDate(epochDay: startEpochDay)) – \(formatReportDate(epochDay: endEpochDay))"
    }

    func generatedOn(date: LocalDate) -> String {
        "Generated on: \(formatReportDate(epochDay: date.epochDay))"
    }

    func loggedDoseLine(percent: Int, taken: Int, logged: Int) -> String {
        "\(taken) of \(logged) recorded doses marked taken (\(percent)%)."
    }

    func contextLabel(context: MeasurementContext) -> String {
        switch context {
        case .fasting: "Fasting"
        case .postMeal: "Post-meal"
        case .bedtime: "Bedtime"
        case .random: "Random"
        }
    }

    func tobaccoStatus(mode: SmokingMode) -> String {
        switch mode {
        case .quit: "Status: quit attempt in progress"
        case .reduce: "Status: reducing"
        }
    }

    func quitDateLine(epochDay: Int) -> String {
        "Quit date: \(formatReportDate(epochDay: epochDay))"
    }

    func quitDurationLine(days: Int) -> String {
        "Time since quit date: \(days) \(days == 1 ? "day" : "days")"
    }

    func slipsLine(count: Int) -> String {
        "Slips during this attempt: \(count)"
    }

    func dailyAverageLine(average: String) -> String {
        "Daily average (logged days of the last 7): \(average)"
    }
}
