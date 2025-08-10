import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userService = LocalUserService.shared
    @Environment(\.theme) private var theme: AppTheme
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var gender = "男"
    @State private var height = ""
    @State private var weight = ""
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var agreeToTerms = false
    
    private let genderOptions = ["男", "女", "其他"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 标题区域
                    VStack(spacing: 16) {
                        Image("StronixLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                        
                        Text("创建账号")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(theme.onSurface)
                        
                        Text("加入STRONIX，开始您的健身之旅")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                    }
                    .padding(.top, 20)
                    
                    // 注册表单
                    VStack(spacing: 16) {
                        // 用户名
                        VStack(alignment: .leading, spacing: 8) {
                            Text("用户名")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.onSurface)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(theme.secondary)
                                    .frame(width: 20)
                                TextField("请输入用户名", text: $username)
                            }
                            .padding()
                            .background(theme.background)
                            .cornerRadius(12)
                        }
                        
                        // 邮箱
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
                        
                        // 密码
                        VStack(alignment: .leading, spacing: 8) {
                            Text("密码")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.onSurface)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(theme.secondary)
                                    .frame(width: 20)
                                SecureField("请输入密码（至少6位）", text: $password)
                            }
                            .padding()
                            .background(theme.background)
                            .cornerRadius(12)
                        }
                        
                        // 确认密码
                        VStack(alignment: .leading, spacing: 8) {
                            Text("确认密码")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.onSurface)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(theme.secondary)
                                    .frame(width: 20)
                                SecureField("请再次输入密码", text: $confirmPassword)
                            }
                            .padding()
                            .background(theme.background)
                            .cornerRadius(12)
                            
                            if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                                Text("密码不匹配")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.error)
                                    .padding(.top, 5)
                            }
                        }
                        
                        // 性别选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("性别")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.onSurface)
                            
                            HStack(spacing: 12) {
                                ForEach(genderOptions, id: \.self) { option in
                                    Button(action: {
                                        gender = option
                                    }) {
                                        HStack {
                                            Image(systemName: gender == option ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(gender == option ? theme.primary : theme.secondary)
                                            Text(option)
                                                .font(.system(size: 14))
                                                .foregroundColor(gender == option ? theme.primary : theme.onSurface)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            gender == option ? 
                                                theme.primary.opacity(0.1) : 
                                                theme.background
                                        )
                                        .cornerRadius(20)
                                    }
                                }
                                Spacer()
                            }
                        }
                        
                        // 身高体重
                        HStack(spacing: 12) {
                            // 身高
                            VStack(alignment: .leading, spacing: 8) {
                                Text("身高 (cm)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.onSurface)
                                
                                HStack {
                                    Image(systemName: "ruler")
                                        .foregroundColor(theme.secondary)
                                        .frame(width: 20)
                                    TextField("170", text: $height)
                                        .keyboardType(.numberPad)
                                }
                                .padding()
                                .background(theme.background)
                                .cornerRadius(12)
                            }
                            
                            // 体重
                            VStack(alignment: .leading, spacing: 8) {
                                Text("体重 (kg)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(theme.onSurface)
                                
                                HStack {
                                    Image(systemName: "scalemass")
                                        .foregroundColor(theme.secondary)
                                        .frame(width: 20)
                                    TextField("70", text: $weight)
                                        .keyboardType(.numberPad)
                                }
                                .padding()
                                .background(theme.background)
                                .cornerRadius(12)
                            }
                        }
                        
                        // 服务条款
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                agreeToTerms.toggle()
                            }) {
                                Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(agreeToTerms ? theme.primary : theme.secondary)
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("我已阅读并同意")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.onSurface)
                                HStack(spacing: 4) {
                                    Button("《用户协议》") {
                                        // TODO: 显示用户协议
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.primary)
                                    
                                    Text("和")
                                        .font(.system(size: 14))
                                        .foregroundColor(theme.onSurface)
                                    
                                    Button("《隐私政策》") {
                                        // TODO: 显示隐私政策
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.primary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // 注册按钮
                    Button(action: {
                        registerUser()
                    }) {
                        HStack {
                            if userService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("注册")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.onPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            isFormValid ? theme.primary : theme.secondary.opacity(0.5)
                        )
                        .cornerRadius(25)
                    }
                    .disabled(!isFormValid || userService.isLoading)
                    .padding(.horizontal, 24)
                    
                    // 登录链接
                    HStack {
                        Text("已有账号？")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                        Button(action: {
                            dismiss()
                        }) {
                            Text("立即登录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.primary)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .alert("注册失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: userService.isLoggedIn) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    private var isFormValid: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        agreeToTerms
    }
    
    private func registerUser() {
        Task {
            do {
                let response = try await userService.register(
                    username: username,
                    email: email,
                    password: password,
                    gender: gender,
                    height: height.isEmpty ? nil : height,
                    weight: weight.isEmpty ? nil : weight
                )
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
}

#Preview {
    RegisterView()
        .environment(\.theme, BlueTheme())
}