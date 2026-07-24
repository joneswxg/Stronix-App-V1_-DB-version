import SQLite
import XCTest
@testable import Stronix

final class AuthenticationUseCasesTests: XCTestCase {
    func testLoginPersistsSessionBeforeReturningAuthenticatedUser() async throws {
        let user = makeUser(id: 42)
        let repository = AuthRepositoryStub(authenticatedUser: user)
        let sessionStore = RecordingSessionStore()
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )

        let authenticatedUser = try await useCases.login(
            email: "member@example.com",
            password: "secure-password"
        )

        XCTAssertEqual(authenticatedUser.id, 42)
        XCTAssertEqual(sessionStore.savedSession, LocalSessionReference(userID: 42))
    }

    func testLogoutFailureDoesNotPretendThePersistentSessionWasCleared() async throws {
        let repository = AuthRepositoryStub(authenticatedUser: makeUser(id: 1))
        let sessionStore = RecordingSessionStore()
        sessionStore.clearError = TestError.expected
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )

        do {
            try await useCases.logout()
            XCTFail("Expected logout to fail")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionUnavailable)
        }
    }
    func testRestoreClearsStaleProtectedReference() async throws {
        let repository = AuthRepositoryStub(authenticatedUser: makeUser(id: 1))
        repository.restoredUser = nil
        let sessionStore = RecordingSessionStore()
        sessionStore.loadedSession = LocalSessionReference(userID: 999)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(999, forKey: "current_user_id")
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: defaults
        )

        let restored = try await useCases.restoreSession()

        XCTAssertNil(restored)
        XCTAssertNil(sessionStore.loadedSession)
        XCTAssertNil(defaults.object(forKey: "current_user_id"))
    }

    func testRegistrationValidationRunsBeforeRepositoryMutation() async throws {
        let repository = AuthRepositoryStub(authenticatedUser: makeUser(id: 1))
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: RecordingSessionStore(),
            legacyDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )

        do {
            _ = try await useCases.register(
                AuthRegistration(username: " ", email: "not-an-email", password: "123", gender: nil, height: 20, weight: 5)
            )
            XCTFail("Expected validation failure")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidUsername)
        }
        XCTAssertEqual(repository.registerCallCount, 0)
    }
}

private final class AuthRepositoryStub: AuthRepository {
    let authenticatedUser: User
    var restoredUser: User?
    var registerCallCount = 0

    init(authenticatedUser: User) {
        self.authenticatedUser = authenticatedUser
        restoredUser = authenticatedUser
    }

    func register(_ registration: AuthRegistration) async throws -> User {
        registerCallCount += 1
        return authenticatedUser
    }
    func authenticate(email: String, password: String) async throws -> User { authenticatedUser }
    func user(id: Int) async throws -> User? { restoredUser?.id == id ? restoredUser : nil }
}

private final class RecordingSessionStore: LocalSessionStore {
    var loadedSession: LocalSessionReference?
    var savedSession: LocalSessionReference?
    var clearError: Error?

    func load() throws -> LocalSessionReference? { loadedSession }
    func save(_ session: LocalSessionReference) throws { savedSession = session }
    func clear() throws {
        if let clearError { throw clearError }
        loadedSession = nil
        savedSession = nil
    }
}

private enum TestError: Error {
    case expected
}

private func makeUser(id: Int) -> User {
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
