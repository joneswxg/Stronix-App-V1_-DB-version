import SQLite
import XCTest
@testable import Stronix

@MainActor
final class AuthenticationSessionIntegrationTests: XCTestCase {
    private var fixture: IsolatedDatabaseFixture!
    private var connection: Connection!
    private var sessionStore: RecordingSessionStore!
    private var defaults: TestUserDefaultsFixture!

    override func setUpWithError() throws {
        fixture = try IsolatedDatabaseFixture()
        connection = try fixture.prepareRepositoryDatabase(named: "authentication-session.db")
        sessionStore = RecordingSessionStore()
        defaults = TestUserDefaultsFixture()
    }

    override func tearDownWithError() throws {
        defaults.tearDown()
        defaults = nil
        sessionStore = nil
        connection = nil
        fixture.tearDown()
        fixture = nil
    }

    func testRegistrationAndLoginPersistCurrentUserThroughRealSQLiteRepository() async throws {
        let session = makeSession()
        let registration = AuthRegistration(
            username: "member",
            email: "member@example.com",
            password: "secure-password",
            gender: nil,
            height: nil,
            weight: nil
        )

        try await session.register(registration)
        let registeredID = try XCTUnwrap(session.currentUserID)
        XCTAssertEqual(try sessionStore.load(), LocalSessionReference(userID: registeredID))

        try await session.logout()
        XCTAssertNil(try sessionStore.load())

        try await session.login(email: registration.email, password: registration.password)
        XCTAssertEqual(session.currentUserID, registeredID)
        XCTAssertEqual(try sessionStore.load(), LocalSessionReference(userID: registeredID))
    }

    func testCredentialFailuresAreSafeAndDuplicateRegistrationIsExplicit() async throws {
        let session = makeSession()
        let registration = AuthRegistration(
            username: "member",
            email: "member@example.com",
            password: "secure-password",
            gender: nil,
            height: nil,
            weight: nil
        )
        try await session.register(registration)

        do {
            try await session.login(email: registration.email, password: "wrong-password")
            XCTFail("Expected invalid credentials")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }

        do {
            try await session.register(registration)
            XCTFail("Expected duplicate registration error")
        } catch {
            XCTAssertEqual(error as? AuthError, .emailAlreadyExists)
        }
    }

    func testSessionSaveFailureRemovesRegisteredUserAndAllowsRetry() async throws {
        sessionStore.saveError = FixtureError.expected
        let session = makeSession()
        let registration = AuthRegistration(
            username: "member",
            email: "member@example.com",
            password: "secure-password",
            gender: nil,
            height: nil,
            weight: nil
        )

        do {
            try await session.register(registration)
            XCTFail("Expected session persistence failure")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionUnavailable)
        }

        XCTAssertEqual(session.state, .restoring)
        XCTAssertNil(session.currentUserID)
        XCTAssertNil(try sessionStore.load())
        XCTAssertEqual(try scalarCount("user"), 0)

        sessionStore.saveError = nil
        try await session.register(registration)
        XCTAssertEqual(try scalarCount("user"), 1)
    }

    func testLogoutOnlyClearsSessionAndPreservesAccountAndBusinessRows() async throws {
        let user = try TestUserFixture(username: "member", email: "member@example.com").insert(into: connection)
        try connection.run(
            "INSERT INTO training_plans (name, user_id) VALUES (?, ?)",
            "Member plan",
            user.id
        )
        try connection.run(
            "INSERT INTO body_measurements (user_id, measurement_timestamp, weight_kg, height_cm, body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level) VALUES (?, datetime('now'), 70, 170, 20, 30, 8)",
            user.id
        )
        try sessionStore.save(LocalSessionReference(userID: user.id))
        let session = makeSession()

        await session.restore()
        try await session.logout()

        XCTAssertNil(try sessionStore.load())
        XCTAssertEqual(try scalarCount("user"), 1)
        XCTAssertEqual(try scalarCount("training_plans"), 1)
        XCTAssertEqual(try scalarCount("body_measurements"), 1)
    }

    func testRelaunchRestoresLastSuccessfulLoginAndReflectsLogout() async throws {
        let firstManager = DatabaseManager(lifecycle: fixture.makeLifecycle())
        let firstSession = makeSession(connectionProvider: firstManager.getConnection)
        let firstCoordinator = AppStartupCoordinator(database: firstManager, arguments: [], session: firstSession)

        await firstCoordinator.start()
        try await firstSession.register(
            AuthRegistration(
                username: "member",
                email: "member@example.com",
                password: "secure-password",
                gender: nil,
                height: nil,
                weight: nil
            )
        )
        let userID = try XCTUnwrap(firstSession.currentUserID)

        let relaunchedManager = DatabaseManager(lifecycle: fixture.makeLifecycle())
        let relaunchedSession = makeSession(connectionProvider: relaunchedManager.getConnection)
        let relaunchedCoordinator = AppStartupCoordinator(database: relaunchedManager, arguments: [], session: relaunchedSession)
        await relaunchedCoordinator.start()

        XCTAssertEqual(relaunchedCoordinator.state, .ready)
        XCTAssertEqual(relaunchedSession.currentUserID, userID)

        try await relaunchedSession.logout()
        let loggedOutManager = DatabaseManager(lifecycle: fixture.makeLifecycle())
        let loggedOutSession = makeSession(connectionProvider: loggedOutManager.getConnection)
        let loggedOutCoordinator = AppStartupCoordinator(database: loggedOutManager, arguments: [], session: loggedOutSession)
        await loggedOutCoordinator.start()

        XCTAssertEqual(loggedOutCoordinator.state, .ready)
        XCTAssertEqual(loggedOutSession.state, .unauthenticated)
    }

    func testFailedLogoutSurvivesRelaunchAsAuthenticatedSession() async throws {
        let manager = DatabaseManager(lifecycle: fixture.makeLifecycle())
        guard case .ready(let prepared) = manager.prepareForStartup(arguments: []) else {
            return XCTFail("Expected the isolated database to become ready")
        }
        let user = try TestUserFixture(username: "member", email: "member@example.com").insert(into: prepared.connection)
        try sessionStore.save(LocalSessionReference(userID: user.id))
        let session = makeSession(connectionProvider: manager.getConnection)
        await session.restore()
        sessionStore.clearError = FixtureError.expected

        do {
            try await session.logout()
            XCTFail("Expected logout to fail")
        } catch {
            XCTAssertEqual(error as? AuthError, .sessionUnavailable)
        }
        sessionStore.clearError = nil

        let relaunchedSession = makeSession(connectionProvider: manager.getConnection)
        let coordinator = AppStartupCoordinator(database: manager, arguments: [], session: relaunchedSession)
        await coordinator.start()

        XCTAssertEqual(relaunchedSession.currentUserID, user.id)
    }

    private func makeSession(
        connectionProvider: (() -> Connection?)? = nil
    ) -> UserSession {
        let provider = connectionProvider ?? { self.connection }
        return UserSession(
            operations: AuthenticationUseCases(
                repository: SQLiteAuthRepository(connectionProvider: provider),
                sessionStore: sessionStore,
                legacyDefaults: defaults.defaults
            )
        )
    }

    private func scalarCount(_ table: String) throws -> Int64 {
        try XCTUnwrap(try connection.scalar("SELECT COUNT(*) FROM \(table)") as? Int64)
    }
}

private enum FixtureError: Error {
    case expected
}
