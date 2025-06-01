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

// MARK: - 认证服务
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    
    private let baseURL = "http://localhost:6000/api/auth"
    
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
            if let user = authResponse.user, let token = authResponse.token {
                await MainActor.run {
                    self.currentUser = user
                    self.isLoggedIn = true
                }
                saveUserToStorage(user: user, token: token)
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
        
        if httpResponse.statusCode == 200 {
            if let user = authResponse.user, let token = authResponse.token {
                await MainActor.run {
                    self.currentUser = user
                    self.isLoggedIn = true
                }
                saveUserToStorage(user: user, token: token)
            }
        }
        
        return authResponse
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
    private func saveUserToStorage(user: User, token: String) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
            UserDefaults.standard.set(token, forKey: "authToken")
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
    }
    
    // MARK: - 获取认证Token
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: "authToken")
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