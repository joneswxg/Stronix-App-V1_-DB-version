//
//  AliCloudEmailService.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/1/25.
//

import Foundation
import CryptoKit

/// 阿里云邮件推送服务
class AliCloudEmailService {
    
    // MARK: - 单例模式
    static let shared = AliCloudEmailService()
    
    private init() {}
    
    // MARK: - 发送邮件
    func sendEmail(to email: String, subject: String, htmlBody: String, textBody: String) async throws -> Bool {
        
        print("🚀 AliCloudEmailService: 开始发送邮件流程")
        print("📧 收件人: \(email)")
        print("📝 主题: \(subject)")
        
        // 检查配置
        let isConfigured = AliCloudEmailConfig.isConfigured()
        print("🔍 AliCloudEmailService: 配置检查结果: \(isConfigured)")
        
        guard isConfigured else {
            print("❌ AliCloudEmailService: 阿里云邮件服务未配置")
            print("📋 配置详情: \(AliCloudEmailConfig.getConfigInfo())")
            throw EmailError.configurationError
        }
        
        print("✅ AliCloudEmailService: 配置验证通过，继续发送流程")
        
        // 构建请求参数
        let parameters = buildRequestParameters(
            toEmail: email,
            subject: subject,
            htmlBody: htmlBody,
            textBody: textBody
        )
        
        // 生成签名
        let signature = try generateSignature(parameters: parameters)
        
        // 发送HTTP请求
        return try await sendHTTPRequest(parameters: parameters, signature: signature)
    }
    
    // MARK: - 构建请求参数
    private func buildRequestParameters(toEmail: String, subject: String, htmlBody: String, textBody: String) -> [String: String] {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let nonce = UUID().uuidString
        
        return [
            "Action": "SingleSendMail",
            "Version": "2015-11-23",
            "AccessKeyId": AliCloudEmailConfig.accessKeyId,
            "SignatureMethod": "HMAC-SHA1",
            "Timestamp": timestamp,
            "SignatureVersion": "1.0",
            "SignatureNonce": nonce,
            "Format": "JSON",
            "AccountName": AliCloudEmailConfig.fromEmail,
            "FromAlias": AliCloudEmailConfig.fromName,
            "AddressType": "1",
            "ToAddress": toEmail,
            "Subject": subject,
            "HtmlBody": htmlBody,
            "TextBody": textBody,
            "ReplyToAddress": "false"
        ]
    }
    
    // MARK: - 生成阿里云API签名
    private func generateSignature(parameters: [String: String]) throws -> String {
        // 1. 对参数进行排序
        let sortedParams = parameters.sorted { $0.key < $1.key }
        
        // 2. 构建查询字符串
        let queryString = sortedParams.map { key, value in
            "\(percentEncode(key))=\(percentEncode(value))"
        }.joined(separator: "&")
        
        // 3. 构建待签名字符串
        let stringToSign = "POST&%2F&\(percentEncode(queryString))"
        
        // 4. 计算签名
        let key = "\(AliCloudEmailConfig.accessKeySecret)&"
        let keyData = Data(key.utf8)
        let dataToSign = Data(stringToSign.utf8)
        
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: dataToSign, using: SymmetricKey(data: keyData))
        let signatureBase64 = Data(signature).base64EncodedString()
        
        return signatureBase64
    }
    
    // MARK: - URL编码
    private func percentEncode(_ string: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        return string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? string
    }
    
    // MARK: - 发送HTTP请求
    private func sendHTTPRequest(parameters: [String: String], signature: String) async throws -> Bool {
        
        guard let url = URL(string: AliCloudEmailConfig.endpoint) else {
            throw EmailError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 添加签名到参数中
        var finalParameters = parameters
        finalParameters["Signature"] = signature
        
        // 构建请求体
        let bodyString = finalParameters.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        print("📧 AliCloudEmailService: 正在发送邮件请求...")
        print("🔗 请求URL: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmailError.invalidResponse
            }
            
            print("📊 HTTP状态码: \(httpResponse.statusCode)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 响应内容: \(responseString)")
            }
            
            // 解析响应
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let _ = json["EnvId"] as? String {
                        print("✅ AliCloudEmailService: 邮件发送成功")
                        return true
                    } else if let errorCode = json["Code"] as? String,
                              let errorMessage = json["Message"] as? String {
                        print("❌ AliCloudEmailService: 邮件发送失败 - \(errorCode): \(errorMessage)")
                        throw EmailError.apiError(errorCode, errorMessage)
                    }
                }
            }
            
            print("❌ AliCloudEmailService: 邮件发送失败 - HTTP \(httpResponse.statusCode)")
            return false
            
        } catch {
            print("❌ AliCloudEmailService: 网络请求失败 - \(error.localizedDescription)")
            throw EmailError.networkError
        }
    }
}