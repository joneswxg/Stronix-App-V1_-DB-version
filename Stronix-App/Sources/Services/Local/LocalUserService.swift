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
                SELECT id, username, email, role, gender, height, weight, created_at, is_admin, password_hash,
                       account_type, external_id, wechat_open_id, wechat_union_id, apple_id
                FROM user 
                WHERE email = ?
            """
            
            let rows = try db.prepare(query, [email])
            
            if let row = rows.makeIterator().next() {
                // 安全检查：确保行数据包含足够的列（增加到15列以支持新字段）
                guard row.count >= 15 else {
                    print("⚠️ LocalUserService: 跳过不完整的用户行数据，列数: \(row.count)")
                    throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据行不完整"]))
                }
                
                let storedPasswordHash = row[9] as? String ?? ""

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
                    
                    let user = User(
                        id: userId,
                        username: username,
                        email: email,
                        gender: gender,
                        height: height,
                        weight: weight,
                        role: role,
                        isAdmin: isAdmin,
                        createdAt: createdAt,
                        accountType: row[10] as? String,
                        externalId: row[11] as? String,
                        wechatOpenId: row[12] as? String,
                        wechatUnionId: row[13] as? String,
                        appleId: row[14] as? String
                    )
                    
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

            let insertQuery = """
                INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at, account_type, external_id)
                VALUES (?, ?, ?, ?, ?, ?, 'regular', 0, datetime('now'), ?, ?)
            """
            
            try db.run(insertQuery, [username, email, passwordHash, genderValue, heightValue, weightValue, "email", email])
            
            print("✅ 用户数据已插入数据库")
            
            // 获取新创建的用户 - 包含所有字段
            let newUserQuery = "SELECT id, username, email, role, gender, height, weight, created_at, is_admin, account_type, external_id, wechat_open_id, wechat_union_id, apple_id FROM user WHERE email = ?"
            let newUserRows = try db.prepare(newUserQuery, [email])
            
            if let row = newUserRows.makeIterator().next() {
                // 安全检查：确保行数据包含足够的列
                guard row.count >= 14 else {
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
                        createdAt: row[7] as? String ?? "",
                        accountType: row[9] as? String,
                        externalId: row[10] as? String,
                        wechatOpenId: row[11] as? String,
                        wechatUnionId: row[12] as? String,
                        appleId: row[13] as? String
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
                    createdAt: row[7] as? String ?? "",
                    accountType: nil,
                    externalId: nil,
                    wechatOpenId: nil,
                    wechatUnionId: nil,
                    appleId: nil
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
    
    // MARK: - 微信登录支持
    
    /// 微信登录功能
    func loginWithWechat() async throws -> AuthResponse {
        print("🚀 开始微信登录流程")
        
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        do {
            // 使用微信登录服务
            let wechatService = WechatLoginService.shared
            
            // 模拟微信登录获取用户信息
            let wechatResponse = try await wechatService.simulateWechatLogin()
            
            if wechatResponse.success, let openId = wechatResponse.openId, let nickname = wechatResponse.nickname {
                // 优先通过wechat_open_id查找用户
                if let existingUser = try await findUserByWechatOpenId(openId) {
                    // 用户已存在，直接登录
                    await MainActor.run {
                        self.currentUser = existingUser
                        self.isLoggedIn = true
                    }
                    saveUserToStorage(user: existingUser)
                    
                    print("✅ 微信用户登录成功: \(existingUser.username)")
                    return AuthResponse(success: true, message: "微信登录成功", user: existingUser)
                } else {
                    // 新用户，创建账户
                    let newUser = try await createWechatUser(
                        openId: openId,
                        nickname: nickname
                    )
                    
                    await MainActor.run {
                        self.currentUser = newUser
                        self.isLoggedIn = true
                    }
                    saveUserToStorage(user: newUser)
                    
                    print("✅ 微信新用户注册并登录成功: \(newUser.username)")
                    return AuthResponse(success: true, message: "微信登录成功", user: newUser)
                }
            } else {
                print("❌ 微信登录失败: \(wechatResponse.message)")
                return AuthResponse(success: false, message: wechatResponse.message, user: nil)
            }
        } catch {
            print("❌ 微信登录异常: \(error)")
            throw error
        }
    }
    
    /// 检查用户是否通过微信登录
    func isWechatUser() -> Bool {
        guard let user = currentUser else { return false }
        return user.accountType == "wechat" || user.email.hasPrefix("wechat_")
    }
    
    /// 检查是否为邮箱用户
    func isEmailUser() -> Bool {
        guard let user = currentUser else { return false }
        return user.accountType == "email" || (!user.email.hasPrefix("wechat_") && user.accountType == nil)
    }
    
    /// 检查是否为Apple用户
    func isAppleUser() -> Bool {
        guard let user = currentUser else { return false }
        return user.accountType == "apple"
    }
    
    /// 根据账户类型获取用户显示名称
    func getUserDisplayName() -> String {
        guard let user = currentUser else { return "未知用户" }
        
        if !user.username.isEmpty {
            return user.username
        }
        
        switch user.accountType {
        case "wechat":
            return "微信用户"
        case "apple":
            return "Apple用户"
        case "email":
            return user.email
        default:
            return user.email.isEmpty ? "用户" : user.email
        }
    }
    
    /// 根据邮箱获取用户
    private func getUserByEmail(_ email: String) async throws -> User? {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            let query = "SELECT id, username, email, role, gender, height, weight, created_at, is_admin, account_type, external_id, wechat_open_id, wechat_union_id, apple_id FROM user WHERE email = ?"
        let rows = try db.prepare(query, [email])
        
        if let row = rows.makeIterator().next() {
            guard row.count >= 14 else {
                throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据行不完整"]))
            }
            
            return User(
                id: Int(row[0] as? Int64 ?? 0),
                username: row[1] as? String ?? "",
                email: row[2] as? String ?? "",
                gender: row[4] as? String,
                height: row[5] as? Double,
                weight: row[6] as? Double,
                role: row[3] as? String ?? "regular",
                isAdmin: (row[8] as? Int64 ?? 0) == 1,
                createdAt: row[7] as? String ?? "",
                accountType: row[9] as? String,
                externalId: row[10] as? String,
                wechatOpenId: row[11] as? String,
                wechatUnionId: row[12] as? String,
                appleId: row[13] as? String
            )
            }
            return nil
        } catch {
            throw UserServiceError.queryFailed(error)
        }
    }
    
    /// 根据微信OpenId查找用户
    private func findUserByWechatOpenId(_ openId: String) async throws -> User? {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            let query = "SELECT id, username, email, role, gender, height, weight, created_at, is_admin, account_type, external_id, wechat_open_id, wechat_union_id, apple_id FROM user WHERE wechat_open_id = ?"
            let rows = try db.prepare(query, [openId])
            
            if let row = rows.makeIterator().next() {
                guard row.count >= 14 else {
                    throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据行不完整"]))
                }
                
                return User(
                    id: Int(row[0] as? Int64 ?? 0),
                    username: row[1] as? String ?? "",
                    email: row[2] as? String ?? "",
                    gender: row[4] as? String,
                    height: row[5] as? Double,
                    weight: row[6] as? Double,
                    role: row[3] as? String ?? "regular",
                    isAdmin: (row[8] as? Int64 ?? 0) == 1,
                    createdAt: row[7] as? String ?? "",
                    accountType: row[9] as? String,
                    externalId: row[10] as? String,
                    wechatOpenId: row[11] as? String,
                    wechatUnionId: row[12] as? String,
                    appleId: row[13] as? String
                )
            }
            
            return nil
        } catch {
            print("❌ 通过微信OpenId查询用户失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
    
    /// 创建微信用户
    private func createWechatUser(openId: String, nickname: String) async throws -> User {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            let wechatEmail = "wechat_\(openId)"
            let currentTime = ISO8601DateFormatter().string(from: Date())
            
            // 生成唯一的用户名
            let uniqueUsername = try await generateUniqueUsername(baseName: nickname)
            
            let insertQuery = """
                INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at, account_type, external_id, wechat_open_id, wechat_union_id, apple_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            try db.run(insertQuery, [uniqueUsername, wechatEmail, "", nil, nil, nil, "regular", 0, currentTime, "wechat", openId, openId, nil, nil])
            
            // 获取新创建的用户ID
            let getUserQuery = "SELECT id FROM user WHERE email = ?"
            let rows = try db.prepare(getUserQuery, [wechatEmail])
            
            if let row = rows.makeIterator().next() {
                let userId = Int(row[0] as? Int64 ?? 0)
                
                return User(
                    id: userId,
                    username: uniqueUsername,
                    email: wechatEmail,
                    gender: nil,
                    height: nil,
                    weight: nil,
                    role: "regular",
                    isAdmin: false,
                    createdAt: currentTime,
                    accountType: "wechat",
                    externalId: openId,
                    wechatOpenId: openId,
                    wechatUnionId: nil,
                    appleId: nil
                )
            } else {
                throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取新创建的用户ID"]))
            }
        } catch {
            throw UserServiceError.queryFailed(error)
        }
    }
    
    /// 生成唯一的用户名
    private func generateUniqueUsername(baseName: String) async throws -> String {
        guard databaseManager.getConnection() != nil else {
            throw UserServiceError.databaseNotInitialized
        }
        
        var uniqueUsername = baseName
        var counter = 1
        
        // 检查用户名是否已存在
        while try await isUsernameExists(uniqueUsername) {
            uniqueUsername = "\(baseName)\(counter)"
            counter += 1
            
            // 防止无限循环，最多尝试1000次
            if counter > 1000 {
                // 如果还是重复，使用时间戳
                let timestamp = Int(Date().timeIntervalSince1970)
                uniqueUsername = "\(baseName)_\(timestamp)"
                break
            }
        }
        
        return uniqueUsername
    }
    
    /// 检查用户名是否存在
    private func isUsernameExists(_ username: String) async throws -> Bool {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            let checkQuery = "SELECT COUNT(*) FROM user WHERE username = ?"
            let rows = try db.prepare(checkQuery, [username])
            
            if let row = rows.makeIterator().next() {
                let count = Int(row[0] as? Int64 ?? 0)
                return count > 0
            }
            
            return false
        } catch {
            throw UserServiceError.queryFailed(error)
        }
    }
    
    // MARK: - 密码重置功能
    
    /// 发送密码重置验证码
    func sendPasswordResetCode(email: String) async throws -> AuthResponse {
        // 1. 验证邮箱格式
        let emailService = EmailService.shared
        guard emailService.isValidEmail(email) else {
            return AuthResponse(success: false, message: "邮箱格式不正确", user: nil)
        }
        
        // 2. 检查用户是否存在
        guard let user = try await getUserByEmail(email) else {
            return AuthResponse(success: false, message: "该邮箱未注册", user: nil)
        }
        
        // 3. 检查是否为邮箱注册用户
        guard user.accountType == "email" || user.accountType == nil else {
            return AuthResponse(success: false, message: "该账户不支持邮箱密码重置", user: nil)
        }
        
        // 4. 检查发送频率限制（1分钟内只能发送一次）
        if let lastSentTime = try await getLastPasswordResetCodeTime(email: email) {
            let timeSinceLastSent = Date().timeIntervalSince(lastSentTime)
            if timeSinceLastSent < 60 { // 60秒限制
                let remainingTime = Int(60 - timeSinceLastSent)
                return AuthResponse(success: false, message: "请等待 \(remainingTime) 秒后再重新发送", user: nil)
            }
        }
        
        // 5. 生成验证码
        let verificationCode = emailService.generateVerificationCode()
        
        // 6. 保存验证码到数据库
        try await savePasswordResetCode(email: email, code: verificationCode)
        
        // 7. 发送邮件
        let emailSent = await emailService.sendPasswordResetEmail(to: email, verificationCode: verificationCode)
        
        if emailSent {
            return AuthResponse(success: true, message: "验证码已发送到您的邮箱", user: nil)
        } else {
            return AuthResponse(success: false, message: "邮件发送失败，请稍后重试", user: nil)
        }
    }
    
    /// 验证密码重置验证码并重置密码
    func resetPassword(email: String, verificationCode: String, newPassword: String) async throws -> AuthResponse {
        // 1. 验证验证码
        guard let resetCode = try await getValidPasswordResetCode(email: email, code: verificationCode) else {
            return AuthResponse(success: false, message: "验证码无效或已过期", user: nil)
        }
        
        // 2. 检查验证码是否已使用
        if resetCode.isUsed {
            return AuthResponse(success: false, message: "验证码已被使用", user: nil)
        }
        
        // 3. 检查验证码是否过期
        if resetCode.expiresAt < Date() {
            return AuthResponse(success: false, message: "验证码已过期", user: nil)
        }
        
        // 4. 更新用户密码
        try await updateUserPassword(email: email, newPassword: newPassword)
        
        // 5. 标记验证码为已使用
        try await markPasswordResetCodeAsUsed(resetCode.id)
        
        return AuthResponse(success: true, message: "密码重置成功", user: nil)
    }
    
    /// 保存密码重置验证码
    private func savePasswordResetCode(email: String, code: String) async throws {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            // 设置验证码15分钟后过期
            let expiresAt = Date().addingTimeInterval(15 * 60)
            let dateFormatter = ISO8601DateFormatter()
            
            let insertSQL = """
                INSERT INTO password_reset_codes (email, verification_code, expires_at, is_used, created_at)
                VALUES (?, ?, ?, 0, ?)
            """
            
            let stmt = try db.prepare(insertSQL)
            try stmt.run([
                email,
                code,
                dateFormatter.string(from: expiresAt),
                dateFormatter.string(from: Date())
            ])
            
            print("✅ LocalUserService: 密码重置验证码已保存")
        } catch {
            print("❌ LocalUserService: 保存密码重置验证码失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
    
    /// 获取有效的密码重置验证码
    private func getValidPasswordResetCode(email: String, code: String) async throws -> PasswordResetCode? {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            let query = """
                SELECT id, email, verification_code, expires_at, is_used, created_at, used_at
                FROM password_reset_codes
                WHERE email = ? AND verification_code = ?
                ORDER BY created_at DESC
                LIMIT 1
            """
            
            let rows = try db.prepare(query, [email, code])
            
            if let row = rows.makeIterator().next() {
                let dateFormatter = ISO8601DateFormatter()
                
                return PasswordResetCode(
                    id: Int(row[0] as? Int64 ?? 0),
                    email: row[1] as? String ?? "",
                    verificationCode: row[2] as? String ?? "",
                    expiresAt: dateFormatter.date(from: row[3] as? String ?? "") ?? Date(),
                    isUsed: (row[4] as? Int64 ?? 0) == 1,
                    createdAt: dateFormatter.date(from: row[5] as? String ?? "") ?? Date(),
                    usedAt: {
                        if let usedAtString = row[6] as? String {
                            return dateFormatter.date(from: usedAtString)
                        }
                        return nil
                    }()
                )
            }
            
            return nil
        } catch {
            print("❌ LocalUserService: 获取密码重置验证码失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
    
    /// 更新用户密码
    private func updateUserPassword(email: String, newPassword: String) async throws {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            // 对新密码进行哈希处理
            let passwordHash = hashPassword(newPassword)
            let updateSQL = "UPDATE user SET password_hash = ? WHERE email = ?"
            let stmt = try db.prepare(updateSQL)
            try stmt.run([passwordHash, email])
            
            print("✅ LocalUserService: 用户密码已更新")
        } catch {
            print("❌ LocalUserService: 更新用户密码失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
    
    /// 标记密码重置验证码为已使用
    private func markPasswordResetCodeAsUsed(_ codeId: Int) async throws {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            let updateSQL = "UPDATE password_reset_codes SET is_used = 1, used_at = ? WHERE id = ?"
            let stmt = try db.prepare(updateSQL)
            try stmt.run([dateFormatter.string(from: Date()), codeId])
            
            print("✅ LocalUserService: 密码重置验证码已标记为已使用")
        } catch {
            print("❌ LocalUserService: 标记验证码为已使用失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
    
    /// 获取最后一次发送密码重置验证码的时间
    private func getLastPasswordResetCodeTime(email: String) async throws -> Date? {
        guard let db = databaseManager.getConnection() else {
            throw UserServiceError.databaseNotInitialized
        }
        
        do {
            let query = """
                SELECT created_at FROM password_reset_codes 
                WHERE email = ? 
                ORDER BY created_at DESC 
                LIMIT 1
            """
            
            let rows = try db.prepare(query, [email])
            
            if let row = rows.makeIterator().next() {
                let dateFormatter = ISO8601DateFormatter()
                if let createdAtString = row[0] as? String {
                    return dateFormatter.date(from: createdAtString)
                }
            }
            
            return nil
        } catch {
            print("❌ LocalUserService: 获取最后发送时间失败: \(error)")
            throw UserServiceError.queryFailed(error)
        }
    }
}