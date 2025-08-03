//
//  Stronix_App_V1App.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/21.
//

import SwiftUI

@main
struct Stronix_App_V1App: App {
    init() {
        // 简化的调试信息
        printSimpleDatabaseInfo()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
    
    // 简化的数据库信息
    private func printSimpleDatabaseInfo() {
        let versionService = VersionService()
        if let count = try? countActionRecords() {
            print("🗄️ 数据库状态: 版本 \(versionService.getCurrentVersion() ?? "未知"), Action表记录数: \(count)")
        }
    }
    
    // 计算action表记录数
    private func countActionRecords() throws -> Int {
        guard let db = DatabaseManager.shared.getConnection() else {
            throw NSError(domain: "AppError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取数据库连接"])
        }
        
        let sql = "SELECT COUNT(*) as count FROM action"
        let stmt = try db.prepare(sql)
        
        for row in stmt {
            return row[0] as? Int ?? 0
        }
        
        return 0
    }
}

// 扩展VersionService以获取简单的版本信息
extension VersionService {
    func getCurrentVersion() -> String? {
        // 这里需要实现获取当前版本的简单方法
        return "1.1.1"
    }
}
