import SQLite
import XCTest
@testable import Stronix

@MainActor
final class AppStartupCoordinatorTests: XCTestCase {
    private var fixture: IsolatedDatabaseFixture!

    override func setUpWithError() throws {
        fixture = try IsolatedDatabaseFixture()
    }

    override func tearDownWithError() throws {
        fixture.tearDown()
        fixture = nil
    }

    func testReadyDatabaseRestoresPersistedSessionBeforePermittingProtectedContent() async throws {
        let manager = DatabaseManager(lifecycle: fixture.makeLifecycle())
        let sessionStore = InMemoryLocalSessionStore()
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }

        guard case .ready(let database) = manager.prepareForStartup(arguments: []) else {
            return XCTFail("Expected the isolated database to become ready")
        }
        let user = try TestUserFixture(
            username: "startup-member",
            email: "startup-member@example.com"
        ).insert(into: database.connection)
        try sessionStore.save(LocalSessionReference(userID: user.id))

        let repository = SQLiteAuthRepository(connectionProvider: manager.getConnection)
        let session = UserSession(
            operations: AuthenticationUseCases(
                repository: repository,
                sessionStore: sessionStore,
                legacyDefaults: defaults.defaults
            )
        )
        let coordinator = AppStartupCoordinator(
            database: manager,
            arguments: [],
            session: session
        )

        XCTAssertFalse(coordinator.state.permitsProtectedContent)

