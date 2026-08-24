// What `SystemReminderEnvironment` answers, and what it asks for.
//
// Two of its three questions are testable off device; the third is not, and the shape of these
// cases says which is which:
//
//  * `notificationsAuthorized()` reads `UNNotificationSettings`, which has no public initializer,
//    so the seam answers optionally and nil means "unknown". The only case a fake can produce is
//    therefore the unknown one — pinned below, because "unknown" must read as NOT authorized: a
//    past-due row settled as FIRED on a guess would tell the user a reminder was delivered when
//    nobody knows whether it was.
//  * `alarmKitAuthorized()` routes on the presence of the AlarmKit seam, exactly as
//    `UserNotificationGateway` routes on the presence of the alarm scheduler — so a case says
//    "this device is iOS 26.1+" by injecting a double instead of faking an availability check.
//  * `backgroundRefreshAvailable()` is a snapshot the app layer samples, because
//    `UIApplication.backgroundRefreshStatus` is main-actor-only and this seam is not.

import Foundation
import Testing
import UserNotifications

@testable import SalusReminder

/// AlarmKit's authorization, in memory.
final class FakeAlarmKitAuthorizer: AlarmKitAuthorizing, @unchecked Sendable {
    private let lock = NSLock()
    private var authorized: Bool
    private var grantsOnRequest: Bool
    private var requests = 0

    /// How many times the user was prompted — a fix button that prompts twice is a bug.
    var requestCount: Int { lock.withLock { requests } }

    init(authorized: Bool = false, grantsOnRequest: Bool = true) {
        self.authorized = authorized
        self.grantsOnRequest = grantsOnRequest
    }

    func isAuthorized() async -> Bool {
        lock.withLock { authorized }
    }

    func requestAuthorization() async -> Bool {
        lock.withLock {
            requests += 1
            authorized = grantsOnRequest
            return authorized
        }
    }
}

@Suite("System reminder environment")
struct SystemReminderEnvironmentTests {
    private let center = FakeUserNotificationCenter()

    private func makeEnvironment(
        alarmKit: (any AlarmKitAuthorizing)? = nil,
        backgroundRefreshAvailable: Bool = true
    ) -> SystemReminderEnvironment {
        SystemReminderEnvironment(
            center: center,
            alarmKit: alarmKit,
            backgroundRefreshAvailable: backgroundRefreshAvailable
        )
    }

    @Test("settings that cannot be read are not authorization")
    func unknownSettingsAreNotAuthorized() async {
        #expect(await makeEnvironment().notificationsAuthorized() == false)
    }

    @Test("without an AlarmKit backend nothing is alarm-authorized")
    func alarmKitIsUnauthorizedWithoutABackend() async {
        let environment = makeEnvironment()

        #expect(await environment.alarmKitAuthorized() == false)
        // And the fix button below iOS 26.1 must not pretend it did something.
        #expect(await environment.requestAlarmKitAuthorization() == false)
    }

    @Test("with an AlarmKit backend the answer is the backend's")
    func alarmKitAnswerComesFromTheBackend() async {
        let authorizer = FakeAlarmKitAuthorizer(authorized: true)

        #expect(await makeEnvironment(alarmKit: authorizer).alarmKitAuthorized() == true)
    }

    @Test("requesting AlarmKit authorization prompts once and reports the outcome")
    func alarmKitRequestIsForwarded() async {
        let authorizer = FakeAlarmKitAuthorizer(authorized: false, grantsOnRequest: true)
        let environment = makeEnvironment(alarmKit: authorizer)

        #expect(await environment.requestAlarmKitAuthorization() == true)
        #expect(authorizer.requestCount == 1)
        #expect(await environment.alarmKitAuthorized() == true)
    }

    @Test("requesting notification authorization goes through the centre seam")
    func notificationRequestIsForwarded() async {
        center.grantAuthorization(false)

        #expect(await makeEnvironment().requestNotificationAuthorization() == false)
        // The alert/sound/badge set: the dose alarm's time-sensitive level is an entitlement, not
        // an authorization option, so there is nothing extra to ask for here.
        #expect(center.authorizationRequests == [SystemReminderEnvironment.notificationOptions])
    }

    @Test("a centre that refuses to ask is not authorization")
    func refusedNotificationRequestIsNotGranted() async {
        center.failAuthorizationRequests()

        #expect(await makeEnvironment().requestNotificationAuthorization() == false)
    }

    @Test("background refresh reports the sampled snapshot")
    func backgroundRefreshReportsTheSnapshot() {
        let environment = makeEnvironment(backgroundRefreshAvailable: false)
        #expect(environment.backgroundRefreshAvailable() == false)

        // The app layer re-samples `UIApplication.backgroundRefreshStatus` whenever the app comes
        // back to the foreground, because the user can flip it in Settings behind our back.
        environment.setBackgroundRefreshAvailable(true)
        #expect(environment.backgroundRefreshAvailable() == true)
    }
}
