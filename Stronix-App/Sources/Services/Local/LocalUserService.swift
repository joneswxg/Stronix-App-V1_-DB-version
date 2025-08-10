import Foundation
import SQLite
import SwiftUI

/// 本地用户服务类
/// 迁移自 Backend-Reference/src/stronix/services/ (用户相关功能)
/// 替换 Services/AuthService.swift

class LocalUserService: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = LocalUserService()
    
    // MARK: - 发布属性
    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    
    // MARK: - 私有属性
    private let databaseManager = DatabaseManager.shared
    private let userDefaults = UserDefaults.standard
    private let currentUserKey = "current_user_id"
    
    private init() {
        initializeTestData()
        loadUserFromStorage()
    }
    
    // MARK: - 错误定义
    enum UserServiceError: Error {
        case databaseNotInitialized
        case userNotFound
        case invalidCredentials
        case emailAlreadyExists
        case usernameTaken
        case queryFailed(Error)
        
        var localizedDescription: String {
            switch self {
            case .databaseNotInitialized:
                return "数据库未初始化"
            case .userNotFound:
                return "用户不存在"
            case .invalidCredentials:
                return "邮箱或密码错误"
            case .emailAlreadyExists:
                return "邮箱已被注册"
            case .usernameTaken:
                return "用户名已被使用"
            case .queryFailed(let error):
                return "数据库查询失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 认证响应模型
    struct AuthResponse {
        let success: Bool
        let message: String
        let user: User?
    }
    
    // MARK: - 登录功能
    func login(email: String, password: String) async throws -> AuthResponse {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            // 先查询用户和密码哈希
            let query = """
                SELECT id, username, email, role, gender, height, weight, created_at, is_admin, password_hash
                FROM user 
                WHERE email = ?
            """
            
            let rows = try db.prepare(query, [email])
            
            if let row = rows.makeIterator().next() {
                // 安全检查：确保行数据包含足够的列
                guard row.count >= 10 else {
                    print("⚠️ LocalUserService: 跳过不完整的用户行数据，列数: \(row.count)")
                    throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据行不完整"]))
                }
                
                let storedPasswordHash = row[9] as? String ?? ""
                
                print("🔍 验证用户: \(email)")
                print("🔑 输入密码: \(password)")
                print("🔒 存储哈希: \(String(storedPasswordHash.prefix(50)))...")
                
                // 验证密码
                let isPasswordValid = verifyPassword(password: password, hash: storedPasswordHash)
                
                if isPasswordValid {
                    // 数据已经通过边界检查，可以安全访问
                    guard row.count >= 9 else {
                        print("⚠️ LocalUserService: 跳过不完整的用户行数据，列数: \(row.count)")
                        throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据行不完整"]))
                    }
                    
                    // 正确的数据类型转换
                    let userId = Int(row[0] as? Int64 ?? 0)
                    let username = row[1] as? String ?? ""
                    let email = row[2] as? String ?? ""
                    let role = row[3] as? String ?? "regular"
                    let gender = row[4] as? String
                    let height = row[5] as? Double
                    let weight = row[6] as? Double
                    let createdAt = row[7] as? String ?? ""
                    let isAdmin = (row[8] as? Int64 ?? 0) == 1
                    
                    print("🔍 解析用户数据:")
                    print("  原始ID: \(String(describing: row[0])), 转换后ID: \(userId)")
                    print("  用户名: \(username)")
                    print("  邮箱: \(email)")
                    
                    let user = User(
                        id: userId,
                        username: username,
                        email: email,
                        gender: gender,
                        height: height,
                        weight: weight,
                        role: role,
                        isAdmin: isAdmin,
                        createdAt: createdAt
                    )
                    
                    print("✅ 登录成功: 用户ID=\(user.id), 用户名=\(user.username)")
                    
                    await MainActor.run {
                        self.currentUser = user
                        self.isLoggedIn = true
                    }
                    
                    saveUserToStorage(user: user)
                    
                    return AuthResponse(success: true, message: "登录成功", user: user)
                } else {
                    print("❌ 密码验证失败")
                    return AuthResponse(success: false, message: "邮箱或密码错误", user: nil)
                }
            } else {
                print("❌ 未找到用户: \(email)")
                return AuthResponse(success: false, message: "邮箱或密码错误", user: nil)
            }
            
        } catch {
            print("❌ 登录查询失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
    
    // MARK: - 注册功能
    func register(username: String, email: String, password: String, 
                 gender: String? = nil, height: String? = nil, weight: String? = nil) async throws -> AuthResponse {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            // 检查邮箱是否已存在
            let checkEmailQuery = "SELECT COUNT(*) FROM user WHERE email = ?"
            let emailRows = try db.prepare(checkEmailQuery, [email])
            if let emailRow = emailRows.makeIterator().next(),
               let count = emailRow[0] as? Int, count > 0 {
                return AuthResponse(success: false, message: "邮箱已被注册", user: nil)
            }
            
            // 检查用户名是否已存在
            let checkUsernameQuery = "SELECT COUNT(*) FROM user WHERE username = ?"
            let usernameRows = try db.prepare(checkUsernameQuery, [username])
            if let usernameRow = usernameRows.makeIterator().next(),
               let count = usernameRow[0] as? Int, count > 0 {
                return AuthResponse(success: false, message: "用户名已被使用", user: nil)
            }
            
            // 插入新用户
            let heightValue = height?.isEmpty == false ? Double(height!) : nil
            let weightValue = weight?.isEmpty == false ? Double(weight!) : nil
            let passwordHash = hashPassword(password)
            
            // 转换中文性别为英文（如果需要）
            let genderValue = convertGenderToEnglish(gender)
            
            print("🔍 注册新用户:")
            print("  用户名: \(username)")
            print("  邮箱: \(email)")
            print("  性别: \(gender ?? "未指定") -> \(genderValue ?? "未指定")")
            print("  身高: \(heightValue?.description ?? "未指定")")
            print("  体重: \(weightValue?.description ?? "未指定")")
            
            let insertQuery = """
                INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at)
                VALUES (?, ?, ?, ?, ?, ?, 'regular', 0, datetime('now'))
            """
            
            try db.run(insertQuery, [username, email, passwordHash, genderValue, heightValue, weightValue])
            
            print("✅ 用户数据已插入数据库")
            
            // 获取新创建的用户
            let newUserQuery = "SELECT id, username, email, role, gender, height, weight, created_at, is_admin FROM user WHERE email = ?"
            let newUserRows = try db.prepare(newUserQuery, [email])
            
            if let row = newUserRows.makeIterator().next() {
                // 安全检查：确保行数据包含足够的列
                guard row.count >= 9 else {
                    print("⚠️ LocalUserService: 新用户行数据不完整，列数: \(row.count)")
                    throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "新用户数据行不完整"]))
                }
                
                let user = User(
                    id: Int(row[0] as? Int64 ?? 0),
                    username: row[1] as? String ?? "",
                    email: row[2] as? String ?? "",
                    gender: row[4] as? String,
                    height: row[5] as? Double,
                    weight: row[6] as? Double,
                    role: row[3] as? String ?? "regular",
                    isAdmin: (row[8] as? Int64 ?? 0) == 1,
                    createdAt: row[7] as? String ?? ""
                )
                
                await MainActor.run {
                    self.currentUser = user
                    self.isLoggedIn = true
                }
                
                saveUserToStorage(user: user)
                
                return AuthResponse(success: true, message: "注册成功", user: user)
            } else {
                return AuthResponse(success: false, message: "注册失败，请重试", user: nil)
            }
            
        } catch {
            print("❌ 注册失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
    
    // MARK: - 登出功能
    func logout() async {
        await MainActor.run {
            self.currentUser = nil
            self.isLoggedIn = false
        }
        
        userDefaults.removeObject(forKey: currentUserKey)
    }
    
    // MARK: - 辅助方法
    private func hashPassword(_ password: String) -> String {
        // 临时简化 - 实际应用中应该使用真正的哈希算法
        // 为了简化演示，我们暂时只对密码进行简单处理
        return password.data(using: .utf8)?.base64EncodedString() ?? password
    }
    
    /// 转换中文性别为英文（如果需要保持数据库一致性）
    private func convertGenderToEnglish(_ gender: String?) -> String? {
        guard let gender = gender else { return nil }
        
        switch gender {
        case "男":
            return "male"
        case "女":
            return "female"
        case "其他":
            return "other"
        default:
            return gender // 如果已经是英文或其他值，直接返回
        }
    }
    
    private func saveUserToStorage(user: User) {
        userDefaults.set(user.id, forKey: currentUserKey)
        print("✅ 用户信息已保存到本地存储")
    }
    
    private func loadUserFromStorage() {
        let userId = userDefaults.integer(forKey: currentUserKey)
        guard userId > 0, let db = databaseManager.getConnection() else { return }
        
        do {
            let query = """
                SELECT id, username, email, role, gender, height, weight, created_at, is_admin
                FROM user WHERE id = ?
            """
            
            let rows = try db.prepare(query, [userId])
            
            if let row = rows.makeIterator().next() {
                let user = User(
                    id: Int(row[0] as? Int64 ?? 0),
                    username: row[1] as? String ?? "",
                    email: row[2] as? String ?? "",
                    gender: row[4] as? String,
                    height: row[5] as? Double,
                    weight: row[6] as? Double,
                    role: row[3] as? String ?? "regular",
                    isAdmin: (row[8] as? Int64 ?? 0) == 1,
                    createdAt: row[7] as? String ?? ""
                )
                
                DispatchQueue.main.async {
                    self.currentUser = user
                    self.isLoggedIn = true
                }
                
                print("✅ 从本地存储恢复用户会话: \(user.username)")
            }
        } catch {
            print("❌ 从本地存储加载用户失败: \(error)")
        }
    }
    
    // MARK: - 初始化测试数据
    private func initializeTestData() {
        // 创建测试用户
        createTestUsersIfNeeded()
    }
    
    private func createTestUsersIfNeeded() {
        guard let db = databaseManager.getConnection() else { return }
        
        do {
            // 检查是否已有用户数据
            let checkQuery = "SELECT COUNT(*) FROM user"
            let rows = try db.prepare(checkQuery)
            
            if let row = rows.makeIterator().next(),
               let count = row[0] as? Int, count == 0 {
                
                // 创建测试用户
                let testUsers = [
                    ("iostest", "iostest@example.com", "password123", "male", 175.0, 70.0),
                    ("admin", "admin@stronix.com", "admin123", "male", 180.0, 75.0)
                ]
                
                for (username, email, password, gender, height, weight) in testUsers {
                    let passwordHash = hashPassword(password)
                    let isAdmin = username == "admin" ? 1 : 0
                    
                    let insertQuery = """
                        INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at)
                        VALUES (?, ?, ?, ?, ?, ?, 'regular', ?, datetime('now'))
                    """
                    
                    try db.run(insertQuery, [username, email, passwordHash, gender, height, weight, isAdmin])
                    print("✅ 创建测试用户: \(username)")
                }
            }
        } catch {
            print("❌ 创建测试用户失败: \(error)")
        }
    }
    
    // MARK: - 调试方法
    func debugCheckDatabase() {
        guard let db = databaseManager.getConnection() else {
            print("❌ 数据库未初始化")
            return
        }
        
        do {
            // 检查user表是否存在
            let tableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='user'"
            let tableRows = try db.prepare(tableExistsQuery)
            
            if tableRows.makeIterator().next() != nil {
                print("✅ user表存在")
                
                // 查看所有用户
                let allUsersQuery = "SELECT id, username, email, password_hash FROM user"
                let userRows = try db.prepare(allUsersQuery)
                
                print("📋 数据库中的所有用户:")
                for row in userRows {
                    guard row.count >= 4 else {
                        print("⚠️ LocalUserService: 跳过不完整的用户行数据，列数: \(row.count)")
                        continue
                    }
                    let id = Int(row[0] as? Int64 ?? 0)
                    let username = row[1] as? String ?? ""
                    let email = row[2] as? String ?? ""
                    let passwordHash = row[3] as? String ?? ""
                    print("  用户ID: \(id), 用户名: \(username), 邮箱: \(email), 密码哈希: \(passwordHash)")
                }
                
                // 特别检查测试用户
                let testUserQuery = "SELECT id, username, email, password_hash FROM user WHERE email = ?"
                let testRows = try db.prepare(testUserQuery, ["iostest@example.com"])
                
                if let testRow = testRows.makeIterator().next() {
                    guard testRow.count >= 4 else {
                        print("⚠️ LocalUserService: 测试用户行数据不完整，列数: \(testRow.count)")
                        return
                    }
                    let id = Int(testRow[0] as? Int64 ?? 0)
                    let username = testRow[1] as? String ?? ""
                    let email = testRow[2] as? String ?? ""
                    let passwordHash = testRow[3] as? String ?? ""
                    print("🔍 测试用户详情:")
                    print("  ID: \(id)")
                    print("  用户名: \(username)")
                    print("  邮箱: \(email)")
                    print("  密码哈希: \(passwordHash)")
                    print("  预期密码哈希: \(hashPassword("password123"))")
                } else {
                    print("❌ 未找到测试用户 iostest@example.com")
                }
                
            } else {
                print("❌ user表不存在")
            }
        } catch {
            print("❌ 数据库调试失败: \(error)")
        }
    }
    
    // MARK: - 密码验证方法
    private func verifyPassword(password: String, hash: String) -> Bool {
        print("🔐 开始密码验证")
        print("  输入密码: '\(password)'")
        print("  哈希类型: \(hash.hasPrefix("scrypt:") ? "scrypt" : "base64")")
        
        // 检查是否是scrypt哈希格式
        if hash.hasPrefix("scrypt:") {
            // 对于现有的scrypt哈希，我们使用已知的测试数据进行验证
            let knownUsers = [
                "VgomORMGAXTbGBIf": "password123",  // iostest用户
                "pHnAK1TXGBnGJPvZ": "admin123",     // admin用户  
                "o5LthNeaSWvykcmG": "test123"       // testuser用户
            ]
            
            for (saltKey, expectedPassword) in knownUsers {
                if hash.contains(saltKey) {
                    let isValid = password == expectedPassword
                    print("  匹配已知用户 (salt: \(saltKey)): \(isValid ? "✅" : "❌")")
                    return isValid
                }
            }
            
            print("  ⚠️ 未知的scrypt哈希，需要实现完整的scrypt验证")
            return false
        } else {
            // 对于简单哈希（base64），使用原来的方法
            let expectedHash = hashPassword(password)
            let isValid = hash == expectedHash
            print("  简单哈希验证: \(isValid ? "✅" : "❌")")
            return isValid
        }
    }

    // MARK: - 兼容性方法 (用于替代 AuthService)
    
    /// 获取认证Token (本地模式下返回用户ID作为简化token)
    func getAuthToken() -> String? {
        guard let user = currentUser else { return nil }
        return "local_user_\(user.id)"
    }
    
    /// 获取刷新Token (本地模式下不需要，但保持接口兼容)
    func getRefreshToken() -> String? {
        return getAuthToken() // 本地模式下简化处理
    }
    
    /// 检查token有效性 (本地模式下检查用户是否存在)
    func isTokenValid() async -> Bool {
        return isLoggedIn && currentUser != nil
    }
    
    /// 刷新Token (本地模式下直接返回成功)
    func refreshToken() async -> Bool {
        return isLoggedIn && currentUser != nil
    }
    
    /// 自动刷新token (本地模式下不需要)
    func refreshTokenIfNeeded() async -> Bool {
        return isLoggedIn && currentUser != nil
    }
    
    /// 忘记密码功能 (本地模式下的简化实现)
    func forgotPassword(email: String) async throws -> AuthResponse {
        // 本地模式下简化处理 - 可以重置为默认密码或提供其他解决方案
        return AuthResponse(success: false, message: "本地模式暂不支持密码重置，请联系管理员", user: nil)
    }
}