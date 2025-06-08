import Foundation

class PlanService {
    static let shared = PlanService()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - 获取模板计划列表
    func getTemplatePlans() async throws -> [TrainingPlan] {
        let apiPlans: [APIPlan] = try await apiService.request(
            endpoint: "/plans/templates",
            method: .GET,
            responseType: [APIPlan].self
        )
        
        return apiPlans.map { $0.toTrainingPlan() }
    }
    
    // MARK: - 获取个人计划列表
    func getPersonalPlans() async throws -> [TrainingPlan] {
        let apiPlans: [APIPlan] = try await apiService.request(
            endpoint: "/plans/personal",
            method: .GET,
            responseType: [APIPlan].self
        )
        
        return apiPlans.map { $0.toTrainingPlan() }
    }
    
    // MARK: - 获取计划详情
    func getPlanDetail(planId: Int) async throws -> TrainingPlan {
        let apiPlanDetail: APIPlanDetail = try await apiService.request(
            endpoint: "/plans/\(planId)",
            method: .GET,
            responseType: APIPlanDetail.self
        )
        
        return apiPlanDetail.toTrainingPlan()
    }
    
    // MARK: - 创建计划
    func createPlan(_ planData: CreatePlanRequest) async throws -> CreatePlanResponse {
        let jsonData = try JSONEncoder().encode(planData)
        
        return try await apiService.request(
            endpoint: "/plans/create",
            method: .POST,
            body: jsonData,
            responseType: CreatePlanResponse.self
        )
    }
    
    // MARK: - 复制模板计划
    func copyTemplatePlan(templateId: Int) async throws -> CreatePlanResponse {
        return try await apiService.request(
            endpoint: "/plans/copy/\(templateId)",
            method: .POST,
            responseType: CreatePlanResponse.self
        )
    }
    
    // MARK: - 删除计划
    func deletePlan(planId: Int) async throws {
        let _: EmptyResponse = try await apiService.request(
            endpoint: "/plans/\(planId)",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
    }
    
    // MARK: - 更新计划
    func updatePlan(planId: Int, planData: UpdatePlanRequest) async throws {
        let jsonData = try JSONEncoder().encode(planData)
        
        let _: EmptyResponse = try await apiService.request(
            endpoint: "/plans/\(planId)",
            method: .PUT,
            body: jsonData,
            responseType: EmptyResponse.self
        )
    }
}

// MARK: - 请求和响应模型

/// 创建计划请求模型
struct CreatePlanRequest: Codable {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [CreatePlanAction]
}

/// 更新计划请求模型
struct UpdatePlanRequest: Codable {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [UpdatePlanAction]
}

/// 更新计划动作模型
struct UpdatePlanAction: Codable {
    let action_id: Int
    let rest: Int
    let note: String
    let record_bilateral: Bool
    let sets: [UpdatePlanSet]
    let order: Int
}

/// 更新计划组数据模型
struct UpdatePlanSet: Codable {
    let weight: Double?
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
    let order: Int
}

/// 创建计划动作模型
struct CreatePlanAction: Codable {
    let action_id: Int
    let rest: Int
    let note: String
    let record_bilateral: Bool
    let sets: [CreatePlanSet]
}

/// 创建计划组数据模型
struct CreatePlanSet: Codable {
    let weight: Double?
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
}

/// 创建计划响应模型
struct CreatePlanResponse: Codable {
    let plan_id: Int
}

/// 空响应模型
struct EmptyResponse: Codable {} 