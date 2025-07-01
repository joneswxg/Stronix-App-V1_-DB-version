import SwiftUI
import Foundation

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localUserService = LocalUserService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false
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
                            .foregroundColor(.black)
                        
                        Text("欢迎回来")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // 登录表单
                    VStack(spacing: 16) {
                        // 邮箱输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("邮箱")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                TextField("请输入邮箱", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            .padding()
                            .background(Color(white: 0.97))
                            .cornerRadius(12)
                        }
                        
                        // 密码输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("密码")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                SecureField("请输入密码", text: $password)
                            }
                            .padding()
                            .background(Color(white: 0.97))
                            .cornerRadius(12)
                        }
                        
                        // 忘记密码
                        HStack {
                            Spacer()
                            Button(action: {
                                showForgotPassword = true
                            }) {
                                Text("忘记密码？")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
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
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("登录")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                (email.isEmpty || password.isEmpty || localUserService.isLoading) ? 
                                    Color.gray.opacity(0.5) : Color.blue
                            )
                            .cornerRadius(25)
                        }
                        .disabled(email.isEmpty || password.isEmpty || localUserService.isLoading)
                        
                        // 分割线
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("或")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        
                        // 微信登录按钮
                        Button(action: {
                            loginWithWechat()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "message.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                                Text("微信登录")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(white: 0.97))
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 注册链接
                    HStack {
                        Text("还没有账号？")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Button(action: {
                            showRegister = true
                        }) {
                            Text("立即注册")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 20)
                    
                    // 测试账户提示
                    VStack(spacing: 8) {
                        Text("测试账户")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 4) {
                            Text("邮箱: iostest@example.com")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text("密码: password123")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {
                            email = "iostest@example.com"
                            password = "password123"
                        }) {
                            Text("使用测试账户")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
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
        print("🚀 开始本地登录流程")
        print("📧 邮箱: \(email)")
        print("🔒 密码长度: \(password.count)")
        
        // 先调试检查数据库
        localUserService.debugCheckDatabase()
        
        Task {
            do {
                print("🗄️ 检查本地数据库...")
                let response = try await localUserService.login(email: email, password: password)
                print("📨 收到登录响应: success=\(response.success), message=\(response.message)")
                
                if !response.success {
                    await MainActor.run {
                        errorMessage = response.message
                        showError = true
                        print("❌ 登录失败: \(response.message)")
                    }
                } else {
                    print("✅ 本地登录成功")
                    print("🔍 检查登录状态: isLoggedIn=\(localUserService.isLoggedIn)")
                    print("🔍 当前用户: \(localUserService.currentUser?.username ?? "无")")
                    print("🔍 用户ID: \(localUserService.currentUser?.id ?? 0)")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    print("❌ 登录异常: \(error)")
                }
            }
        }
    }
    
    private func loginWithWechat() {
        // TODO: 实现微信登录逻辑
        print("微信登录")
    }
}

#Preview {
    LoginView()
} 