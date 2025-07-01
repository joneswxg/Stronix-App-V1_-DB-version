import Foundation
import SQLite

/// 本地动作服务类
/// 迁移自 Backend-Reference/src/stronix/services/ActionService.py
/// 替换 DatabaseManager.swift 中的 fetchActions() 和 fetchTargetMuscles() 方法

class LocalActionService: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = LocalActionService()
    
    // MARK: - 发布属性
    @Published var actions: [Action] = []
    @Published var targetMuscles: [TargetMuscle] = []
    @Published var equipments: [Equipment] = []
    @Published var isLoading = false
    
    // MARK: - 私有属性
    private let databaseManager = DatabaseManager.shared
    
    // 数据库表结构定义
    private let actionTable = Table("action")
    private let targetMuscleTable = Table("target_muscle")
    private let equipmentTable = Table("equipment")
    private let actionTargetMuscleLinkTable = Table("action_target_muscle_link")
    private let bodyPartTable = Table("body_part")
    
    // Action表字段
    private let actionId = Expression<Int>("id")
    private let actionExternalId = Expression<String>("external_id")
    private let actionName = Expression<String>("name")
    private let actionNameEn = Expression<String?>("name_en")
    private let actionGifUrl = Expression<String?>("gifUrl")
    private let actionDescription = Expression<String?>("description")
    private let actionDescriptionEn = Expression<String?>("description_en")
    private let actionDifficulty = Expression<String?>("difficulty")
    private let actionBodypartId = Expression<Int>("bodypart_id")
    private let actionEquipmentId = Expression<Int?>("equipment_id")
    private let actionIsBilateral = Expression<Bool>("is_bilateral")
    
    // TargetMuscle表字段
    private let targetMuscleId = Expression<Int>("id")
    private let targetMuscleName = Expression<String>("name")
    private let targetMuscleDisplayName = Expression<String?>("display_name")
    
    // Equipment表字段
    private let equipmentId = Expression<Int>("id")
    private let equipmentName = Expression<String>("name")
    private let equipmentDisplayName = Expression<String?>("display_name")
    
    // ActionTargetMuscleLink表字段
    private let linkActionId = Expression<Int>("action_id")
    private let linkTargetMuscleId = Expression<Int>("target_muscle_id")
    
    // BodyPart表字段
    private let bodyPartId = Expression<Int>("id")
    private let bodyPartName = Expression<String>("name")
    private let bodyPartDisplayName = Expression<String?>("display_name")
    
    private init() {
        // 初始化时不需要额外设置，DatabaseManager已经处理了数据库连接
    }
    
    // MARK: - 公共API方法
    
    /// 获取所有目标肌肉
    func fetchTargetMuscles() async throws -> [TargetMuscle] {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            let query = targetMuscleTable.select(targetMuscleId, targetMuscleName, targetMuscleDisplayName)
                .order(targetMuscleId.asc)
            
            let rows = try db.prepare(query)
            var targetMuscles: [TargetMuscle] = []
            
            for row in rows {
                let targetMuscle = TargetMuscle(
                    id: row[targetMuscleId],
                    name: row[targetMuscleName],
                    display_name: row[targetMuscleDisplayName] ?? row[targetMuscleName]
                )
                targetMuscles.append(targetMuscle)
            }
            
            print("✅ LocalActionService: 成功获取 \(targetMuscles.count) 个目标肌肉")
            return targetMuscles
            
        } catch {
            print("❌ LocalActionService: 获取目标肌肉失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    /// 获取所有设备
    func fetchEquipments() async throws -> [Equipment] {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            let query = equipmentTable.select(equipmentId, equipmentName, equipmentDisplayName)
                .order(equipmentId.asc)
            
            let rows = try db.prepare(query)
            var equipments: [Equipment] = []
            
            for row in rows {
                let equipment = Equipment(
                    id: row[equipmentId],
                    name: row[equipmentName],
                    display_name: row[equipmentDisplayName] ?? row[equipmentName]
                )
                equipments.append(equipment)
            }
            
            print("✅ LocalActionService: 成功获取 \(equipments.count) 个设备")
            return equipments
            
        } catch {
            print("❌ LocalActionService: 获取设备失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    /// 获取所有动作
    func fetchActions() async throws -> [Action] {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            // 使用SQL查询获取动作及其目标肌肉
            let sql = """
            SELECT 
                a.id,
                    a.external_id,
                a.name,
                a.name_en,
                    a.gifUrl,
                    a.description,
                    a.description_en,
                    a.difficulty,
                    a.bodypart_id,
                a.equipment_id,
                    a.is_bilateral,
                GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
            FROM action a
            LEFT JOIN action_target_muscle_link atml ON a.id = atml.action_id
            GROUP BY a.id
                ORDER BY a.id
        """
        
            let rows = try db.prepare(sql)
            var actions: [Action] = []
            
            for row in rows {
                let targetMuscleIdsString = row[11] as? String
                let targetMuscleIds: [Int]
                if let idsString = targetMuscleIdsString, !idsString.isEmpty {
                    targetMuscleIds = idsString.split(separator: ",").compactMap { Int($0) }
                } else {
                    targetMuscleIds = []
                }
                
                let action = Action(
                    id: row[0] as? Int ?? 0,
                    external_id: row[1] as? String ?? "",
                    name: row[2] as? String ?? "",
                    name_en: row[3] as? String,
                    gifUrl: row[4] as? String,
                    description: row[5] as? String,
                    description_en: row[6] as? String,
                    difficulty: row[7] as? String,
                    bodypart_id: row[8] as? Int ?? 0,
                    equipment_id: row[9] as? Int,
                    is_bilateral: (row[10] as? Int ?? 0) == 1,
                    target_muscle_ids: targetMuscleIds
                )
                actions.append(action)
            }
            
            print("✅ LocalActionService: 成功获取 \(actions.count) 个动作")
            return actions
            
        } catch {
            print("❌ LocalActionService: 获取动作失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    /// 根据目标肌肉ID获取动作
    func fetchActions(byTargetMuscleId targetMuscleId: Int) async throws -> [Action] {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            // 使用与Python代码相同的单一查询方法
            let sql = """
                SELECT 
                    a.id,
                    a.external_id,
                    a.name,
                    a.name_en,
                    a.gifUrl,
                    a.description,
                    a.description_en,
                    a.difficulty,
                    a.bodypart_id,
                    a.equipment_id,
                    a.is_bilateral,
                    GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
                FROM action a
                JOIN action_target_muscle_link atml ON a.id = atml.action_id
                WHERE atml.target_muscle_id = ?
                GROUP BY a.id
                ORDER BY a.id
            """
            
            print("🔍 LocalActionService: 查询目标肌肉 \(targetMuscleId) 的动作")
            print("🔍 SQL: \(sql)")
            print("🔍 参数: \(targetMuscleId)")
            
            // 使用SQLite.swift的正确语法
            let statement = try db.prepare(sql, targetMuscleId)
            var actions: [Action] = []
            
            print("🔍 开始处理查询结果")
            
            for row in statement {
                print("🔍 处理行数据，第一个字段值: \(row[0]), 类型: \(type(of: row[0]))")
                
                // 尝试不同的类型转换
                let actionId: Int
                if let intValue = row[0] as? Int {
                    actionId = intValue
                } else if let int64Value = row[0] as? Int64 {
                    actionId = Int(int64Value)
                } else {
                    print("⚠️ LocalActionService: 跳过无效的动作ID，值: \(String(describing: row[0])), 类型: \(type(of: row[0]))")
                    continue
                }
                
                // 处理 target_muscle_ids 字段
                let targetMuscleIdsString = row[11] as? String
                let targetMuscleIds: [Int]
                if let idsString = targetMuscleIdsString, !idsString.isEmpty {
                    targetMuscleIds = idsString.split(separator: ",").compactMap { Int($0) }
                } else {
                    targetMuscleIds = []
                }
                
                let action = Action(
                    id: actionId,
                    external_id: row[1] as? String ?? "",
                    name: row[2] as? String ?? "",
                    name_en: row[3] as? String,
                    gifUrl: row[4] as? String,
                    description: row[5] as? String,
                    description_en: row[6] as? String,
                    difficulty: row[7] as? String,
                    bodypart_id: row[8] as? Int64 != nil ? Int(row[8] as! Int64) : 0,
                    equipment_id: row[9] as? Int64 != nil ? Int(row[9] as! Int64) : nil,
                    is_bilateral: (row[10] as? Int64 ?? 0) == 1,
                    target_muscle_ids: targetMuscleIds
                )
                actions.append(action)
            }
            
            print("✅ LocalActionService: 成功获取目标肌肉 \(targetMuscleId) 的 \(actions.count) 个动作")
            if actions.count > 0 {
                print("📋 动作列表:")
                for action in actions {
                    print("  - \(action.id): \(action.name) (external_id: \(action.external_id), localImageName: \(String(describing: action.localImageName)))")
                }
            } else {
                print("⚠️ LocalActionService: 目标肌肉 \(targetMuscleId) 没有关联的动作")
            }
            return actions
            
        } catch {
            print("❌ LocalActionService: 根据目标肌肉获取动作失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    /// 根据设备ID获取动作
    func fetchActions(byEquipmentId equipmentId: Int) async throws -> [Action] {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            let sql = """
                SELECT 
                a.id,
                    a.external_id,
                a.name,
                a.name_en,
                    a.gifUrl,
                    a.description,
                    a.description_en,
                    a.difficulty,
                    a.bodypart_id,
                a.equipment_id,
                    a.is_bilateral,
                    GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
            FROM action a
                LEFT JOIN action_target_muscle_link atml ON a.id = atml.action_id
                WHERE a.equipment_id = ?
            GROUP BY a.id
                ORDER BY a.id
        """
        
            let rows = try db.prepare(sql, [equipmentId])
            var actions: [Action] = []
            
            for row in rows {
                let targetMuscleIdsString = row[11] as? String
                let targetMuscleIds: [Int]
                if let idsString = targetMuscleIdsString, !idsString.isEmpty {
                    targetMuscleIds = idsString.split(separator: ",").compactMap { Int($0) }
                } else {
                    targetMuscleIds = []
                }
                
                let action = Action(
                    id: row[0] as? Int ?? 0,
                    external_id: row[1] as? String ?? "",
                    name: row[2] as? String ?? "",
                    name_en: row[3] as? String,
                    gifUrl: row[4] as? String,
                    description: row[5] as? String,
                    description_en: row[6] as? String,
                    difficulty: row[7] as? String,
                    bodypart_id: row[8] as? Int ?? 0,
                    equipment_id: row[9] as? Int,
                    is_bilateral: (row[10] as? Int ?? 0) == 1,
                    target_muscle_ids: targetMuscleIds
                )
                actions.append(action)
            }
            
            print("✅ LocalActionService: 成功获取设备 \(equipmentId) 的 \(actions.count) 个动作")
            return actions
            
        } catch {
            print("❌ LocalActionService: 根据设备获取动作失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    /// 获取动作详情（包含完整信息）
    func fetchActionDetail(actionId: Int) async throws -> ActionDetail {
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            // 获取动作基本信息
            let actionQuery = actionTable.select(self.actionId, actionExternalId, actionName, actionNameEn, 
                                               actionGifUrl, actionDescription, actionDescriptionEn,
                                               actionDifficulty, actionBodypartId, actionEquipmentId, actionIsBilateral)
                .filter(self.actionId == actionId)
                .limit(1)
            
            guard let actionRow = try db.pluck(actionQuery) else {
                throw LocalActionError.dataNotFound
            }
            
            // 获取目标肌肉信息
            let targetMuscleQuery = """
                SELECT tm.id, tm.name, tm.display_name
                FROM target_muscle tm
                JOIN action_target_muscle_link atml ON tm.id = atml.target_muscle_id
                WHERE atml.action_id = ?
            """
            
            let targetMuscleRows = try db.prepare(targetMuscleQuery, [actionRow[self.actionId]])
            var targetMuscles: [TargetMuscle] = []
            
            for row in targetMuscleRows {
                guard let id = row[0] as? Int,
                      let name = row[1] as? String else {
                    print("⚠️ LocalActionService: 跳过无效的目标肌肉数据")
                    continue
                }
                
                let targetMuscle = TargetMuscle(
                    id: id,
                    name: name,
                    display_name: row[2] as? String ?? name
                )
                targetMuscles.append(targetMuscle)
            }
            
            // 获取设备信息（如果有）
            var equipment: Equipment?
            if let equipmentIdValue = actionRow[actionEquipmentId] {
                let equipmentQuery = equipmentTable.select(equipmentId, equipmentName, equipmentDisplayName)
                    .filter(equipmentId == equipmentIdValue)
                    .limit(1)
                
                if let equipmentRow = try db.pluck(equipmentQuery) {
                    equipment = Equipment(
                        id: equipmentRow[equipmentId],
                        name: equipmentRow[equipmentName],
                        display_name: equipmentRow[equipmentDisplayName] ?? equipmentRow[equipmentName]
                    )
                }
            }
            
            // 获取身体部位信息
            var bodypart: BodyPart?
            let bodypartQuery = bodyPartTable.select(bodyPartId, bodyPartName, bodyPartDisplayName)
                .filter(bodyPartId == actionRow[actionBodypartId])
                .limit(1)
            
            if let bodypartRow = try db.pluck(bodypartQuery) {
                bodypart = BodyPart(
                    id: bodypartRow[bodyPartId],
                    name: bodypartRow[bodyPartName],
                    display_name: bodypartRow[bodyPartDisplayName] ?? bodypartRow[bodyPartName]
                )
            }
            
            let actionDetail = ActionDetail(
                id: actionRow[self.actionId],
                external_id: actionRow[actionExternalId],
                name: actionRow[actionName],
                name_en: actionRow[actionNameEn],
                gifUrl: actionRow[actionGifUrl],
                description: actionRow[actionDescription],
                description_en: actionRow[actionDescriptionEn],
                difficulty: actionRow[actionDifficulty],
                bodypart_id: actionRow[actionBodypartId],
                equipment_id: actionRow[actionEquipmentId],
                is_bilateral: actionRow[actionIsBilateral],
                target_muscles: targetMuscles,
                equipment: equipment,
                bodypart: bodypart
            )
            
            print("✅ LocalActionService: 成功获取动作详情 \(actionRow[self.actionId])")
            return actionDetail
            
        } catch {
            print("❌ LocalActionService: 获取动作详情失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    /// 搜索动作
    func searchActions(query: String) async throws -> [Action] {
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            let sql = """
                SELECT 
                    a.id,
                    a.external_id,
                    a.name,
                    a.name_en,
                    a.gifUrl,
                    a.description,
                    a.description_en,
                    a.difficulty,
                    a.bodypart_id,
                    a.equipment_id,
                    a.is_bilateral,
                    GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
                FROM action a
                LEFT JOIN action_target_muscle_link atml ON a.id = atml.action_id
                WHERE a.name LIKE ? OR a.name_en LIKE ? OR a.description LIKE ?
                GROUP BY a.id
                ORDER BY a.id
            """
            
            let searchPattern = "%\(query)%"
            let rows = try db.prepare(sql, [searchPattern, searchPattern, searchPattern])
            var actions: [Action] = []
            
            for row in rows {
                let targetMuscleIdsString = row[11] as? String
                let targetMuscleIds: [Int]
                if let idsString = targetMuscleIdsString, !idsString.isEmpty {
                    targetMuscleIds = idsString.split(separator: ",").compactMap { Int($0) }
                } else {
                    targetMuscleIds = []
                }
                
                let action = Action(
                    id: row[0] as? Int ?? 0,
                    external_id: row[1] as? String ?? "",
                    name: row[2] as? String ?? "",
                    name_en: row[3] as? String,
                    gifUrl: row[4] as? String,
                    description: row[5] as? String,
                    description_en: row[6] as? String,
                    difficulty: row[7] as? String,
                    bodypart_id: row[8] as? Int ?? 0,
                    equipment_id: row[9] as? Int,
                    is_bilateral: (row[10] as? Int ?? 0) == 1,
                    target_muscle_ids: targetMuscleIds
                )
                actions.append(action)
            }
            
            print("✅ LocalActionService: 搜索到 \(actions.count) 个动作，关键词: \(query)")
            return actions
            
        } catch {
            print("❌ LocalActionService: 搜索动作失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    // MARK: - ActionListViewModel需要的方法
    
    /// 根据筛选条件获取动作列表
    func getActions(filters: [String: Any] = [:]) async throws -> [Action] {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            var whereConditions: [String] = []
            
            // 处理目标肌肉筛选
            if let targetMuscleId = filters["target_muscle_id"] as? Int, targetMuscleId > 0 {
                whereConditions.append("EXISTS (SELECT 1 FROM action_target_muscle_link WHERE action_id = a.id AND target_muscle_id = \(targetMuscleId))")
            }
            
            // 处理器材筛选
            if let equipmentId = filters["equipment_id"] as? Int, equipmentId > 0 {
                whereConditions.append("a.equipment_id = \(equipmentId)")
            }
            
            // 处理身体部位筛选
            if let bodyPartId = filters["bodypart_id"] as? Int, bodyPartId > 0 {
                whereConditions.append("a.bodypart_id = \(bodyPartId)")
            }
            
            // 处理搜索文本
            if let searchText = filters["search"] as? String, !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                let trimmedText = searchText.trimmingCharacters(in: .whitespaces)
                whereConditions.append("(a.name LIKE '%\(trimmedText)%' OR a.name_en LIKE '%\(trimmedText)%')")
            }
            
            let whereClause = whereConditions.isEmpty ? "" : "WHERE " + whereConditions.joined(separator: " AND ")
            
            let sql = """
            SELECT 
                a.id,
                a.external_id,
                a.name,
                a.name_en,
                a.gifUrl,
                a.description,
                a.description_en,
                a.difficulty,
                a.bodypart_id,
                a.equipment_id,
                a.is_bilateral,
                GROUP_CONCAT(atml.target_muscle_id) as target_muscle_ids
            FROM action a
            LEFT JOIN action_target_muscle_link atml ON a.id = atml.action_id
            \(whereClause)
            GROUP BY a.id
            ORDER BY a.id
            """
            
            let rows = try db.prepare(sql)
            var actions: [Action] = []
            
            for row in rows {
                // 安全地解析每个字段，使用 Int64 处理数据库的 INTEGER 类型
                let actionId = row[0] as? Int64 ?? 0
                let externalId = row[1] as? String ?? ""
                let actionName = row[2] as? String ?? ""
                let nameEn = row[3] as? String
                let gifUrl = row[4] as? String
                let description = row[5] as? String
                let descriptionEn = row[6] as? String
                let difficulty = row[7] as? String
                let bodypartId = row[8] as? Int64 ?? 0
                let equipmentId = row[9] as? Int64  // 注意：可能为nil
                let isBilateral = row[10] as? Int64 ?? 0
                let targetMuscleIdsString = row[11] as? String
                
                // 解析目标肌肉ID
                let targetMuscleIds: [Int]
                if let idsString = targetMuscleIdsString, !idsString.isEmpty {
                    targetMuscleIds = idsString.split(separator: ",").compactMap { Int($0) }
                } else {
                    targetMuscleIds = []
                }
                
                let action = Action(
                    id: Int(actionId),
                    external_id: externalId,
                    name: actionName,
                    name_en: nameEn,
                    gifUrl: gifUrl ?? "",
                    description: description,
                    description_en: descriptionEn,
                    difficulty: difficulty,
                    bodypart_id: Int(bodypartId),
                    equipment_id: equipmentId != nil ? Int(equipmentId!) : nil,
                    is_bilateral: isBilateral == 1,
                    target_muscle_ids: targetMuscleIds
                )
                
                actions.append(action)
            }
            
            print("✅ LocalActionService: 成功获取 \(actions.count) 个动作")
            return actions
            
        } catch {
            print("❌ LocalActionService: 获取动作失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
    
    /// 获取目标肌肉列表 (兼容ActionListViewModel)
    func getTargetMuscles() async throws -> [TargetMuscle] {
        return try await fetchTargetMuscles()
    }
    
    /// 获取器材列表 (兼容ActionListViewModel)
    func getEquipments() async throws -> [Equipment] {
        return try await fetchEquipments()
    }
    
    /// 获取身体部位列表
    func getBodyParts() async throws -> [BodyPart] {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalActionError.databaseNotInitialized
        }
        
        do {
            let query = bodyPartTable.select(bodyPartId, bodyPartName, bodyPartDisplayName)
                .order(bodyPartId.asc)
            
            let rows = try db.prepare(query)
            var bodyParts: [BodyPart] = []
            
            for row in rows {
                let bodyPart = BodyPart(
                    id: row[bodyPartId],
                    name: row[bodyPartName],
                    display_name: row[bodyPartDisplayName] ?? row[bodyPartName]
                )
                bodyParts.append(bodyPart)
            }
            
            print("✅ LocalActionService: 成功获取 \(bodyParts.count) 个身体部位")
            return bodyParts
            
        } catch {
            print("❌ LocalActionService: 获取身体部位失败: \(error)")
            throw LocalActionError.queryFailed(error)
        }
    }
} 