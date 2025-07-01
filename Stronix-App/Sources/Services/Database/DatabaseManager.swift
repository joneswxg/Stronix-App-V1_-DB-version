//
//  DatabaseManager.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/26.
//

import Foundation
import SQLite

class DatabaseManager {
    // 单例模式，确保整个应用只有一个数据库管理实例
    static let shared = DatabaseManager()
    private var db: Connection?
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - 数据库初始化
    private func setupDatabase() {
        let dbPath = getDatabasePath()
        
        do {
            db = try Connection(dbPath)
            print("✅ DatabaseManager: 数据库连接成功: \(dbPath)")
        } catch {
            print("❌ DatabaseManager: 数据库连接失败: \(error)")
        }
    }
    
    private func getDatabasePath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dbPath = "\(documentsPath)/database_stronix.db"
        
        // 如果Documents目录中不存在数据库，则从Bundle复制
        if !FileManager.default.fileExists(atPath: dbPath) {
            guard let bundleDbPath = Bundle.main.path(forResource: "database_stronix", ofType: "db") else {
                print("❌ DatabaseManager: 找不到Bundle中的数据库文件")
                return dbPath
            }
            
            do {
                try FileManager.default.copyItem(atPath: bundleDbPath, toPath: dbPath)
                print("✅ DatabaseManager: 数据库已复制到Documents目录")
            } catch {
                print("❌ DatabaseManager: 复制数据库失败: \(error)")
            }
        }
        
        return dbPath
    }
    
    // MARK: - 公共数据库连接方法
    /// 获取数据库连接 - 供所有Local服务使用
    func getConnection() -> Connection? {
        return db
    }
    
    /// 执行SQL查询 - 统一的查询方法
    func executeQuery<T>(_ sql: String, bindings: [Binding?] = []) throws -> [T] {
        guard let db = db else {
            throw DatabaseError.databaseNotInitialized
        }
        
        let stmt = try db.prepare(sql)
        return try stmt.map { row in
            return row as! T
        }
    }
    
    // MARK: - 错误定义
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
    
    // MARK: - 数据库状态检查
    func isDatabaseReady() -> Bool {
        return db != nil
    }
    
    // MARK: - 数据库路径获取（供其他服务使用）
    func getDatabasePathForServices() -> String {
        return getDatabasePath()
    }
    
    // TODO: 其他功能待迁移到对应的Local服务类
    // 动作相关功能已迁移到 LocalActionService.swift
    
    // MARK: - 辅助方法
    // 注意：getDatabasePath()已在上面重新实现为支持Documents目录
}