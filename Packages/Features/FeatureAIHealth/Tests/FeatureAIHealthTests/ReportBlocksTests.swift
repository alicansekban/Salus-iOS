// Ported 1:1 from Android
// `feature/aihealth/src/test/kotlin/com/alicansekban/salus/feature/aihealth/report/
// ReportBlocksTest.kt` — the cases, in the Kotlin order, with the Kotlin inputs and expectations.

import Foundation
import SalusAI
import SalusModel
import Testing

@testable import FeatureAIHealth

/// What the report says, independent of where the ink lands.
///
/// Every claim a reader could be harmed by is decided here: which sections appear at all, how the
/// medication figures are worded, and what stands in for a narrative that was never produced.
@Suite("ReportBlocks")
struct ReportBlocksTests {
    /// A metric with no reading gets no section at all.
    @Test("a metric with no reading gets no section at all")
    func metricWithNoReadingGetsNoSection() {
        let blocks = blocksOf(
            rows: HealthPeriodRows(
                bloodPressure: [BloodPressureRow(epochDay: day, systolic: 128, diastolic: 82, pulse: 71)],
                glucose: [],
                weight: []
            )
        )

        let headings = blocks.compactMap { block -> String? in
            if case let .table(heading, _, _, _) = block {
                return heading
            }
            return nil
        }
        #expect(headings == ["Blood pressure records"])
    }

    /// Every measured metric gets its own table.
    @Test("every measured metric gets its own table")
    func everyMeasuredMetricGetsItsOwnTable() {
        let blocks = blocksOf(
            rows: HealthPeriodRows(
                bloodPressure: [BloodPressureRow(epochDay: day, systolic: 128, diastolic: 82, pulse: 71)],
                glucose: [GlucoseRow(epochDay: day, mgDl: 96, context: .fasting)],
                weight: [WeightRow(epochDay: day, kilograms: 74.25)]
            )
        )

        let headings = blocks.compactMap { block -> String? in
            if case let .table(heading, _, _, _) = block {
                return heading
            }
            return nil
        }
        #expect(headings == ["Blood pressure records", "Blood glucose records", "Weight records"])
    }

