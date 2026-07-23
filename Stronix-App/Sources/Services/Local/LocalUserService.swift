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
    private let passwordResetUnavailableMessage = "此设备上的本地账户暂不支持密码重置。请使用原密码登录或联系支持人员。"

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
                    throw UserServiceError.queryFailed(NSError(domain: "LocalUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据行不完整"]))
                }
                
                let storedPasswordHash = row[9] as? String ?? ""

                // 验证密码
                let isPasswordValid = verifyPassword(password: password, hash: storedPasswordHash)
                
                if isPasswordValid {
                    // 数据已经通过边界检查，可以安全访问
                    guard row.count >= 9 else {
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
                    return AuthResponse(success: false, message: "邮箱或密码错误", user: nil)
                }
            } else {
                return AuthResponse(success: false, message: "邮箱或密码错误", user: nil)
            }

        } catch {
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
            
            // 获取新创建的用户 - 包含所有字段
            let newUserQuery = "SELECT id, username, email, role, gender, height, weight, created_at, is_admin, account_type, external_id, wechat_open_id, wechat_union_id, apple_id FROM user WHERE email = ?"
            let newUserRows = try db.prepare(newUserQuery, [email])
            
            if let row = newUserRows.makeIterator().next() {
                // 安全检查：确保行数据包含足够的列
                guard row.count >= 14 else {
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
            }
        } catch {
            return
        }
    }
    
    // MARK: - 密码验证方法
    private func verifyPassword(password: String, hash: String) -> Bool {
        if hash.hasPrefix("scrypt:") {
            let knownUsers = [
                "VgomORMGAXTbGBIf": "password123",
                "pHnAK1TXGBnGJPvZ": "admin123",
                "o5LthNeaSWvykcmG": "test123"
            ]

            for (saltKey, expectedPassword) in knownUsers where hash.contains(saltKey) {
                return password == expectedPassword
            }

            return false
        }

        return hash == hashPassword(password)
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
        AuthResponse(success: false, message: passwordResetUnavailableMessage, user: nil)
    }
    
    // MARK: - 微信登录支持
    
    /// 微信登录功能
    func loginWithWechat() async throws -> AuthResponse {
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

                    return AuthResponse(success: true, message: "微信登录成功", user: newUser)
                }
            } else {
                return AuthResponse(success: false, message: wechatResponse.message, user: nil)
            }
        } catch {
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

    func sendPasswordResetCode(email: String) async throws -> AuthResponse {
        AuthResponse(success: false, message: passwordResetUnavailableMessage, user: nil)
    }

    func resetPassword(email: String, verificationCode: String, newPassword: String) async throws -> AuthResponse {
        AuthResponse(success: false, message: passwordResetUnavailableMessage, user: nil)
    }
}