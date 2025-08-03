//
//  VersionService.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/26.
//

import Foundation
import SQLite

class VersionService {
    // 避免循环依赖，通过方法获取数据库连接
    private func getDatabaseConnection() -> Connection? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dbPath = "\(documentsPath)/database_stronix.db"
        
        // 如果数据库文件不存在，返回nil
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return nil
        }
        
        do {
            return try Connection(dbPath)
        } catch {
            print("❌ VersionService: 数据库连接失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 版本检查
    /// 检查数据库版本并返回比较结果
    func checkDatabaseVersion() -> VersionComparisonResult {
        let bundleVersion = DatabaseVersionConfig.currentBundleVersion
        
        guard let documentsVersion = getCurrentDocumentsVersion() else {
            // Documents中没有版本信息，说明是首次安装或需要更新
            return .bundleNewer
        }
        
        // 比较版本
        if bundleVersion.buildNumber > documentsVersion.buildNumber {
            return .bundleNewer
        } else if bundleVersion.buildNumber < documentsVersion.buildNumber {
            return .documentsNewer
        } else {
            return .same
        }
    }
    
    // MARK: - 获取当前Documents数据库版本
    private func getCurrentDocumentsVersion() -> DatabaseVersion? {
        guard let connection = getDatabaseConnection() else {
            print("❌ VersionService: 无法获取数据库连接")
            return nil
        }
        
        do {
            // 首先检查版本表是否存在
            let tableExists = checkVersionTableExists(connection: connection)
            if !tableExists {
                print("⚠️ VersionService: 版本控制表不存在")
                return nil
            }
            
            // 查询最新版本
            let stmt = try connection.prepare(DatabaseVersionConfig.getLatestVersionSQL)
            
            for row in stmt {
                let version = row[0] as? String ?? ""
                let buildNumber = row[1] as? Int64 ?? 0
                let updateDateString = row[2] as? String ?? ""
                let description = row[3] as? String ?? ""
                
                let dateFormatter = ISO8601DateFormatter()
                let updateDate = dateFormatter.date(from: updateDateString) ?? Date()
                
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
    
    // MARK: - 检查版本表是否存在
    private func checkVersionTableExists(connection: Connection) -> Bool {
        do {
            let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
            let stmt = try connection.prepare(sql)
            
            for _ in try stmt.run([DatabaseVersionConfig.versionTableName]) {
                return true
            }
            return false
        } catch {
            print("❌ VersionService: 检查版本表失败: \(error)")
            return false
        }
    }
    
    // MARK: - 创建版本控制表
    func createVersionTable() -> Bool {
        guard let connection = getDatabaseConnection() else {
            print("❌ VersionService: 无法获取数据库连接")
            return false
        }
        
        do {
            try connection.execute(DatabaseVersionConfig.createVersionTableSQL)
            print("✅ VersionService: 版本控制表创建成功")
            return true
        } catch {
            print("❌ VersionService: 创建版本控制表失败: \(error)")
            return false
        }
    }
    
    // MARK: - 更新版本信息
    func updateVersionInfo(version: DatabaseVersion) -> Bool {
        guard let connection = getDatabaseConnection() else {
            print("❌ VersionService: 无法获取数据库连接")
            return false
        }
        
        do {
            // 确保版本表存在
            if !createVersionTable() {
                return false
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let updateDateString = dateFormatter.string(from: version.updateDate)
            
            let stmt = try connection.prepare(DatabaseVersionConfig.insertVersionSQL)
            try stmt.run([
                version.version,
                version.buildNumber,
                updateDateString,
                version.description
            ])
            
            print("✅ VersionService: 版本信息更新成功 - 版本: \(version.version), 构建号: \(version.buildNumber)")
            return true
            
        } catch {
            print("❌ VersionService: 更新版本信息失败: \(error)")
            return false
        }
    }
    
    // MARK: - 获取版本信息描述
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
}

