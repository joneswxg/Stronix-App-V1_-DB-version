import Foundation
import SQLite

/// 本地训练历史服务类
/// 迁移自 Backend-Reference/src/stronix/services/TrainingHistoryService.py
/// 替换 Services/TrainingHistoryService.swift 中的网络调用

class LocalTrainingHistoryService {
    static let shared = LocalTrainingHistoryService()

    private let connectionProvider: () -> Connection?
    private let currentUserProvider: any CurrentUserProviding
    
    // MARK: - 数据库表定义（与Python代码保持一致）
    private let training_history = Table("training_history")
    private let training_history_details = Table("training_history_details")
    private let training_plans = Table("training_plans")
    private let plan_actions = Table("plan_actions")
    private let plan_sets = Table("plan_sets")
    private let action = Table("action")
    
    // training_history 表字段
    private let th_id = Expression<Int>("id")
    private let th_user_id = Expression<Int>("user_id")
    private let th_plan_id = Expression<Int?>("plan_id")
    private let th_session_id = Expression<Int>("session_id")
    private let th_plan_name = Expression<String>("plan_name")
    private let th_plan_description = Expression<String?>("plan_description")
    private let th_training_date = Expression<String>("training_date")
    private let th_volume = Expression<Double>("volume")
    private let th_duration = Expression<Int>("duration")
    private let th_note = Expression<String?>("note")
    private let th_created_at = Expression<String>("created_at")
    
    // training_history_details 表字段
    private let thd_id = Expression<Int>("id")
    private let thd_history_id = Expression<Int>("history_id")
    private let thd_action_id = Expression<Int>("action_id")
    private let thd_set_number = Expression<Int>("set_number")
    private let thd_weight = Expression<Double?>("weight")
    private let thd_weight_unit = Expression<String>("weight_unit")
    private let thd_reps = Expression<Int?>("reps")
    private let thd_difficulty = Expression<String?>("difficulty")
    private let thd_rir = Expression<Int?>("rir")
    private let thd_left_weight = Expression<Double?>("left_weight")
    private let thd_right_weight = Expression<Double?>("right_weight")
    private let thd_is_completed = Expression<Bool>("is_completed")
    private let thd_history_record_bilateral = Expression<Bool>("history_record_bilateral")
    
    // training_plans 表字段（用于验证）
    private let tp_id = Expression<Int>("id")
    private let tp_user_id = Expression<Int>("user_id")
    
    // plan_actions 表字段（用于更新计划）
    private let pa_plan_id = Expression<Int>("plan_id")
    private let pa_action_id = Expression<Int>("action_id")
    private let pa_order = Expression<Int>("order")
    private let pa_sets = Expression<Int>("sets")
    private let pa_weight = Expression<Double>("weight")
    private let pa_rest = Expression<Int>("rest")
    private let pa_note = Expression<String?>("note")
    private let pa_record_bilateral = Expression<Bool>("record_bilateral")
    
    // plan_sets 表字段（用于更新计划）
    private let ps_id = Expression<Int>("id")
    private let ps_plan_id = Expression<Int>("plan_id")
    private let ps_action_id = Expression<Int>("action_id")
    private let ps_set_number = Expression<Int>("set_number")
    private let ps_weight = Expression<Double>("weight")
    private let ps_reps = Expression<Int>("reps")
    private let ps_left_weight = Expression<Double>("left_weight")
    private let ps_right_weight = Expression<Double>("right_weight")
    
    // action 表字段（用于查询动作名称）
    private let a_id = Expression<Int>("id")
    private let a_name = Expression<String>("name")
    private let a_name_en = Expression<String?>("name_en")
    
    init(
        connectionProvider: @escaping () -> Connection? = { DatabaseManager.shared.getConnection() },
        currentUserProvider: any CurrentUserProviding = CurrentUserContext.shared
    ) {
        self.connectionProvider = connectionProvider
        self.currentUserProvider = currentUserProvider
    }

    private func currentUserID(_ providedUserID: Int?) throws -> Int {
        if let providedUserID {
            guard currentUserProvider.currentUserID == providedUserID else {
                throw LocalTrainingHistoryError.unauthorized("用户未登录")
            }
            return providedUserID
        }
        guard let currentUserID = currentUserProvider.currentUserID else {
            throw LocalTrainingHistoryError.unauthorized("用户未登录")
        }
        return currentUserID
    }
    
