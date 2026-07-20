import Foundation
import SQLite

/// 本地用户测试数据初始化
/// 用于创建演示和测试用户账户
class LocalUserTestData {
    
    static func initializeTestUsers() {
        let dbPath = getDatabasePath()
        
        do {
            let db = try Connection(dbPath)
            
            // 检查是否已有测试用户
            let checkQuery = "SELECT COUNT(*) FROM user WHERE email = ?"
            let testEmail = "iostest@example.com"
            
            let rows = try db.prepare(checkQuery, [testEmail])
            if let row = rows.makeIterator().next(),
               let count = row[0] as? Int, count > 0 {
                print("✅ 测试用户已存在")
                return
            }
            
            // 创建测试用户
            let password = "password123"
            let passwordHash = password.data(using: .utf8)?.base64EncodedString() ?? password
            
            let insertQuery = """
                INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
            """
            
            try db.run(insertQuery, [
                "iOS测试用户",
                testEmail,
                passwordHash,
                "male",
                175.0,
                70.0,
                "regular",
                0
            ])
            
            print("✅ 测试用户创建成功: \(testEmail)")
            print("📝 用户名: iOS测试用户")
            print("📧 邮箱: \(testEmail)")
            print("🔒 密码: \(password)")
            
        } catch {
            print("❌ 初始化测试用户失败: \(error)")
        }
    }
    
    static func createAdminUser() {
        let dbPath = getDatabasePath()
        
        do {
            let db = try Connection(dbPath)
            
            // 检查是否已有管理员用户
            let checkQuery = "SELECT COUNT(*) FROM user WHERE email = ?"
            let adminEmail = "admin@stronix.com"
            
            let rows = try db.prepare(checkQuery, [adminEmail])
            if let row = rows.makeIterator().next(),
               let count = row[0] as? Int, count > 0 {
                print("✅ 管理员用户已存在")
                return
            }
            
            // 创建管理员用户
            let password = "admin123"
            let passwordHash = password.data(using: .utf8)?.base64EncodedString() ?? password
            
            let insertQuery = """
                INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
            """
            
            try db.run(insertQuery, [
                "系统管理员",
                adminEmail,
                passwordHash,
                "male",
                180.0,
                75.0,
                "admin",
                1
            ])
            
            print("✅ 管理员用户创建成功: \(adminEmail)")
            print("📝 用户名: 系统管理员")
            print("📧 邮箱: \(adminEmail)")
            print("🔒 密码: \(password)")
            
        } catch {
            print("❌ 初始化管理员用户失败: \(error)")
        }
    }
    
    // MARK: - 辅助方法
    private static func getDatabasePath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return "\(documentsPath)/database_stronix.db"
    }
} 