import Foundation
import SQLite

enum DatabaseError: Error {
    case notReady
    case operationFailed(underlying: Error)
}

final class DatabaseManager {
    static let shared = DatabaseManager()

    private let lifecycle: DatabaseLifecycle

    private init() {
        lifecycle = DatabaseLifecycle(environment: .application())
    }

    init(lifecycle: DatabaseLifecycle) {
        self.lifecycle = lifecycle
    }

    func prepare() -> DatabasePreparationResult {
        lifecycle.prepare()
    }

    func prepareForStartup(arguments: [String]) -> DatabasePreparationResult {
#if DEBUG
        if arguments.contains("-StronixRebuildLocalDatabase") {
            return lifecycle.rebuildFromSource()
        }
#endif
        return lifecycle.prepare()
    }

    func retryPreparation() -> DatabasePreparationResult {
        lifecycle.retry()
    }

    /// 仅返回已经完成生命周期准备并标记为 ready 的连接。
    func getConnection() -> Connection? {
        lifecycle.readyConnection()
    }

    func isDatabaseReady() -> Bool {
        lifecycle.readyConnection() != nil
    }
}
