// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/report/
// ReportBlocks.kt`.

import Foundation
import SalusAI
import SalusModel

/// One block of the report, chosen before anything is drawn.
///
/// The document is built in two steps — *what* it says, then *where* the ink goes — because the
/// first step is where every decision a reader could be harmed by lives: which sections appear,
/// how the dose figures are worded, what stands in for a narrative that was skipped. Those are
/// assertable as data. Only the second step needs a graphics stack, and it has no choices left
/// to make by the time it runs.
enum ReportBlock: Equatable, Sendable {
    case title(String)
    case section(String)
    case body(String)

    /// Blank vertical space; a paragraph break inside narrative prose.
    case gap

    /// - Parameters:
    ///   - weights: column widths as a share of the usable page width.
    ///   - rows: one list of cells per record, in the column order of `columns`.
    case table(heading: String, columns: [String], weights: [Float], rows: [[String]])
}

/// Everything the report says, in order.
///
/// A metric with no reading in the period is omitted entirely rather than printed as an empty
/// table: a doctor reading "Blood glucose records" above nothing is being told the patient
/// measured and got no result, which is not what happened.
func reportBlocksOf(
    stats: HealthPeriodStats,
    rows: HealthPeriodRows,
    narrative: String?,
    copy: ReportCopy,
    generatedOn: LocalDate
) -> [ReportBlock] {
    var blocks: [ReportBlock] = []
    blocks.append(.title(copy.documentTitle))
    blocks.append(.body(copy.periodRange(startEpochDay: stats.startEpochDay, endEpochDay: stats.endEpochDay)))
    // The generation date matters as much as the period: a report read three weeks later must
    // not be mistaken for a current one.
    blocks.append(.body(copy.generatedOn(date: generatedOn)))

    addMeasurementTables(&blocks, rows: rows, copy: copy)
    addDoseSummary(&blocks, stats: stats, copy: copy)
    addNarrative(&blocks, narrative: narrative, copy: copy)
    return blocks
}

private func addMeasurementTables(
    _ blocks: inout [ReportBlock],
    rows: HealthPeriodRows,
    copy: ReportCopy
) {
    if rows.isEmpty {
        blocks.append(.section(copy.measurementsHeading))
        blocks.append(.body(copy.noMeasurements))
        return
    }

    if !rows.bloodPressure.isEmpty {
        blocks.append(
            .table(
                heading: copy.bloodPressureHeading,
                columns: copy.bloodPressureColumns,
                weights: bloodPressureWeights,
                rows: rows.bloodPressure.map { row in
                    [
                        copy.date(epochDay: row.epochDay),
                        "\(row.systolic.asInteger())/\(row.diastolic?.asInteger() ?? emptyCell)",
                        row.pulse?.asInteger() ?? emptyCell
                    ]
                }
            )
        )
    }

    if !rows.glucose.isEmpty {
        blocks.append(
            .table(
                heading: copy.glucoseHeading,
                columns: copy.glucoseColumns,
                weights: glucoseWeights,
                rows: rows.glucose.map { row in
                    [
                        copy.date(epochDay: row.epochDay),
                        row.mgDl.asInteger(),
                        row.context.map(copy.contextLabel) ?? emptyCell
                    ]
                }
            )
        )
    }

    if !rows.weight.isEmpty {
        blocks.append(
            .table(
                heading: copy.weightHeading,
                columns: copy.weightColumns,
                weights: weightWeights,
                rows: rows.weight.map { row in
                    [copy.date(epochDay: row.epochDay), row.kilograms.asDecimal()]
                }
            )
        )
    }
}

/// The medication block, worded as what it measures: doses the user *recorded*, not doses the
/// schedule called for. Nothing writes a row for a dose that was silently missed, so calling this
/// adherence in front of a doctor would overstate it for anyone who only logs what they take —
/// and a doctor acting on that number is the exact harm this report must not cause.
private func addDoseSummary(
    _ blocks: inout [ReportBlock],
    stats: HealthPeriodStats,
    copy: ReportCopy
) {
    blocks.append(.section(copy.medicationHeading))
    if let percent = stats.takenPercent {
        blocks.append(.body(copy.loggedDoseLine(percent: percent, taken: stats.takenDoses, logged: stats.loggedDoses)))
    } else {
        blocks.append(.body(copy.noDoses))
    }
}

/// The AI section, or the note that stands in for it when it was skipped.
private func addNarrative(
    _ blocks: inout [ReportBlock],
    narrative: String?,
    copy: ReportCopy
) {
    blocks.append(.section(copy.narrativeHeading))
    guard let narrative else {
        // Deliberately one note for every skip reason — quota spent, model failure, too few
        // recorded days. Those distinctions matter to the app and mean nothing on a printed
        // page, and the model SDK's own failure text is vendor-worded diagnostics that must
        // never end up in front of a doctor.
        blocks.append(.body(copy.narrativeUnavailable))
        return
    }
    narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .forEach { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            blocks.append(trimmed.isEmpty ? .gap : .body(String(trimmed)))
        }
}

/// Locale-independent whole-number rendering, so a report reads the same on every device.
extension Double {
    fileprivate func asInteger() -> String {
        String(Int(rounded()))
    }

    /// Locale-independent one-decimal rendering, matching how `PromptBuilder` formats its numbers.
    fileprivate func asDecimal() -> String {
        let tenths = Int64((self * tenthsScale).rounded())
        let sign = tenths < 0 ? "-" : ""
        let magnitude = abs(tenths)
        return "\(sign)\(magnitude / tenthsScaleL).\(magnitude % tenthsScaleL)"
    }
}

/// Renders an epoch day as `dd.MM.yyyy` without going through a locale-dependent formatter, so
/// one document does not change shape because the reader's device is set to another region.
func formatReportDate(epochDay: Int) -> String {
    let date = LocalDate(epochDay: epochDay)
    return "\(date.day.padded()).\(date.month.padded()).\(date.year)"
}

extension Int {
    /// Kotlin's `toString().padStart(2, '0')` — a two-digit zero-padded decimal, locale-free.
    fileprivate func padded() -> String {
        let text = String(self)
        return text.count >= 2 ? text : "0" + text
    }
}

private let tenthsScale = 10.0
private let tenthsScaleL: Int64 = 10

/// Column widths as a share of the usable width, per table.
private let bloodPressureWeights: [Float] = [0.35, 0.35, 0.30]
private let glucoseWeights: [Float] = [0.35, 0.25, 0.40]
private let weightWeights: [Float] = [0.50, 0.50]

/// Stands in for a value the record does not carry, so a column never collapses.
private let emptyCell = "–"
