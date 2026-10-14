import Foundation
import SalusAI
import SalusModel
import SalusSmoking
import Testing

@testable import FeatureAIHealth

// Twin of Android `feature/aihealth/src/test/.../report/TobaccoUseReportTest.kt`: the "Tobacco
// use" section of the doctor report (spec section 7) - status, quit date, duration, slips and,
// while reducing, the daily average - and never money, whatever the snapshot knows.

@Suite("Tobacco use report section")
struct TobaccoUseReportTests {
    private let zone = TobaccoFixture.istanbul

    // MARK: - The summary, taken from the snapshot

    @Test("a quit snapshot becomes quit date, whole days and slips")
    func quitSnapshotBecomesDateDaysAndSlips() throws {
        let summary = try #require(tobaccoUseSummaryOf(TobaccoFixture.quitSnapshot(), zone: zone))

        #expect(summary.mode == .quit)
        // 21:30 UTC is already the next morning in Istanbul: the quit date is the local one.
        #expect(summary.quitDateEpochDay == LocalDate(year: 2026, month: 8, day: 11).epochDay)
        #expect(summary.durationDays == 9)
        #expect(summary.slipCount == 2)
        #expect(summary.dailyAverageTenths == nil)
    }

    @Test("a reduce snapshot averages only the days that have an entry")
    func reduceAveragesOnlyLoggedDays() throws {
        // 4, 5, none, 0, 6, none, 5 -> five logged days, 20 units. A day without data is not a
        // zero, and a logged zero is.
        let snapshot = TobaccoFixture.reduceSnapshot([4, 5, nil, 0, 6, nil, 5])

        let summary = try #require(tobaccoUseSummaryOf(snapshot, zone: zone))

        #expect(summary.mode == .reduce)
        #expect(summary.dailyAverageTenths == 40)
        #expect(summary.quitDateEpochDay == nil)
        #expect(summary.durationDays == nil)
        #expect(summary.slipCount == nil)
    }

    @Test("the daily average is rounded to the nearest tenth")
    func averageIsRoundedToTheNearestTenth() {
        // 5 units over 3 days is 1.666..., printed 1.7.
        #expect(tobaccoUseSummaryOf(TobaccoFixture.reduceSnapshot([1, 2, 2]), zone: zone)?.dailyAverageTenths == 17)
    }

    @Test("a reduce plan with no logged day has no average rather than zero")
    func noLoggedDayHasNoAverage() throws {
        let summary = try #require(tobaccoUseSummaryOf(TobaccoFixture.reduceSnapshot([nil, nil, nil]), zone: zone))

        #expect(summary.mode == .reduce)
        #expect(summary.dailyAverageTenths == nil)
    }

    @Test("nothing set up means no summary")
    func notSetUpMeansNoSummary() {
        #expect(tobaccoUseSummaryOf(.notSetUp, zone: zone) == nil)
    }

    // MARK: - The block

    @Test("a quit block carries status, quit date, duration and slips in English")
    func quitBlockInEnglish() throws {
        let block = try tobaccoBlock(of: blocksOf(summary: quitSummary))

        #expect(block.heading == "Tobacco use")
        #expect(block.status == "Status: quit attempt in progress")
        #expect(block.quitDate == "Quit date: 11.08.2026")
        #expect(block.duration == "Time since quit date: 9 days")
        #expect(block.slips == "Slips during this attempt: 2")
        #expect(block.dailyAverage == nil)
    }

    @Test("a quit block carries the same lines in Turkish")
    func quitBlockInTurkish() throws {
        let block = try tobaccoBlock(of: blocksOf(summary: quitSummary, language: .tr))

        #expect(block.heading == "Tütün kullanımı")
        #expect(block.status == "Durum: bırakma sürecinde")
        #expect(block.quitDate == "Bırakma tarihi: 11.08.2026")
        #expect(block.duration == "Bırakma tarihinden bu yana: 9 gün")
        #expect(block.slips == "Bu denemedeki kaçamak sayısı: 2")
    }

    @Test("a single day reads as one day")
    func singleDayReadsAsOneDay() throws {
        let summary = TobaccoUseSummary(mode: .quit, quitDateEpochDay: quitDay, durationDays: 1, slipCount: 0)

        #expect(try tobaccoBlock(of: blocksOf(summary: summary)).duration == "Time since quit date: 1 day")
    }

