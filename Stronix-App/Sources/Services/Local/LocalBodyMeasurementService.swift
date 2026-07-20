import Foundation
import SQLite
import SwiftUI

/// 本地身体测量服务类
/// 迁移自 Backend-Reference/src/stronix/services/BodyMeasurementService.py
/// 替换 Services/Network/ 中身体测量相关的网络调用

class LocalBodyMeasurementService: ObservableObject {
    
    // MARK: - 单例模式
    static let shared = LocalBodyMeasurementService()
    
    // MARK: - 发布属性
    @Published var measurements: [BodyMeasurement] = []
    @Published var isLoading = false
    @Published var latestMeasurement: BodyMeasurement?
    
    // MARK: - 私有属性
    private let databaseManager = DatabaseManager.shared
    
    // 数据库表结构
    private let bodyMeasurementsTable = Table("body_measurements")
    private let id = Expression<Int>("id")
    private let userId = Expression<Int>("user_id")
    private let measurementTimestamp = Expression<String>("measurement_timestamp")
    private let weightKg = Expression<Double>("weight_kg")
    private let heightCm = Expression<Double>("height_cm")
    private let bodyFatPercentage = Expression<Double>("body_fat_percentage")
    private let skeletalMuscleMassKg = Expression<Double>("skeletal_muscle_mass_kg")
    private let visceralFatLevel = Expression<Int>("visceral_fat_level")
    private let createdAt = Expression<String>("created_at")
    private let updatedAt = Expression<String>("updated_at")
    
    private init() {
        initializeDatabase()
        initializeTestData()
    }
    
