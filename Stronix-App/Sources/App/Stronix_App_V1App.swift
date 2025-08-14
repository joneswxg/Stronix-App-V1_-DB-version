//
//  Stronix_App_V1App.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/21.
//

import SwiftUI

@main
struct Stronix_App_V1App: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // 简化的调试信息
        printSimpleDatabaseInfo()
        
        // 请求通知权限
        NotificationManager.shared.requestPermissionIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .withAppTheme()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    // 处理应用生命周期变化
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("📱 应用进入后台")
            // 应用进入后台时，保存计时器状态
            TrainingSessionManager.shared.handleAppDidEnterBackground()
            
        case .active:
            print("📱 应用变为活跃状态")
            // 应用回到前台时，恢复计时器状态
            TrainingSessionManager.shared.handleAppDidBecomeActive()
            
        case .inactive:
            print("📱 应用变为非活跃状态")
            
        @unknown default:
            break
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
