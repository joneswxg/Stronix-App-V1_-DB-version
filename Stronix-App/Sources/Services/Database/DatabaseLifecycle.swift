import Foundation
import SQLite

struct DatabaseEnvironment {
    let documentsDirectory: URL
    let databaseFilename: String
    let sourceDatabaseURL: URL?

    var databaseURL: URL {
        documentsDirectory.appendingPathComponent(databaseFilename)
    }

    static func application() -> DatabaseEnvironment {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let sourceDatabaseURL = Bundle.main.url(
            forResource: "database_stronix",
            withExtension: "db"
        )

        return DatabaseEnvironment(
            documentsDirectory: documentsDirectory,
            databaseFilename: "database_stronix.db",
            sourceDatabaseURL: sourceDatabaseURL
        )
    }
}

enum DatabasePreparation: Equatable {
    case initialized
    case alreadyReady
    case rebuilt
}

struct ReadyDatabase {
    let connection: Connection
    let databaseURL: URL
    let preparation: DatabasePreparation
}

enum DatabasePreparationResult: CustomStringConvertible {
    case ready(ReadyDatabase)
    case failed(DatabasePreparationFailure)

    var description: String {
        switch self {
        case .ready(let database):
            return "ready(\(database.databaseURL.path))"
        case .failed(let failure):
            return "failed(\(failure.message))"
        }
    }
}

struct DatabasePreparationFailure: Error, Equatable {
    let message: String
}

final class DatabaseLifecycle {
    private let environment: DatabaseEnvironment
    private let fileManager: FileManager
    private let preparationQueue: DispatchQueue
    private var readyDatabase: ReadyDatabase?
    private var failure: DatabasePreparationFailure?

    init(
        environment: DatabaseEnvironment,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.preparationQueue = DispatchQueue(
            label: "database.lifecycle.prepare.\(UUID().uuidString)",
            qos: .userInitiated
        )
    }

    func prepare() -> DatabasePreparationResult {
        preparationQueue.sync {
            prepareLocked()
        }
    }

    func retry() -> DatabasePreparationResult {
        preparationQueue.sync {
            failure = nil
            return prepareLocked()
        }
    }

    func rebuildFromSource() -> DatabasePreparationResult {
        preparationQueue.sync {
            rebuildFromSourceLocked()
        }
    }

    func readyConnection() -> Connection? {
        preparationQueue.sync {
            readyDatabase?.connection
        }
    }

    private func prepareLocked() -> DatabasePreparationResult {
        if let readyDatabase {
            return .ready(
                ReadyDatabase(
                    connection: readyDatabase.connection,
                    databaseURL: readyDatabase.databaseURL,
                    preparation: .alreadyReady
                )
            )
        }

        if let failure {
            return .failed(failure)
        }

        var preparation: DatabasePreparation?
        do {
            preparation = try prepareDatabaseFile()
            let database = try openReadyDatabase(
                preparation: preparation ?? .alreadyReady
            )
            readyDatabase = database
            return .ready(database)
        } catch let preparationFailure as DatabasePreparationFailure {
            if preparation == .initialized {
                removeDatabaseArtifacts(at: environment.databaseURL)
            }
            failure = preparationFailure
            return .failed(preparationFailure)
        } catch {
            if preparation == .initialized {
                removeDatabaseArtifacts(at: environment.databaseURL)
            }
            let preparationFailure = DatabasePreparationFailure(
                message: error.localizedDescription
            )
            failure = preparationFailure
            return .failed(preparationFailure)
        }
    }

    private func rebuildFromSourceLocked() -> DatabasePreparationResult {
        guard readyDatabase == nil else {
            return .failed(
                DatabasePreparationFailure(
                    message: "数据库已在使用中，无法执行整改重建"
                )
            )
        }

        do {
            try fileManager.createDirectory(
                at: environment.documentsDirectory,
                withIntermediateDirectories: true
            )
            let stagingURL = try makeValidatedStagingDatabase()
            defer {
                removeDatabaseArtifacts(at: stagingURL)
            }
            try promoteStagingDatabase(
                at: stagingURL,
                replacingDatabaseAt: environment.databaseURL
            )

            let database = try openReadyDatabase(preparation: .rebuilt)
            failure = nil
            readyDatabase = database
            return .ready(database)
        } catch let rebuildFailure as DatabasePreparationFailure {
            failure = rebuildFailure
            return .failed(rebuildFailure)
        } catch {
            let rebuildFailure = DatabasePreparationFailure(
                message: error.localizedDescription
            )
            failure = rebuildFailure
            return .failed(rebuildFailure)
        }
    }

