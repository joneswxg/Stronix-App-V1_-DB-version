import Foundation
import SQLite
import SwiftUI

final class LocalUserService: ObservableObject {
    static let shared = LocalUserService()

    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published private(set) var isLoading = false

    private let connectionProvider: () -> Connection?
    private let credentialing: any PasswordCredentialing
    private let sessionStore: any LocalSessionStore
    private let legacyDefaults: UserDefaults
    private let legacySessionKey = "current_user_id"

    init(
        connectionProvider: @escaping () -> Connection? = { DatabaseManager.shared.getConnection() },
        credentialing: any PasswordCredentialing = PBKDF2PasswordCredentialing(),
        sessionStore: any LocalSessionStore = KeychainLocalSessionStore(),
        legacyDefaults: UserDefaults = .standard
    ) {
        self.connectionProvider = connectionProvider
        self.credentialing = credentialing
        self.sessionStore = sessionStore
        self.legacyDefaults = legacyDefaults
    }

    enum UserServiceError: Error, LocalizedError {
        case databaseNotInitialized
        case userNotFound
        case invalidCredentials
        case emailAlreadyExists
        case usernameTaken
        case sessionUnavailable
        case queryFailed(Error)

        var errorDescription: String? {
            switch self {
            case .databaseNotInitialized: "数据库未初始化"
            case .userNotFound: "用户不存在"
            case .invalidCredentials: "邮箱或密码错误"
            case .emailAlreadyExists: "邮箱已被注册"
            case .usernameTaken: "用户名已被使用"
            case .sessionUnavailable: "无法安全保存登录状态，请重试"
            case .queryFailed: "数据库查询失败"
            }
        }
    }

    struct AuthResponse {
        let success: Bool
        let message: String
        let user: User?
    }

    func restoreSession() async {
        legacyDefaults.removeObject(forKey: legacySessionKey)
        do {
            guard let session = try sessionStore.load() else { return }
            guard let user = try user(id: session.userID) else {
                try sessionStore.clear()
                return
            }
            await publishAuthenticatedUser(user)
        } catch {
            try? sessionStore.clear()
            await publishLoggedOut()
        }
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        await setLoading(true)
        defer { Task { await self.setLoading(false) } }

        guard let db = connectionProvider() else { throw UserServiceError.databaseNotInitialized }
        guard let row = try db.prepare(userSelectSQL + " WHERE email = ?", [email]).makeIterator().next() else {
            return AuthResponse(success: false, message: "邮箱或密码错误", user: nil)
        }
        guard row.count == 15, let storedCredential = row[9] as? String else {
            throw UserServiceError.queryFailed(LocalCredentialError.malformedCredential)
        }

        let verification: PasswordCredentialVerification
        do {
            verification = try credentialing.verify(password: password, storedCredential: storedCredential)
        } catch {
            return AuthResponse(success: false, message: "邮箱或密码错误", user: nil)
        }
        guard verification != .invalid else {
            return AuthResponse(success: false, message: "邮箱或密码错误", user: nil)
        }

        if verification == .validLegacy {
            let upgradedCredential = try credentialing.makeCredential(password: password)
            try db.run("UPDATE user SET password_hash = ? WHERE id = ?", [upgradedCredential, row[0]])
        }

        let user = try makeUser(from: row)
        try await establishSession(for: user)
        return AuthResponse(success: true, message: "登录成功", user: user)
    }

