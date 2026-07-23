import SQLite
import XCTest
@testable import Stronix

final class LocalCredentialAndSessionTests: XCTestCase {
    private var temporaryRoot: URL!
    private var connection: Connection!
    private var sessionStore: InMemoryLocalSessionStore!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let databaseURL = temporaryRoot.appendingPathComponent("authentication.db")
        try FileManager.default.copyItem(at: try bundledBaselineURL(), to: databaseURL)
        connection = try Connection(databaseURL.path)
        sessionStore = InMemoryLocalSessionStore()
        defaults = UserDefaults(suiteName: UUID().uuidString)!
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        sessionStore = nil
        connection = nil
        if let temporaryRoot { try? FileManager.default.removeItem(at: temporaryRoot) }
        temporaryRoot = nil
    }

    func testRegistrationStoresVersionedSaltedCredentialAndSession() async throws {
        let service = makeService()
        let first = try await service.register(username: "first", email: "first@example.com", password: "secure-password")
        let second = try await service.register(username: "second", email: "second@example.com", password: "secure-password")

        XCTAssertTrue(first.success)
        XCTAssertTrue(second.success)
        let credentials = try connection.prepare("SELECT password_hash FROM user ORDER BY id").compactMap { $0[0] as? String }
        XCTAssertEqual(credentials.count, 2)
        XCTAssertTrue(credentials.allSatisfy { $0.hasPrefix("pbkdf2-sha256$v=1$") })
        XCTAssertFalse(credentials.contains("secure-password"))
        XCTAssertFalse(credentials.contains(Data("secure-password".utf8).base64EncodedString()))
        XCTAssertNotEqual(credentials[0], credentials[1])
        XCTAssertEqual(try sessionStore.load()?.userID, second.user?.id)
    }

    func testCorrectAndIncorrectPasswords() async throws {
        let service = makeService()
        _ = try await service.register(username: "member", email: "member@example.com", password: "correct-password")
        await service.logout()

        let failed = try await service.login(email: "member@example.com", password: "wrong-password")
        XCTAssertFalse(failed.success)
        XCTAssertNil(try sessionStore.load())

        let succeeded = try await service.login(email: "member@example.com", password: "correct-password")
        XCTAssertTrue(succeeded.success)
        XCTAssertEqual(try sessionStore.load()?.userID, succeeded.user?.id)
    }

    func testSuccessfulLegacyLoginUpgradesOnlySupportedBase64Credential() async throws {
        try insertUser(username: "legacy", email: "legacy@example.com", credential: Data("legacy-password".utf8).base64EncodedString())
        let service = makeService()

        let response = try await service.login(email: "legacy@example.com", password: "legacy-password")
        XCTAssertTrue(response.success)
        let upgraded = try XCTUnwrap(try connection.scalar("SELECT password_hash FROM user WHERE email = 'legacy@example.com'") as? String)
        XCTAssertTrue(upgraded.hasPrefix("pbkdf2-sha256$v=1$"))

        await service.logout()
        let secondLogin = try await service.login(email: "legacy@example.com", password: "legacy-password")
        XCTAssertTrue(secondLogin.success)
    }

    func testMalformedAndPseudoScryptCredentialsFailWithoutSession() async throws {
        try insertUser(username: "malformed", email: "malformed@example.com", credential: "pbkdf2-sha256$v=99$i=1$l=1$s=bad$h=bad")
        try insertUser(username: "pseudo", email: "pseudo@example.com", credential: "scrypt:demonstration")
        let service = makeService()

        let malformedResult = try await service.login(email: "malformed@example.com", password: "any-password")
        let pseudoResult = try await service.login(email: "pseudo@example.com", password: "any-password")
        XCTAssertFalse(malformedResult.success)
        XCTAssertFalse(pseudoResult.success)
        XCTAssertNil(try sessionStore.load())
    }

    func testSessionRestoreUsesProtectedReferenceAndClearsStaleSession() async throws {
        let firstService = makeService()
        let registration = try await firstService.register(username: "restored", email: "restored@example.com", password: "secure-password")
        let userID = try XCTUnwrap(registration.user?.id)
        defaults.set(userID, forKey: "current_user_id")

        let restoredService = makeService()
        await restoredService.restoreSession()
        XCTAssertEqual(restoredService.currentUser?.id, userID)

        await restoredService.logout()
        let defaultsOnlyService = makeService()
        await defaultsOnlyService.restoreSession()
        XCTAssertFalse(defaultsOnlyService.isLoggedIn)

        try sessionStore.save(LocalSessionReference(userID: userID))
        try connection.run("DELETE FROM user WHERE id = ?", userID)
        let staleService = makeService()
        await staleService.restoreSession()
        XCTAssertFalse(staleService.isLoggedIn)
        XCTAssertNil(try sessionStore.load())
    }

    private var defaultsSuiteName: String { defaults.volatileDomainNames.first ?? "" }

    private func makeService() -> LocalUserService {
        LocalUserService(
            connectionProvider: { self.connection },
            sessionStore: sessionStore,
            legacyDefaults: defaults
        )
    }

    private func insertUser(username: String, email: String, credential: String) throws {
        try connection.run(
            "INSERT INTO user (username, email, password_hash, created_at, account_type) VALUES (?, ?, ?, datetime('now'), 'email')",
            [username, email, credential]
        )
    }

    private func bundledBaselineURL() throws -> URL {
        try XCTUnwrap(DatabaseEnvironment.application().sourceDatabaseURL)
    }
}
