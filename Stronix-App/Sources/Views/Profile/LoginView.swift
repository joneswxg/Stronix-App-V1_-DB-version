import SwiftUI
import Foundation

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localUserService = LocalUserService.shared
    @Environment(\.theme) private var theme: AppTheme
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo区域
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
                    
                    // 登录表单
                    VStack(spacing: 16) {
                        // 邮箱输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("邮箱")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.onSurface)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(theme.secondary)
                                    .frame(width: 20)
                                TextField("请输入邮箱", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            .padding()
                            .background(theme.background)
                            .cornerRadius(12)
                        }
                        
                        // 密码输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("密码")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.onSurface)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(theme.secondary)
                                    .frame(width: 20)
                                SecureField("请输入密码", text: $password)
                            }
                            .padding()
                            .background(theme.background)
                            .cornerRadius(12)
                        }
                        
                    }
                    .padding(.horizontal, 24)
                    
                    // 登录按钮
                    VStack(spacing: 16) {
                        Button(action: {
                            loginWithEmail()
                        }) {
                            HStack {
                                if localUserService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: theme.onPrimary))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("登录")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundColor(theme.onPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                (email.isEmpty || password.isEmpty || localUserService.isLoading) ? 
                                    theme.disabled.opacity(0.5) : theme.primary
                            )
                            .cornerRadius(25)
                        }
                        .disabled(email.isEmpty || password.isEmpty || localUserService.isLoading)
                        
                        // 分割线
                        HStack {
                            Rectangle()
                                .fill(theme.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text("或")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondary)
                                .padding(.horizontal, 16)
                            Rectangle()
                                .fill(theme.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        
                        // 微信登录按钮
                        Button(action: {
                            loginWithWechat()
                        }) {
                            HStack(spacing: 12) {
                                if localUserService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: theme.success))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "message.circle.fill")
                                        .foregroundColor(theme.success)
                                        .font(.system(size: 20))
                                }
                                Text(localUserService.isLoading ? "微信登录中..." : "微信登录")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.onSurface)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                localUserService.isLoading ? 
                                    theme.background.opacity(0.7) : theme.background
                            )
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(localUserService.isLoading)
                    }
                    .padding(.horizontal, 24)
                    
                    // 注册链接
                    HStack {
                        Text("还没有账号？")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                        Button(action: {
                            showRegister = true
                        }) {
                            Text("立即注册")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.primary)
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
        .alert("登录失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: localUserService.isLoggedIn) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    private func loginWithEmail() {
        Task {
            do {
                let response = try await localUserService.login(email: email, password: password)
                if !response.success {
                    await MainActor.run {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func loginWithWechat() {
        print("🚀 开始微信登录流程")
        
        Task {
            do {
                let response = try await localUserService.loginWithWechat()
                
                if !response.success {
                    await MainActor.run {
                        errorMessage = response.message
                        showError = true
                        print("❌ 微信登录失败: \(response.message)")
                    }
                } else {
                    print("✅ 微信登录成功")
                    print("🔍 检查登录状态: isLoggedIn=\(localUserService.isLoggedIn)")
                    print("🔍 当前用户: \(localUserService.currentUser?.username ?? "无")")
                    print("🔍 用户ID: \(localUserService.currentUser?.id ?? 0)")
                    
                    // 微信登录成功后自动关闭登录页面
                    await MainActor.run {
                        if localUserService.isLoggedIn {
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    print("❌ 微信登录异常: \(error)")
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
