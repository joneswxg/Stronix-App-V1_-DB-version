import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localUserService = LocalUserService.shared
    @State private var email = ""
    @State private var showSuccess = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 标题区域
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("重置密码")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("请输入您的邮箱地址，我们将发送重置密码的链接到您的邮箱")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 40)
                
                // 邮箱输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("邮箱")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                    
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        TextField("请输入注册时使用的邮箱", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(Color(white: 0.97))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                
                // 发送按钮
                Button(action: {
                    sendResetEmail()
                }) {
                    HStack {
                        if localUserService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("发送重置链接")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        (email.isEmpty || localUserService.isLoading) ? 
                            Color.gray.opacity(0.5) : Color.blue
                    )
                    .cornerRadius(25)
                }
                .disabled(email.isEmpty || localUserService.isLoading)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // 返回登录
                Button(action: {
                    dismiss()
                }) {
                    Text("返回登录")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .alert("发送成功", isPresented: $showSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text(successMessage)
        }
        .alert("发送失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sendResetEmail() {
        Task {
            do {
                let response = try await localUserService.forgotPassword(email: email)
                await MainActor.run {
                    if response.success {
                        successMessage = response.message
                        showSuccess = true
                    } else {
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
    ForgotPasswordView()
} 