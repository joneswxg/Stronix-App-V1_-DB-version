import Foundation

@MainActor
protocol AuthSessionIntending: AnyObject {
    func login(email: String, password: String) async throws
    func register(_ registration: AuthRegistration) async throws
}

extension UserSession: AuthSessionIntending {}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var loginEmail = ""
    @Published var loginPassword = ""
    @Published var registrationUsername = ""
    @Published var registrationEmail = ""
    @Published var registrationPassword = ""
    @Published var registrationConfirmation = ""
    @Published var registrationGender = "男"
    @Published var registrationHeight = ""
    @Published var registrationWeight = ""
    @Published var agreesToTerms = false
    @Published private(set) var isLoggingIn = false
    @Published private(set) var isRegistering = false
    @Published var errorMessage: String?

    var canLogin: Bool {
        !loginEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !loginPassword.isEmpty &&
        !isLoggingIn
    }

    var canRegister: Bool {
        !registrationUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !registrationEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        registrationPassword.count >= 6 &&
        registrationPassword == registrationConfirmation &&
        agreesToTerms &&
        !isRegistering
    }

    func login(using session: any AuthSessionIntending) async {
        guard canLogin else { return }
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }
        do {
            try await session.login(email: loginEmail, password: loginPassword)
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    func register(using session: any AuthSessionIntending) async {
        errorMessage = nil
        guard registrationPassword == registrationConfirmation else {
            errorMessage = AppStrings.text("auth.validation.passwordMismatch")
            return
        }
        guard agreesToTerms else {
            errorMessage = AppStrings.text("auth.validation.termsRequired")
            return
        }
        guard canRegister else {
            errorMessage = AppStrings.text("auth.validation.checkRegistration")
            return
        }
        isRegistering = true
        defer { isRegistering = false }

        guard let height = optionalNumber(registrationHeight) else {
            errorMessage = AppStrings.text("auth.error.invalidHeight")
            return
        }
        guard let weight = optionalNumber(registrationWeight) else {
            errorMessage = AppStrings.text("auth.error.invalidWeight")
            return
        }
        do {
            try await session.register(
                AuthRegistration(
                    username: registrationUsername,
                    email: registrationEmail,
                    password: registrationPassword,
                    gender: registrationGender,
                    height: height,
                    weight: weight
                )
            )
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    private func optionalNumber(_ value: String) -> Double?? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .some(nil) }
        guard let number = Double(trimmed) else { return nil }
        return .some(number)
    }

    private func userMessage(for error: Error) -> String {
        guard let authError = error as? AuthError else {
            return AppStrings.text("auth.error.generic")
        }
        return switch authError {
        case .invalidCredentials: AppStrings.text("auth.error.invalidCredentials")
        case .emailAlreadyExists: AppStrings.text("auth.error.emailAlreadyExists")
        case .usernameTaken: AppStrings.text("auth.error.usernameTaken")
        case .invalidUsername: AppStrings.text("auth.error.invalidUsername")
        case .invalidEmail: AppStrings.text("auth.error.invalidEmail")
        case .invalidPassword: AppStrings.text("auth.error.invalidPassword")
        case .invalidHeight: AppStrings.text("auth.error.invalidHeight")
        case .invalidWeight: AppStrings.text("auth.error.invalidWeight")
        case .sessionUnavailable: AppStrings.text("auth.error.sessionUnavailable")
        case .databaseUnavailable, .requestFailed: AppStrings.text("auth.error.generic")
        }
    }
}