    /// A period without any measurement says so instead of printing empty tables.
    @Test("a period without any measurement says so instead of printing empty tables")
    func periodWithoutMeasurementSaysSo() {
        let blocks = blocksOf(rows: .empty)

        #expect(blocks.compactMap { block -> String? in
            if case .table = block {
                return ""
            }
            return nil
        }.isEmpty)
        #expect(blocks.bodyText().contains("No measurement was recorded in this period."))
    }

    /// Values are rendered without a locale.
    @Test("values are rendered without a locale")
    func valuesRenderedWithoutLocale() {
        let blocks = blocksOf(
            rows: HealthPeriodRows(
                bloodPressure: [BloodPressureRow(epochDay: day, systolic: 128.4, diastolic: 82, pulse: nil)],
                glucose: [GlucoseRow(epochDay: day, mgDl: 96, context: nil)],
                weight: [WeightRow(epochDay: day, kilograms: 74.25)]
            )
        )
        let tables = blocks.compactMap { block -> (String, [[String]])? in
            if case let .table(heading, _, _, rows) = block {
                return (heading, rows)
            }
            return nil
        }
        let byHeading = Dictionary(uniqueKeysWithValues: tables)

        // A missing pulse becomes a dash, never a zero — a printed 0 bpm is a clinical claim.
        #expect(byHeading["Blood pressure records"]?.first == ["20.08.2026", "128/82", "–"])
        #expect(byHeading["Blood glucose records"]?.first == ["20.08.2026", "96", "–"])
        #expect(byHeading["Weight records"]?.first == ["20.08.2026", "74.3"])
    }

    /// A glucose context is printed as a label and never as a raw enum name.
    @Test("a glucose context is printed as a label and never as a raw enum name")
    func glucoseContextPrintedAsLabel() {
        let blocks = blocksOf(
            rows: HealthPeriodRows(
                bloodPressure: [],
                glucose: [GlucoseRow(epochDay: day, mgDl: 142, context: .postMeal)],
                weight: []
            )
        )

        let cells = blocks.compactMap { block -> [[String]]? in
            if case let .table(_, _, _, rows) = block {
                return rows
            }
            return nil
        }.first?.first
        #expect(cells?.last == "Post-meal")
        #expect(cells?.contains("POST_MEAL") == false)
    }

    // MARK: - The medication wording

    /// The dose line says recorded doses and never adherence.
    @Test("the dose line says recorded doses and never adherence")
    func doseLineSaysRecordedDoses() {
        let blocks = blocksOf(stats: statsWith(loggedDoses: 12, takenDoses: 9))

        let line = blocks.bodyText().first { $0.contains("recorded doses") }
        #expect(line == "9 of 12 recorded doses marked taken (75%).")
        #expect(!blocks.bodyText().contains { $0.localizedCaseInsensitiveContains("adherence") })
    }

    /// The Turkish dose line uses logged-dose wording.
    @Test("the Turkish dose line uses logged-dose wording")
    func turkishDoseLineUsesLoggedDoseWording() {
        let blocks = blocksOf(
            stats: statsWith(loggedDoses: 12, takenDoses: 9),
            language: .tr
        )

        let line = blocks.bodyText().first { $0.contains("dozun") }
        #expect(line == "Kaydedilen 12 dozun 9 tanesi alındı olarak işaretlendi (%75).")
        #expect(!blocks.bodyText().contains { $0.contains("planlanan") || $0.contains("uyum") })
    }

    /// A period with no recorded dose says so rather than showing zero percent.
    @Test("a period with no recorded dose says so rather than showing zero percent")
    func noRecordedDoseSaysSo() {
        let blocks = blocksOf(stats: statsWith(loggedDoses: 0, takenDoses: 0))

        #expect(blocks.bodyText().contains("No medication dose was recorded in this period."))
        #expect(!blocks.bodyText().contains { $0.contains("0%") })
    }

    // MARK: - The narrative

    /// A skipped narrative leaves a note in place of the section body.
    @Test("a skipped narrative leaves a note in place of the section body")
    func skippedNarrativeLeavesNote() {
        let blocks = blocksOf(narrative: nil)

        #expect(blocks.sectionHeadings().contains("AI assessment"))
        #expect(blocks.bodyText().contains("The AI summary could not be produced for this report."))
    }

    /// A narrative is kept as its own paragraphs.
    @Test("a narrative is kept as its own paragraphs")
    func narrativeKeptAsOwnParagraphs() {
        let blocks = blocksOf(narrative: "Period summary\n\nQuestions for your doctor")

        let body = blocks.bodyText()
        #expect(body.contains("Period summary"))
        #expect(body.contains("Questions for your doctor"))
        // The blank line between them survives as a gap rather than as an empty text line.
        #expect(blocks.contains(.gap))
        #expect(!body.contains { $0.isEmpty })
    }

    // MARK: - The header

    /// The header names the period and the day the file was produced.
    @Test("the header names the period and the day the file was produced")
    func headerNamesPeriodAndDay() {
        let blocks = blocksOf()

        #expect(blocks.first == .title("Salus Health Report"))
        let body = blocks.bodyText()
        #expect(body.contains("Period: 14.08.2026 – 20.08.2026"))
        #expect(body.contains("Generated on: 20.08.2026"))
    }

    // MARK: - Helpers

    private func blocksOf(
        stats: HealthPeriodStats? = nil,
        rows: HealthPeriodRows = .empty,
        narrative: String? = nil,
        language: AiLanguage = .en
    ) -> [ReportBlock] {
        reportBlocksOf(
            stats: stats ?? statsWith(loggedDoses: 4, takenDoses: 3),
            rows: rows,
            narrative: narrative,
            copy: language.reportCopy(),
            generatedOn: LocalDate(epochDay: day)
        )
    }

    private func statsWith(loggedDoses: Int, takenDoses: Int) -> HealthPeriodStats {
        HealthPeriodStats(
            periodType: .weekly,
            startEpochDay: day - 6,
            endEpochDay: day,
            distinctRecordDays: 5,
            systolic: nil,
            diastolic: nil,
            pulse: nil,
            glucoseMgDl: nil,
            weightKg: nil,
            loggedDoses: loggedDoses,
            takenDoses: takenDoses
        )
    }

    /// 2026-08-20.
    private let day = 20685
}

extension [ReportBlock] {
    fileprivate func bodyText() -> [String] {
        compactMap { block in
            if case let .body(text) = block {
                return text
            }
            return nil
        }
    }

    fileprivate func sectionHeadings() -> [String] {
        compactMap { block in
            if case let .section(heading) = block {
                return heading
            }
            return nil
        }
    }
}
