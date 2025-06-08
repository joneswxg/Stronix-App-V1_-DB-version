import Foundation

/// 训练历史服务类
class TrainingHistoryService: ObservableObject {
    static let shared = TrainingHistoryService()
    
    private let baseURL = "http://127.0.0.1:6000/api"
    
    private init() {}
    
    /// 获取认证token
    private func getAuthToken() -> String? {
        return AuthService.shared.getAuthToken()
    }
    
    /// 保存训练历史
    func saveTrainingHistory(_ request: SaveTrainingHistoryRequest) async throws -> SaveTrainingHistoryResponse {
        print("🔄 开始保存训练历史...")
        print("📊 训练数据: 计划=\(request.plan_name), 容量=\(request.volume)kg, 时长=\(request.duration)秒")
        print("📝 详情数量: \(request.details.count)组")
        
        let url = URL(string: "\(baseURL)/training/history")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("zh_CN", forHTTPHeaderField: "Accept-Language")
        
        // 添加认证头
        if let token = getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ 警告：没有找到认证token")
            throw NetworkError.unauthorized
        }
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(TrainingHistoryAPIResponse.self, from: data)
            if let historyData = result.data {
                print("✅ 训练历史保存成功，历史ID: \(historyData.history_id)")
                return historyData
            } else {
                throw NetworkError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            print("❌ 认证失败，请重新登录")
            throw NetworkError.unauthorized
        } else {
            // 处理错误响应
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                print("❌ 保存训练历史失败: \(errorData.message)")
                throw NetworkError.serverError(errorData.message)
            } else {
                throw NetworkError.invalidResponse
            }
        }
    }
    
    /// 从训练更新计划
    func updatePlanFromTraining(planId: Int, request: UpdatePlanFromTrainingRequest) async throws {
        print("🔄 开始更新训练计划...")
        print("📋 计划ID: \(planId)")
        print("📝 计划名称: \(request.name)")
        print("🏃‍♂️ 动作数量: \(request.actions.count)")
        
        let url = URL(string: "\(baseURL)/training/plans/\(planId)/update-from-training")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("zh_CN", forHTTPHeaderField: "Accept-Language")
        
        // 添加认证头
        if let token = getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ 警告：没有找到认证token")
            throw NetworkError.unauthorized
        }
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            print("✅ 训练计划更新成功")
        } else if httpResponse.statusCode == 401 {
            print("❌ 认证失败，请重新登录")
            throw NetworkError.unauthorized
        } else {
            // 处理错误响应
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                print("❌ 更新训练计划失败: \(errorData.message)")
                throw NetworkError.serverError(errorData.message)
            } else {
                throw NetworkError.invalidResponse
            }
        }
    }
    
    /// 获取训练历史列表
    func getTrainingHistory(page: Int = 1, limit: Int = 20, planId: Int? = nil, startDate: String? = nil, endDate: String? = nil) async throws -> TrainingHistoryListResponse {
        print("🔄 获取训练历史列表...")
        
        var urlComponents = URLComponents(string: "\(baseURL)/training/history")!
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let planId = planId {
            queryItems.append(URLQueryItem(name: "plan_id", value: "\(planId)"))
        }
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: startDate))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("zh_CN", forHTTPHeaderField: "Accept-Language")
        
        // 添加认证头
        if let token = getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ 警告：没有找到认证token")
            throw NetworkError.unauthorized
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(TrainingHistoryListAPIResponse.self, from: data)
            if let historyData = result.data {
                print("✅ 获取训练历史成功，共 \(historyData.histories.count) 条记录")
                return historyData
            } else {
                throw NetworkError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            print("❌ 认证失败，请重新登录")
            throw NetworkError.unauthorized
        } else {
            // 处理错误响应
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                print("❌ 获取训练历史失败: \(errorData.message)")
                throw NetworkError.serverError(errorData.message)
            } else {
                throw NetworkError.invalidResponse
            }
        }
    }
    
    /// 获取指定日期范围内有训练记录的日期列表
    func getTrainingDates(startDate: String, endDate: String) async throws -> TrainingDatesResponse {
        print("🗓️ 获取训练日期列表: \(startDate) 到 \(endDate)")
        
        var urlComponents = URLComponents(string: "\(baseURL)/training/training-dates")!
        urlComponents.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate)
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("zh_CN", forHTTPHeaderField: "Accept-Language")
        
        // 添加认证头
        if let token = getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ 警告：没有找到认证token")
            throw NetworkError.unauthorized
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(TrainingDatesAPIResponse.self, from: data)
            if let datesData = result.data {
                print("✅ 获取训练日期成功，共 \(datesData.total_days) 天有训练记录")
                return datesData
            } else {
                throw NetworkError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            print("❌ 认证失败，请重新登录")
            throw NetworkError.unauthorized
        } else {
            // 处理错误响应
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                print("❌ 获取训练日期失败: \(errorData.message)")
                throw NetworkError.serverError(errorData.message)
            } else {
                throw NetworkError.invalidResponse
            }
        }
    }
    
    /// 获取训练历史详情
    func getTrainingHistoryDetail(historyId: Int) async throws -> TrainingHistoryDetailResponse {
        print("🔄 获取训练历史详情，ID: \(historyId)")
        
        let url = URL(string: "\(baseURL)/training/history/\(historyId)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("zh_CN", forHTTPHeaderField: "Accept-Language")
        
        // 添加认证头
        if let token = getAuthToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ 警告：没有找到认证token")
            throw NetworkError.unauthorized
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(TrainingHistoryDetailAPIResponse.self, from: data)
            if let detailData = result.data {
                print("✅ 获取训练历史详情成功")
                return detailData
            } else {
                throw NetworkError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            print("❌ 认证失败，请重新登录")
            throw NetworkError.unauthorized
        } else {
            // 处理错误响应
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                print("❌ 获取训练历史详情失败: \(errorData.message)")
                throw NetworkError.serverError(errorData.message)
            } else {
                throw NetworkError.invalidResponse
            }
        }
    }
}

