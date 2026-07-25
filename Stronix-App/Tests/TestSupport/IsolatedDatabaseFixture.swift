import Foundation
import SQLite
import XCTest
@testable import Stronix

final class IsolatedDatabaseFixture {
    let rootURL: URL
    let documentsURL: URL
    let baselineSourceURL: URL

    private(set) var preparedDatabaseURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("StronixTests-\(UUID().uuidString)", isDirectory: true)
        documentsURL = rootURL.appendingPathComponent("Documents", isDirectory: true)
        preparedDatabaseURL = rootURL.appendingPathComponent("database_stronix.db")
        baselineSourceURL = try XCTUnwrap(
            DatabaseEnvironment.application().sourceDatabaseURL,
            "Expected the generated baseline database in the app bundle"
        )
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }

    func prepareRepositoryDatabase(named filename: String = "database_stronix.db") throws -> Connection {
        preparedDatabaseURL = rootURL.appendingPathComponent(filename)
        try requireIsolatedMutableURL(preparedDatabaseURL)
        if fileManager.fileExists(atPath: preparedDatabaseURL.path) {
            try fileManager.removeItem(at: preparedDatabaseURL)
        }
        try fileManager.copyItem(at: baselineSourceURL, to: preparedDatabaseURL)
        let connection = try Connection(preparedDatabaseURL.path)
        try connection.execute("PRAGMA foreign_keys = ON")
        return connection
    }

    func makeLifecycle(
        documentsDirectory: URL? = nil,
        databaseFilename: String = "database_stronix.db",
        sourceDatabaseURL: URL? = nil,
        migrationCatalog: DatabaseMigrationCatalog = .production,
        snapshotStore: DatabaseSnapshotStore? = nil
    ) -> DatabaseLifecycle {
        let documentsDirectory = documentsDirectory ?? documentsURL
        precondition(contains(documentsDirectory), "Lifecycle Documents directory must be fixture-owned")
        return DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsDirectory,
                databaseFilename: databaseFilename,
                sourceDatabaseURL: sourceDatabaseURL ?? baselineSourceURL
            ),
            fileManager: fileManager,
            migrationCatalog: migrationCatalog,
            snapshotStore: snapshotStore
        )
    }

    func makeMutableBaselineCopy(named filename: String) throws -> URL {
        let url = rootURL.appendingPathComponent(filename)
        try requireIsolatedMutableURL(url)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.copyItem(at: baselineSourceURL, to: url)
        return url
    }

    func contains(_ url: URL) -> Bool {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let candidatePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    func tearDown() {
        if fileManager.fileExists(atPath: rootURL.path) {
            try? fileManager.removeItem(at: rootURL)
        }
    }

    private func requireIsolatedMutableURL(_ url: URL) throws {
        guard contains(url),
              url.standardizedFileURL != baselineSourceURL.standardizedFileURL,
              url.standardizedFileURL != DatabaseEnvironment.application().databaseURL.standardizedFileURL else {
            throw NSError(
                domain: "IsolatedDatabaseFixture",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mutable database path is not fixture-owned: \(url.path)"]
            )
        }
    }
}
