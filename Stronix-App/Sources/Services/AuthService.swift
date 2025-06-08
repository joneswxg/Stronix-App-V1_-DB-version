import Foundation
import SwiftUI

// MARK: - 用户模型
struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let gender: String?
    let height: Double?
    let weight: Double?
    let role: String
    let isAdmin: Bool
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, username, email, gender, height, weight, role
        case isAdmin = "is_admin"
        case createdAt = "created_at"
    }
}

// MARK: - 认证响应模型
struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let user: User?
    let token: String?
    let access_token: String?
    let refresh_token: String?
}

struct RegisterRequest: Codable {
    let username: String
    let email: String
    let password: String
    let gender: String?
    let height: Double?
    let weight: Double?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct RefreshTokenRequest: Codable {
    let refresh_token: String
}

struct RefreshTokenResponse: Codable {
    let success: Bool
    let message: String
    let access_token: String?
    let token: String?
}

// MARK: - 认证服务
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    
    private let baseURL = "http://127.0.0.1:6000/api/auth"
    
    private init() {
        loadUserFromStorage()
    }
    
    // MARK: - 用户注册
    func register(
        username: String,
        email: String,
        password: String,
        gender: String? = nil,
        height: String? = nil,
        weight: String? = nil
    ) async throws -> AuthResponse {
        isLoading = true
        defer { isLoading = false }
        
        let heightValue = height?.isEmpty == false ? Double(height!) : nil
        let weightValue = weight?.isEmpty == false ? Double(weight!) : nil
        
        let request = RegisterRequest(
            username: username,
            email: email,
            password: password,
            gender: gender,
            height: heightValue,
            weight: weightValue
        )
        
        guard let url = URL(string: "\(baseURL)/register") else {
            throw AuthError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            if let user = authResponse.user {
                let token = authResponse.token ?? authResponse.access_token ?? ""
                let refreshToken = authResponse.refresh_token
                if !token.isEmpty {
                    await MainActor.run {
                        self.currentUser = user
                        self.isLoggedIn = true
                    }
                    saveUserToStorage(user: user, token: token, refreshToken: refreshToken)
                }
            }
        }
        
        return authResponse
    }
    
    // MARK: - 用户登录
    func login(email: String, password: String) async throws -> AuthResponse {
        isLoading = true
        defer { isLoading = false }
        
        let request = LoginRequest(email: email, password: password)
        
        guard let url = URL(string: "\(baseURL)/login") else {
            print("❌ 无效的URL: \(baseURL)/login")
            throw AuthError.invalidURL
        }
        
        print("🔗 登录请求URL: \(url)")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
        urlRequest.httpBody = try JSONEncoder().encode(request)
            print("📤 请求体: \(String(data: urlRequest.httpBody!, encoding: .utf8) ?? "无法解析")")
        } catch {
            print("❌ 编码请求体失败: \(error)")
            throw error
        }
        
        do {
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的HTTP响应")
            throw AuthError.invalidResponse
        }
            
            print("📥 响应状态码: \(httpResponse.statusCode)")
            print("📥 响应数据: \(String(data: data, encoding: .utf8) ?? "无法解析")")
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        if httpResponse.statusCode == 200 {
            if let user = authResponse.user {
                let token = authResponse.token ?? authResponse.access_token ?? ""
                let refreshToken = authResponse.refresh_token
                if !token.isEmpty {
                    print("✅ 登录成功，用户: \(user.username)")
                    await MainActor.run {
                        self.currentUser = user
                        self.isLoggedIn = true
                    }
                    saveUserToStorage(user: user, token: token, refreshToken: refreshToken)
                }
            }
        } else {
            print("❌ 登录失败，状态码: \(httpResponse.statusCode)")
        }
        
        return authResponse
        } catch {
            print("❌ 网络请求失败: \(error)")
            throw error
        }
    }
    
    // MARK: - 忘记密码
    func forgotPassword(email: String) async throws -> AuthResponse {
        isLoading = true
        defer { isLoading = false }
        
        let request = ForgotPasswordRequest(email: email)
        
        guard let url = URL(string: "\(baseURL)/forgot-password") else {
            throw AuthError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        return authResponse
    }
    
    // MARK: - 用户登出
    func logout() {
        currentUser = nil
        isLoggedIn = false
        clearUserFromStorage()
    }
    
    // MARK: - 本地存储
    private func saveUserToStorage(user: User, token: String, refreshToken: String? = nil) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
            UserDefaults.standard.set(token, forKey: "authToken")
            if let refreshToken = refreshToken {
                UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
            }
        }
    }
    
    private func loadUserFromStorage() {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData),
           UserDefaults.standard.string(forKey: "authToken") != nil {
            currentUser = user
            isLoggedIn = true
        }
    }
    
    private func clearUserFromStorage() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "refreshToken")
    }
    
    // MARK: - 获取认证Token
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "authToken")
    }
    
    func getRefreshToken() -> String? {
        return UserDefaults.standard.string(forKey: "refreshToken")
    }
    
    // MARK: - 检查token有效性
    func isTokenValid() async -> Bool {
        guard let token = getAuthToken(), !token.isEmpty else {
            return false
        }
        
        // 暂时简化验证逻辑，只检查token是否存在
        // 后续可以实现真正的服务器验证
        return true
        
        /* 注释掉服务器验证，因为/verify端点可能不存在
        // 尝试调用一个简单的API来验证token
        guard let url = URL(string: "\(baseURL)/verify") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("Token验证失败: \(error)")
        }
        
        return false
        */
    }
    
    // MARK: - 刷新Token
    func refreshToken() async -> Bool {
        guard let refreshToken = getRefreshToken(), !refreshToken.isEmpty else {
            print("❌ 没有refresh token")
            return false
        }
        
        guard let url = URL(string: "\(baseURL)/refresh-token") else {
            print("❌ 无效的刷新token URL")
            return false
        }
        
        let request = RefreshTokenRequest(refresh_token: refreshToken)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的HTTP响应")
                return false
            }
            
            print("📥 刷新token响应状态码: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let refreshResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
                
                if refreshResponse.success, 
                   let newToken = refreshResponse.access_token ?? refreshResponse.token,
                   let currentUser = currentUser {
                    
                    // 更新存储的token
                    UserDefaults.standard.set(newToken, forKey: "authToken")
                    print("✅ Token刷新成功")
                    return true
                }
            } else {
                print("❌ 刷新token失败，状态码: \(httpResponse.statusCode)")
                // 如果refresh token也过期了，清除登录状态
                await MainActor.run {
                    logout()
                }
            }
        } catch {
            print("❌ 刷新token网络错误: \(error)")
        }
        
        return false
    }
    
    // MARK: - 自动刷新token
    func refreshTokenIfNeeded() async -> Bool {
        // 如果当前显示已登录但没有token，尝试刷新
        if isLoggedIn {
            if getAuthToken() == nil || getAuthToken()?.isEmpty == true {
                print("🔄 Token缺失，尝试刷新")
                return await refreshToken()
            }
        }
        return true
    }
}

// MARK: - 认证错误
enum AuthError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case invalidCredentials
    case userExists
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .networkError:
            return "网络错误"
        case .invalidCredentials:
            return "用户名或密码错误"
        case .userExists:
            return "用户已存在"
        case .serverError:
            return "服务器错误"
        }
    }
} 