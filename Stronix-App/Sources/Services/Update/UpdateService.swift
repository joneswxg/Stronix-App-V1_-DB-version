//
//  UpdateService.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/26.
//

import Foundation
import SQLite

class UpdateService {
    private let versionService = VersionService()
    // 避免循环依赖，不直接引用DatabaseManager.shared
    private var databaseManager: DatabaseManager? {
        return DatabaseManager.shared
    }
    
    // MARK: - 数据库更新检查和执行
    /// 检查并执行数据库更新（在应用启动时调用）
    func checkAndUpdateDatabase() {
        print("🔄 UpdateService: 开始检查数据库更新...")
        
        let comparisonResult = versionService.checkDatabaseVersion()
        
        switch comparisonResult {
        case .bundleNewer:
            print("📦 UpdateService: 发现Bundle中有新版本数据库，准备更新...")
            performDatabaseUpdate()
            
        case .documentsNewer:
            print("⚠️ UpdateService: Documents中的数据库版本较新，可能存在版本回退")
            // 这种情况通常不应该发生，可能是开发过程中的版本回退
            // 可以选择保留当前版本或提示用户
            
        case .same:
            print("✅ UpdateService: 数据库版本一致，无需更新")
            
        case .error:
            print("❌ UpdateService: 版本检查出错")
        }
    }
    
    // MARK: - 执行数据库更新
    private func performDatabaseUpdate() {
        print("🔄 UpdateService: 开始执行数据库更新...")
        
        // 1. 备份当前数据库
        if !backupCurrentDatabase() {
            print("❌ UpdateService: 数据库备份失败，取消更新")
            return
        }
        
        // 2. 复制新的数据库文件
        if !copyBundleDatabaseToDocuments() {
            print("❌ UpdateService: 复制新数据库失败，尝试恢复备份")
            restoreBackupDatabase()
            return
        }
        
        // 3. 重新初始化数据库连接
        reinitializeDatabaseConnection()
        
        // 4. 更新版本信息
        if !updateVersionInfo() {
            print("⚠️ UpdateService: 版本信息更新失败，但数据库更新成功")
        }
        
        // 5. 清理备份文件
        cleanupBackupFiles()
        
        print("✅ UpdateService: 数据库更新完成")
    }
    
    // MARK: - 备份当前数据库
    private func backupCurrentDatabase() -> Bool {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let currentDbPath = "\(documentsPath)/database_stronix.db"
        let backupDbPath = "\(documentsPath)/database_stronix_backup.db"
        
        // 检查当前数据库是否存在
        guard FileManager.default.fileExists(atPath: currentDbPath) else {
            print("⚠️ UpdateService: 当前数据库不存在，跳过备份")
            return true
        }
        
        do {
            // 如果备份文件已存在，先删除
            if FileManager.default.fileExists(atPath: backupDbPath) {
                try FileManager.default.removeItem(atPath: backupDbPath)
            }
            
            // 创建备份
            try FileManager.default.copyItem(atPath: currentDbPath, toPath: backupDbPath)
            print("✅ UpdateService: 数据库备份成功")
            return true
            
        } catch {
            print("❌ UpdateService: 数据库备份失败: \(error)")
            return false
        }
    }
    
    // MARK: - 复制Bundle数据库到Documents
    private func copyBundleDatabaseToDocuments() -> Bool {
        guard let bundleDbPath = Bundle.main.path(forResource: "database_stronix", ofType: "db") else {
            print("❌ UpdateService: 找不到Bundle中的数据库文件")
            return false
        }
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsDbPath = "\(documentsPath)/database_stronix.db"
        
        do {
            // 如果目标文件存在，先删除
            if FileManager.default.fileExists(atPath: documentsDbPath) {
                try FileManager.default.removeItem(atPath: documentsDbPath)
            }
            
            // 复制新的数据库文件
            try FileManager.default.copyItem(atPath: bundleDbPath, toPath: documentsDbPath)
            print("✅ UpdateService: 新数据库复制成功")
            return true
            
        } catch {
            print("❌ UpdateService: 复制数据库失败: \(error)")
            return false
        }
    }
    
    // MARK: - 恢复备份数据库
    private func restoreBackupDatabase() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let currentDbPath = "\(documentsPath)/database_stronix.db"
        let backupDbPath = "\(documentsPath)/database_stronix_backup.db"
        
        guard FileManager.default.fileExists(atPath: backupDbPath) else {
            print("❌ UpdateService: 备份文件不存在，无法恢复")
            return
        }
        
        do {
            // 删除当前损坏的数据库
            if FileManager.default.fileExists(atPath: currentDbPath) {
                try FileManager.default.removeItem(atPath: currentDbPath)
            }
            
            // 恢复备份
            try FileManager.default.copyItem(atPath: backupDbPath, toPath: currentDbPath)
            print("✅ UpdateService: 数据库恢复成功")
            
        } catch {
            print("❌ UpdateService: 数据库恢复失败: \(error)")
        }
    }
    
    // MARK: - 重新初始化数据库连接
    private func reinitializeDatabaseConnection() {
        print("🔄 UpdateService: 重新初始化数据库连接...")
        databaseManager?.reinitializeConnection()
    }
    

    
    // MARK: - 更新版本信息
    private func updateVersionInfo() -> Bool {
        let currentVersion = DatabaseVersionConfig.currentBundleVersion
        return versionService.updateVersionInfo(version: currentVersion)
    }
    
    // MARK: - 清理备份文件
    private func cleanupBackupFiles() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let backupDbPath = "\(documentsPath)/database_stronix_backup.db"
        
        if FileManager.default.fileExists(atPath: backupDbPath) {
            do {
                try FileManager.default.removeItem(atPath: backupDbPath)
                print("✅ UpdateService: 备份文件清理成功")
            } catch {
                print("⚠️ UpdateService: 备份文件清理失败: \(error)")
            }
        }
    }
    
    // MARK: - 手动触发数据库更新
    /// 手动触发数据库更新（用于开发和调试）
    func forceDatabaseUpdate() {
        print("🔄 UpdateService: 手动触发数据库更新...")
        performDatabaseUpdate()
    }
    
    // MARK: - 获取更新状态
    func getUpdateStatus() -> String {
        let comparisonResult = versionService.checkDatabaseVersion()
        
        switch comparisonResult {
        case .bundleNewer:
            return "有可用更新"
        case .documentsNewer:
            return "本地版本较新"
        case .same:
            return "版本最新"
        case .error:
            return "检查失败"
        }
    }
}

