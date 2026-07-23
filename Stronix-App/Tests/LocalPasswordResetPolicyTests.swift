import XCTest
@testable import Stronix

final class LocalPasswordResetPolicyTests: XCTestCase {
    func testSendingPasswordResetCodeIsUnavailableForEveryEmailInput() async throws {
        for email in ["member@example.com", "not-an-email", ""] {
            let response = try await LocalUserService.shared.sendPasswordResetCode(email: email)

            XCTAssertFalse(response.success)
            XCTAssertNil(response.user)
            XCTAssertEqual(response.message, "此设备上的本地账户暂不支持密码重置。请使用原密码登录或联系支持人员。")
        }
    }

    func testResettingPasswordIsUnavailableWithoutChangingAccountState() async throws {
        let response = try await LocalUserService.shared.resetPassword(
            email: "member@example.com",
            verificationCode: "123456",
            newPassword: "new-password"
        )

        XCTAssertFalse(response.success)
        XCTAssertNil(response.user)
        XCTAssertEqual(response.message, "此设备上的本地账户暂不支持密码重置。请使用原密码登录或联系支持人员。")
    }
}