    // MARK: - 数据库初始化
    private func initializeDatabase() {
        guard let db = databaseManager.getConnection() else {
            print("❌ LocalBodyMeasurementService: 数据库连接失败")
            return
        }
        
        do {
            // 创建body_measurements表
            try db.run(bodyMeasurementsTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(userId)
                t.column(measurementTimestamp)
                t.column(weightKg)
                t.column(heightCm)
                t.column(bodyFatPercentage)
                t.column(skeletalMuscleMassKg)
                t.column(visceralFatLevel)
                t.column(createdAt, defaultValue: "datetime('now')")
                t.column(updatedAt, defaultValue: "datetime('now')")
                
                // 创建索引
                t.foreignKey(userId, references: Table("user"), Expression<Int>("id"))
            })
            
            // 创建索引以提高查询性能
            try db.run("CREATE INDEX IF NOT EXISTS idx_body_measurements_user_id ON body_measurements(user_id)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_body_measurements_timestamp ON body_measurements(measurement_timestamp)")
            
            print("✅ LocalBodyMeasurementService: body_measurements表初始化成功")
            
        } catch {
            print("❌ LocalBodyMeasurementService: 数据库表创建失败: \(error)")
        }
    }
    
    // MARK: - CRUD 操作
    
    /// 创建新的体测记录
    func createMeasurement(_ request: CreateBodyMeasurementRequest) async throws -> BodyMeasurementResponse {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalBodyMeasurementError.databaseNotInitialized
        }
        
        do {
            let timestampString = ISO8601DateFormatter().string(from: request.measurementTimestamp)
            
            let insert = bodyMeasurementsTable.insert(
                userId <- request.userId,
                measurementTimestamp <- timestampString,
                weightKg <- request.weightKg,
                heightCm <- request.heightCm,
                bodyFatPercentage <- request.bodyFatPercentage,
                skeletalMuscleMassKg <- request.skeletalMuscleMassKg,
                visceralFatLevel <- request.visceralFatLevel,
                createdAt <- ISO8601DateFormatter().string(from: Date()),
                updatedAt <- ISO8601DateFormatter().string(from: Date())
            )
            
            let measurementId = try db.run(insert)
            
            print("✅ LocalBodyMeasurementService: 创建体测记录成功，ID: \(measurementId)")
            
            // 更新缓存
            await refreshUserMeasurements(userId: request.userId)
            
            return BodyMeasurementResponse(
                success: true,
                message: "体测记录创建成功",
                measurementId: Int(measurementId)
            )
            
        } catch {
            print("❌ LocalBodyMeasurementService: 创建体测记录失败: \(error)")
            throw LocalBodyMeasurementError.createFailed(error)
        }
    }
    
    /// 获取用户的体测记录
    func getUserMeasurements(_ query: BodyMeasurementQuery) async throws -> BodyMeasurementListResponse {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalBodyMeasurementError.databaseNotInitialized
        }
        
        do {
            // 构建查询
            var baseQuery = bodyMeasurementsTable.filter(userId == query.userId)
            
            // 添加日期范围过滤
            if let startDate = query.startDate {
                let startDateString = ISO8601DateFormatter().string(from: startDate)
                baseQuery = baseQuery.filter(measurementTimestamp >= startDateString)
            }
            
            if let endDate = query.endDate {
                let endDateString = ISO8601DateFormatter().string(from: endDate)
                baseQuery = baseQuery.filter(measurementTimestamp <= endDateString)
            }
            
            // 获取总数
            let totalCount = try db.scalar(baseQuery.count)
            
            // 添加排序
            let orderedQuery: QueryType
            if query.orderDirection.uppercased() == "ASC" {
                orderedQuery = baseQuery.order(measurementTimestamp.asc)
            } else {
                orderedQuery = baseQuery.order(measurementTimestamp.desc)
            }
            
            // 添加分页
            var finalQuery = orderedQuery
            if let limit = query.limit {
                if let offset = query.offset {
                    finalQuery = finalQuery.limit(limit, offset: offset)
                } else {
                    finalQuery = finalQuery.limit(limit)
                }
            }
            
            // 执行查询
            let rows = try db.prepare(finalQuery)
            var measurements: [BodyMeasurement] = []
            
            for row in rows {
                let measurement = try convertRowToMeasurement(row)
                measurements.append(measurement)
            }
            
            print("✅ LocalBodyMeasurementService: 获取用户 \(query.userId) 体测记录成功，共 \(measurements.count) 条")
            
            return BodyMeasurementListResponse(
                measurements: measurements,
                totalCount: totalCount
            )
            
        } catch {
            print("❌ LocalBodyMeasurementService: 获取体测记录失败: \(error)")
            throw LocalBodyMeasurementError.queryFailed(error)
        }
    }
    
    /// 根据ID获取单条体测记录
    func getMeasurementById(_ measurementId: Int) async throws -> BodyMeasurement? {
        guard let db = databaseManager.getConnection() else {
            throw LocalBodyMeasurementError.databaseNotInitialized
        }
        
        do {
            let query = bodyMeasurementsTable.filter(id == measurementId)
            
            if let row = try db.pluck(query) {
                return try convertRowToMeasurement(row)
            }
            
            return nil
            
        } catch {
            print("❌ LocalBodyMeasurementService: 获取体测记录详情失败: \(error)")
            throw LocalBodyMeasurementError.queryFailed(error)
        }
    }
    
    /// 更新体测记录
    func updateMeasurement(_ measurementId: Int, _ request: UpdateBodyMeasurementRequest) async throws -> BodyMeasurementResponse {
        await MainActor.run {
            self.isLoading = true
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard let db = databaseManager.getConnection() else {
            throw LocalBodyMeasurementError.databaseNotInitialized
        }
        
        do {
            let measurementQuery = bodyMeasurementsTable.filter(id == measurementId)
            
            // 构建更新字段
            var setters: [Setter] = [updatedAt <- ISO8601DateFormatter().string(from: Date())]
            
            if let weight = request.weightKg {
                setters.append(weightKg <- weight)
            }
            if let height = request.heightCm {
                setters.append(heightCm <- height)
            }
            if let bodyFat = request.bodyFatPercentage {
                setters.append(bodyFatPercentage <- bodyFat)
            }
            if let muscleMass = request.skeletalMuscleMassKg {
                setters.append(skeletalMuscleMassKg <- muscleMass)
            }
            if let visceralFat = request.visceralFatLevel {
                setters.append(visceralFatLevel <- visceralFat)
            }
            
            let updateCount = try db.run(measurementQuery.update(setters))
            
            if updateCount > 0 {
                print("✅ LocalBodyMeasurementService: 更新体测记录成功，ID: \(measurementId)")
                return BodyMeasurementResponse(
                    success: true,
                    message: "体测记录更新成功",
                    measurementId: measurementId
                )
            } else {
                throw LocalBodyMeasurementError.recordNotFound
            }
            
        } catch {
            print("❌ LocalBodyMeasurementService: 更新体测记录失败: \(error)")
            throw LocalBodyMeasurementError.updateFailed(error)
        }
    }
    
    /// 删除体测记录
    func deleteMeasurement(_ measurementId: Int) async throws -> BodyMeasurementResponse {
        guard let db = databaseManager.getConnection() else {
            throw LocalBodyMeasurementError.databaseNotInitialized
        }
        
        do {
            let measurementQuery = bodyMeasurementsTable.filter(id == measurementId)
            let deleteCount = try db.run(measurementQuery.delete())
            
            if deleteCount > 0 {
                print("✅ LocalBodyMeasurementService: 删除体测记录成功，ID: \(measurementId)")
                return BodyMeasurementResponse(
                    success: true,
                    message: "体测记录删除成功",
                    measurementId: measurementId
                )
            } else {
                throw LocalBodyMeasurementError.recordNotFound
            }
            
        } catch {
            print("❌ LocalBodyMeasurementService: 删除体测记录失败: \(error)")
            throw LocalBodyMeasurementError.deleteFailed(error)
        }
    }
    
    // MARK: - 统计分析
    
    /// 获取用户体测数据统计
    func getUserStatistics(userId: Int, days: Int = 30) async throws -> BodyMeasurementStatistics {
        guard let db = databaseManager.getConnection() else {
            throw LocalBodyMeasurementError.databaseNotInitialized
        }
        
        do {
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let startDateString = ISO8601DateFormatter().string(from: startDate)
            
            // 获取指定时间范围内的记录
            let query = bodyMeasurementsTable
                .filter(self.userId == userId)
                .filter(measurementTimestamp >= startDateString)
                .order(measurementTimestamp.desc)
            
            let rows = try db.prepare(query)
            var measurements: [BodyMeasurement] = []
            
            for row in rows {
                let measurement = try convertRowToMeasurement(row)
                measurements.append(measurement)
            }
            
            // 计算统计数据
            let latestMeasurement = measurements.first
            var weightTrend: Double? = nil
            var bodyFatTrend: Double? = nil
            var muscleMassTrend: Double? = nil
            
            if measurements.count >= 2 {
                let first = measurements.last!  // 最早的记录
                let latest = measurements.first! // 最新的记录
                
                weightTrend = latest.weightKg - first.weightKg
                bodyFatTrend = latest.bodyFatPercentage - first.bodyFatPercentage
                muscleMassTrend = latest.skeletalMuscleMassKg - first.skeletalMuscleMassKg
            }
            
            return BodyMeasurementStatistics(
                latestMeasurement: latestMeasurement,
                weightTrend: weightTrend,
                bodyFatTrend: bodyFatTrend,
                muscleMassTrend: muscleMassTrend,
                measurementCount: measurements.count,
                dateRangeDays: days
            )
            
        } catch {
            print("❌ LocalBodyMeasurementService: 获取统计数据失败: \(error)")
            throw LocalBodyMeasurementError.queryFailed(error)
        }
    }
    
    // MARK: - 辅助方法
    
    /// 刷新指定用户的测量记录缓存
    private func refreshUserMeasurements(userId: Int) async {
        do {
            let query = BodyMeasurementQuery(userId: userId, limit: 50)
            let response = try await getUserMeasurements(query)
            
            await MainActor.run {
                self.measurements = response.measurements
                self.latestMeasurement = response.measurements.first
            }
        } catch {
            print("❌ LocalBodyMeasurementService: 刷新缓存失败: \(error)")
        }
    }
    
    /// 将数据库行转换为BodyMeasurement对象
    private func convertRowToMeasurement(_ row: Row) throws -> BodyMeasurement {
        let timestampString = row[measurementTimestamp]
        let createdAtString = row[createdAt]
        let updatedAtString = row[updatedAt]
        
        func parseDate(_ dateString: String) -> Date? {
            // 先尝试 ISO8601 格式
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // 再尝试其他常见格式
            let dateFormats = [
                "yyyy-MM-dd HH:mm:ss",  // SQLite datetime 格式
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",  // 带微秒的ISO格式
                "yyyy-MM-dd'T'HH:mm:ss"  // 标准ISO格式
            ]
            
            for format in dateFormats {
                let formatter = createDateFormatter(format: format)
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            return nil
        }
        
        guard let timestamp = parseDate(timestampString),
              let createdDate = parseDate(createdAtString),
              let updatedDate = parseDate(updatedAtString) else {
            print("❌ 日期转换失败:")
            print("  measurementTimestamp: '\(timestampString)'")
            print("  createdAt: '\(createdAtString)'")
            print("  updatedAt: '\(updatedAtString)'")
            throw LocalBodyMeasurementError.dateConversionFailed
        }
        
        return BodyMeasurement(
            id: row[id],
            userId: row[userId],
            measurementTimestamp: timestamp,
            weightKg: row[weightKg],
            heightCm: row[heightCm],
            bodyFatPercentage: row[bodyFatPercentage],
            skeletalMuscleMassKg: row[skeletalMuscleMassKg],
            visceralFatLevel: row[visceralFatLevel],
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
    
    /// 创建日期格式器的辅助方法
    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone.current
        return formatter
    }
    
    // MARK: - 初始化测试数据
    private func initializeTestData() {
        // 检查是否已有测试数据
        guard let db = databaseManager.getConnection() else { return }
        
        do {
            let count = try db.scalar(bodyMeasurementsTable.count)
            if count == 0 {
                // 创建一些测试数据
                createTestMeasurements()
            }
        } catch {
            print("❌ LocalBodyMeasurementService: 检查测试数据失败: \(error)")
        }
    }
    
    private func createTestMeasurements() {
        // 为测试用户创建一些示例数据
        let testMeasurements = [
            (Date().addingTimeInterval(-7*24*3600), 70.5, 175.0, 15.2, 32.1, 8),  // 7天前
            (Date().addingTimeInterval(-14*24*3600), 71.2, 175.0, 15.8, 31.9, 9), // 14天前
            (Date().addingTimeInterval(-21*24*3600), 72.0, 175.0, 16.1, 31.5, 9), // 21天前
        ]
        
        Task {
            for (date, weight, height, bodyFat, muscle, visceral) in testMeasurements {
                let request = CreateBodyMeasurementRequest(
                    userId: 1, // 假设用户ID为1
                    measurementTimestamp: date,
                    weightKg: weight,
                    heightCm: height,
                    bodyFatPercentage: bodyFat,
                    skeletalMuscleMassKg: muscle,
                    visceralFatLevel: visceral
                )
                
                do {
                    _ = try await createMeasurement(request)
                } catch {
                    print("❌ LocalBodyMeasurementService: 创建测试数据失败: \(error)")
                }
            }
            print("✅ LocalBodyMeasurementService: 测试数据创建完成")
        }
    }
}

// MARK: - 错误定义

enum LocalBodyMeasurementError: Error, LocalizedError {
    case databaseNotInitialized
    case createFailed(Error)
    case queryFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case recordNotFound
    case dateConversionFailed
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "数据库未初始化"
        case .createFailed(let error):
            return "创建记录失败: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "查询失败: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "更新失败: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "删除失败: \(error.localizedDescription)"
        case .recordNotFound:
            return "记录不存在"
        case .dateConversionFailed:
            return "日期转换失败"
        case .validationFailed(let message):
            return "数据验证失败: \(message)"
        }
    }
} 