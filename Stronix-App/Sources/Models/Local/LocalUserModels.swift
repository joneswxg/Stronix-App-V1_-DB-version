import Foundation
import SQLite

/// 本地用户相关数据模型
/// 迁移自 Backend-Reference/src/stronix/models/UserModel.py

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let gender: String?
    let height: Double?
    let weight: Double?
    let role: String
    let isAdmin: Bool
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, gender, height, weight, role
        case isAdmin = "is_admin"
        case createdAt = "created_at"
    }
}

// MARK: - 认证响应模型
struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let user: User?
    let token: String?
    let access_token: String?
    let refresh_token: String?
}

// MARK: - 请求模型
struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let gender: String?
    let height: Double?
    let weight: Double?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct RefreshTokenRequest: Codable {
    let refresh_token: String
}

struct RefreshTokenResponse: Codable {
    let success: Bool
    let message: String
    let access_token: String?
    let token: String?
}

// MARK: - 本地用户认证错误
enum LocalUserError: Error {
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

// TODO: 迁移User、UserProfile等模型
// TODO: 实现本地用户管理（不再需要JWT认证） 