    private func openReadyDatabase(
        preparation: DatabasePreparation
    ) throws -> ReadyDatabase {
        let connection = try Connection(environment.databaseURL.path)
        try configureAndValidate(connection)
        return ReadyDatabase(
            connection: connection,
            databaseURL: environment.databaseURL,
            preparation: preparation
        )
    }

    private func configureAndValidate(_ connection: Connection) throws {
        try connection.execute("PRAGMA foreign_keys = ON")
        try connection.execute("PRAGMA busy_timeout = 5000")

        let integrityResult = try connection.scalar("PRAGMA quick_check") as? String
        guard integrityResult == "ok" else {
            throw DatabasePreparationFailure(
                message: "数据库完整性检查失败"
            )
        }
    }

    private func prepareDatabaseFile() throws -> DatabasePreparation {
        try fileManager.createDirectory(
            at: environment.documentsDirectory,
            withIntermediateDirectories: true
        )

        guard !fileManager.fileExists(atPath: environment.databaseURL.path) else {
            return .alreadyReady
        }

        let stagingURL = try makeValidatedStagingDatabase()
        defer {
            removeDatabaseArtifacts(at: stagingURL)
        }

        try fileManager.moveItem(at: stagingURL, to: environment.databaseURL)
        return .initialized
    }

    private func makeValidatedStagingDatabase() throws -> URL {
        guard let sourceDatabaseURL = environment.sourceDatabaseURL else {
            throw DatabasePreparationFailure(
                message: "找不到数据库初始化源文件"
            )
        }

        let stagingURL = environment.documentsDirectory.appendingPathComponent(
            ".\(environment.databaseFilename).staging-\(UUID().uuidString)"
        )
        do {
            try fileManager.copyItem(at: sourceDatabaseURL, to: stagingURL)
            try validateDatabase(at: stagingURL)
            return stagingURL
        } catch {
            removeDatabaseArtifacts(at: stagingURL)
            throw error
        }
    }

    private func promoteStagingDatabase(
        at stagingURL: URL,
        replacingDatabaseAt databaseURL: URL
    ) throws {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: databaseURL)
            return
        }

        let backupName = ".\(environment.databaseFilename).backup-\(UUID().uuidString)"
        try checkpointDatabaseIfNeeded(at: databaseURL)
        try removeSidecars(for: databaseURL)
        _ = try fileManager.replaceItemAt(
            databaseURL,
            withItemAt: stagingURL,
            backupItemName: backupName,
            options: []
        )

        let backupURL = environment.documentsDirectory.appendingPathComponent(backupName)
        do {
            try validateDatabase(at: databaseURL)
            removeDatabaseArtifacts(at: backupURL)
        } catch {
            removeDatabaseArtifacts(at: databaseURL)
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.moveItem(at: backupURL, to: databaseURL)
            }
            throw error
        }
    }

    private func validateDatabase(at databaseURL: URL) throws {
        let connection = try Connection(databaseURL.path)
        try configureAndValidate(connection)
    }

    private func checkpointDatabaseIfNeeded(at databaseURL: URL) throws {
        let connection = try Connection(databaseURL.path)
        let journalMode = try connection.scalar("PRAGMA journal_mode") as? String
        if journalMode?.lowercased() == "wal" {
            try connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    private func removeDatabaseArtifacts(at databaseURL: URL) {
        for url in databaseArtifactURLs(for: databaseURL) {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    private func removeSidecars(for databaseURL: URL) throws {
        for url in databaseArtifactURLs(for: databaseURL).dropFirst() {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try fileManager.removeItem(at: url)
        }
    }

    private func databaseArtifactURLs(for databaseURL: URL) -> [URL] {
        [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-journal")
        ]
    }
}