        await coordinator.start()

        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertTrue(coordinator.state.permitsProtectedContent)
        XCTAssertEqual(session.currentUserID, user.id)
    }

    func testBlockedStartupReportsOnlySafeCategoryAndRedactedDiagnostic() async throws {
        let privateSourceName = "private-user@example.com-password-marker.db"
        let sourceURL = fixture.rootURL.appendingPathComponent(privateSourceName)
        let diagnostics = DiagnosticRecorder()
        let coordinator = AppStartupCoordinator(
            database: DatabaseManager(
                lifecycle: fixture.makeLifecycle(sourceDatabaseURL: sourceURL)
            ),
            arguments: [],
            session: RecordingSessionRestorer(),
            reportDiagnostic: diagnostics.record
        )

        await coordinator.start()

        let report = try XCTUnwrap(diagnostics.reports.first)
        XCTAssertEqual(report.reason, .recoverablePreparationFailure)
        XCTAssertFalse(report.summary.contains(fixture.rootURL.path))
        XCTAssertFalse(report.summary.contains(privateSourceName))
        XCTAssertFalse(report.summary.contains("private-user@example.com"))
        XCTAssertFalse(report.summary.contains("password-marker"))
    }

    func testRecoverableFailureCanRetryToReadyAndRestoreSession() async throws {
        let sourceURL = fixture.rootURL.appendingPathComponent("delayed-source.db")
        let manager = DatabaseManager(
            lifecycle: fixture.makeLifecycle(sourceDatabaseURL: sourceURL)
        )
        let session = RecordingSessionRestorer()
        let coordinator = AppStartupCoordinator(
            database: manager,
            arguments: [],
            session: session
        )

        await coordinator.start()

        XCTAssertEqual(coordinator.state, .blocked(.recoverablePreparationFailure))
        XCTAssertTrue(DatabaseStartupBlockReason.recoverablePreparationFailure.permitsRetry)
        XCTAssertEqual(session.restoreCount, 0)

        try FileManager.default.copyItem(at: fixture.baselineSourceURL, to: sourceURL)
        await coordinator.retry()

        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertTrue(coordinator.state.permitsProtectedContent)
        XCTAssertEqual(session.restoreCount, 1)
    }

    func testUnrecoverableRecoveryBlocksProtectedContentWithoutRestoringSessionOrOfferingRetry() async throws {
        let databaseURL = fixture.documentsURL.appendingPathComponent("database_stronix.db")
        try FileManager.default.copyItem(at: fixture.baselineSourceURL, to: databaseURL)
        let migrationCatalog = DatabaseMigrationCatalog(
            migrations: DatabaseMigrationCatalog.production.migrations + [
                DatabaseMigration(id: "20260726_0004_unrecoverable_startup") { _ in
                    throw DatabasePreparationFailure(message: "private-migration-marker")
                }
            ]
        )
        let manager = DatabaseManager(
            lifecycle: fixture.makeLifecycle(
                migrationCatalog: migrationCatalog,
                snapshotStore: RestorationFailingSnapshotStore()
            )
        )
        let operations = StartupAuthenticationOperations(restoredUser: startupTestUser(id: 502))
        let resetter = StartupScopedStateResetter()
        let session = UserSession(operations: operations, resetters: [resetter])
        await session.restore()
        XCTAssertTrue(session.isAuthenticated)

        let coordinator = AppStartupCoordinator(
            database: manager,
            arguments: [],
            session: session
        )

        await coordinator.start()

        XCTAssertEqual(coordinator.state, .blocked(.unrecoverableRecoveryFailure))
        XCTAssertFalse(coordinator.state.permitsProtectedContent)
        XCTAssertFalse(DatabaseStartupBlockReason.unrecoverableRecoveryFailure.permitsRetry)
        XCTAssertEqual(session.state, .unauthenticated)
        XCTAssertEqual(resetter.resetCount, 1)
    }

    func testIncompatibleSchemaBlocksProtectedContentWithoutRestoringSessionOrOfferingRetry() async throws {
        let databaseURL = fixture.documentsURL.appendingPathComponent("database_stronix.db")
        try FileManager.default.copyItem(at: fixture.baselineSourceURL, to: databaseURL)
        let connection = try SQLite.Connection(databaseURL.path)
        try connection.run(
            "INSERT INTO schema_migrations (migration_id, applied_at) VALUES (?, datetime('now'))",
            "20990101_9999_future_schema"
        )

        let operations = StartupAuthenticationOperations(restoredUser: startupTestUser(id: 501))
        let resetter = StartupScopedStateResetter()
        let session = UserSession(operations: operations, resetters: [resetter])
        await session.restore()
        XCTAssertTrue(session.isAuthenticated)

        let coordinator = AppStartupCoordinator(
            database: DatabaseManager(lifecycle: fixture.makeLifecycle()),
            arguments: [],
            session: session
        )

        await coordinator.start()

        XCTAssertEqual(coordinator.state, .blocked(.incompatibleSchema))
        XCTAssertFalse(coordinator.state.permitsProtectedContent)
        XCTAssertFalse(DatabaseStartupBlockReason.incompatibleSchema.permitsRetry)
        XCTAssertEqual(session.state, .unauthenticated)
        XCTAssertEqual(resetter.resetCount, 1)
    }

    func testRecoveredDatabaseRestoresPersistedSessionAndPermitsProtectedContent() async throws {
        let existingDatabaseURL = fixture.documentsURL.appendingPathComponent("database_stronix.db")
        try FileManager.default.copyItem(at: fixture.baselineSourceURL, to: existingDatabaseURL)
        let connection = try Connection(existingDatabaseURL.path)
        let user = try TestUserFixture(
            username: "recovered-member",
            email: "recovered-member@example.com"
        ).insert(into: connection)
        let migrationCatalog = DatabaseMigrationCatalog(
            migrations: DatabaseMigrationCatalog.production.migrations + [
                DatabaseMigration(id: "20260726_0004_startup_recovery") { _ in
                    throw DatabasePreparationFailure(message: "startup-recovery-private-marker")
                }
            ]
        )
        let manager = DatabaseManager(
            lifecycle: fixture.makeLifecycle(migrationCatalog: migrationCatalog)
        )
        let sessionStore = InMemoryLocalSessionStore()
        try sessionStore.save(LocalSessionReference(userID: user.id))
        let defaults = TestUserDefaultsFixture()
        defer { defaults.tearDown() }
        let session = UserSession(
            operations: AuthenticationUseCases(
                repository: SQLiteAuthRepository(connectionProvider: manager.getConnection),
                sessionStore: sessionStore,
                legacyDefaults: defaults.defaults
            )
        )
        let coordinator = AppStartupCoordinator(
            database: manager,
            arguments: [],
            session: session
        )

        await coordinator.start()

        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertTrue(coordinator.state.permitsProtectedContent)
        XCTAssertEqual(session.currentUserID, user.id)
    }

    func testReadyDatabaseKeepsProtectedContentBlockedUntilSessionRestorationFinishes() async {
        let manager = DatabaseManager(lifecycle: fixture.makeLifecycle())
        let restorationStarted = expectation(description: "Session restoration started")
        let session = SuspendingSessionRestorer(onStart: restorationStarted.fulfill)
        let coordinator = AppStartupCoordinator(
            database: manager,
            arguments: [],
            session: session
        )

        let startup = Task { await coordinator.start() }
        await fulfillment(of: [restorationStarted])

        XCTAssertEqual(coordinator.state, .restoringSession)
        XCTAssertFalse(coordinator.state.permitsProtectedContent)

        session.finishRestoration()
        await startup.value

        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertTrue(coordinator.state.permitsProtectedContent)
    }
}