/// 训练历史API响应包装器
struct TrainingHistoryAPIResponse: Codable {
    let code: Int
    let message: String
    let data: SaveTrainingHistoryResponse?
}

/// 训练历史列表API响应包装器
struct TrainingHistoryListAPIResponse: Codable {
    let code: Int
    let message: String
    let data: TrainingHistoryListResponse?
}

/// 训练历史详情API响应包装器
struct TrainingHistoryDetailAPIResponse: Codable {
    let code: Int
    let message: String
    let data: TrainingHistoryDetailResponse?
}

/// 训练日期API响应包装器
struct TrainingDatesAPIResponse: Codable {
    let code: Int
    let message: String
    let data: TrainingDatesResponse?
}

/// API错误响应
struct APIErrorResponse: Codable {
    let code: Int
    let message: String
}

/// 训练历史列表响应
struct TrainingHistoryListResponse: Codable {
    let histories: [TrainingHistoryItem]
    let pagination: PaginationInfo
}

/// 训练历史项目
struct TrainingHistoryItem: Codable {
    let id: Int
    let plan_id: Int?
    let plan_name: String
    let training_date: String
    let volume: Double
    let duration: Int
    let note: String?
    let created_at: String?
}

/// 分页信息
struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

/// 训练历史详情响应
struct TrainingHistoryDetailResponse: Codable {
    let history: TrainingHistoryItem
    let details: [TrainingHistoryDetailItem]
}

/// 训练日期响应
struct TrainingDatesResponse: Codable {
    let training_dates: [String]
    let start_date: String
    let end_date: String
    let total_days: Int
}

/// 训练历史详情项目
struct TrainingHistoryDetailItem: Codable {
    let action_id: Int
    let set_number: Int
    let weight: Double?
    let weight_unit: String
    let reps: Int?
    let difficulty: String?
    let left_weight: Double?
    let right_weight: Double?
    let is_completed: Bool
    let action_name: String?
}

/// 网络错误枚举
enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case decodingError
    case networkUnavailable
    case unauthorized
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .decodingError:
            return "数据解析失败"
        case .networkUnavailable:
            return "网络不可用"
        case .unauthorized:
            return "未授权，请重新登录"
        case .serverError(let message):
            return message
        }
    }
} 