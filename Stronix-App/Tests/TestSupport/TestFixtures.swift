import Foundation
import SQLite
@testable import Stronix

struct TestUserFixture {
    let username: String
    let email: String
    var passwordHash = "test-hash"
    var createdAt = "2026-07-22T00:00:00Z"

    @discardableResult
    func insert(into connection: Connection) throws -> User {
        try connection.run(
            """
            INSERT INTO user (
                username, email, password_hash, role, is_admin, created_at,
                account_type, external_id
            ) VALUES (?, ?, ?, 'regular', 0, ?, 'email', ?)
            """,
            username,
            email,
            passwordHash,
            createdAt,
            email
        )
        return User(
            id: Int(connection.lastInsertRowid),
            username: username,
            email: email,
            gender: nil,
            height: nil,
            weight: nil,
            role: "regular",
            isAdmin: false,
            createdAt: createdAt,
            accountType: "email",
            externalId: email,
            wechatOpenId: nil,
            wechatUnionId: nil,
            appleId: nil
        )
    }
}

final class TestCurrentUser: CurrentUserProviding {
    var user: User?
    var id: Int?

    init(user: User? = nil) {
        self.user = user
        id = user?.id
    }

    convenience init(id: Int?) {
        self.init()
        self.id = id
    }

    var currentUser: User? { user }
    var currentUserID: Int? { id }
}

final class TestUserDefaultsFixture {
    let suiteName: String
    let defaults: UserDefaults

    init() {
        suiteName = "StronixTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
