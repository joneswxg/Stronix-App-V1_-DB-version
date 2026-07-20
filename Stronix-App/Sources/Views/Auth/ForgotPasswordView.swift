//
//  ForgotPasswordView.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/1/25.
//

import SwiftUI

struct AuthForgotPasswordView: View {
    @StateObject private var userService = LocalUserService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var currentStep: ForgotPasswordStep = .enterEmail
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    enum ForgotPasswordStep {
        case enterEmail
        case enterCode
        case resetPassword
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 标题和描述
                headerSection
                
                // 主要内容
                mainContent
                
                Spacer()
                
                // 底部按钮
                bottomButtons
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .navigationTitle("重置密码")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 头部区域
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: stepIcon)
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text(stepTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(stepDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 主要内容
    private var mainContent: some View {
        VStack(spacing: 20) {
            switch currentStep {
            case .enterEmail:
                emailInputSection
            case .enterCode:
                codeInputSection
            case .resetPassword:
                passwordInputSection
            }
        }
    }
    
    // MARK: - 邮箱输入区域
    private var emailInputSection: some View {
        VStack(spacing: 16) {
            TextField("请输入您的邮箱", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
        }
    }
    
    // MARK: - 验证码输入区域
    private var codeInputSection: some View {
        VStack(spacing: 16) {
            Text("验证码已发送到：")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(email)
                .font(.body)
                .fontWeight(.medium)
            
            TextField("请输入6位验证码", text: $verificationCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: verificationCode) { oldValue, newValue in
                    // 限制输入长度为6位
                    if newValue.count > 6 {
                        verificationCode = String(newValue.prefix(6))
                    }
                }
        }
    }
    
    // MARK: - 密码输入区域
    private var passwordInputSection: some View {
        VStack(spacing: 16) {
            SecureField("请输入新密码", text: $newPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.none)
            
            SecureField("请确认新密码", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.none)
            
            if !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - 底部按钮
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Button(action: primaryButtonAction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(primaryButtonTitle)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(primaryButtonEnabled ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!primaryButtonEnabled || isLoading)
            
            if currentStep == .enterCode {
                Button("重新发送验证码") {
                    Task {
                        await resendVerificationCode()
                    }
                }
                .foregroundColor(.blue)
            }
            
            if currentStep != .enterEmail {
                Button("返回上一步") {
                    goToPreviousStep()
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 计算属性
    private var stepIcon: String {
        switch currentStep {
        case .enterEmail:
            return "envelope"
        case .enterCode:
            return "number.circle"
        case .resetPassword:
            return "lock.rotation"
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case .enterEmail:
            return "输入邮箱地址"
        case .enterCode:
            return "输入验证码"
        case .resetPassword:
            return "设置新密码"
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case .enterEmail:
            return "请输入您注册时使用的邮箱地址，我们将向您发送密码重置验证码"
        case .enterCode:
            return "请查看您的邮箱并输入收到的6位验证码"
        case .resetPassword:
            return "请设置您的新密码，密码长度至少6位"
        }
    }
    
    private var primaryButtonTitle: String {
        switch currentStep {
        case .enterEmail:
            return "发送验证码"
        case .enterCode:
            return "验证"
        case .resetPassword:
            return "重置密码"
        }
    }
    
    private var primaryButtonEnabled: Bool {
        switch currentStep {
        case .enterEmail:
            return !email.isEmpty && EmailService.shared.isValidEmail(email)
        case .enterCode:
            return verificationCode.count == 6
        case .resetPassword:
            return !newPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
        }
    }
    
    // MARK: - 方法
    private func primaryButtonAction() {
        Task {
            switch currentStep {
            case .enterEmail:
                await sendVerificationCode()
            case .enterCode:
                await verifyCode()
            case .resetPassword:
                await resetPassword()
            }
        }
    }
    
    private func sendVerificationCode() async {
        isLoading = true
        
        do {
            let response = try await userService.sendPasswordResetCode(email: email)
            
            await MainActor.run {
                isLoading = false
                
                if response.success {
                    currentStep = .enterCode
                } else {
                    showAlert(title: "发送失败", message: response.message)
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showAlert(title: "发送失败", message: error.localizedDescription)
            }
        }
    }
    
    private func verifyCode() async {
        isLoading = true
        
        // 这里只是验证验证码格式，实际验证在重置密码时进行
        await MainActor.run {
            isLoading = false
            currentStep = .resetPassword
        }
    }
    
    private func resetPassword() async {
        isLoading = true
        
        do {
            let response = try await userService.resetPassword(
                email: email,
                verificationCode: verificationCode,
                newPassword: newPassword
            )
            
            await MainActor.run {
                isLoading = false
                
                if response.success {
                    showAlert(title: "重置成功", message: "密码重置成功，请使用新密码登录") {
                        dismiss()
                    }
                } else {
                    showAlert(title: "重置失败", message: response.message)
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                showAlert(title: "重置失败", message: error.localizedDescription)
            }
        }
    }
    
    private func resendVerificationCode() async {
        await sendVerificationCode()
    }
    
    private func goToPreviousStep() {
        switch currentStep {
        case .enterCode:
            currentStep = .enterEmail
        case .resetPassword:
            currentStep = .enterCode
        case .enterEmail:
            break
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        alertTitle = title
        alertMessage = message
        showAlert = true
        
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }
    }
}

#Preview {
    AuthForgotPasswordView()
}