    @Test("a reduce block carries status and the daily average and nothing about a quit")
    func reduceBlockCarriesStatusAndAverage() throws {
        let block = try tobaccoBlock(of: blocksOf(summary: reduceSummary))

        #expect(block.status == "Status: reducing")
        #expect(block.dailyAverage == "Daily average (logged days of the last 7): 4.0")
        #expect(block.quitDate == nil)
        #expect(block.duration == nil)
        #expect(block.slips == nil)
    }

    @Test("a reduce block without an average leaves the line out")
    func reduceBlockWithoutAverage() throws {
        let block = try tobaccoBlock(of: blocksOf(summary: TobaccoUseSummary(mode: .reduce)))

        #expect(block.dailyAverage == nil)
    }

    @Test("the block is absent when smoking is not set up")
    func blockIsAbsentWhenNotSetUp() {
        let blocks = blocksOf(summary: nil)

        #expect(!blocks.contains {
            if case .tobaccoUse = $0 {
                true
            } else {
                false
            }
        })
        #expect(!blocks.sectionHeadings().contains { $0.contains("obacco") })
    }

    @Test("the block sits between the dose summary and the AI section")
    func blockSitsBetweenDosesAndNarrative() {
        let order = blocksOf(summary: quitSummary).compactMap { block -> String? in
            switch block {
            case let .section(heading): heading
            case let .tobaccoUse(block): block.heading
            default: nil
            }
        }

        #expect(order.suffix(3) == ["Recorded dose summary", "Tobacco use", "AI assessment"])
    }

    @Test("no money appears in the block, whatever the snapshot knows")
    func noMoneyAppearsInTheBlock() throws {
        let markers = ["₺", "$", "€", "£", "try", "usd", "eur", "lira", "saved", "tasarruf"]
        for language in [AiLanguage.en, .tr] {
            for summary in [quitSummary, reduceSummary] {
                let block = try tobaccoBlock(of: blocksOf(summary: summary, language: language))
                let text = [
                    block.heading,
                    block.status,
                    block.quitDate,
                    block.duration,
                    block.slips,
                    block.dailyAverage
                ]
                .compactMap(\.self)
                .joined(separator: "\n")

                for marker in markers {
                    #expect(!text.lowercased().contains(marker), "\(language) block contains '\(marker)': \(text)")
                }
                #expect(!text.contains(String(TobaccoFixture.savedMinor)))
            }
        }
    }

    // MARK: - Helpers

    private func tobaccoBlock(of blocks: [ReportBlock]) throws -> TobaccoUseBlock {
        let found = blocks.compactMap { block -> TobaccoUseBlock? in
            if case let .tobaccoUse(tobacco) = block {
                return tobacco
            }
            return nil
        }
        return try #require(found.first)
    }

    private func blocksOf(summary: TobaccoUseSummary?, language: AiLanguage = .en) -> [ReportBlock] {
        reportBlocksOf(
            stats: HealthPeriodStats(
                periodType: .weekly,
                startEpochDay: TobaccoFixture.day - 6,
                endEpochDay: TobaccoFixture.day,
                distinctRecordDays: 5,
                systolic: nil,
                diastolic: nil,
                pulse: nil,
                glucoseMgDl: nil,
                weightKg: nil,
                loggedDoses: 4,
                takenDoses: 3
            ),
            rows: .empty,
            narrative: nil,
            copy: language.reportCopy(),
            generatedOn: LocalDate(epochDay: TobaccoFixture.day),
            tobacco: summary
        )
    }

    private let quitDay = LocalDate(year: 2026, month: 8, day: 11).epochDay

    private var quitSummary: TobaccoUseSummary {
        TobaccoUseSummary(mode: .quit, quitDateEpochDay: quitDay, durationDays: 9, slipCount: 2)
    }

    private var reduceSummary: TobaccoUseSummary {
        TobaccoUseSummary(mode: .reduce, dailyAverageTenths: 40)
    }
}

extension [ReportBlock] {
    fileprivate func sectionHeadings() -> [String] {
        compactMap { block in
            if case let .section(heading) = block {
                return heading
            }
            return nil
        }
    }
}
