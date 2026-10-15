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
//    "this device is iOS 26.0+" by injecting a double instead of faking an availability check.
//  * `backgroundRefreshAvailable()` asks a main-actor probe the app layer supplies, because
//    `UIApplication.backgroundRefreshStatus` is main-actor-only. It is asked at the moment of the
//    question and never at construction: a value sampled while the app was still launching read
//    as "off" and kept the Home readiness card up on every cold start.

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

/// `UIApplication.backgroundRefreshStatus`, in memory, counting how often it is read.
final class FakeBackgroundRefreshStatus: @unchecked Sendable {
    private let lock = NSLock()
    private var available: Bool
    private var reads = 0

    var readCount: Int { lock.withLock { reads } }

    init(available: Bool) {
        self.available = available
    }

    func set(_ available: Bool) {
        lock.withLock { self.available = available }
    }

    func read() -> Bool {
        lock.withLock {
            reads += 1
            return available
        }
    }
}

@Suite("System reminder environment")
struct SystemReminderEnvironmentTests {
    private let center = FakeUserNotificationCenter()

    private func makeEnvironment(
        alarmKit: (any AlarmKitAuthorizing)? = nil,
        backgroundRefresh: FakeBackgroundRefreshStatus = FakeBackgroundRefreshStatus(available: true)
    ) -> SystemReminderEnvironment {
        SystemReminderEnvironment(
            center: center,
            alarmKit: alarmKit,
            backgroundRefreshStatus: { backgroundRefresh.read() }
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
        // And the fix button below iOS 26.0 must not pretend it did something.
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

    @Test("background refresh is not read while the environment is built")
    func backgroundRefreshIsNotReadAtConstruction() {
        let status = FakeBackgroundRefreshStatus(available: false)
        _ = makeEnvironment(backgroundRefresh: status)

        // The composition root is built inside `App.init`, before launch finishes, where the
        // status is not yet the device's answer.
        #expect(status.readCount == 0)
    }

    @Test("background refresh answers what the status is when asked")
    func backgroundRefreshIsReadLive() async {
        let status = FakeBackgroundRefreshStatus(available: false)
        let environment = makeEnvironment(backgroundRefresh: status)
        #expect(await environment.backgroundRefreshAvailable() == false)

        // The user can flip it in Settings behind our back; no re-sample step is needed.
        status.set(true)
        #expect(await environment.backgroundRefreshAvailable() == true)
    }

    @Test("readiness drops the background refresh problem once the status reads available")
    func readinessFollowsTheLiveStatus() async {
        // The fake centre can only answer "unknown" (see the header), so notifications stay off
        // here; what is pinned is the background refresh row alone.
        let status = FakeBackgroundRefreshStatus(available: false)
        let environment = makeEnvironment(backgroundRefresh: status)
        #expect(await environment.readiness(alarmKitSupported: false).problems.contains(.backgroundRefreshOff))

        status.set(true)
        #expect(await !environment.readiness(alarmKitSupported: false).problems.contains(.backgroundRefreshOff))
    }
}