    func register(
        username: String,
        email: String,
        password: String,
        gender: String? = nil,
        height: String? = nil,
        weight: String? = nil
    ) async throws -> AuthResponse {
        await setLoading(true)
        defer { Task { await self.setLoading(false) } }

        guard let db = connectionProvider() else { throw UserServiceError.databaseNotInitialized }
        if try exists(db, query: "SELECT 1 FROM user WHERE email = ?", value: email) {
            return AuthResponse(success: false, message: "邮箱已被注册", user: nil)
        }
        if try exists(db, query: "SELECT 1 FROM user WHERE username = ?", value: username) {
            return AuthResponse(success: false, message: "用户名已被使用", user: nil)
        }

        let credential = try credentialing.makeCredential(password: password)
        let heightValue = height.flatMap(Double.init)
        let weightValue = weight.flatMap(Double.init)
        try db.run(
            """
            INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at, account_type, external_id)
            VALUES (?, ?, ?, ?, ?, ?, 'regular', 0, datetime('now'), 'email', ?)
            """,
            [username, email, credential, convertGenderToEnglish(gender), heightValue, weightValue, email]
        )
        guard let user = try user(email: email) else {
            throw UserServiceError.userNotFound
        }
        try await establishSession(for: user)
        return AuthResponse(success: true, message: "注册成功", user: user)
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> AuthResponse {
        guard let user = currentUser, isEmailUser(), let db = connectionProvider() else {
            throw UserServiceError.databaseNotInitialized
        }
        guard let row = try db.prepare("SELECT password_hash FROM user WHERE id = ?", [user.id]).makeIterator().next(),
              let credential = row[0] as? String else {
            throw UserServiceError.userNotFound
        }
        guard (try? credentialing.verify(password: currentPassword, storedCredential: credential)) != .invalid else {
            return AuthResponse(success: false, message: "当前密码错误", user: nil)
        }
        try db.run("UPDATE user SET password_hash = ? WHERE id = ?", [try credentialing.makeCredential(password: newPassword), user.id])
        return AuthResponse(success: true, message: "密码已更新", user: user)
    }

    func logout() async {
        try? sessionStore.clear()
        await publishLoggedOut()
    }

    func isWechatUser() -> Bool {
        currentUser?.accountType == "wechat" || currentUser?.email.hasPrefix("wechat_") == true
    }

    func isEmailUser() -> Bool {
        guard let user = currentUser else { return false }
        return user.accountType == "email" || (!user.email.hasPrefix("wechat_") && user.accountType == nil)
    }

    func isAppleUser() -> Bool {
        currentUser?.accountType == "apple"
    }

    func getUserDisplayName() -> String {
        guard let user = currentUser else { return "未知用户" }
        if !user.username.isEmpty { return user.username }
        return user.email.isEmpty ? "用户" : user.email
    }

    func loginWithWechat() async throws -> AuthResponse {
        await setLoading(true)
        defer { Task { await self.setLoading(false) } }
        let response = try await WechatLoginService.shared.simulateWechatLogin()
        guard response.success, let openID = response.openId, let nickname = response.nickname else {
            return AuthResponse(success: false, message: response.message, user: nil)
        }
        if let existingUser = try user(wechatOpenID: openID) {
            try await establishSession(for: existingUser)
            return AuthResponse(success: true, message: "微信登录成功", user: existingUser)
        }

        guard let db = connectionProvider() else { throw UserServiceError.databaseNotInitialized }
        let username = try uniqueUsername(base: nickname, database: db)
        let email = "wechat_\(openID)"
        try db.run(
            """
            INSERT INTO user (username, email, password_hash, role, is_admin, created_at, account_type, external_id, wechat_open_id)
            VALUES (?, ?, '', 'regular', 0, datetime('now'), 'wechat', ?, ?)
            """,
            [username, email, openID, openID]
        )
        guard let user = try user(wechatOpenID: openID) else { throw UserServiceError.userNotFound }
        try await establishSession(for: user)
        return AuthResponse(success: true, message: "微信登录成功", user: user)
    }

    private func establishSession(for user: User) async throws {
        do {
            try sessionStore.save(LocalSessionReference(userID: user.id))
        } catch {
            throw UserServiceError.sessionUnavailable
        }
        await publishAuthenticatedUser(user)
    }

    private func publishAuthenticatedUser(_ user: User) async {
        await MainActor.run {
            currentUser = user
            isLoggedIn = true
        }
    }

    private func publishLoggedOut() async {
        await MainActor.run {
            currentUser = nil
            isLoggedIn = false
        }
    }

    private func setLoading(_ value: Bool) async {
        await MainActor.run { isLoading = value }
    }

    private func user(id: Int) throws -> User? {
        guard let db = connectionProvider() else { throw UserServiceError.databaseNotInitialized }
        return try findUser(db, whereClause: "id = ?", value: id)
    }

    private func user(email: String) throws -> User? {
        guard let db = connectionProvider() else { throw UserServiceError.databaseNotInitialized }
        return try findUser(db, whereClause: "email = ?", value: email)
    }

    private func user(wechatOpenID: String) throws -> User? {
        guard let db = connectionProvider() else { throw UserServiceError.databaseNotInitialized }
        return try findUser(db, whereClause: "wechat_open_id = ?", value: wechatOpenID)
    }

    private func findUser(_ db: Connection, whereClause: String, value: SQLite.Binding?) throws -> User? {
        guard let row = try db.prepare(userSelectSQL + " WHERE \(whereClause)", [value]).makeIterator().next() else { return nil }
        return try makeUser(from: row)
    }

    private func exists(_ db: Connection, query: String, value: SQLite.Binding?) throws -> Bool {
        try db.prepare(query, [value]).makeIterator().next() != nil
    }

    private func makeUser(from row: [SQLite.Binding?]) throws -> User {
        guard row.count == 15 else { throw UserServiceError.queryFailed(LocalCredentialError.malformedCredential) }
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
            accountType: row[10] as? String,
            externalId: row[11] as? String,
            wechatOpenId: row[12] as? String,
            wechatUnionId: row[13] as? String,
            appleId: row[14] as? String
        )
    }

    private func convertGenderToEnglish(_ gender: String?) -> String? {
        switch gender {
        case "男": "male"
        case "女": "female"
        case "其他": "other"
        default: gender
        }
    }

    private func uniqueUsername(base: String, database: Connection) throws -> String {
        var candidate = base
        var suffix = 1
        while try exists(database, query: "SELECT 1 FROM user WHERE username = ?", value: candidate) {
            candidate = "\(base)\(suffix)"
            suffix += 1
        }
        return candidate
    }

    private let userSelectSQL = """
        SELECT id, username, email, role, gender, height, weight, created_at, is_admin, password_hash,
               account_type, external_id, wechat_open_id, wechat_union_id, apple_id
        FROM user
        """
}
