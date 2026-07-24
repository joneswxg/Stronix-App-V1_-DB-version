import XCTest
@testable import Stronix

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testLoginMapsInvalidCredentialsAndStopsOnlyLoginLoading() async {
        let session = AuthSessionIntentStub()
        session.loginError = AuthError.invalidCredentials
        let viewModel = AuthViewModel()
        viewModel.loginEmail = "member@example.com"
        viewModel.loginPassword = "wrong-password"

        await viewModel.login(using: session)

        XCTAssertFalse(viewModel.isLoggingIn)
        XCTAssertFalse(viewModel.isRegistering)
        XCTAssertEqual(viewModel.errorMessage, "邮箱或密码错误")
    }

    func testRegistrationRejectsMismatchedPasswordsBeforeSubmitting() async {
        let session = AuthSessionIntentStub()
        let viewModel = AuthViewModel()
        viewModel.registrationUsername = "member"
        viewModel.registrationEmail = "member@example.com"
        viewModel.registrationPassword = "secure-password"
        viewModel.registrationConfirmation = "different-password"
        viewModel.agreesToTerms = true

        await viewModel.register(using: session)

        XCTAssertEqual(session.registerCallCount, 0)
        XCTAssertEqual(viewModel.errorMessage, "两次输入的密码不一致")
    }
}

@MainActor
private final class AuthSessionIntentStub: AuthSessionIntending {
    var loginError: Error?
    var registerCallCount = 0

    func login(email: String, password: String) async throws {
        if let loginError { throw loginError }
    }

    func register(_ registration: AuthRegistration) async throws {
        registerCallCount += 1
    }
}
