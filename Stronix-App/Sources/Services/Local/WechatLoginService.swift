import Foundation

final class WechatLoginService {
    static let shared = WechatLoginService()

    struct WechatLoginResponse {
        let success: Bool
        let message: String
        let openId: String?
        let unionId: String?
        let nickname: String?
    }

    private init() {}

    func simulateWechatLogin() async throws -> WechatLoginResponse {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return WechatLoginResponse(
            success: true,
            message: "微信登录成功",
            openId: "wx_test_user_12345678",
            unionId: "union_test_user_87654321",
            nickname: "微信测试用户"
        )
    }
}
