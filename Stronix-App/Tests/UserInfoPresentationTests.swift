import XCTest
@testable import Stronix

final class UserInfoPresentationTests: XCTestCase {
    func testRowsShowReadOnlyAccountIdentityWithoutProfileMeasurements() {
        let user = User(
            id: 1,
            username: "member",
            email: "member@example.com",
            gender: "female",
            height: 168.5,
            weight: 58,
            role: "regular",
            isAdmin: false,
            createdAt: "2026-07-31 12:00:00",
            accountType: "email",
            externalId: "member@example.com",
            wechatOpenId: nil,
            wechatUnionId: nil,
            appleId: nil
        )

        let presentation = UserInfoPresentation(user: user)

        XCTAssertEqual(
            presentation.rows,
            [
                UserInfoRowPresentation(title: "用户名", value: "member"),
                UserInfoRowPresentation(title: "注册邮箱", value: "member@example.com"),
                UserInfoRowPresentation(title: "性别", value: "female")
            ]
        )
        XCTAssertFalse(presentation.rows.contains { $0.title == "身高" || $0.value == "168.5" })
        XCTAssertFalse(presentation.rows.contains { $0.title == "体重" || $0.value == "58" })
    }
}
