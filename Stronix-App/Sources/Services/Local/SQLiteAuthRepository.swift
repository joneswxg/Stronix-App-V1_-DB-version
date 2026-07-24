import Foundation
import SQLite

struct AuthRegistration: Equatable {
    let username: String
    let email: String
    let password: String
    let gender: String?
    let height: Double?
    let weight: Double?
}

enum AuthError: Error, Equatable {
    case databaseUnavailable
    case invalidCredentials
    case emailAlreadyExists
    case usernameTaken
    case invalidUsername
    case invalidEmail
    case invalidPassword
    case invalidHeight
    case invalidWeight
    case sessionUnavailable
    case requestFailed
}

protocol AuthRepository {
    func register(_ registration: AuthRegistration) async throws -> User
    func authenticate(email: String, password: String) async throws -> User
    func user(id: Int) async throws -> User?
}

final class SQLiteAuthRepository: AuthRepository {
    private let connectionProvider: () -> Connection?
    private let credentialing: any PasswordCredentialing

    init(
        connectionProvider: @escaping () -> Connection? = { DatabaseManager.shared.getConnection() },
        credentialing: any PasswordCredentialing = PBKDF2PasswordCredentialing()
    ) {
        self.connectionProvider = connectionProvider
        self.credentialing = credentialing
    }

    func register(_ registration: AuthRegistration) async throws -> User {
        guard let database = connectionProvider() else { throw AuthError.databaseUnavailable }
        do {
            if try exists(database, query: "SELECT 1 FROM user WHERE email = ?", value: registration.email) {
                throw AuthError.emailAlreadyExists
            }
            if try exists(database, query: "SELECT 1 FROM user WHERE username = ?", value: registration.username) {
                throw AuthError.usernameTaken
            }

            let credential = try credentialing.makeCredential(password: registration.password)
            try database.run(
                """
                INSERT INTO user (username, email, password_hash, gender, height, weight, role, is_admin, created_at, account_type, external_id)
                VALUES (?, ?, ?, ?, ?, ?, 'regular', 0, datetime('now'), 'email', ?)
                """,
                [
                    registration.username,
                    registration.email,
                    credential,
                    convertGenderToEnglish(registration.gender),
                    registration.height,
                    registration.weight,
                    registration.email
                ]
            )
            guard let user = try findUser(database, whereClause: "email = ?", value: registration.email) else {
                throw AuthError.requestFailed
            }
            return user
        } catch let error as AuthError {
            throw error
        } catch let error as Result {
            switch error {
            case .error(_, let code, _), .extendedError(_, let code, _):
                guard code == 19 || (code & 0xFF) == 19 else { throw AuthError.requestFailed }
                if (try? exists(database, query: "SELECT 1 FROM user WHERE email = ?", value: registration.email)) == true {
                    throw AuthError.emailAlreadyExists
                }
                if (try? exists(database, query: "SELECT 1 FROM user WHERE username = ?", value: registration.username)) == true {
                    throw AuthError.usernameTaken
                }
                throw AuthError.requestFailed
            }
        } catch {
            throw AuthError.requestFailed
        }
    }

    func authenticate(email: String, password: String) async throws -> User {
        guard let database = connectionProvider() else { throw AuthError.databaseUnavailable }
        do {
            guard let row = try database.prepare(userSelectSQL + " WHERE email = ?", [email]).makeIterator().next(),
                  row.count == 15,
                  let storedCredential = row[9] as? String else {
                throw AuthError.invalidCredentials
            }

            let verification: PasswordCredentialVerification
            do {
                verification = try credentialing.verify(password: password, storedCredential: storedCredential)
            } catch {
                throw AuthError.invalidCredentials
            }
            guard verification != .invalid else { throw AuthError.invalidCredentials }

            if verification == .validLegacy {
                let upgradedCredential = try credentialing.makeCredential(password: password)
                try database.run(
                    "UPDATE user SET password_hash = ? WHERE id = ? AND password_hash = ?",
                    [upgradedCredential, row[0], storedCredential]
                )
            }
            return try makeUser(from: row)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.requestFailed
        }
    }

    func user(id: Int) async throws -> User? {
        guard let database = connectionProvider() else { throw AuthError.databaseUnavailable }
        do {
            return try findUser(database, whereClause: "id = ?", value: id)
        } catch {
            throw AuthError.requestFailed
        }
    }

    private func findUser(_ database: Connection, whereClause: String, value: SQLite.Binding?) throws -> User? {
        guard let row = try database.prepare(userSelectSQL + " WHERE \(whereClause)", [value]).makeIterator().next() else {
            return nil
        }
        return try makeUser(from: row)
    }

    private func exists(_ database: Connection, query: String, value: SQLite.Binding?) throws -> Bool {
        try database.prepare(query, [value]).makeIterator().next() != nil
    }

    private func makeUser(from row: [SQLite.Binding?]) throws -> User {
        guard row.count == 15 else { throw AuthError.requestFailed }
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

    private let userSelectSQL = """
        SELECT id, username, email, role, gender, height, weight, created_at, is_admin,
               password_hash, account_type, external_id, wechat_open_id, wechat_union_id, apple_id
        FROM user
        """
}
