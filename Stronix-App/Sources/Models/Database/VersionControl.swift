//
//  VersionControl.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/26.
//

import Foundation

// MARK: - 数据库版本控制模型
struct DatabaseVersion {
    let version: String
    let buildNumber: Int
    let updateDate: Date
    let description: String
    
    init(version: String, buildNumber: Int, updateDate: Date = Date(), description: String = "") {
        self.version = version
        self.buildNumber = buildNumber
        self.updateDate = updateDate
        self.description = description
    }
}

// MARK: - 版本比较结果
enum VersionComparisonResult {
    case bundleNewer    // Bundle中的数据库更新
    case documentsNewer // Documents中的数据库更新
    case same          // 版本相同
    case error         // 比较出错
}

// MARK: - 数据库版本控制配置
struct DatabaseVersionConfig {
    // 当前Bundle中数据库的版本信息
    static let currentBundleVersion = DatabaseVersion(
        version: "1.2.0",
        buildNumber: 4,
        description: "添加密码重置功能 - 新增password_reset_codes表"
    )
    
    // 版本控制表名
    static let versionTableName = "database_version"
    
    // 版本控制表创建SQL
    static let createVersionTableSQL = """
        CREATE TABLE IF NOT EXISTS database_version (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            version TEXT NOT NULL,
            build_number INTEGER NOT NULL,
            update_date TEXT NOT NULL,
            description TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """
    
    // 插入版本记录SQL
    static let insertVersionSQL = """
        INSERT INTO database_version (version, build_number, update_date, description)
        VALUES (?, ?, ?, ?)
    """
    
    // 获取最新版本SQL
    static let getLatestVersionSQL = """
        SELECT version, build_number, update_date, description
        FROM database_version
        ORDER BY build_number DESC, id DESC
        LIMIT 1
    """
    
    // 密码重置验证码表创建SQL
    static let createPasswordResetTableSQL = """
        CREATE TABLE IF NOT EXISTS password_reset_codes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL,
            verification_code TEXT NOT NULL,
            expires_at DATETIME NOT NULL,
            is_used INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            used_at DATETIME NULL
        )
    """
}

