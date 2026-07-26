import Foundation

struct AuthenticationUseCases {
    private let repository: any AuthRepository
    private let sessionStore: any LocalSessionStore
    private let legacyDefaults: UserDefaults
    private let legacySessionKey = "current_user_id"

    init(
        repository: any AuthRepository,
        sessionStore: any LocalSessionStore,
        legacyDefaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.legacyDefaults = legacyDefaults
    }

    func register(_ registration: AuthRegistration) async throws -> User {
        try Task.checkCancellation()
        let validated = try validate(registration)
        try Task.checkCancellation()
        let user = try await repository.register(validated)
        try Task.checkCancellation()
        try saveSession(for: user)
        try Task.checkCancellation()
        return user
    }

    func login(email: String, password: String) async throws -> User {
        try Task.checkCancellation()
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmedEmail), !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
        try Task.checkCancellation()
        let user = try await repository.authenticate(email: trimmedEmail, password: password)
        try Task.checkCancellation()
        try saveSession(for: user)
        try Task.checkCancellation()
        return user
    }

    func restoreSession() async throws -> User? {
        try Task.checkCancellation()
        legacyDefaults.removeObject(forKey: legacySessionKey)
        let reference: LocalSessionReference?
        do {
            reference = try sessionStore.load()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try? sessionStore.clear()
            return nil
        }
        guard let reference else { return nil }
        try Task.checkCancellation()
        do {
            guard let user = try await repository.user(id: reference.userID) else {
                try sessionStore.clear()
                return nil
            }
            try Task.checkCancellation()
            return user
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AuthError where error == .databaseUnavailable {
            throw error
        } catch {
            try? sessionStore.clear()
            return nil
        }
    }

    func logout() async throws {
        try Task.checkCancellation()
        do {
            try sessionStore.clear()
        } catch {
            throw AuthError.sessionUnavailable
        }
        try Task.checkCancellation()
    }

    private func saveSession(for user: User) throws {
        do {
            try sessionStore.save(LocalSessionReference(userID: user.id))
        } catch {
            throw AuthError.sessionUnavailable
        }
    }

    private func validate(_ registration: AuthRegistration) throws -> AuthRegistration {
        let username = registration.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = registration.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { throw AuthError.invalidUsername }
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        guard registration.password.count >= 6 else { throw AuthError.invalidPassword }
        if let height = registration.height, !(50...300).contains(height) { throw AuthError.invalidHeight }
        if let weight = registration.weight, !(10...500).contains(weight) { throw AuthError.invalidWeight }
        return AuthRegistration(
            username: username,
            email: email,
            password: registration.password,
            gender: registration.gender,
            height: registration.height,
            weight: registration.weight
        )
    }

    private func isValidEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return false }
        return !value.contains(where: { $0.isWhitespace })
    }
}
