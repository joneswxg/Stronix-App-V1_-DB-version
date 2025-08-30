//
//  EmailConfig.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/1/25.
//

import Foundation

/// 阿里云邮件推送服务配置
struct AliCloudEmailConfig {
    
    // MARK: - 阿里云邮件推送配置
    // 请在这里填入您的阿里云邮件推送服务配置信息
    
    /// 阿里云 Access Key ID
    static let accessKeyId = "LTAI5tNvnkhckz57CKS1bH1e"
    
    /// 阿里云 Access Key Secret
    static let accessKeySecret = "WM7Yn1JNmaDwygtrOQP7AxXmw1uWwf"
    
    /// 阿里云邮件推送服务地域
    static let region = "cn-hangzhou" // 或其他地域，如 cn-beijing, cn-shanghai
    
    /// 发件人邮箱地址（必须是已验证的域名邮箱）
    static let fromEmail = "passwordreset@mail.stronix.tech"
    
    /// 发件人名称
    static let fromName = "Stronix Tech"
    
    /// 邮件推送服务端点
    static let endpoint: String = {
        switch region {
        case "cn-hangzhou":
            return "https://dm.aliyuncs.com" // 华东1（杭州）地区的正确端点
        case "ap-southeast-1":
            return "https://dm.ap-southeast-1.aliyuncs.com"
        case "ap-southeast-2":
            return "https://dm.ap-southeast-2.aliyuncs.com"
        case "us-east-1":
            return "https://dm.us-east-1.aliyuncs.com"
        case "eu-central-1":
            return "https://dm.eu-central-1.aliyuncs.com"
        default:
            return "https://dm.aliyuncs.com" // 默认使用杭州地区
        }
    }()
    
    // MARK: - 验证配置
    static func isConfigured() -> Bool {
        return !accessKeyId.contains("YOUR_") && 
               !accessKeySecret.contains("YOUR_") &&
               !fromEmail.contains("yourdomain")
    }
    
    // MARK: - 获取配置信息
    static func getConfigInfo() -> String {
        return """
        阿里云邮件推送配置信息：
        - Region: \(region)
        - Endpoint: \(endpoint)
        - From Email: \(fromEmail)
        - From Name: \(fromName)
        - 配置状态: \(isConfigured() ? "已配置" : "未配置")
        """
    }
}

/// 邮件模板配置
struct EmailTemplateConfig {
    
    // MARK: - 密码重置邮件模板
    static func passwordResetTemplate(verificationCode: String) -> (subject: String, htmlBody: String, textBody: String) {
        let subject = "Stronix - 密码重置验证码"
        
        let htmlBody = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>密码重置验证码</title>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background-color: #007AFF; color: white; padding: 20px; text-align: center; }
                .content { padding: 30px; background-color: #f9f9f9; }
                .code { font-size: 24px; font-weight: bold; color: #007AFF; text-align: center; padding: 20px; background-color: white; border: 2px dashed #007AFF; margin: 20px 0; }
                .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Stronix</h1>
                    <p>密码重置验证码</p>
                </div>
                <div class="content">
                    <p>您好，</p>
                    <p>您正在申请重置Stronix账户密码。请使用以下验证码完成密码重置：</p>
                    <div class="code">\(verificationCode)</div>
                    <p><strong>重要提醒：</strong></p>
                    <ul>
                        <li>此验证码将在15分钟后过期，请尽快使用</li>
                        <li>为了您的账户安全，请勿将验证码告诉他人</li>
                        <li>如果您没有申请密码重置，请忽略此邮件</li>
                    </ul>
                </div>
                <div class="footer">
                    <p>感谢您使用Stronix！</p>
                    <p>——————————————————————</p>
                    <p>Stronix团队</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        let textBody = """
        您好，
        
        您正在申请重置Stronix账户密码。请使用以下验证码完成密码重置：
        
        验证码：\(verificationCode)
        
        重要提醒：
        - 此验证码将在15分钟后过期，请尽快使用
        - 为了您的账户安全，请勿将验证码告诉他人
        - 如果您没有申请密码重置，请忽略此邮件
        
        感谢您使用Stronix！
        
        ——————————————————————
        Stronix团队
        """
        
        return (subject, htmlBody, textBody)
    }
}