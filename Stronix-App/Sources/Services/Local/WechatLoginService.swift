import Foundation
import SwiftUI

/// 微信登录服务
/// 处理微信登录相关功能
class WechatLoginService: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = WechatLoginService()
    
    // MARK: - 发布属性
    @Published var isWechatLoginInProgress = false
    @Published var wechatLoginError: String?
    
    // MARK: - 私有属性
    private let localUserService = LocalUserService.shared
    
    private init() {}
    
    // MARK: - 微信登录响应模型
    struct WechatLoginResponse {
        let success: Bool
        let message: String
        let openId: String?
        let unionId: String?
        let nickname: String?
    }
    
    // MARK: - 微信登录功能
    func loginWithWechat() async throws -> LocalUserService.AuthResponse {
        await MainActor.run {
            self.isWechatLoginInProgress = true
            self.wechatLoginError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isWechatLoginInProgress = false
            }
        }
        
        do {
            // 模拟微信登录流程
            let wechatResponse = try await simulateWechatLogin()
            
            if wechatResponse.success {
                // 使用微信信息创建或登录用户
                return try await handleWechatLoginSuccess(wechatResponse)
            } else {
                await MainActor.run {
                    self.wechatLoginError = wechatResponse.message
                }
                return LocalUserService.AuthResponse(
                    success: false,
                    message: wechatResponse.message,
                    user: nil
                )
            }
        } catch {
            await MainActor.run {
                self.wechatLoginError = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - 私有方法
    
    /// 模拟微信登录过程
    func simulateWechatLogin() async throws -> WechatLoginResponse {
        // 模拟网络延迟
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        // 模拟微信登录成功
        // 在实际应用中，这里会调用微信SDK
        let mockOpenId = "wx_" + UUID().uuidString.prefix(8)
        let mockUnionId = "union_" + UUID().uuidString.prefix(8)
        
        return WechatLoginResponse(
            success: true,
            message: "微信登录成功",
            openId: String(mockOpenId),
            unionId: String(mockUnionId),
            nickname: "微信用户"
        )
    }
    
    /// 处理微信登录成功后的用户创建或登录
    private func handleWechatLoginSuccess(_ wechatResponse: WechatLoginResponse) async throws -> LocalUserService.AuthResponse {
        guard let openId = wechatResponse.openId else {
            throw NSError(domain: "WechatLoginService", code: -1, userInfo: [NSLocalizedDescriptionKey: "微信OpenID获取失败"])
        }
        
        // 尝试通过微信OpenID查找现有用户
        if let existingUser = try await findUserByWechatOpenId(openId) {
            // 用户已存在，直接登录
            await MainActor.run {
                localUserService.currentUser = existingUser
                localUserService.isLoggedIn = true
            }
            
            return LocalUserService.AuthResponse(
                success: true,
                message: "微信登录成功",
                user: existingUser
            )
        } else {
            // 用户不存在，创建新用户
            return try await createUserFromWechat(wechatResponse)
        }
    }
    
    /// 通过微信OpenID查找用户
    private func findUserByWechatOpenId(_ openId: String) async throws -> User? {
        // 在实际应用中，这里会查询数据库中的微信绑定信息
        // 目前返回nil，表示用户不存在
        return nil
    }
    
    /// 从微信信息创建新用户
    private func createUserFromWechat(_ wechatResponse: WechatLoginResponse) async throws -> LocalUserService.AuthResponse {
        guard let openId = wechatResponse.openId,
              let nickname = wechatResponse.nickname else {
            throw NSError(domain: "WechatLoginService", code: -1, userInfo: [NSLocalizedDescriptionKey: "微信用户信息不完整"])
        }
        
        // 生成唯一的邮箱和用户名
        let wechatEmail = "wechat_\(openId)@stronix.app"
        let wechatUsername = "\(nickname)_\(String(openId.suffix(6)))"
        let defaultPassword = "wechat_login_\(openId)"
        
        print("🔍 创建微信用户:")
        print("  用户名: \(wechatUsername)")
        print("  邮箱: \(wechatEmail)")
        print("  OpenID: \(openId)")
        
        // 使用LocalUserService注册新用户
        let registerResponse = try await localUserService.register(
            username: wechatUsername,
            email: wechatEmail,
            password: defaultPassword
        )
        
        if registerResponse.success {
            // TODO: 在实际应用中，这里应该保存微信OpenID与用户的绑定关系
            print("✅ 微信用户创建成功")
        }
        
        return registerResponse
    }
    
    // MARK: - 公共方法
    
    /// 检查微信是否已安装
    func isWechatInstalled() -> Bool {
        // 在实际应用中，这里会检查微信是否已安装
        // 目前返回true进行模拟
        return true
    }
    
    /// 清除微信登录错误
    func clearWechatLoginError() {
        wechatLoginError = nil
    }
}

// MARK: - 微信登录错误定义
enum WechatLoginError: Error {
    case wechatNotInstalled
    case userCancelled
    case networkError
    case authFailed
    case userInfoIncomplete
    
    var localizedDescription: String {
        switch self {
        case .wechatNotInstalled:
            return "未安装微信应用"
        case .userCancelled:
            return "用户取消登录"
        case .networkError:
            return "网络连接失败"
        case .authFailed:
            return "微信授权失败"
        case .userInfoIncomplete:
            return "微信用户信息不完整"
        }
    }
}