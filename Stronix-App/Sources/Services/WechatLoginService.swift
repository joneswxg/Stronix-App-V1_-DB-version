import Foundation
import SwiftUI

/// 微信登录服务类
/// 处理微信登录相关功能
class WechatLoginService: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = WechatLoginService()
    
    // MARK: - 发布属性
    @Published var isWechatLoginInProgress = false
    
    private init() {}
    
    // MARK: - 微信登录错误类型
    enum WechatLoginError: Error {
        case wechatNotInstalled
        case loginCancelled
        case loginFailed(String)
        case networkError
        case invalidResponse
        
        var localizedDescription: String {
            switch self {
            case .wechatNotInstalled:
                return "未安装微信应用"
            case .loginCancelled:
                return "用户取消登录"
            case .loginFailed(let message):
                return "登录失败: \(message)"
            case .networkError:
                return "网络连接错误"
            case .invalidResponse:
                return "服务器响应无效"
            }
        }
    }
    
    // MARK: - 微信用户信息结构
    struct WechatUserInfo {
        let openId: String
        let nickname: String
        let avatarUrl: String?
        let unionId: String?
    }
    
    // MARK: - 检查微信是否已安装
    func isWechatInstalled() -> Bool {
        // 在实际项目中，这里应该检查微信SDK的安装状态
        // 目前返回true用于演示
        return true
    }
    
    // MARK: - 微信登录主方法
    func loginWithWechat() async throws -> WechatUserInfo {
        guard isWechatInstalled() else {
            throw WechatLoginError.wechatNotInstalled
        }
        
        await MainActor.run {
            isWechatLoginInProgress = true
        }
        
        defer {
            Task { @MainActor in
                isWechatLoginInProgress = false
            }
        }
        
        // 模拟微信登录过程
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒延迟模拟网络请求
        
        // 模拟登录成功，返回用户信息
        // 在实际项目中，这里应该调用微信SDK进行真实的登录
        let fixedOpenId = "mock_openid_12345678" // 使用固定的openId用于测试
        let mockUserInfo = WechatUserInfo(
            openId: fixedOpenId,
            nickname: "张三", // 模拟真实微信昵称
            avatarUrl: "https://thirdwx.qlogo.cn/mmopen/vi_32/Q0j4TwGTfTLL1byctY955FrMQueH2c4kzlELtPnX5rM8wLGqjcqIqLfNVC8XJX1M9H1qlzJoKdcqUHkiaBEiasnw/132", // 模拟真实微信头像URL
            unionId: nil
        )
        
        print("[WechatLoginService] 微信登录成功: \(mockUserInfo.nickname)")
        return mockUserInfo
    }
    
    // MARK: - 处理微信登录回调
    func handleWechatLoginCallback(code: String) async throws -> WechatUserInfo {
        // 在实际项目中，这里应该用授权码换取access_token
        // 然后获取用户信息
        
        // 模拟网络请求
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟
        
        // 返回模拟用户信息
        return WechatUserInfo(
            openId: "openid_from_code_\(code.prefix(8))",
            nickname: "微信用户",
            avatarUrl: "https://example.com/avatar.jpg",
            unionId: "unionid_example"
        )
    }
    
    // MARK: - 登出微信
    func logoutWechat() {
        // 在实际项目中，这里应该清除微信相关的本地数据
        print("[WechatLoginService] 微信登出")
    }
}