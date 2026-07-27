import XCTest
@testable import Stronix

final class AuthenticationUseCasesTests: XCTestCase {
    func testLoginPersistsSessionBeforeReturningAuthenticatedUser() async throws {
        let user = makeUser(id: 42)
        let repository = ResultAuthRepository(authenticatedUser: user)
        let sessionStore = RecordingSessionStore()
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: defaults.defaults
        )

        let authenticatedUser = try await useCases.login(
            email: "member@example.com",
            password: "secure-password"
        )

        XCTAssertEqual(authenticatedUser.id, 42)
        XCTAssertEqual(sessionStore.savedSession, LocalSessionReference(userID: 42))
    }

    func testLogoutFailureDoesNotPretendThePersistentSessionWasCleared() async throws {
        let repository = ResultAuthRepository(authenticatedUser: makeUser(id: 1))
        let sessionStore = RecordingSessionStore()
        sessionStore.clearError = TestError.expected
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: defaults.defaults
        )

        do {
            try await useCases.logout()
            XCTFail("Expected logout to fail")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionUnavailable)
        }
    }

    func testRestoreClearsStaleProtectedReference() async throws {
        let repository = ResultAuthRepository(
            authenticatedUser: makeUser(id: 1),
            userResult: .success(nil)
        )
        let sessionStore = RecordingSessionStore()
        sessionStore.loadedSession = LocalSessionReference(userID: 999)
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        defaults.defaults.set(999, forKey: "current_user_id")
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: defaults.defaults
        )

        let restored = try await useCases.restoreSession()

        XCTAssertNil(restored)
        XCTAssertNil(sessionStore.loadedSession)
        XCTAssertNil(defaults.defaults.object(forKey: "current_user_id"))
    }

    func testRegistrationValidationRunsBeforeRepositoryMutation() async throws {
        let repository = ResultAuthRepository(authenticatedUser: makeUser(id: 1))
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: InMemoryLocalSessionStore(),
            legacyDefaults: defaults.defaults
        )

        do {
            _ = try await useCases.register(
                AuthRegistration(username: " ", email: "not-an-email", password: "123", gender: nil, height: 20, weight: 5)
            )
            XCTFail("Expected validation failure")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidUsername)
        }
        XCTAssertTrue(repository.registrations.isEmpty)
        XCTAssertTrue(repository.deletedUserIDs.isEmpty)
    }

    func testRegistrationSessionSaveFailureDeletesNewUser() async throws {
        let user = makeUser(id: 42)
        let repository = ResultAuthRepository(authenticatedUser: user)
        let sessionStore = RecordingSessionStore()
        sessionStore.saveError = TestError.expected
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: defaults.defaults
        )

        do {
            _ = try await useCases.register(
                AuthRegistration(username: "member", email: "member@example.com", password: "secure-password", gender: nil, height: nil, weight: nil)
            )
            XCTFail("Expected session persistence failure")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionUnavailable)
        }

        XCTAssertEqual(repository.deletedUserIDs, [user.id])
    }

    func testSuccessfulRegistrationDoesNotDeleteUser() async throws {
        let user = makeUser(id: 42)
        let repository = ResultAuthRepository(authenticatedUser: user)
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: InMemoryLocalSessionStore(),
            legacyDefaults: defaults.defaults
        )

        _ = try await useCases.register(
            AuthRegistration(username: "member", email: "member@example.com", password: "secure-password", gender: nil, height: nil, weight: nil)
        )

        XCTAssertTrue(repository.deletedUserIDs.isEmpty)
    }

    func testRegistrationCleanupFailureIsExposed() async throws {
        let user = makeUser(id: 42)
        let repository = ResultAuthRepository(authenticatedUser: user)
        repository.deleteUserResult = .failure(TestError.expected)
        let sessionStore = RecordingSessionStore()
        sessionStore.saveError = TestError.expected
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: sessionStore,
            legacyDefaults: defaults.defaults
        )

        do {
            _ = try await useCases.register(
                AuthRegistration(username: "member", email: "member@example.com", password: "secure-password", gender: nil, height: nil, weight: nil)
            )
            XCTFail("Expected cleanup failure")
        } catch {
            XCTAssertTrue(error is TestError)
        }

        XCTAssertEqual(repository.deletedUserIDs, [user.id])
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
