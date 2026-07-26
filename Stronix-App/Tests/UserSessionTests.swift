import XCTest
@testable import Stronix

@MainActor
final class UserSessionTests: XCTestCase {
    func testRestorePublishesAuthenticatedUserAndLogoutResetsUserScopedState() async throws {
        let user = sessionTestUser(id: 7)
        let operations = AuthenticationOperationsStub(restoredUser: user)
        let resetter = RecordingUserScopedResetter()
        let session = UserSession(operations: operations, resetters: [resetter])

        XCTAssertEqual(session.state, .restoring)

        await session.restore()
        XCTAssertEqual(session.state, .authenticated(user))

        try await session.logout()
        XCTAssertEqual(session.state, .unauthenticated)
        XCTAssertEqual(resetter.resetCount, 1)
    }

    func testSwitchingAuthenticatedUsersResetsUserScopedStateAndAdvancesScope() async throws {
        let userA = sessionTestUser(id: 9)
        let userB = sessionTestUser(id: 10)
        let operations = AuthenticationOperationsStub(restoredUser: userA)
        operations.loggedInUser = userB
        let resetter = RecordingUserScopedResetter()
        let session = UserSession(operations: operations, resetters: [resetter])

        await session.restore()
        let initialScopeID = session.scopeID

        try await session.login(email: userB.email, password: "password")

        XCTAssertEqual(session.currentUserID, userB.id)
        XCTAssertEqual(resetter.resetCount, 1)
        XCTAssertEqual(session.scopeID, initialScopeID + 1)
    }

    func testFailedLogoutKeepsAuthenticatedUserAndDoesNotResetState() async throws {
        let user = sessionTestUser(id: 8)
        let operations = AuthenticationOperationsStub(restoredUser: user)
        operations.logoutError = AuthError.sessionUnavailable
        let resetter = RecordingUserScopedResetter()
        let session = UserSession(operations: operations, resetters: [resetter])
        await session.restore()

        do {
            try await session.logout()
            XCTFail("Expected logout to fail")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionUnavailable)
        }

        XCTAssertEqual(session.state, .authenticated(user))
        XCTAssertEqual(resetter.resetCount, 0)
    }
    func testRegisteringTheSameResetterAgainDoesNotDuplicateScopeReset() async throws {
        let user = sessionTestUser(id: 12)
        let operations = AuthenticationOperationsStub(restoredUser: user)
        let resetter = RecordingUserScopedResetter()
        let session = UserSession(operations: operations)

        session.registerResetter(resetter)
        session.registerResetter(resetter)
        await session.restore()
        try await session.logout()

        XCTAssertEqual(resetter.resetCount, 1)
    }

    func testNewerLogoutCancelsOlderLoginBeforeItCanAuthenticate() async throws {
        let user = sessionTestUser(id: 11)
        let operations = SuspendingAuthenticationOperations(user: user)
        let session = UserSession(operations: operations)

        let login = Task { try await session.login(email: user.email, password: "password") }
        await fulfillment(of: [operations.loginStarted])

        try await session.logout()
        operations.completeLogin()
        try await login.value

        XCTAssertTrue(operations.loginWasCancelled)
        XCTAssertEqual(session.state, .unauthenticated)
    }
}

private final class SuspendingAuthenticationOperations: AuthenticationOperating {
    let loginStarted = XCTestExpectation(description: "Login started")
    private let user: User
    private var continuation: CheckedContinuation<User, Error>?
    private(set) var loginWasCancelled = false

    init(user: User) {
        self.user = user
    }

    func register(_ registration: AuthRegistration) async throws -> User { user }

    func login(email: String, password: String) async throws -> User {
        loginStarted.fulfill()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation = $0 }
        } onCancel: {
            self.loginWasCancelled = true
            self.continuation?.resume(throwing: CancellationError())
            self.continuation = nil
        }
    }

    func restoreSession() async throws -> User? { nil }
    func logout() async throws {}

    func completeLogin() {
        continuation?.resume(returning: user)
        continuation = nil
    }
}

private final class AuthenticationOperationsStub: AuthenticationOperating {
    let restoredUser: User?
    var loggedInUser: User?
    var logoutError: Error?

    init(restoredUser: User?) {
        self.restoredUser = restoredUser
    }

    func register(_ registration: AuthRegistration) async throws -> User {
        try XCTUnwrap(restoredUser)
    }

    func login(email: String, password: String) async throws -> User {
        try XCTUnwrap(loggedInUser ?? restoredUser)
    }

    func restoreSession() async throws -> User? { restoredUser }

    func logout() async throws {
        if let logoutError { throw logoutError }
    }
}

@MainActor
private final class RecordingUserScopedResetter: UserScopedStateResetting {
    var resetCount = 0
    func resetUserScopedState() { resetCount += 1 }
}

private func sessionTestUser(id: Int) -> User {
    User(
        id: id,
        username: "member",
        email: "member@example.com",
        gender: nil,
        height: nil,
        weight: nil,
        role: "regular",
        isAdmin: false,
        createdAt: "2026-07-24",
        accountType: "email",
        externalId: "member@example.com",
        wechatOpenId: nil,
        wechatUnionId: nil,
        appleId: nil
    )
}
