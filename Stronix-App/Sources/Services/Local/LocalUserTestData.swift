import Foundation
import SQLite

/// 本地用户测试数据初始化
/// 仅通过已经完成生命周期准备的连接创建演示账户。
final class LocalUserTestData {
    static func initializeTestUsers() {
        guard let db = DatabaseManager.shared.getConnection() else {
            print("❌ 初始化测试用户失败: 数据库尚未 ready")
            return
        }

        do {
            let checkQuery = "SELECT COUNT(*) FROM user WHERE email = ?"
            let testEmail = "iostest@example.com"
            let rows = try db.prepare(checkQuery, [testEmail])
            if let row = rows.makeIterator().next(),
               let count = row[0] as? Int, count > 0 {
                print("✅ 测试用户已存在")
                return
            }

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
        } catch {
            print("❌ 初始化测试用户失败: \(error)")
        }
    }

    static func createAdminUser() {
        guard let db = DatabaseManager.shared.getConnection() else {
            print("❌ 初始化管理员用户失败: 数据库尚未 ready")
            return
        }

        do {
            let checkQuery = "SELECT COUNT(*) FROM user WHERE email = ?"
            let adminEmail = "admin@stronix.com"
            let rows = try db.prepare(checkQuery, [adminEmail])
            if let row = rows.makeIterator().next(),
               let count = row[0] as? Int, count > 0 {
                print("✅ 管理员用户已存在")
                return
            }

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
        } catch {
            print("❌ 初始化管理员用户失败: \(error)")
        }
    }
}
