import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xLarge) {
                    VStack(spacing: DesignTokens.Spacing.large) {
                        Image("StronixLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 80)
                            .accessibilityHidden(true)
                        Text("STRONIX")
                            .font(DesignTokens.Typography.screenTitle)
                        Text("auth.login.subtitle")
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, DesignTokens.Spacing.xxLarge)

                    VStack(spacing: DesignTokens.Spacing.large) {
                        AuthTextField(
                            text: $viewModel.loginEmail,
                            label: "auth.field.email.label",
                            placeholder: "auth.field.email.placeholder",
                            symbol: "envelope",
                            kind: .email
                        )
                        AuthTextField(
                            text: $viewModel.loginPassword,
                            label: "auth.field.password.label",
                            placeholder: "auth.field.password.placeholder",
                            symbol: "lock",
                            kind: .password
                        )
                    }

                    AuthActionButton(
                        title: "auth.action.login",
                        loadingTitle: "auth.login.loading",
                        style: .primary,
                        isEnabled: viewModel.canLogin,
                        isLoading: viewModel.isLoggingIn
                    ) {
                        Task { await viewModel.login(using: userSession) }
                    }

                    AuthActionButton(
                        title: "auth.login.forgotPassword",
                        loadingTitle: "auth.login.forgotPassword",
                        style: .secondary,
                        isEnabled: true,
                        isLoading: false,
                        action: { showForgotPassword = true }
                    )

                    HStack(spacing: DesignTokens.Spacing.small) {
                        Text("auth.login.noAccount")
                            .foregroundStyle(.secondary)
                        Button("auth.action.registerNow") { showRegister = true }
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.bottom, DesignTokens.Spacing.xLarge)
                }
                .padding(.horizontal, DesignTokens.Spacing.xLarge)
            }
            .background { DesignTokenBackground() }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(userSession)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .alert("auth.feedback.loginFailed", isPresented: errorBinding) {
            Button("auth.action.confirm", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: userSession.isAuthenticated) { _, authenticated in
            if authenticated { dismiss() }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignTokens.Spacing.xLarge) {
                Image(systemName: "lock.slash")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text("auth.forgotPassword.unavailable")
                    .font(.title3.bold())
                Text("auth.forgotPassword.message")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                AuthActionButton(
                    title: "auth.action.backToLogin",
                    loadingTitle: "auth.action.backToLogin",
                    style: .primary,
                    isEnabled: true,
                    isLoading: false,
                    action: { dismiss() }
                )
            }
            .padding(DesignTokens.Spacing.xLarge)
            .background { DesignTokenBackground() }
            .navigationTitle("auth.forgotPassword.title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DesignTokenBackground: View {
    @Environment(\.designTokens) private var tokens

    var body: some View {
        tokens.canvas.ignoresSafeArea()
    }
}

#Preview {
    LoginView()
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
