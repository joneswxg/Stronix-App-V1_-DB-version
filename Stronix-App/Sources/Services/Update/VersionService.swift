import Foundation
import SQLite

final class VersionService {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    func checkDatabaseVersion() -> VersionComparisonResult {
        let bundleVersion = DatabaseVersionConfig.currentBundleVersion

        guard let documentsVersion = getCurrentDocumentsVersion() else {
            return .bundleNewer
        }

        if bundleVersion.buildNumber > documentsVersion.buildNumber {
            return .bundleNewer
        } else if bundleVersion.buildNumber < documentsVersion.buildNumber {
            return .documentsNewer
        } else {
            return .same
        }
    }

    func createVersionTable() -> Bool {
        guard let connection = databaseManager.getConnection() else {
            print("❌ VersionService: 数据库尚未 ready")
            return false
        }

        do {
            try connection.execute(DatabaseVersionConfig.createVersionTableSQL)
            return true
        } catch {
            print("❌ VersionService: 创建版本控制表失败: \(error)")
            return false
        }
    }

    func updateVersionInfo(version: DatabaseVersion) -> Bool {
        guard let connection = databaseManager.getConnection() else {
            print("❌ VersionService: 数据库尚未 ready")
            return false
        }

        do {
            try connection.execute(DatabaseVersionConfig.createVersionTableSQL)
            let updateDateString = ISO8601DateFormatter().string(from: version.updateDate)
            let statement = try connection.prepare(DatabaseVersionConfig.insertVersionSQL)
            try statement.run([
                version.version,
                version.buildNumber,
                updateDateString,
                version.description
            ])
            return true
        } catch {
            print("❌ VersionService: 更新版本信息失败: \(error)")
            return false
        }
    }

    func getVersionDescription() -> String {
        guard let version = getCurrentDocumentsVersion() else {
            return "未知版本"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return """
        当前版本: \(version.version)
        构建号: \(version.buildNumber)
        更新时间: \(dateFormatter.string(from: version.updateDate))
        描述: \(version.description.isEmpty ? "无描述" : version.description)
        """
    }

    private func getCurrentDocumentsVersion() -> DatabaseVersion? {
        guard let connection = databaseManager.getConnection() else {
            return nil
        }

        do {
            guard try versionTableExists(connection: connection) else {
                return nil
            }

            let statement = try connection.prepare(DatabaseVersionConfig.getLatestVersionSQL)
            for row in statement {
                let version = row[0] as? String ?? ""
                let buildNumber = row[1] as? Int64 ?? 0
                let updateDateString = row[2] as? String ?? ""
                let description = row[3] as? String ?? ""
                let updateDate = ISO8601DateFormatter().date(from: updateDateString) ?? Date()

                return DatabaseVersion(
                    version: version,
                    buildNumber: Int(buildNumber),
                    updateDate: updateDate,
                    description: description
                )
            }
            return nil
        } catch {
            print("❌ VersionService: 获取版本信息失败: \(error)")
            return nil
        }
    }

    private func versionTableExists(connection: Connection) throws -> Bool {
        let statement = try connection.prepare(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
        )
        for _ in try statement.run([DatabaseVersionConfig.versionTableName]) {
            return true
        }
        return false
    }
}
