//
//  APIService.swift
//  Stronix-App-V1
//
//  Created by jones wang on 2025/5/26.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = "http://127.0.0.1:6000/api"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - 通用网络请求方法
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type,
        retryCount: Int = 0
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("zh_CN", forHTTPHeaderField: "Accept-Language")
        
        // 自动添加认证token
        if let token = AuthService.shared.getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            urlRequest.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // 添加详细的响应日志
            print("🌐 API响应 [\(endpoint)]:")
            print("   状态码: \(httpResponse.statusCode)")
            print("   响应数据: \(String(data: data, encoding: .utf8) ?? "无法解析")")
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                do {
                    let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
                    if apiResponse.code == 200 {
                        return apiResponse.data
                    } else {
                        throw APIError.serverError(apiResponse.message)
                    }
                } catch let decodingError {
                    print("❌ JSON解析失败: \(decodingError)")
                    if let decodingError = decodingError as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("   缺少键: \(key.stringValue), 路径: \(context.codingPath)")
                        case .typeMismatch(let type, let context):
                            print("   类型不匹配: 期望 \(type), 路径: \(context.codingPath)")
                        case .valueNotFound(let type, let context):
                            print("   值不存在: 期望 \(type), 路径: \(context.codingPath)")
                        case .dataCorrupted(let context):
                            print("   数据损坏: \(context.debugDescription), 路径: \(context.codingPath)")
                        @unknown default:
                            print("   未知解析错误")
                        }
                    }
                    throw APIError.networkError(decodingError)
                }
            } else if httpResponse.statusCode == 401 {
                // 认证失败，尝试刷新token并重试
                print("🔄 API认证失败，token可能已过期")
                
                // 只重试一次，避免无限循环
                if retryCount == 0 {
                    print("🔄 尝试刷新token...")
                    let refreshSuccess = await AuthService.shared.refreshToken()
                    
                    if refreshSuccess {
                        print("✅ Token刷新成功，重试请求")
                        // 递归调用，增加重试计数
                        return try await self.request(
                            endpoint: endpoint,
                            method: method,
                            body: body,
                            responseType: responseType,
                            retryCount: retryCount + 1
                        )
                    } else {
                        print("❌ Token刷新失败")
                        throw APIError.unauthorized
                    }
                } else {
                    print("❌ 重试后仍然认证失败")
                    throw APIError.unauthorized
                }
            } else {
                throw APIError.httpError(httpResponse.statusCode)
            }
        } catch {
            if error is APIError {
                throw error
            } else {
                throw APIError.networkError(error)
            }
        }
    }
}

// MARK: - HTTP方法枚举
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - API响应模型
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T
}

// MARK: - API错误类型
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case serverError(String)
    case httpError(Int)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .unauthorized:
            return "请先登录"
        }
    }
}

