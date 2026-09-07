// Ported 1:1 from Android
// `core/reminder/src/test/kotlin/com/alicansekban/salus/core/reminder/api/ReminderReadinessTest.kt`,
// minus the three Android-only problems (exact alarms, background restriction, battery
// optimization) and plus the two the iOS environment answers instead: AlarmKit's authorization
// and background refresh. Both of the new ones are SOFT — on iOS the plain notification is the
// fallback for everything, so only its own denial is hard.

import Testing

@testable import SalusReminder

@Suite("Reminder readiness")
struct ReminderReadinessTests {
    // MARK: - Problem classification

    /// Everything but a denied notification degrades to the plain notification, so on iOS the
    /// notification authorization is the only problem that can stop a reminder outright —
    /// `ReminderContracts.swift`'s `alarmKitAuthorized()` says a dose still posts without
    /// AlarmKit, which makes `alarmKitDenied` the twin of Android's soft `FULL_SCREEN_DENIED`.
    @Test("only a denied notification is hard")
    func onlyDeniedNotificationIsHard() {
        #expect(ReminderProblem.notificationsOff.isHard)
        #expect(!ReminderProblem.alarmKitDenied.isHard)
        #expect(!ReminderProblem.backgroundRefreshOff.isHard)
    }

    @Test("the declaration order is worst first")
    func declarationOrderIsWorstFirst() {
        #expect(ReminderProblem.allCases == [.notificationsOff, .alarmKitDenied, .backgroundRefreshOff])
    }

    // MARK: - Report

    @Test("the healthy report names no problem")
    func healthyReportNamesNoProblem() {
        #expect(ReminderReadinessReport.ok == ReminderReadinessReport(problems: []))
        #expect(ReminderReadinessReport.ok.readiness == .ok)
        #expect(ReminderReadinessReport.ok.hardProblems.isEmpty)
    }

    /// The report takes problems only, so no caller can pair a level with a list that contradicts
    /// it — the classification is the initializer's, and this is it read directly rather than
    /// through an environment.
    @Test("the report derives its readiness from the problems it is given")
    func reportDerivesItsReadinessFromItsProblems() {
        #expect(ReminderReadinessReport(problems: []).readiness == .ok)
        #expect(ReminderReadinessReport(problems: [.alarmKitDenied]).readiness == .degraded)
        #expect(ReminderReadinessReport(problems: [.backgroundRefreshOff]).readiness == .degraded)
        #expect(ReminderReadinessReport(problems: [.notificationsOff]).readiness == .broken)
        // A hard problem decides the level whatever else is beside it.
        #expect(
            ReminderReadinessReport(problems: [.notificationsOff, .backgroundRefreshOff]).readiness == .broken
        )
    }

    @Test("hardProblems keeps only the hard ones, in order")
    func hardProblemsKeepsOnlyHardOnes() {
        let report = ReminderReadinessReport(
            problems: [.notificationsOff, .alarmKitDenied, .backgroundRefreshOff]
        )

        #expect(report.hardProblems == [.notificationsOff])
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

    @Test("denied AlarmKit only degrades — the dose still posts as a notification")
    func deniedAlarmKitOnlyDegrades() async {
        let environment = FakeReminderEnvironment(isAlarmKitAuthorized: false)

        let report = await environment.readiness(alarmKitSupported: true)

        #expect(report.readiness == .degraded)
        #expect(report.problems == [.alarmKitDenied])
        #expect(report.hardProblems.isEmpty)
    }

    @Test("denied AlarmKit is not a problem below iOS 26")
    func deniedAlarmKitIsNotAProblemWhereUnsupported() async {
        let environment = FakeReminderEnvironment(isAlarmKitAuthorized: false)

        #expect(await environment.readiness(alarmKitSupported: false) == .ok)
    }

    @Test("AlarmKit is not even asked below iOS 26")
    func alarmKitIsNotAskedWhereUnsupported() async {
        let environment = FakeReminderEnvironment(isAlarmKitAuthorized: false)

        _ = await environment.readiness(alarmKitSupported: false)
        #expect(environment.alarmKitAuthorizationReads == 0)

        _ = await environment.readiness(alarmKitSupported: true)
        #expect(environment.alarmKitAuthorizationReads == 1)
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
        #expect(report.hardProblems == [.notificationsOff])
    }
}
