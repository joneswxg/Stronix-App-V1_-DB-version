//
//  EmailService.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/1/25.
//

import Foundation
import MessageUI

/// 邮件服务类
/// 负责发送密码重置验证码邮件
class EmailService: NSObject, ObservableObject {
    
    // MARK: - 单例模式
    static let shared = EmailService()
    
    // MARK: - 发布属性
    @Published var canSendMail = false
    
    private override init() {
        super.init()
        checkMailCapability()
    }
    
    // MARK: - 检查邮件发送能力
    private func checkMailCapability() {
        canSendMail = MFMailComposeViewController.canSendMail()
        print(canSendMail ? "✅ EmailService: 设备支持发送邮件" : "❌ EmailService: 设备不支持发送邮件")
    }
    
    // MARK: - 生成验证码
    func generateVerificationCode() -> String {
        let digits = "0123456789"
        var code = ""
        for _ in 0..<6 {
            let randomIndex = Int.random(in: 0..<digits.count)
            let index = digits.index(digits.startIndex, offsetBy: randomIndex)
            code += String(digits[index])
        }
        return code
    }
    
    // MARK: - 发送密码重置验证码邮件
    func sendPasswordResetEmail(to email: String, verificationCode: String) async -> Bool {
        print("📧 EmailService: 正在发送密码重置邮件到 \(email)")
        print("🔑 验证码: \(verificationCode)")
        
        // 验证邮箱格式
        guard isValidEmail(email) else {
            print("❌ EmailService: 邮箱格式不正确")
            return false
        }
        
        // 生成邮件内容
        let emailTemplate = EmailTemplateConfig.passwordResetTemplate(verificationCode: verificationCode)
        
        do {
            // 检查阿里云配置状态
            let isConfigured = AliCloudEmailConfig.isConfigured()
            print("🔍 EmailService: 阿里云配置检查结果: \(isConfigured)")
            print("📋 EmailService: \(AliCloudEmailConfig.getConfigInfo())")
            
            // 优先使用阿里云邮件服务
            if isConfigured {
                print("📮 EmailService: 使用阿里云邮件推送服务")
                let success = try await AliCloudEmailService.shared.sendEmail(
                    to: email,
                    subject: emailTemplate.subject,
                    htmlBody: emailTemplate.htmlBody,
                    textBody: emailTemplate.textBody
                )
                
                if success {
                    print("✅ EmailService: 密码重置邮件发送成功（阿里云）")
                } else {
                    print("❌ EmailService: 密码重置邮件发送失败（阿里云）")
                }
                
                return success
            } else {
                // 如果阿里云未配置，使用本地邮件服务（需要设备支持）
                print("📱 EmailService: 阿里云未配置，尝试使用设备邮件服务")
                return await sendEmailUsingDevice(to: email, subject: emailTemplate.subject, body: emailTemplate.textBody)
            }
        } catch {
            print("❌ EmailService: 邮件发送异常 - \(error.localizedDescription)")
            print("🔍 EmailService: 异常详情 - \(error)")
            
            // 如果阿里云服务失败，尝试使用设备邮件服务作为备选
            print("🔄 EmailService: 尝试使用设备邮件服务作为备选")
            let emailTemplate = EmailTemplateConfig.passwordResetTemplate(verificationCode: verificationCode)
            return await sendEmailUsingDevice(to: email, subject: emailTemplate.subject, body: emailTemplate.textBody)
        }
    }
    
    // MARK: - 使用设备邮件服务发送邮件
    private func sendEmailUsingDevice(to email: String, subject: String, body: String) async -> Bool {
        guard canSendMail else {
            print("❌ EmailService: 设备不支持发送邮件")
            // 如果设备不支持邮件，则模拟发送（仅用于开发测试）
            return await simulateEmailSending(to: email, verificationCode: extractVerificationCode(from: body))
        }
        
        // 这里可以实现使用 MFMailComposeViewController 发送邮件的逻辑
        // 但由于这需要UI交互，在密码重置场景中不太适用
        print("⚠️ EmailService: 设备邮件服务需要用户交互，不适用于自动发送")
        
        // 作为备选，使用模拟发送
        return await simulateEmailSending(to: email, verificationCode: extractVerificationCode(from: body))
    }
    
    // MARK: - 模拟邮件发送（仅用于开发测试）
    private func simulateEmailSending(to email: String, verificationCode: String) async -> Bool {
        print("🧪 EmailService: 模拟邮件发送模式（仅用于开发测试）")
        print("📧 收件人: \(email)")
        print("🔑 验证码: \(verificationCode)")
        print("⚠️ 注意: 这是模拟发送，实际邮件不会被发送")
        print("💡 请配置阿里云邮件服务以启用真实邮件发送")
        
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        print("✅ EmailService: 模拟邮件发送完成")
        return true
    }
    
    // MARK: - 从邮件内容中提取验证码
    private func extractVerificationCode(from body: String) -> String {
        // 简单的正则表达式提取6位数字验证码
        let pattern = "验证码：(\\d{6})"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
           let range = Range(match.range(at: 1), in: body) {
            return String(body[range])
        }
        return "未知"
    }
    
    // MARK: - 验证邮箱格式
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - 邮件发送错误
enum EmailError: Error, LocalizedError {
    case deviceNotSupported
    case invalidEmail
    case sendFailed
    case networkError
    case configurationError
    case invalidURL
    case invalidResponse
    case apiError(String, String)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            return "设备不支持发送邮件"
        case .invalidEmail:
            return "邮箱格式不正确"
        case .sendFailed:
            return "邮件发送失败"
        case .networkError:
            return "网络连接错误"
        case .configurationError:
            return "阿里云邮件服务配置错误"
        case .invalidURL:
            return "无效的服务端点URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .apiError(let code, let message):
            return "API错误 \(code): \(message)"
        }
    }
}