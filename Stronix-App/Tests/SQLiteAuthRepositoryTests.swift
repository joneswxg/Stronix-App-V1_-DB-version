import SQLite
import XCTest
@testable import Stronix

final class SQLiteAuthRepositoryTests: XCTestCase {
    private var temporaryRoot: URL!
    private var connection: Connection!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let databaseURL = temporaryRoot.appendingPathComponent("authentication.db")
        try FileManager.default.copyItem(at: try bundledBaselineURL(), to: databaseURL)
        connection = try Connection(databaseURL.path)
    }

    override func tearDownWithError() throws {
        connection = nil
        if let temporaryRoot { try? FileManager.default.removeItem(at: temporaryRoot) }
        temporaryRoot = nil
    }

    func testRegisteredUserCanAuthenticateWithTheirPassword() async throws {
        let repository = SQLiteAuthRepository(connectionProvider: { self.connection })
        let registration = AuthRegistration(
            username: "member",
            email: "member@example.com",
            password: "secure-password",
            gender: nil,
            height: nil,
            weight: nil
        )

        let registeredUser = try await repository.register(registration)
        let authenticatedUser = try await repository.authenticate(
            email: "member@example.com",
            password: "secure-password"
        )

        XCTAssertEqual(authenticatedUser.id, registeredUser.id)
        XCTAssertEqual(authenticatedUser.email, "member@example.com")
    }

    func testInvalidAndUnknownCredentialsFailWithoutDistinguishingAccounts() async throws {
        let repository = SQLiteAuthRepository(connectionProvider: { self.connection })
        _ = try await repository.register(
            AuthRegistration(
                username: "member",
                email: "member@example.com",
                password: "secure-password",
                gender: nil,
                height: nil,
                weight: nil
            )
        )

        for attempt in [("member@example.com", "wrong-password"), ("missing@example.com", "wrong-password")] {
            do {
                _ = try await repository.authenticate(email: attempt.0, password: attempt.1)
                XCTFail("Expected invalid credentials")
            } catch {
                XCTAssertEqual(error as? AuthError, .invalidCredentials)
            }
        }
    }

    func testSupportedLegacyCredentialUpgradesOnceAfterSuccessfulLogin() async throws {
        let credentialing = RecordingCredentialing()
        credentialing.verification = .validLegacy
        let repository = SQLiteAuthRepository(
            connectionProvider: { self.connection },
            credentialing: credentialing
        )
        try connection.run(
            "INSERT INTO user (username, email, password_hash, created_at, account_type) VALUES (?, ?, ?, datetime('now'), 'email')",
            ["legacy", "legacy@example.com", "legacy-base64$v=1$credential"]
        )

        _ = try await repository.authenticate(email: "legacy@example.com", password: "legacy-password")
        credentialing.verification = .valid
        _ = try await repository.authenticate(email: "legacy@example.com", password: "legacy-password")

        XCTAssertEqual(credentialing.makeCredentialCallCount, 1)
        let stored = try XCTUnwrap(
            try connection.scalar("SELECT password_hash FROM user WHERE email = 'legacy@example.com'") as? String
        )
        XCTAssertEqual(stored, "upgraded-credential")
    }

    func testDuplicateEmailAndUsernameReturnTypedErrors() async throws {
        let repository = SQLiteAuthRepository(connectionProvider: { self.connection })
        let first = AuthRegistration(
            username: "member",
            email: "member@example.com",
            password: "secure-password",
            gender: nil,
            height: nil,
            weight: nil
        )
        _ = try await repository.register(first)

        do {
            _ = try await repository.register(
                AuthRegistration(username: "other", email: first.email, password: first.password, gender: nil, height: nil, weight: nil)
            )
            XCTFail("Expected duplicate email")
        } catch {
            XCTAssertEqual(error as? AuthError, .emailAlreadyExists)
        }

        do {
            _ = try await repository.register(
                AuthRegistration(username: first.username, email: "other@example.com", password: first.password, gender: nil, height: nil, weight: nil)
            )
            XCTFail("Expected duplicate username")
        } catch {
            XCTAssertEqual(error as? AuthError, .usernameTaken)
        }
    }

    private func bundledBaselineURL() throws -> URL {
        try XCTUnwrap(DatabaseEnvironment.application().sourceDatabaseURL)
    }
}

private final class RecordingCredentialing: PasswordCredentialing {
    var verification: PasswordCredentialVerification = .invalid
    var makeCredentialCallCount = 0

    func makeCredential(password: String) throws -> String {
        makeCredentialCallCount += 1
        return "upgraded-credential"
    }

    func verify(password: String, storedCredential: String) throws -> PasswordCredentialVerification {
        verification
    }
}
