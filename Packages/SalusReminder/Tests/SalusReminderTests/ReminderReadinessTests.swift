// Ported 1:1 from Android
// `core/reminder/src/test/kotlin/com/alicansekban/salus/core/reminder/api/ReminderReadinessTest.kt`,
// minus the three Android-only problems (exact alarms, background restriction, battery
// optimization) and plus the two the iOS environment answers instead: AlarmKit's authorization
// and background refresh.

import Testing

@testable import SalusReminder

@Suite("Reminder readiness")
struct ReminderReadinessTests {
    // MARK: - Problem classification

    @Test("only the two permission problems are hard")
    func onlyPermissionProblemsAreHard() {
        #expect(ReminderProblem.notificationsOff.isHard)
        #expect(ReminderProblem.alarmKitDenied.isHard)
        #expect(!ReminderProblem.backgroundRefreshOff.isHard)
    }

    @Test("the declaration order is worst first")
    func declarationOrderIsWorstFirst() {
        #expect(ReminderProblem.allCases == [.notificationsOff, .alarmKitDenied, .backgroundRefreshOff])
    }

    // MARK: - Report

    @Test("the healthy report names no problem")
    func healthyReportNamesNoProblem() {
        #expect(ReminderReadinessReport.ok == ReminderReadinessReport(readiness: .ok, problems: []))
        #expect(ReminderReadinessReport.ok.hardProblems.isEmpty)
    }

    @Test("hardProblems keeps only the hard ones, in order")
    func hardProblemsKeepsOnlyHardOnes() {
        let report = ReminderReadinessReport(
            readiness: .broken,
            problems: [.notificationsOff, .alarmKitDenied, .backgroundRefreshOff]
        )

        #expect(report.hardProblems == [.notificationsOff, .alarmKitDenied])
    }

    // MARK: - Classification

    @Test("a healthy environment is ok")
    func healthyEnvironmentIsOk() async {
        let environment = FakeReminderEnvironment()

        #expect(await environment.readiness(alarmKitSupported: true) == .ok)
    }

    @Test("denied notifications break the pipeline")
    func deniedNotificationsBreakThePipeline() async {
        let environment = FakeReminderEnvironment(isNotificationsAuthorized: false)

        let report = await environment.readiness(alarmKitSupported: true)

        #expect(report.readiness == .broken)
        #expect(report.problems == [.notificationsOff])
        #expect(report.hardProblems == [.notificationsOff])
    }

    @Test("denied AlarmKit breaks the pipeline where AlarmKit exists")
    func deniedAlarmKitBreaksThePipelineWhereSupported() async {
        let environment = FakeReminderEnvironment(isAlarmKitAuthorized: false)

        let report = await environment.readiness(alarmKitSupported: true)

        #expect(report.readiness == .broken)
        #expect(report.problems == [.alarmKitDenied])
    }

    @Test("denied AlarmKit is not a problem below iOS 26")
    func deniedAlarmKitIsNotAProblemWhereUnsupported() async {
        let environment = FakeReminderEnvironment(isAlarmKitAuthorized: false)

        #expect(await environment.readiness(alarmKitSupported: false) == .ok)
    }

    @Test("background refresh off only degrades")
    func backgroundRefreshOffOnlyDegrades() async {
        let environment = FakeReminderEnvironment(isBackgroundRefreshAvailable: false)

        let report = await environment.readiness(alarmKitSupported: true)

        #expect(report.readiness == .degraded)
        #expect(report.problems == [.backgroundRefreshOff])
        #expect(report.hardProblems.isEmpty)
    }

    @Test("a hard problem alongside a soft one still breaks, and both are reported")
    func hardProblemAlongsideSoftOneStillBreaks() async {
        let environment = FakeReminderEnvironment(
            isNotificationsAuthorized: false,
            isBackgroundRefreshAvailable: false
        )

        let report = await environment.readiness(alarmKitSupported: true)

        #expect(report.readiness == .broken)
        #expect(report.problems == [.notificationsOff, .backgroundRefreshOff])
        #expect(report.hardProblems == [.notificationsOff])
    }

    @Test("every problem is reported at once when nothing is authorized")
    func everyProblemIsReportedAtOnce() async {
        let environment = FakeReminderEnvironment(
            isNotificationsAuthorized: false,
            isAlarmKitAuthorized: false,
            isBackgroundRefreshAvailable: false
        )

        let report = await environment.readiness(alarmKitSupported: true)

        #expect(report.readiness == .broken)
        #expect(report.problems == ReminderProblem.allCases)
    }
}