@MainActor
private final class StartupAuthenticationOperations: AuthenticationOperating {
    private let restoredUser: User?

    init(restoredUser: User?) {
        self.restoredUser = restoredUser
    }

    func register(_ registration: AuthRegistration) async throws -> User {
        try XCTUnwrap(restoredUser)
    }

    func login(email: String, password: String) async throws -> User {
        try XCTUnwrap(restoredUser)
    }

    func restoreSession() async throws -> User? {
        restoredUser
    }

    func logout() async throws {}
}

@MainActor
private final class StartupScopedStateResetter: UserScopedStateResetting {
    private(set) var resetCount = 0

    func resetUserScopedState() {
        resetCount += 1
    }
}

private func startupTestUser(id: Int) -> User {
    User(
        id: id,
        username: "startup-member",
        email: "startup-member@example.com",
        gender: nil,
        height: nil,
        weight: nil,
        role: "regular",
        isAdmin: false,
        createdAt: "2026-07-26",
        accountType: "email",
        externalId: "startup-member@example.com",
        wechatOpenId: nil,
        wechatUnionId: nil,
        appleId: nil
    )
}

@MainActor
private final class DiagnosticRecorder {
    private(set) var reports: [(reason: DatabaseStartupBlockReason, summary: String)] = []

    func record(reason: DatabaseStartupBlockReason, summary: String) {
        reports.append((reason, summary))
    }
}

private final class RestorationFailingSnapshotStore: DatabaseSnapshotStore {
    private let underlying = SQLiteDatabaseSnapshotStore()

    func createSnapshot(from sourceConnection: Connection, at snapshotURL: URL) throws {
        try underlying.createSnapshot(from: sourceConnection, at: snapshotURL)
    }

    func restoreSnapshot(at snapshotURL: URL, replacing databaseURL: URL) throws {
        throw DatabasePreparationFailure(message: "private-restoration-marker")
    }

    func discardSnapshot(at snapshotURL: URL) {
        underlying.discardSnapshot(at: snapshotURL)
    }
}

@MainActor
private final class RecordingSessionRestorer: PersistedSessionRestoring {
    private(set) var restoreCount = 0
    private(set) var discardCount = 0

    func restore() async {
        restoreCount += 1
    }

    func discardStaleState() {
        discardCount += 1
    }
}

@MainActor
private final class SuspendingSessionRestorer: PersistedSessionRestoring {
    private let onStart: () -> Void
    private var continuation: CheckedContinuation<Void, Never>?

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    func restore() async {
        onStart()
        await withCheckedContinuation { continuation = $0 }
    }

    func finishRestoration() {
        continuation?.resume()
        continuation = nil
    }

    func discardStaleState() {}
}
