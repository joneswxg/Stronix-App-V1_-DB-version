import Foundation
import SQLite
import SwiftUI

/// 本地动作相关数据模型
/// 迁移自 Backend-Reference/src/stronix/models/ActionListModel.py

// MARK: - 目标肌肉模型
struct TargetMuscle: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let display_name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case display_name
    }
    
    static func == (lhs: TargetMuscle, rhs: TargetMuscle) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 设备模型
struct Equipment: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let display_name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case display_name
    }
    
    static func == (lhs: Equipment, rhs: Equipment) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 身体部位模型
struct BodyPart: Identifiable, Codable {
    let id: Int
    let name: String
    let display_name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case display_name
    }
}

// MARK: - 动作模型
struct Action: Identifiable, Codable {
    let id: Int
    let external_id: String
    let name: String
    let name_en: String?
    let gifUrl: String?
    let description: String?
    let description_en: String?
    let difficulty: String?
    let bodypart_id: Int
    let equipment_id: Int?
    let is_bilateral: Bool
    let target_muscle_ids: [Int]
    
    // 计算属性：基于external_id生成本地资源名
    var localImageName: String {
        // 基于external_id生成图片名称：external_id = "1" -> "exercise_1"
        if !external_id.isEmpty {
            return "exercise_\(external_id)"
        }
        return "exercise_default"
    }
    
    // 计算属性：默认组数和次数
    var default_sets: Int { 3 }
    var default_reps: Int { 12 }
    
    enum CodingKeys: String, CodingKey {
        case id, external_id, name, name_en, gifUrl, description, description_en
        case difficulty, bodypart_id, equipment_id, is_bilateral, target_muscle_ids
    }
}

// MARK: - 动作详情模型（包含完整信息）
struct ActionDetail: Identifiable, Codable {
    let id: Int
    let external_id: String
    let name: String
    let name_en: String?
    let gifUrl: String?
    let description: String?
    let description_en: String?
    let difficulty: String?
    let bodypart_id: Int
    let equipment_id: Int?
    let is_bilateral: Bool
    let target_muscles: [TargetMuscle]
    let equipment: Equipment?
    let bodypart: BodyPart?
    
    // 计算属性：基于external_id生成本地资源名
    var localImageName: String {
        // 基于external_id生成图片名称：external_id = "1" -> "exercise_1"
        if !external_id.isEmpty {
            return "exercise_\(external_id)"
        }
        return "exercise_default"
    }
    
    var default_sets: Int { 3 }
    var default_reps: Int { 12 }
}

// MARK: - 动作查询参数
struct ActionQuery {
    let target_muscle_id: Int?
    let equipment_id: Int?
    let bodypart_id: Int?
    let difficulty: String?
    let search_term: String?
    let limit: Int?
    let offset: Int?
    
    init(target_muscle_id: Int? = nil,
         equipment_id: Int? = nil,
         bodypart_id: Int? = nil,
         difficulty: String? = nil,
         search_term: String? = nil,
         limit: Int? = nil,
         offset: Int? = nil) {
        self.target_muscle_id = target_muscle_id
        self.equipment_id = equipment_id
        self.bodypart_id = bodypart_id
        self.difficulty = difficulty
        self.search_term = search_term
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - 响应模型
struct ActionResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let result: T?
    let error: String?
}

struct ActionListResponse: Codable {
    let actions: [Action]
    let total_count: Int
    let page: Int?
    let per_page: Int?
}

// MARK: - 错误定义
enum LocalActionError: Error, LocalizedError {
    case databaseNotInitialized
    case queryFailed(Error)
    case dataNotFound
    case invalidParameters
    
    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "数据库未初始化"
        case .queryFailed(let error):
            return "查询失败: \(error.localizedDescription)"
        case .dataNotFound:
            return "未找到数据"
        case .invalidParameters:
            return "无效参数"
        }
    }
}

// MARK: - ActionListViewModel（迁移自Backend ActionService功能）

@MainActor
class ActionListViewModel: ObservableObject {
    @Published var actions: [Action] = []
    @Published var targetMuscles: [TargetMuscle] = []
    @Published var equipments: [Equipment] = []
    @Published var bodyParts: [BodyPart] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var error: Error?
    
    private let actionService = LocalActionService.shared
    
    init() {
        loadInitialData()
    }
    
    func loadInitialData() {
        Task {
            await loadFilters()
            // 只加载筛选数据，动作数据由 ActionListView 根据选中的目标肌肉加载
        }
    }
    
    func loadActions(targetMuscleId: Int? = nil, equipmentId: Int? = nil, bodyPartId: Int? = nil, searchText: String = "") async {
        isLoading = true
        errorMessage = nil
        error = nil
        
        do {
            let filters: [String: Any] = [
                "target_muscle_id": targetMuscleId ?? 0,
                "equipment_id": equipmentId ?? 0,
                "bodypart_id": bodyPartId ?? 0,
                "search": searchText
            ]
            
            let result = try await actionService.getActions(filters: filters)
            actions = result
        } catch {
            handleError(error, context: "加载动作列表")
        }
        
        isLoading = false
    }
    
    func loadFilters() async {
        do {
            // 加载目标肌肉组
            targetMuscles = try await actionService.getTargetMuscles()
            
            // 加载器材类型
            equipments = try await actionService.getEquipments()
            
            // 加载身体部位
            bodyParts = try await actionService.getBodyParts()
            
        } catch {
            handleError(error, context: "加载筛选选项")
        }
    }
    
    func searchActions(text: String, targetMuscleId: Int? = nil, equipmentId: Int? = nil, bodyPartId: Int? = nil) {
        Task {
            await loadActions(targetMuscleId: targetMuscleId, equipmentId: equipmentId, bodyPartId: bodyPartId, searchText: text)
        }
    }
    
    func loadActionsByTargetMuscle(targetMuscleId: Int) async {
        await loadActions(targetMuscleId: targetMuscleId)
    }
    
    private func handleError(_ error: Error, context: String) {
        print("[\(context)] 错误: \(error.localizedDescription)")
        
        self.error = error
        
        if let localError = error as? LocalActionError {
            errorMessage = "\(context)失败: \(localError.localizedDescription)"
        } else {
            errorMessage = "\(context)失败: \(error.localizedDescription)"
        }
        
        showError = true
    }
}

// MARK: - 前端兼容层模型（来自ActionInfo.swift）

/// 动作信息模型（前端兼容层）
struct ActionInfo: Identifiable {
    let id: Int
    let name: String
    let imageUrl: String
    
    /// 直接创建
    init(id: Int, name: String, imageUrl: String) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
    }
}

// TODO: 从DatabaseManager.swift迁移相关数据结构 