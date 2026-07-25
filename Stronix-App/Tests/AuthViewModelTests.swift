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
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("auth.error.invalidCredentials"))
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
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("auth.validation.passwordMismatch"))
    }

    func testRegistrationRequiresTermsBeforeSubmitting() async {
        let session = AuthSessionIntentStub()
        let viewModel = validRegistrationViewModel()
        viewModel.agreesToTerms = false

        await viewModel.register(using: session)

        XCTAssertEqual(session.registerCallCount, 0)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("auth.validation.termsRequired"))
    }

    func testRegistrationRejectsInvalidOptionalHeightBeforeSubmitting() async {
        let session = AuthSessionIntentStub()
        let viewModel = validRegistrationViewModel()
        viewModel.registrationHeight = "not-a-number"

        await viewModel.register(using: session)

        XCTAssertEqual(session.registerCallCount, 0)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("auth.error.invalidHeight"))
    }

    func testRegistrationPassesUnchangedPayloadToSession() async {
        let session = AuthSessionIntentStub()
        let viewModel = validRegistrationViewModel()
        viewModel.registrationGender = "女"
        viewModel.registrationHeight = "168.5"
        viewModel.registrationWeight = "58"

        await viewModel.register(using: session)

        XCTAssertEqual(session.registerCallCount, 1)
        XCTAssertEqual(
            session.registration,
            AuthRegistration(
                username: "member",
                email: "member@example.com",
                password: "secure-password",
                gender: "女",
                height: 168.5,
                weight: 58
            )
        )
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isRegistering)
    }

    private func validRegistrationViewModel() -> AuthViewModel {
        let viewModel = AuthViewModel()
        viewModel.registrationUsername = "member"
        viewModel.registrationEmail = "member@example.com"
        viewModel.registrationPassword = "secure-password"
        viewModel.registrationConfirmation = "secure-password"
        viewModel.agreesToTerms = true
        return viewModel
    }
}

@MainActor
private final class AuthSessionIntentStub: AuthSessionIntending {
    var loginError: Error?
    var registerCallCount = 0
    var registration: AuthRegistration?

    func login(email: String, password: String) async throws {
        if let loginError { throw loginError }
    }

    func register(_ registration: AuthRegistration) async throws {
        registerCallCount += 1
        self.registration = registration
    }
}
