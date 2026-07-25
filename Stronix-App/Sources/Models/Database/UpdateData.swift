//
//  UpdateData.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/26.
//

import Foundation

// MARK: - 数据库更新状态
enum DatabaseUpdateStatus {
    case checking           // 正在检查更新
    case updateAvailable    // 有可用更新
    case updating          // 正在更新
    case upToDate          // 已是最新版本
    case updateFailed      // 更新失败
    case backupFailed      // 备份失败
    case restoreFailed     // 恢复失败
}

// MARK: - 数据库更新结果
struct DatabaseUpdateResult {
    let status: DatabaseUpdateStatus
    let message: String
    let oldVersion: DatabaseVersion?
    let newVersion: DatabaseVersion?
    let updateDate: Date
    let error: Error?
    
    init(status: DatabaseUpdateStatus, 
         message: String, 
         oldVersion: DatabaseVersion? = nil, 
         newVersion: DatabaseVersion? = nil, 
         error: Error? = nil) {
        self.status = status
        self.message = message
        self.oldVersion = oldVersion
        self.newVersion = newVersion
        self.updateDate = Date()
        self.error = error
    }
}

// MARK: - 数据库更新配置
struct DatabaseUpdateConfig {
    // 是否启用自动更新检查
    static let autoUpdateEnabled = true
    
    // 更新检查间隔（秒）
    static let updateCheckInterval: TimeInterval = 60 * 60 * 24 // 24小时
    
    // 备份保留天数
    static let backupRetentionDays = 7
    
    // 最大备份文件数量
    static let maxBackupFiles = 5
}

// MARK: - 数据库更新错误
enum DatabaseUpdateError: Error, LocalizedError {
    case bundleDatabaseNotFound
    case backupFailed(Error)
    case copyFailed(Error)
    case versionUpdateFailed(Error)
    case connectionFailed(Error)
    case invalidVersion
    
    var errorDescription: String? {
        switch self {
        case .bundleDatabaseNotFound:
            return "找不到Bundle中的数据库文件"
        case .backupFailed(let error):
            return "数据库备份失败: \(error.localizedDescription)"
        case .copyFailed(let error):
            return "数据库复制失败: \(error.localizedDescription)"
        case .versionUpdateFailed(let error):
            return "版本信息更新失败: \(error.localizedDescription)"
        case .connectionFailed(let error):
            return "数据库连接失败: \(error.localizedDescription)"
        case .invalidVersion:
            return "无效的版本信息"
        }
    }
}

// MARK: - 数据库更新通知
extension Notification.Name {
    static let databaseUpdateStarted = Notification.Name("databaseUpdateStarted")
    static let databaseUpdateCompleted = Notification.Name("databaseUpdateCompleted")
    static let databaseUpdateFailed = Notification.Name("databaseUpdateFailed")
}

// MARK: - 数据库更新通知数据
struct DatabaseUpdateNotificationData {
    let result: DatabaseUpdateResult
    let progress: Float? // 更新进度 (0.0 - 1.0)
    
    init(result: DatabaseUpdateResult, progress: Float? = nil) {
        self.result = result
        self.progress = progress
    }
}

