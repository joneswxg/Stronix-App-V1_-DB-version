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

        do {
            let preparation = try prepareDatabaseFile()
            let connection = try Connection(environment.databaseURL.path)
            try configureAndValidate(connection)
            let database = ReadyDatabase(
                connection: connection,
                databaseURL: environment.databaseURL,
                preparation: preparation
            )
            readyDatabase = database
            return .ready(database)
        } catch let failure as DatabasePreparationFailure {
            self.failure = failure
            return .failed(failure)
        } catch {
            let failure = DatabasePreparationFailure(
                message: error.localizedDescription
            )
            self.failure = failure
            return .failed(failure)
        }
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

        guard let sourceDatabaseURL = environment.sourceDatabaseURL else {
            throw DatabasePreparationFailure(
                message: "找不到数据库初始化源文件"
            )
        }

        try fileManager.copyItem(
            at: sourceDatabaseURL,
            to: environment.databaseURL
        )
        return .initialized
    }
}