    // MARK: - 保存训练历史
    /// 保存训练历史
    /// 迁移自 Backend-Reference save_training_history
    func saveTrainingHistory(_ request: SaveTrainingHistoryRequest, user_id: Int? = nil, language: String = "zh_CN") async throws -> SaveTrainingHistoryResponse {
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        // 转换为本地请求模型
        let localRequest = LocalSaveTrainingHistoryRequest(from: request)
        
        // 验证必要字段
        if localRequest.plan_name.isEmpty || localRequest.training_date.isEmpty {
            print("❌ LocalTrainingHistoryService.saveTrainingHistory: 计划名称或训练日期为空。")
            throw LocalTrainingHistoryError.invalidTrainingData("计划名称和训练日期不能为空")
        }
        
        do {
            var historyId: Int = 0
            try db.transaction(.immediate) {
                let existingHistory = training_history
                    .filter(th_user_id == currentUserId && th_session_id == localRequest.session_id)
                    .select(th_id)
                    .limit(1)
                if let row = try db.pluck(existingHistory) {
                    historyId = row[th_id]
                    print("✅ 训练历史已存在，ID: \(historyId)")
                    return
                }

                // 如果有plan_id，验证计划是否存在且属于用户
                if let planId = localRequest.plan_id {
                    let planExists = try db.scalar(training_plans.filter(tp_id == planId && tp_user_id == currentUserId).count) > 0
                    if !planExists {
                        print("❌ LocalTrainingHistoryService.saveTrainingHistory: 训练计划(ID: \(planId))不存在或不属于当前用户。")
                        throw LocalTrainingHistoryError.planNotFound("训练计划不存在或不属于当前用户")
                    }
                }
                
                // 插入训练历史主记录
                let historyRowId = try db.run(training_history.insert(
                    th_user_id <- currentUserId,
                    th_plan_id <- localRequest.plan_id,
                    th_session_id <- localRequest.session_id,
                    th_plan_name <- localRequest.plan_name,
                    th_plan_description <- localRequest.plan_description,
                    th_training_date <- localRequest.training_date,
                    th_volume <- localRequest.volume,
                    th_duration <- localRequest.duration,
                    th_note <- localRequest.note,
                    th_created_at <- ISO8601DateFormatter().string(from: Date())
                ))
                
                // 插入训练历史详情
                for detail in localRequest.details {
                    try db.run(training_history_details.insert(
                        thd_history_id <- Int(historyRowId),
                        thd_action_id <- detail.action_id,
                        thd_set_number <- detail.set_number,
                        thd_weight <- detail.weight,
                        thd_weight_unit <- detail.weight_unit,
                        thd_reps <- detail.reps,
                        thd_difficulty <- detail.difficulty,
                        thd_rir <- detail.rir?.rawValue,
                        thd_left_weight <- detail.left_weight,
                        thd_right_weight <- detail.right_weight,
                        thd_is_completed <- detail.is_completed,
                        thd_history_record_bilateral <- detail.history_record_bilateral
                    ))
                }
                
                historyId = Int(historyRowId)
                print("✅ 训练历史保存成功，ID: \(historyId)")
            }
            
            return SaveTrainingHistoryResponse(history_id: historyId)
            
        } catch let error as LocalTrainingHistoryError {
            throw error
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("保存训练历史失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 从训练更新计划
    /// 从训练更新计划
    /// 迁移自 Backend-Reference update_plan_from_training
    func updatePlanFromTraining(planId: Int, request: UpdatePlanFromTrainingRequest, user_id: Int? = nil, language: String = "zh_CN") async throws {
        print("🔄 LocalTrainingHistoryService.updatePlanFromTraining 开始...")
        print("📋 计划ID: \(planId)")
        print("📝 计划名称: \(request.name)")
        print("🏃‍♂️ 动作数量: \(request.actions.count)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        // 转换为本地请求模型
        let localRequest = LocalUpdatePlanFromTrainingRequest(from: request)
        
        // 验证必要字段
        if localRequest.name.isEmpty {
            throw LocalTrainingHistoryError.invalidTrainingData("计划名称不能为空")
        }
        
        do {
            try db.transaction {
                // 验证计划是否存在且属于用户
                let planExists = try db.scalar(training_plans.filter(tp_id == planId && tp_user_id == currentUserId).count) > 0
                if !planExists {
                    throw LocalTrainingHistoryError.planNotFound("训练计划不存在或不属于当前用户")
                }
                
                // 更新训练计划基本信息
                let planTable = Table("training_plans")
                let tp_name = Expression<String>("name")
                let tp_description = Expression<String?>("description")
                let tp_difficulty = Expression<String?>("difficulty")
                let tp_duration = Expression<Int?>("duration")
                let tp_updated_at = Expression<String>("updated_at")
                
                try db.run(planTable.filter(tp_id == planId && tp_user_id == currentUserId).update(
                    tp_name <- localRequest.name,
                    tp_description <- localRequest.description,
                    tp_difficulty <- localRequest.difficulty,
                    tp_duration <- localRequest.duration,
                    tp_updated_at <- ISO8601DateFormatter().string(from: Date())
                ))
                
                // 删除现有的计划动作和组数据
                try db.run(plan_sets.filter(ps_plan_id == planId).delete())
                try db.run(plan_actions.filter(pa_plan_id == planId).delete())
                
                // 插入新的计划动作和组数据
                for action in localRequest.actions {
                    // 插入计划动作
                    try db.run(plan_actions.insert(
                        pa_plan_id <- planId,
                        pa_action_id <- action.action_id,
                        pa_order <- action.order,
                        pa_sets <- action.sets.count,
                        pa_weight <- actionVolume(action),
                        pa_rest <- action.rest,
                        pa_note <- action.note,
                        pa_record_bilateral <- action.record_bilateral
                    ))
                    
                    // 插入计划组数据
                    for setData in action.sets {
                        // 对于双侧训练，weight字段设置为0；对于普通训练，使用实际重量
                        let weightValue = action.record_bilateral ? 0.0 : (setData.weight ?? 0.0)
                        let leftWeightValue = setData.left_weight ?? 0.0
                        let rightWeightValue = setData.right_weight ?? 0.0
                        
                        try db.run(plan_sets.insert(
                            ps_plan_id <- planId,
                            ps_action_id <- action.action_id,
                            ps_set_number <- setData.order,
                            ps_weight <- weightValue,
                            ps_reps <- setData.reps,
                            ps_left_weight <- leftWeightValue,
                            ps_right_weight <- rightWeightValue
                        ))
                    }
                }
                
                print("✅ 训练计划更新成功")
            }
        } catch let error as LocalTrainingHistoryError {
            throw error
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("更新训练计划失败: \(error.localizedDescription)")
        }
    }
    
    private func actionVolume(_ action: LocalUpdatePlanActionFromTraining) -> Double {
        action.sets.reduce(0) { volume, set in
            let weight: Double
            if action.record_bilateral {
                weight = (set.left_weight ?? 0) + (set.right_weight ?? 0)
            } else {
                weight = set.weight ?? 0
            }
            return volume + weight * Double(set.reps)
        }
    }

    // MARK: - 获取训练历史列表
    /// 获取训练历史列表
    /// 迁移自 Backend-Reference get_training_history
    func getTrainingHistory(user_id: Int? = nil, page: Int = 1, limit: Int = 20, planId: Int? = nil, startDate: String? = nil, endDate: String? = nil, language: String = "zh_CN") async throws -> TrainingHistoryListResponse {
        print("🔍 LocalTrainingHistoryService.getTrainingHistory 调用参数: page=\(page), limit=\(limit), planId=\(planId ?? 0), startDate=\(startDate ?? ""), endDate=\(endDate ?? "")")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }
        
        let currentUserId = try currentUserID(user_id)
        
        do {
            // 使用SQLite.swift的类型安全查询方式
            var query = training_history.filter(th_user_id == currentUserId)
            
            if let planId = planId {
                query = query.filter(th_plan_id == planId)
                print("🔍 添加计划ID过滤: \(planId)")
            }
            
            // 对于日期过滤，我们需要使用原生SQL来使用DATE()函数
            var additionalConditions: [String] = []
            var additionalParams: [Binding?] = []
            
            if let startDate = startDate {
                additionalConditions.append("DATE(training_date) >= DATE(?)")
                additionalParams.append(startDate)
                print("🔍 添加开始日期过滤: DATE(training_date) >= DATE('\(startDate)')")
            }
            
            if let endDate = endDate {
                additionalConditions.append("DATE(training_date) <= DATE(?)")
                additionalParams.append(endDate)
                print("🔍 添加结束日期过滤: DATE(training_date) <= DATE('\(endDate)')")
            }
            
            var historyList: [TrainingHistoryItem] = []
            var total = 0
            
            if additionalConditions.isEmpty {
                // 如果没有日期条件，使用类型安全的SQLite.swift查询
                total = try db.scalar(query.count)
                let offset = (page - 1) * limit
                let histories = try db.prepare(query.order(th_training_date.desc, th_created_at.desc).limit(limit, offset: offset))
                
                for row in histories {
                    let historyItem = TrainingHistoryItem(
                        id: row[th_id],
                        plan_id: row[th_plan_id],
                        plan_name: row[th_plan_name],
                        training_date: row[th_training_date],
                        volume: row[th_volume],
                        duration: row[th_duration],
                        note: row[th_note],
                        created_at: row[th_created_at]
                    )
                    historyList.append(historyItem)
                    print("📝 找到记录: ID=\(historyItem.id), 计划=\(historyItem.plan_name), 日期=\(historyItem.training_date)")
                }
            } else {
                // 如果有日期条件，使用原生SQL
                var baseConditions = ["user_id = ?"]
                var allParams: [Binding?] = [currentUserId]
                
                if let planId = planId {
                    baseConditions.append("plan_id = ?")
                    allParams.append(planId)
                }
                
                baseConditions.append(contentsOf: additionalConditions)
                allParams.append(contentsOf: additionalParams)
                
                let whereClause = baseConditions.joined(separator: " AND ")
                print("🔍 查询条件: \(whereClause)")
                print("🔍 查询参数: \(allParams)")
                
                // 获取总数
                let countQuery = "SELECT COUNT(*) FROM training_history WHERE \(whereClause)"
                let countRows = try db.prepare(countQuery, allParams)
                for row in countRows {
                    total = Int(row[0] as? Int64 ?? 0)
                    break
                }
                print("🔍 查询到总记录数: \(total)")
                
                // 获取分页数据
                let offset = (page - 1) * limit
                let dataQuery = """
                    SELECT id, user_id, plan_id, session_id, plan_name, plan_description, 
                           training_date, volume, duration, note, created_at
                    FROM training_history 
                    WHERE \(whereClause)
                    ORDER BY training_date DESC, created_at DESC 
                    LIMIT \(limit) OFFSET \(offset)
                """
                
                let dataRows = try db.prepare(dataQuery, allParams)
                for row in dataRows {
                    // 安全检查：确保行数据包含足够的列
                    guard row.count >= 11 else {
                        print("⚠️ LocalTrainingHistoryService: 跳过不完整的行数据，列数: \(row.count)")
                        continue
                    }
                    
                    let historyItem = TrainingHistoryItem(
                        id: Int(row[0] as? Int64 ?? 0),
                        plan_id: row[2] as? Int64 != nil ? Int(row[2] as! Int64) : nil,
                        plan_name: row[4] as? String ?? "",
                        training_date: row[6] as? String ?? "",
                        volume: row[7] as? Double ?? 0.0,
                        duration: Int(row[8] as? Int64 ?? 0),
                        note: row[9] as? String,
                        created_at: row[10] as? String
                    )
                    historyList.append(historyItem)
                    print("📝 找到记录: ID=\(historyItem.id), 计划=\(historyItem.plan_name), 日期=\(historyItem.training_date)")
                }
            }
            
            let pagination = PaginationInfo(
                page: page,
                limit: limit,
                total: total,
                pages: (total + limit - 1) / limit
            )
            
            print("✅ 获取训练历史成功，共 \(historyList.count) 条记录")
            return TrainingHistoryListResponse(histories: historyList, pagination: pagination)
            
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("获取训练历史失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 获取训练日期列表
    /// 获取指定日期范围内有训练记录的日期列表
    /// 迁移自 Backend-Reference get_training_dates
    func getTrainingDates(startDate: String, endDate: String, user_id: Int? = nil, language: String = "zh_CN") async throws -> TrainingDatesResponse {
        print("🗓️ LocalTrainingHistoryService.getTrainingDates: \(startDate) 到 \(endDate)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 查询指定日期范围内的训练日期（去重）
            let query = """
                SELECT DISTINCT DATE(training_date) as training_date
                FROM training_history 
                WHERE user_id = ? AND DATE(training_date) BETWEEN DATE(?) AND DATE(?)
                ORDER BY training_date
            """
            
            var trainingDates: [String] = []
            
            let rows = try db.prepare(query, [currentUserId, startDate, endDate])
            for row in rows {
                if let dateString = row[0] as? String {
                    trainingDates.append(dateString)
                }
            }
            
            print("✅ 查询到训练日期: \(trainingDates)")
            
            return TrainingDatesResponse(
                training_dates: trainingDates,
                start_date: startDate,
                end_date: endDate,
                total_days: trainingDates.count
            )
            
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("获取训练日期失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 获取训练历史详情
    /// 获取训练历史详情
    /// 迁移自 Backend-Reference get_training_history_detail
    func getTrainingHistoryDetail(historyId: Int, user_id: Int? = nil, language: String = "zh_CN") async throws -> TrainingHistoryDetailResponse {
        print("🔄 LocalTrainingHistoryService.getTrainingHistoryDetail，ID: \(historyId)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 获取训练历史基本信息
            let historyQuery = training_history.filter(th_id == historyId && th_user_id == currentUserId)
            guard let historyRow = try db.pluck(historyQuery) else {
                throw LocalTrainingHistoryError.historyNotFound("训练历史不存在或不属于当前用户")
            }
            
            let history = TrainingHistoryItem(
                id: historyRow[th_id],
                plan_id: historyRow[th_plan_id],
                plan_name: historyRow[th_plan_name],
                training_date: historyRow[th_training_date],
                volume: historyRow[th_volume],
                duration: historyRow[th_duration],
                note: historyRow[th_note],
                created_at: historyRow[th_created_at]
            )
            
            // 获取训练历史详情（包含动作名称）
            let detailQuery = """
                SELECT thd.action_id, thd.set_number, thd.weight, thd.weight_unit,
                       thd.reps, thd.difficulty, thd.rir, thd.left_weight, thd.right_weight,
                       thd.is_completed, a.name as action_name, thd.history_record_bilateral
                FROM training_history_details thd
                LEFT JOIN action a ON thd.action_id = a.id
                WHERE thd.history_id = ?
                ORDER BY thd.action_id, thd.set_number
            """
            
            var details: [TrainingHistoryDetailItem] = []
            
            let detailRows = try db.prepare(detailQuery, [historyId])
            for row in detailRows {
                // 安全检查：确保行数据包含足够的列
                guard row.count >= 12 else {
                    print("⚠️ LocalTrainingHistoryService: 跳过不完整的详情行数据，列数: \(row.count)")
                    continue
                }
                
                let detail = TrainingHistoryDetailItem(
                    action_id: Int(row[0] as? Int64 ?? 0),
                    set_number: Int(row[1] as? Int64 ?? 0),
                    weight: row[2] as? Double,
                    weight_unit: row[3] as? String ?? "kg",
                    reps: row[4] as? Int64 != nil ? Int(row[4] as! Int64) : nil,
                    difficulty: row[5] as? String,
                    rir: (row[6] as? Int64).flatMap { SetRIR(rawValue: Int($0)) },
                    left_weight: row[7] as? Double,
                    right_weight: row[8] as? Double,
                    is_completed: (row[9] as? Int64 ?? 0) == 1,
                    action_name: row[10] as? String,
                    history_record_bilateral: (row[11] as? Int64 ?? 0) == 1
                )
                details.append(detail)
            }
            
            print("✅ 获取训练历史详情成功")
            return TrainingHistoryDetailResponse(history: history, details: details)
            
        } catch let error as LocalTrainingHistoryError {
            throw error
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("获取训练历史详情失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 更新训练历史
    /// 更新训练历史
    func updateTrainingHistory(historyId: Int, request: UpdateTrainingHistoryRequest, user_id: Int? = nil, language: String = "zh_CN") async throws {
        print("🔄 LocalTrainingHistoryService.updateTrainingHistory，ID: \(historyId)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            try db.transaction {
                // 验证训练历史是否存在且属于用户
                let historyExists = try db.scalar(training_history.filter(th_id == historyId && th_user_id == currentUserId).count) > 0
                if !historyExists {
                    throw LocalTrainingHistoryError.historyNotFound("训练历史不存在或不属于当前用户")
                }
                
                // 更新训练历史基本信息
                try db.run(training_history.filter(th_id == historyId && th_user_id == currentUserId).update(
                    th_training_date <- request.training_date,
                    th_volume <- request.volume ?? 0.0,
                    th_duration <- request.duration ?? 0,
                    th_note <- request.note
                ))
                
                // 如果有训练详情数据，更新训练详情
                if let details = request.details, !details.isEmpty {
                    // 删除现有的训练详情
                    try db.run(training_history_details.filter(thd_history_id == historyId).delete())
                    
                    // 插入新的训练详情
                    for detail in details {
                        try db.run(training_history_details.insert(
                            thd_history_id <- historyId,
                            thd_action_id <- detail.action_id,
                            thd_set_number <- detail.set_number,
                            thd_weight <- detail.weight,
                            thd_weight_unit <- detail.weight_unit,
                            thd_reps <- detail.reps,
                            thd_difficulty <- detail.difficulty,
                            thd_rir <- detail.rir?.rawValue,
                            thd_left_weight <- detail.left_weight,
                            thd_right_weight <- detail.right_weight,
                            thd_is_completed <- detail.is_completed,
                            thd_history_record_bilateral <- detail.history_record_bilateral
                        ))
                    }
                    print("✅ 训练详情更新成功，共 \(details.count) 条记录")
                }
                
                print("✅ 训练历史更新成功，ID: \(historyId)")
            }
        } catch let error as LocalTrainingHistoryError {
            throw error
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("更新训练历史失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 删除训练历史
    /// 删除训练历史
    /// 迁移自 Backend-Reference delete_training_history
    func deleteTrainingHistory(historyId: Int, user_id: Int? = nil, language: String = "zh_CN") async throws {
        print("🗑️ LocalTrainingHistoryService.deleteTrainingHistory，ID: \(historyId)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            try db.transaction {
                // 验证训练历史是否存在且属于用户
                let historyExists = try db.scalar(training_history.filter(th_id == historyId && th_user_id == currentUserId).count) > 0
                if !historyExists {
                    throw LocalTrainingHistoryError.historyNotFound("训练历史不存在或不属于当前用户")
                }
                
                // 删除训练历史详情
                try db.run(training_history_details.filter(thd_history_id == historyId).delete())
                
                // 删除训练历史主记录
                try db.run(training_history.filter(th_id == historyId && th_user_id == currentUserId).delete())
                
                print("✅ 训练历史删除成功，ID: \(historyId)")
            }
        } catch let error as LocalTrainingHistoryError {
            throw error
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("删除训练历史失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 获取训练统计数据
    /// 获取训练统计数据
    /// 迁移自 Backend-Reference get_training_statistics
    func getTrainingStatistics(timeRange: String = "week", user_id: Int? = nil, language: String = "zh_CN") async throws -> TrainingStatisticsResponse {
        print("📊 LocalTrainingHistoryService.getTrainingStatistics，时间范围: \(timeRange)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 根据时间范围构建完整的SQL查询
            let coreStatsQuery: String
            
            switch timeRange {
            case "week":
                coreStatsQuery = """
                    SELECT 
                        COUNT(*) as training_count,
                        COALESCE(SUM(volume), 0) as total_volume,
                        COALESCE(SUM(duration), 0) as total_duration
                    FROM training_history 
                    WHERE user_id = \(currentUserId) AND DATE(training_date) >= DATE('now', '-7 days')
                """
            case "month":
                coreStatsQuery = """
                    SELECT 
                        COUNT(*) as training_count,
                        COALESCE(SUM(volume), 0) as total_volume,
                        COALESCE(SUM(duration), 0) as total_duration
                    FROM training_history 
                    WHERE user_id = \(currentUserId) AND DATE(training_date) >= DATE('now', '-30 days')
                """
            case "year":
                coreStatsQuery = """
                    SELECT 
                        COUNT(*) as training_count,
                        COALESCE(SUM(volume), 0) as total_volume,
                        COALESCE(SUM(duration), 0) as total_duration
                    FROM training_history 
                    WHERE user_id = \(currentUserId) AND DATE(training_date) >= DATE('now', '-365 days')
                """
            case "current_month":
                coreStatsQuery = """
                    SELECT 
                        COUNT(*) as training_count,
                        COALESCE(SUM(volume), 0) as total_volume,
                        COALESCE(SUM(duration), 0) as total_duration
                    FROM training_history 
                    WHERE user_id = \(currentUserId) AND DATE(training_date) >= DATE('now', 'start of month')
                """
            case "current_year":
                coreStatsQuery = """
                    SELECT 
                        COUNT(*) as training_count,
                        COALESCE(SUM(volume), 0) as total_volume,
                        COALESCE(SUM(duration), 0) as total_duration
                    FROM training_history 
                    WHERE user_id = \(currentUserId) AND DATE(training_date) >= DATE('now', 'start of year')
                """
            default:
                coreStatsQuery = """
                    SELECT 
                        COUNT(*) as training_count,
                        COALESCE(SUM(volume), 0) as total_volume,
                        COALESCE(SUM(duration), 0) as total_duration
                    FROM training_history 
                    WHERE user_id = \(currentUserId)
                """
            }
            
            let statement = try db.prepare(coreStatsQuery)
            var trainingCount = 0
            var totalVolume = 0.0
            var totalDuration = 0
            
            for row in try statement.run() {
                // SQLite.swift可能返回Int64类型，需要转换
                if let count = row[0] as? Int64 {
                    trainingCount = Int(count)
                } else if let count = row[0] as? Int {
                    trainingCount = count
                } else {
                    trainingCount = 0
                }
                
                totalVolume = row[1] as? Double ?? 0.0
                
                let rawTotalDuration: Int
                if let duration = row[2] as? Int64 {
                    rawTotalDuration = Int(duration)
                } else if let duration = row[2] as? Int {
                    rawTotalDuration = duration
                } else {
                    rawTotalDuration = 0
                }
                
                // duration字段已经是分钟单位，直接使用
                totalDuration = rawTotalDuration
                print("📊 总时长: \(totalDuration)分钟")
                

                break // 只取第一行
            }
            
            // 获取连续训练天数（简化实现）
            let streakDays = try calculateTrainingStreak(db: db, userId: currentUserId)
            
            // 获取训练容量趋势数据
            let volumeTrend = try getVolumeTrend(db: db, userId: currentUserId, timeRange: timeRange)
            
            // 获取训练时长趋势数据
            let durationTrend = try getDurationTrend(db: db, userId: currentUserId, timeRange: timeRange)
            
            // 获取最常用训练计划
            let planUsage = try getPlanUsage(db: db, userId: currentUserId, timeRange: timeRange)
            
            let coreMetrics = CoreMetrics(
                training_count: trainingCount,
                total_volume: totalVolume,
                total_duration: totalDuration, // 已在SQL中转换为分钟
                streak_days: streakDays
            )
            
            print("✅ 统计数据获取成功: 训练次数=\(trainingCount), 总容量=\(totalVolume)kg, 总时长=\(totalDuration)分钟")
            
            return TrainingStatisticsResponse(
                core_metrics: coreMetrics,
                volume_trend: volumeTrend,
                duration_trend: durationTrend,
                plan_usage: planUsage,
                time_range: timeRange
            )
            
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("获取训练统计失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 辅助方法
    
    /// 计算连续训练天数
    private func calculateTrainingStreak(db: Connection, userId: Int) throws -> Int {
        // 简化实现：计算最近连续有训练记录的天数
        let query = """
            SELECT DISTINCT DATE(training_date) as training_date
            FROM training_history 
            WHERE user_id = ?
            ORDER BY training_date DESC
            LIMIT 30
        """
        
        let statement = try db.prepare(query)
        var dates: [String] = []
        
        for row in try statement.run([userId]) {
            if let dateString = row[0] as? String {
                dates.append(dateString)
            }
        }
        
        // 计算连续天数（简化逻辑）
        var streak = 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for (index, dateString) in dates.enumerated() {
            if index == 0 {
                streak = 1
                continue
            }
            
            guard let currentDate = dateFormatter.date(from: dateString),
                  let previousDate = dateFormatter.date(from: dates[index - 1]) else {
                break
            }
            
            let daysDifference = Calendar.current.dateComponents([.day], from: currentDate, to: previousDate).day ?? 0
            
            if daysDifference == 1 {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    /// 获取训练容量趋势数据
    private func getVolumeTrend(db: Connection, userId: Int, timeRange: String) throws -> [VolumeTrendData] {
        let query: String
        let queryParams: [Int]
        
        switch timeRange {
        case "week":
            // 按天分组，基于当前日期的最近7天
            query = """
                SELECT 
                    DATE(training_date) as date,
                    COALESCE(SUM(volume), 0) as volume
                FROM training_history 
                WHERE user_id = ? AND DATE(training_date) >= DATE('now', '-7 days')
                GROUP BY DATE(training_date)
                ORDER BY date
            """
            queryParams = [userId]
        case "month":
            // 按周分组，基于当前日期的最近30天
            query = """
                SELECT 
                    DATE(training_date, 'weekday 0', '-6 days') as week_start,
                    COALESCE(SUM(volume), 0) as volume
                FROM training_history 
                WHERE user_id = ? AND DATE(training_date) >= DATE('now', '-30 days')
                GROUP BY week_start
                ORDER BY week_start
            """
            queryParams = [userId]
        case "year":
            // 按月分组，基于当前日期的最近365天
            query = """
                SELECT 
                    DATE(training_date, 'start of month') as month_start,
                    COALESCE(SUM(volume), 0) as volume
                FROM training_history 
                WHERE user_id = ? AND DATE(training_date) >= DATE('now', '-365 days')
                GROUP BY month_start
                ORDER BY month_start
            """
            queryParams = [userId]
        case "current_month":
            // 按天分组，基于当前自然月
            query = """
                SELECT 
                    DATE(training_date) as date,
                    COALESCE(SUM(volume), 0) as volume
                FROM training_history 
                WHERE user_id = ? AND DATE(training_date) >= DATE('now', 'start of month')
                GROUP BY DATE(training_date)
                ORDER BY date
            """
            queryParams = [userId]
        case "current_year":
            // 按月分组，基于当前自然年
            query = """
                SELECT 
                    DATE(training_date, 'start of month') as month_start,
                    COALESCE(SUM(volume), 0) as volume
                FROM training_history 
                WHERE user_id = ? AND DATE(training_date) >= DATE('now', 'start of year')
                GROUP BY month_start
                ORDER BY month_start
            """
            queryParams = [userId]
        default:
            // 按月分组，基于当前日期的最近365天
            query = """
                SELECT 
                    DATE(training_date, 'start of month') as month_start,
                    COALESCE(SUM(volume), 0) as volume
                FROM training_history 
                WHERE user_id = ? AND DATE(training_date) >= DATE('now', '-365 days')
                GROUP BY month_start
                ORDER BY month_start
            """
            queryParams = [userId]
        }
        
        let statement = try db.prepare(query)
        var trendData: [VolumeTrendData] = []
        
        for row in try statement.run(queryParams) {
            let trend = VolumeTrendData(
                date: row[0] as? String ?? "",
                volume: row[1] as? Double ?? 0.0
            )
            trendData.append(trend)
        }
        
        return trendData
    }
    
    /// 获取训练时长趋势数据
    private func getDurationTrend(db: Connection, userId: Int, timeRange: String) throws -> [DurationTrendData] {
        
        let query: String
        
        switch timeRange {
        case "week":
            // 直接查询原始数据，不使用GROUP BY
            query = """
                SELECT 
                    DATE(training_date) as date,
                    duration
                FROM training_history 
                WHERE user_id = \(userId) AND DATE(training_date) >= DATE('now', '-7 days')
                ORDER BY date
            """
        case "month":
            query = """
                SELECT 
                    DATE(training_date) as date,
                    duration
                FROM training_history 
                WHERE user_id = \(userId) AND DATE(training_date) >= DATE('now', '-30 days')
                ORDER BY date
            """
        case "year":
            query = """
                SELECT 
                    DATE(training_date, 'start of month') as month_start,
                    duration
                FROM training_history 
                WHERE user_id = \(userId) AND DATE(training_date) >= DATE('now', '-365 days')
                ORDER BY month_start
            """
        case "current_month":
            query = """
                SELECT 
                    DATE(training_date) as date,
                    duration
                FROM training_history 
                WHERE user_id = \(userId) AND DATE(training_date) >= DATE('now', 'start of month')
                ORDER BY date
            """
        case "current_year":
            query = """
                SELECT 
                    DATE(training_date, 'start of month') as month_start,
                    duration
                FROM training_history 
                WHERE user_id = \(userId) AND DATE(training_date) >= DATE('now', 'start of year')
                ORDER BY month_start
            """
        default:
            query = """
                SELECT 
                    DATE(training_date, 'start of month') as month_start,
                    duration
                FROM training_history 
                WHERE user_id = \(userId) AND DATE(training_date) >= DATE('now', '-365 days')
                ORDER BY month_start
            """
        }
        
        let statement = try db.prepare(query)
        var dateToTotalDuration: [String: Int] = [:]
        
        for row in try statement.run() {
            let date = row[0] as? String ?? ""
            
            // 优化的类型转换逻辑
            var rawDuration: Int = 0
            if let intValue = row[1] as? Int {
                rawDuration = intValue
            } else if let int64Value = row[1] as? Int64 {
                rawDuration = Int(int64Value)
            } else if let stringValue = row[1] as? String, let intValue = Int(stringValue) {
                rawDuration = intValue
            }
            
            // duration字段已经是分钟单位，直接使用
            let duration = rawDuration
            
            // 在Swift中进行聚合
            dateToTotalDuration[date, default: 0] += duration
        }
        
        // 转换为DurationTrendData数组
        var trendData: [DurationTrendData] = []
        for (date, totalDuration) in dateToTotalDuration.sorted(by: { $0.key < $1.key }) {
            let trend = DurationTrendData(
                date: date,
                duration: totalDuration
            )
            trendData.append(trend)
        }
        
        return trendData
    }
    
    /// 获取最常用训练计划
    private func getPlanUsage(db: Connection, userId: Int, timeRange: String) throws -> [PlanUsageDataAPI] {
        let dateFilter: String
        switch timeRange {
        case "week":
            dateFilter = "DATE(training_date) >= DATE('now', '-7 days')"
        case "month":
            dateFilter = "DATE(training_date) >= DATE('now', '-30 days')"
        case "year":
            dateFilter = "DATE(training_date) >= DATE('now', '-365 days')"
        case "current_month":
            dateFilter = "DATE(training_date) >= DATE('now', 'start of month')"
        case "current_year":
            dateFilter = "DATE(training_date) >= DATE('now', 'start of year')"
        default:
            dateFilter = "1=1"
        }
        
        let query = """
            SELECT 
                plan_name,
                COUNT(*) as usage_count,
                COALESCE(SUM(volume), 0) as total_volume
            FROM training_history 
            WHERE user_id = ? AND \(dateFilter)
            GROUP BY plan_name
            ORDER BY usage_count DESC
            LIMIT 5
        """
        
        let statement = try db.prepare(query)
        var planUsageData: [PlanUsageDataAPI] = []
        
        for row in try statement.run([userId]) {
            let planUsage = PlanUsageDataAPI(
                plan_name: row[0] as? String ?? "",
                count: row[1] as? Int ?? 0,
                percentage: Int((row[2] as? Double ?? 0.0) / 100.0)
            )
            planUsageData.append(planUsage)
        }
        
        return planUsageData
    }
    
    /// 获取按身体部位和周统计的训练容量数据
    func getWeeklyVolumeByBodyPart(bodyPart: String, user_id: Int? = nil, language: String = "zh_CN") async throws -> [VolumeTrendData] {
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 按周分组，获取过去10周的数据，按身体部位筛选
            let query = """
                SELECT 
                    DATE(th.training_date, 'weekday 0', '-6 days') as week_start,
                    COALESCE(SUM(th.volume), 0) as volume
                FROM training_history th
                JOIN training_history_details thd ON th.id = thd.history_id
                JOIN action a ON thd.action_id = a.id
                JOIN body_part bp ON a.bodypart_id = bp.id
                WHERE th.user_id = ? 
                    AND DATE(th.training_date) >= DATE('now', '-70 days')
                    AND bp.display_name = ?
                GROUP BY week_start
                ORDER BY week_start
            """
            
            let statement = try db.prepare(query)
            var trendData: [VolumeTrendData] = []
            
            for row in try statement.run([currentUserId, bodyPart]) {
                let trend = VolumeTrendData(
                    date: row[0] as? String ?? "",
                    volume: row[1] as? Double ?? 0.0
                )
                trendData.append(trend)
            }
            
            return trendData
        } catch {
            print("❌ 获取周训练容量数据失败: \(error)")
            throw LocalTrainingHistoryError.serverError("获取周训练容量数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取按身体部位和周统计的训练时长数据
    func getWeeklyDurationByBodyPart(bodyPart: String, user_id: Int? = nil, language: String = "zh_CN") async throws -> [DurationTrendData] {
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 按周分组，获取过去10周的数据，按身体部位筛选
            let query = """
                SELECT 
                    DATE(th.training_date, 'weekday 0', '-6 days') as week_start,
                    COALESCE(SUM(th.duration), 0) as duration
                FROM training_history th
                JOIN training_history_details thd ON th.id = thd.history_id
                JOIN action a ON thd.action_id = a.id
                JOIN body_part bp ON a.bodypart_id = bp.id
                WHERE th.user_id = ? 
                    AND DATE(th.training_date) >= DATE('now', '-70 days')
                    AND bp.display_name = ?
                GROUP BY week_start
                ORDER BY week_start
            """
            
            let statement = try db.prepare(query)
            var trendData: [DurationTrendData] = []
            
            for row in try statement.run([currentUserId, bodyPart]) {
                let trend = DurationTrendData(
                    date: row[0] as? String ?? "",
                    duration: row[1] as? Int ?? 0
                )
                trendData.append(trend)
            }
            
            return trendData
        } catch {
            print("❌ 获取周训练时长数据失败: \(error)")
            throw LocalTrainingHistoryError.serverError("获取周训练时长数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取按身体部位和月统计的训练容量数据
    func getMonthlyVolumeByBodyPart(bodyPart: String, year: Int, user_id: Int? = nil, language: String = "zh_CN") async throws -> [VolumeTrendData] {
        print("📊 LocalTrainingHistoryService.getMonthlyVolumeByBodyPart: \(bodyPart), year: \(year)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 构建SQL查询，按月统计指定年份的训练容量
            let query = """
                SELECT 
                    strftime('%m', th.training_date) as month,
                    SUM(thd.weight * thd.reps) as total_volume
                FROM training_history th
                JOIN training_history_details thd ON th.id = thd.history_id
                JOIN action a ON thd.action_id = a.id
                JOIN body_part bp ON a.body_part_id = bp.id
                WHERE th.user_id = ? 
                    AND bp.name = ? 
                    AND strftime('%Y', th.training_date) = ?
                    AND thd.is_completed = 1
                    AND thd.weight IS NOT NULL 
                    AND thd.reps IS NOT NULL
                GROUP BY strftime('%m', th.training_date)
                ORDER BY month
            """
            
            let statement = try db.prepare(query)
            var trendData: [VolumeTrendData] = []
            
            // 创建一个包含所有月份的字典，初始值为0
            var monthlyData: [String: Double] = [:]
            for month in 1...12 {
                let monthStr = String(format: "%02d", month)
                monthlyData[monthStr] = 0.0
            }
            
            // 填充实际数据
            for row in try statement.run([currentUserId, bodyPart, String(year)]) {
                let month = row[0] as? String ?? ""
                let volume = row[1] as? Double ?? 0.0
                monthlyData[month] = volume
            }
            
            // 转换为TrendData格式
            for month in 1...12 {
                let monthStr = String(format: "%02d", month)
                let dateStr = "\(year)-\(monthStr)-01"
                let volume = monthlyData[monthStr] ?? 0.0
                
                let trend = VolumeTrendData(
                    date: dateStr,
                    volume: volume
                )
                trendData.append(trend)
            }
            
            return trendData
        } catch {
            print("❌ 获取月训练容量数据失败: \(error)")
            throw LocalTrainingHistoryError.serverError("获取月训练容量数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取按身体部位和月统计的训练时长数据
    func getMonthlyDurationByBodyPart(bodyPart: String, year: Int, user_id: Int? = nil, language: String = "zh_CN") async throws -> [DurationTrendData] {
        print("📊 LocalTrainingHistoryService.getMonthlyDurationByBodyPart: \(bodyPart), year: \(year)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 构建SQL查询，按月统计指定年份的训练时长
            let query = """
                SELECT 
                    strftime('%m', th.training_date) as month,
                    SUM(th.duration) as total_duration
                FROM training_history th
                JOIN training_history_details thd ON th.id = thd.history_id
                JOIN action a ON thd.action_id = a.id
                JOIN body_part bp ON a.body_part_id = bp.id
                WHERE th.user_id = ? 
                    AND bp.name = ? 
                    AND strftime('%Y', th.training_date) = ?
                    AND thd.is_completed = 1
                GROUP BY strftime('%m', th.training_date)
                ORDER BY month
            """
            
            let statement = try db.prepare(query)
            var trendData: [DurationTrendData] = []
            
            // 创建一个包含所有月份的字典，初始值为0
            var monthlyData: [String: Int] = [:]
            for month in 1...12 {
                let monthStr = String(format: "%02d", month)
                monthlyData[monthStr] = 0
            }
            
            // 填充实际数据
            for row in try statement.run([currentUserId, bodyPart, String(year)]) {
                let month = row[0] as? String ?? ""
                let duration = row[1] as? Int ?? 0
                monthlyData[month] = duration
            }
            
            // 转换为TrendData格式
            for month in 1...12 {
                let monthStr = String(format: "%02d", month)
                let dateStr = "\(year)-\(monthStr)-01"
                let duration = monthlyData[monthStr] ?? 0
                
                let trend = DurationTrendData(
                    date: dateStr,
                    duration: duration
                )
                trendData.append(trend)
            }
            
            return trendData
        } catch {
            print("❌ 获取月训练时长数据失败: \(error)")
            throw LocalTrainingHistoryError.serverError("获取月训练时长数据失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 获取动作进步数据（可选实现）
    /// 获取特定动作的进步数据
    /// 迁移自 Backend-Reference get_action_progress
    func getActionProgress(actionName: String, user_id: Int? = nil, language: String = "zh_CN") async throws -> ActionProgressResponse {
        print("💪 LocalTrainingHistoryService.getActionProgress: \(actionName)")
        
        guard let db = connectionProvider() else {
            throw LocalTrainingHistoryError.databaseNotInitialized
        }

        let currentUserId = try currentUserID(user_id)
        
        do {
            // 查找动作ID（模糊匹配动作名称）
            let actionQuery = action.filter(a_name.like("%\(actionName)%"))
            guard let actionRow = try db.pluck(actionQuery) else {
                // 如果没有找到动作，返回空数据
                return ActionProgressResponse(
                    action_name: actionName,
                    current_record: ActionRecord(max_weight: 0.0, date: "", max_reps: 0),
                    best_record: ActionRecord(max_weight: 0.0, date: "", max_reps: 0),
                    progress_data: []
                )
            }
            
            let actionId = actionRow[a_id]
            
            // 获取该动作的历史记录
            let progressQuery = """
                SELECT 
                    th.training_date,
                    MAX(thd.weight) as max_weight,
                    SUM(thd.weight * thd.reps) as total_volume,
                    MAX(thd.reps) as max_reps
                FROM training_history th
                JOIN training_history_details thd ON th.id = thd.history_id
                WHERE th.user_id = ? AND thd.action_id = ? AND thd.is_completed = 1
                GROUP BY DATE(th.training_date)
                ORDER BY th.training_date
            """
            
            let statement = try db.prepare(progressQuery)
            var progressData: [ProgressData] = []
            var maxWeight: Double = 0
            var maxReps: Int = 0
            var bestDate: String = ""
            
            for row in try statement.run([currentUserId, actionId]) {
                let date = row[0] as? String ?? ""
                let weight = row[1] as? Double ?? 0.0
                let volume = row[2] as? Double ?? 0.0
                let reps = row[3] as? Int ?? 0
                
                let progress = ProgressData(
                    date: date,
                    max_weight: weight,
                    total_volume: volume,
                    max_reps: reps
                )
                progressData.append(progress)
                
                // 更新个人记录
                if weight > maxWeight {
                    maxWeight = weight
                    bestDate = date
                }
                if reps > maxReps {
                    maxReps = reps
                }
            }
            
            let currentRecord = ActionRecord(
                max_weight: maxWeight,
                date: bestDate,
                max_reps: maxReps
            )
            
            print("✅ 获取动作进步数据成功")
            return ActionProgressResponse(
                action_name: actionName,
                current_record: currentRecord,
                best_record: currentRecord,
                progress_data: progressData
            )
            
        } catch {
            print("❌ 数据库错误: \(error)")
            throw LocalTrainingHistoryError.serverError("获取动作进步数据失败: \(error.localizedDescription)")
        }
    }
}