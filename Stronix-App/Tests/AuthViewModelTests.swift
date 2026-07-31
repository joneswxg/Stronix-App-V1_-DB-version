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

    func testRegistrationSubmitsAccountFieldsWithoutProfileMeasurements() async {
        let session = AuthSessionIntentStub()
        let viewModel = validRegistrationViewModel()
        viewModel.registrationGender = "女"

        await viewModel.register(using: session)

        XCTAssertEqual(session.registerCallCount, 1)
        XCTAssertEqual(
            session.registration,
            AuthRegistration(
                username: "member",
                email: "member@example.com",
                password: "secure-password",
                gender: "女",
                height: nil,
                weight: nil
            )
        )
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isRegistering)
    }

    func testRegistrationEligibilityUsesOnlyAccountFieldsAndTerms() {
        let viewModel = validRegistrationViewModel()

        XCTAssertTrue(viewModel.canRegister)
    }

    func testRegistrationMapsDuplicateAndPersistenceFailuresToSafeMessages() async {
        let scenarios: [(AuthError, String)] = [
            (.emailAlreadyExists, AppStrings.text("auth.error.emailAlreadyExists")),
            (.sessionUnavailable, AppStrings.text("auth.error.sessionUnavailable"))
        ]

        for (error, expectedMessage) in scenarios {
            let session = AuthSessionIntentStub()
            session.registerError = error
            let viewModel = validRegistrationViewModel()

            await viewModel.register(using: session)

            XCTAssertEqual(viewModel.errorMessage, expectedMessage)
            XCTAssertFalse(viewModel.isRegistering)
            XCTAssertFalse(viewModel.errorMessage?.contains("password") ?? true)
            XCTAssertFalse(viewModel.errorMessage?.contains("SQLite") ?? true)
            XCTAssertFalse(viewModel.errorMessage?.contains("Keychain") ?? true)
        }
    }

    func testLogoutMapsPersistenceFailure() async {
        let session = AuthSessionIntentStub()
        session.logoutError = AuthError.sessionUnavailable
        let viewModel = AuthViewModel()

        await viewModel.logout(using: session)
        await viewModel.logout(using: session)

        XCTAssertEqual(session.logoutCallCount, 2)
        XCTAssertFalse(viewModel.isLoggingOut)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("auth.error.sessionUnavailable"))
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
    var registerError: Error?
    var logoutError: Error?
    var registerCallCount = 0
    var logoutCallCount = 0
    var registration: AuthRegistration?

    func login(email: String, password: String) async throws {
        if let loginError { throw loginError }
    }

    func register(_ registration: AuthRegistration) async throws {
        registerCallCount += 1
        self.registration = registration
        if let registerError { throw registerError }
    }

    func logout() async throws {
        logoutCallCount += 1
        if let logoutError { throw logoutError }
    }
}
