import XCTest
import UserNotifications
@testable import Stronix

@MainActor
final class NotificationManagerTests: XCTestCase {
    func testInitializationDoesNotCheckOrRequestAuthorization() {
        let client = NotificationAuthorizationClientSpy(status: .notDetermined)

        _ = NotificationManager(authorizationClient: client)

        XCTAssertEqual(client.statusRequestCount, 0)
        XCTAssertEqual(client.authorizationRequestCount, 0)
    }

    func testRestReminderPermissionRequestsOnlyOnceWhenStatusIsUndetermined() {
        let client = NotificationAuthorizationClientSpy(status: .notDetermined)
        let authorizationRequested = expectation(description: "authorization requested")
        client.onAuthorizationRequested = { authorizationRequested.fulfill() }
        let manager = NotificationManager(authorizationClient: client)

        manager.requestPermissionForRestReminderIfNeeded()
        manager.requestPermissionForRestReminderIfNeeded()

        wait(for: [authorizationRequested], timeout: 1)
        XCTAssertEqual(client.statusRequestCount, 1)
        XCTAssertEqual(client.authorizationRequestCount, 1)
    }

    func testRestReminderPermissionDoesNotPromptWhenAuthorizationWasAlreadyDecided() {
        let client = NotificationAuthorizationClientSpy(status: .denied)
        let manager = NotificationManager(authorizationClient: client)

        manager.requestPermissionForRestReminderIfNeeded()

        XCTAssertEqual(client.statusRequestCount, 1)
        XCTAssertEqual(client.authorizationRequestCount, 0)
    }
}

private final class NotificationAuthorizationClientSpy: NotificationAuthorizationClient {
    let status: UNAuthorizationStatus
    private(set) var statusRequestCount = 0
    private(set) var authorizationRequestCount = 0
    var onAuthorizationRequested: (() -> Void)?

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        statusRequestCount += 1
        completion(status)
    }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        authorizationRequestCount += 1
        onAuthorizationRequested?()
        completion(false, nil)
    }
}
