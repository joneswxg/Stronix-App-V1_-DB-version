import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showError = false

    private let genderOptions = ["男", "女", "其他"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xLarge) {
                    header
                    form
                    AuthActionButton(
                        title: "auth.action.register",
                        loadingTitle: "auth.register.loading",
                        style: .primary,
                        isEnabled: viewModel.canRegister,
                        isLoading: viewModel.isRegistering,
                        action: registerUser
                    )
                    loginLink
                }
                .padding(.horizontal, DesignTokens.Spacing.xLarge)
                .padding(.bottom, DesignTokens.Spacing.xLarge)
            }
            .background { DesignTokenBackground() }
            .navigationTitle("auth.action.register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("auth.action.cancel") { dismiss() }
                }
            }
        }
        .alert("auth.feedback.registerFailed", isPresented: $showError) {
            Button("auth.action.confirm", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? AppStrings.text("auth.error.generic"))
        }
        .onChange(of: userSession.isAuthenticated) { _, authenticated in
            if authenticated { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            Image("StronixLogo")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 60)
                .accessibilityHidden(true)
            Text("auth.register.title")
                .font(DesignTokens.Typography.pageTitle)
            Text("auth.register.subtitle")
                .font(DesignTokens.Typography.supporting)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignTokens.Spacing.large)
    }

    private var form: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            AuthTextField(text: $viewModel.registrationUsername, label: "auth.field.username.label", placeholder: "auth.field.username.placeholder", symbol: "person")
            AuthTextField(text: $viewModel.registrationEmail, label: "auth.field.email.label", placeholder: "auth.field.email.placeholder", symbol: "envelope", kind: .email)
            AuthTextField(text: $viewModel.registrationPassword, label: "auth.field.password.label", placeholder: "auth.field.passwordRegistration.placeholder", symbol: "lock", kind: .password)
            AuthTextField(
                text: $viewModel.registrationConfirmation,
                label: "auth.field.passwordConfirmation.label",
                placeholder: "auth.field.passwordConfirmation.placeholder",
                symbol: "lock",
                kind: .password,
                error: passwordsMismatch ? "auth.feedback.passwordMismatch" : nil
            )
            genderPicker
            measurements
            termsAgreement
        }
    }

    private var passwordsMismatch: Bool {
        !viewModel.registrationPassword.isEmpty &&
            !viewModel.registrationConfirmation.isEmpty &&
            viewModel.registrationPassword != viewModel.registrationConfirmation
    }

    private var genderPicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("auth.field.gender")
                .font(.subheadline.weight(.medium))
            ForEach(genderOptions, id: \.self) { option in
                Button {
                    viewModel.registrationGender = option
                } label: {
                    HStack {
                        Image(systemName: viewModel.registrationGender == option ? "largecircle.fill.circle" : "circle")
                            .accessibilityHidden(true)
                        Text(genderLabel(for: option))
                        Spacer()
                    }
                    .frame(minHeight: DesignTokens.Metric.minimumTapSize)
                }
                .accessibilityLabel(genderLabel(for: option))
                .accessibilityValue(viewModel.registrationGender == option ? Text("auth.accessibility.selected") : Text("auth.accessibility.unselected"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("auth.field.gender")
    }

    @ViewBuilder
    private var measurements: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: DesignTokens.Spacing.large) {
                heightField
                weightField
            }
        } else {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
                heightField
                weightField
            }
        }
    }

    private var heightField: some View {
        AuthTextField(text: $viewModel.registrationHeight, label: "auth.field.height.label", placeholder: "auth.field.height.placeholder", symbol: "ruler", kind: .number)
    }

    private var weightField: some View {
        AuthTextField(text: $viewModel.registrationWeight, label: "auth.field.weight.label", placeholder: "auth.field.weight.placeholder", symbol: "scalemass", kind: .number)
    }

    private var termsAgreement: some View {
        Toggle(isOn: $viewModel.agreesToTerms) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                Text("auth.register.agreement")
                HStack(spacing: DesignTokens.Spacing.xSmall) {
                    Button("auth.register.terms") { }
                    Text("auth.register.termsConnector")
                    Button("auth.register.privacyPolicy") { }
                }
                .font(.footnote)
            }
        }
        .accessibilityHint("auth.accessibility.registrationReady")
    }

    private var loginLink: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Text("auth.register.alreadyHaveAccount")
                .foregroundStyle(.secondary)
            Button("auth.action.loginNow") { dismiss() }
                .fontWeight(.semibold)
        }
        .font(DesignTokens.Typography.supporting)
    }

    private func genderLabel(for option: String) -> LocalizedStringKey {
        switch option {
        case "男": "auth.gender.male"
        case "女": "auth.gender.female"
        default: "auth.gender.other"
        }
    }

    private func registerUser() {
        Task {
            await viewModel.register(using: userSession)
            showError = viewModel.errorMessage != nil
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(
            UserSession(
                operations: AuthenticationUseCases(
                    repository: SQLiteAuthRepository(),
                    sessionStore: InMemoryLocalSessionStore()
                )
            )
        )
        .withAppTheme()
}
