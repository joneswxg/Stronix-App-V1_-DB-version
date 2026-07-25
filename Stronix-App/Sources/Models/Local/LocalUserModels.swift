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
    
    // 新增：多种登录方式支持字段
    let accountType: String?        // 账户类型：'email', 'wechat', 'apple'
    let externalId: String?         // 外部ID（统一存储第三方平台ID）
    let wechatOpenId: String?       // 微信OpenID
    let wechatUnionId: String?      // 微信UnionID
    let appleId: String?            // Apple ID
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, gender, height, weight, role
        case isAdmin = "is_admin"
        case createdAt = "created_at"
        case accountType = "account_type"
        case externalId = "external_id"
        case wechatOpenId = "wechat_open_id"
        case wechatUnionId = "wechat_union_id"
        case appleId = "apple_id"
    }
}

// TODO: 迁移User、UserProfile等模型
// TODO: 实现本地用户管理（不再需要JWT认证）