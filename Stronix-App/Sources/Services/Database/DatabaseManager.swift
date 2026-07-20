import Foundation
import SQLite

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

    enum DatabaseError: Error {
        case databaseNotInitialized
        case queryFailed(Error)
        case dataNotFound

        var localizedDescription: String {
            switch self {
            case .databaseNotInitialized:
                return "数据库未初始化"
            case .queryFailed(let error):
                return "数据库查询失败: \(error.localizedDescription)"
            case .dataNotFound:
                return "数据未找到"
            }
        }
    }
}
