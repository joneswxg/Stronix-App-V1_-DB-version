import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.theme) private var theme: AppTheme
    @StateObject private var viewModel = AuthViewModel()
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image("StronixLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                        Text("STRONIX")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(theme.onSurface)
                        Text("欢迎回来")
                            .font(.system(size: 16))
                            .foregroundColor(theme.secondary)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        authField(title: "邮箱", icon: "envelope") {
                            TextField("请输入邮箱", text: $viewModel.loginEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        authField(title: "密码", icon: "lock") {
                            SecureField("请输入密码", text: $viewModel.loginPassword)
                        }
                    }
                    .padding(.horizontal, 24)

                    Button {
                        Task { await viewModel.login(using: userSession) }
                    } label: {
                        HStack {
                            if viewModel.isLoggingIn {
                                ProgressView()
                                    .tint(theme.onPrimary)
                            } else {
                                Text("登录")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .foregroundColor(theme.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(viewModel.canLogin ? theme.primary : theme.disabled.opacity(0.5))
                        .cornerRadius(25)
                    }
                    .disabled(!viewModel.canLogin)
                    .padding(.horizontal, 24)

                    Button("忘记密码？") {
                        showForgotPassword = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primary)

                    HStack {
                        Text("还没有账号？")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                        Button("立即注册") { showRegister = true }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.primary)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(userSession)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .alert("登录失败", isPresented: errorBinding) {
            Button("确定", role: .cancel) { viewModel.errorMessage = nil }
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

    private func authField<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.onSurface)
            HStack {
                Image(systemName: icon)
                    .foregroundColor(theme.secondary)
                    .frame(width: 20)
                content()
            }
            .padding()
            .background(theme.background)
            .cornerRadius(12)
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "lock.slash")
                    .font(.system(size: 48))
                    .foregroundColor(theme.secondary)
                Text("暂不支持密码重置")
                    .font(.title3.bold())
                    .foregroundColor(theme.onSurface)
                Text("此设备上的本地账户暂不支持密码重置。请使用原密码登录或联系支持人员。")
                    .foregroundColor(theme.secondary)
                    .multilineTextAlignment(.center)
                Button("返回登录") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
        }
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
}
