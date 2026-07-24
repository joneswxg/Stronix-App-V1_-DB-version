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
}

private final class AuthenticationOperationsStub: AuthenticationOperating {
    let restoredUser: User?
    var logoutError: Error?

    init(restoredUser: User?) {
        self.restoredUser = restoredUser
    }

    func register(_ registration: AuthRegistration) async throws -> User {
        try XCTUnwrap(restoredUser)
    }

    func login(email: String, password: String) async throws -> User {
        try XCTUnwrap(restoredUser)
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
