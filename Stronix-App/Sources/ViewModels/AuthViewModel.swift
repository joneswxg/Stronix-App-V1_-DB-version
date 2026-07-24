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
            errorMessage = "两次输入的密码不一致"
            return
        }
        guard agreesToTerms else {
            errorMessage = "请先阅读并同意用户协议和隐私政策"
            return
        }
        guard canRegister else {
            errorMessage = "请检查注册信息后重试"
            return
        }
        isRegistering = true
        defer { isRegistering = false }

        guard let height = optionalNumber(registrationHeight) else {
            errorMessage = "请输入有效的身高"
            return
        }
        guard let weight = optionalNumber(registrationWeight) else {
            errorMessage = "请输入有效的体重"
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
            return "暂时无法完成请求，请稍后重试"
        }
        return switch authError {
        case .invalidCredentials: "邮箱或密码错误"
        case .emailAlreadyExists: "邮箱已被注册"
        case .usernameTaken: "用户名已被使用"
        case .invalidUsername: "请输入有效的用户名"
        case .invalidEmail: "请输入有效的邮箱"
        case .invalidPassword: "密码至少需要 6 位"
        case .invalidHeight: "请输入有效的身高"
        case .invalidWeight: "请输入有效的体重"
        case .sessionUnavailable: "无法安全保存登录状态，请重试"
        case .databaseUnavailable, .requestFailed: "暂时无法完成请求，请稍后重试"
        }
    }
}
