import Foundation
import SQLite

/// 本地身体测量相关数据模型
/// 迁移自 Backend-Reference/src/stronix/models/BodyMeasurementModels.py

// MARK: - BodyMeasurement 数据模型
/// 迁移自 Backend-Reference/src/stronix/models/BodyMeasurementModels.py

struct BodyMeasurement: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    let measurementTimestamp: Date
    let weightKg: Double
    let heightCm: Double
    let bodyFatPercentage: Double
    let skeletalMuscleMassKg: Double
    let visceralFatLevel: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case measurementTimestamp = "measurement_timestamp"
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case bodyFatPercentage = "body_fat_percentage"
        case skeletalMuscleMassKg = "skeletal_muscle_mass_kg"
        case visceralFatLevel = "visceral_fat_level"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - 计算属性
    
    /// 计算BMI
    var bmi: Double {
        let heightM = heightCm / 100
        return (weightKg / (heightM * heightM)).rounded(toPlaces: 2)
    }
    
    /// 计算体脂肪重量(kg)
    var bodyFatKg: Double {
        return (weightKg * bodyFatPercentage / 100).rounded(toPlaces: 2)
    }
    
    /// 计算瘦体重(kg)
    var leanBodyMass: Double {
        return (weightKg * (1 - bodyFatPercentage / 100)).rounded(toPlaces: 2)
    }
    
    /// 计算基础代谢率(BMR) - 使用Katch-McArdle公式
    /// - Parameters:
    ///   - age: 年龄
    ///   - gender: 性别 ("male" 或 "female")
    /// - Returns: BMR值
    func calculateBMR(age: Int, gender: String) -> Double {
        // 使用Katch-McArdle公式计算BMR
        // BMR = 370 + (21.6 * LBM)
        let bmr = 370 + (21.6 * leanBodyMass)
        return bmr.rounded()
    }
    
    /// BMI分类
    var bmiCategory: BMICategory {
        switch bmi {
        case 0..<18.5:
            return .underweight
        case 18.5..<24:
            return .normal
        case 24..<28:
            return .overweight
        case 28...:
            return .obese
        default:
            return .normal
        }
    }
    
    /// 体脂率健康范围判断
    func bodyFatCategory(for gender: String) -> BodyFatCategory {
        if gender.lowercased() == "male" {
            switch bodyFatPercentage {
            case 0..<6:
                return .essential
            case 6..<14:
                return .athletic
            case 14..<18:
                return .fitness
            case 18..<25:
                return .average
            case 25...:
                return .obese
            default:
                return .average
            }
        } else {
            switch bodyFatPercentage {
            case 0..<10:
                return .essential
            case 10..<17:
                return .athletic
            case 17..<21:
                return .fitness
            case 21..<32:
                return .average
            case 32...:
                return .obese
            default:
                return .average
            }
        }
    }
}

// MARK: - 创建/更新请求模型

struct CreateBodyMeasurementRequest: Codable {
    let userId: Int
    let measurementTimestamp: Date
    let weightKg: Double
    let heightCm: Double
    let bodyFatPercentage: Double
    let skeletalMuscleMassKg: Double
    let visceralFatLevel: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case measurementTimestamp = "measurement_timestamp"
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case bodyFatPercentage = "body_fat_percentage"
        case skeletalMuscleMassKg = "skeletal_muscle_mass_kg"
        case visceralFatLevel = "visceral_fat_level"
    }
}

struct UpdateBodyMeasurementRequest: Codable {
    let weightKg: Double?
    let heightCm: Double?
    let bodyFatPercentage: Double?
    let skeletalMuscleMassKg: Double?
    let visceralFatLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case bodyFatPercentage = "body_fat_percentage"
        case skeletalMuscleMassKg = "skeletal_muscle_mass_kg"
        case visceralFatLevel = "visceral_fat_level"
    }
}

// MARK: - 响应模型

struct BodyMeasurementResponse: Codable {
    let success: Bool
    let message: String
    let measurementId: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case measurementId = "measurement_id"
    }
}

struct BodyMeasurementListResponse: Codable {
    let measurements: [BodyMeasurement]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case measurements
        case totalCount = "total_count"
    }
}

// MARK: - 统计模型

struct BodyMeasurementStatistics: Codable {
    let latestMeasurement: BodyMeasurement?
    let weightTrend: Double?
    let bodyFatTrend: Double?
    let muscleMassTrend: Double?
    let measurementCount: Int
    let dateRangeDays: Int
    
    enum CodingKeys: String, CodingKey {
        case latestMeasurement = "latest_measurement"
        case weightTrend = "weight_trend"
        case bodyFatTrend = "body_fat_trend"
        case muscleMassTrend = "muscle_mass_trend"
        case measurementCount = "measurement_count"
        case dateRangeDays = "date_range_days"
    }
}

// MARK: - 查询参数模型

struct BodyMeasurementQuery {
    let userId: Int
    let limit: Int?
    let offset: Int?
    let startDate: Date?
    let endDate: Date?
    let orderBy: String
    let orderDirection: String
    
    init(userId: Int, 
         limit: Int? = nil, 
         offset: Int? = nil, 
         startDate: Date? = nil, 
         endDate: Date? = nil, 
         orderBy: String = "measurement_timestamp", 
         orderDirection: String = "DESC") {
        self.userId = userId
        self.limit = limit
        self.offset = offset
        self.startDate = startDate
        self.endDate = endDate
        self.orderBy = orderBy
        self.orderDirection = orderDirection
    }
}

// MARK: - 枚举类型

enum BMICategory: String, CaseIterable {
    case underweight = "偏瘦"
    case normal = "正常"
    case overweight = "超重"
    case obese = "肥胖"
    
    var color: String {
        switch self {
        case .underweight:
            return "blue"
        case .normal:
            return "green"
        case .overweight:
            return "orange"
        case .obese:
            return "red"
        }
    }
}

enum BodyFatCategory: String, CaseIterable {
    case essential = "必需脂肪"
    case athletic = "运动员"
    case fitness = "健身"
    case average = "平均"
    case obese = "肥胖"
    
    var color: String {
        switch self {
        case .essential:
            return "blue"
        case .athletic:
            return "green"
        case .fitness:
            return "teal"
        case .average:
            return "orange"
        case .obese:
            return "red"
        }
    }
}

enum MetricType: String, CaseIterable {
    case weight = "体重"
    case muscleMass = "骨骼肌量"
    case bodyFat = "体脂百分比"
    
    var unit: String {
        switch self {
        case .weight: return "kg"
        case .muscleMass: return "kg"
        case .bodyFat: return "%"
        }
    }
    
    /// 从体测记录中获取对应指标的值
    func getValue(from measurement: BodyMeasurement) -> Double {
        switch self {
        case .weight: return measurement.weightKg
        case .muscleMass: return measurement.skeletalMuscleMassKg
        case .bodyFat: return measurement.bodyFatPercentage
        }
    }
}

// MARK: - 扩展

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - 详细测量数据模型（用于详情页面）

/// 测量变化数据
struct MeasurementChange {
    let change: Double
    let percentage: Double
    
    init(current: Double, previous: Double?) {
        if let prev = previous {
            self.change = current - prev
            self.percentage = prev != 0 ? (change / prev) * 100 : 0
        } else {
            self.change = 0
            self.percentage = 0
        }
    }
}

/// 详细测量数据（包含变化信息）
struct DetailedMeasurementData {
    // 基础数据
    let weight: Double
    let muscleMass: Double
    let bodyFat: Double
    let bmi: Double
    let bodyFatPercentage: Double
    let visceralFatLevel: Int
    let basalMetabolicRate: Int
    
    // 变化数据
    let weightChange: MeasurementChange
    let muscleMassChange: MeasurementChange
    let bodyFatChange: MeasurementChange
    let bmiChange: MeasurementChange
    let bodyFatPercentageChange: MeasurementChange
    let visceralFatChange: MeasurementChange
    let bmrChange: MeasurementChange
    
    init(current: BodyMeasurement, previous: BodyMeasurement?, userAge: Int, userGender: String) {
        // 设置基础数据
        self.weight = current.weightKg
        self.muscleMass = current.skeletalMuscleMassKg
        self.bodyFat = current.bodyFatKg
        self.bmi = current.bmi
        self.bodyFatPercentage = current.bodyFatPercentage
        self.visceralFatLevel = current.visceralFatLevel
        self.basalMetabolicRate = Int(current.calculateBMR(age: userAge, gender: userGender))
        
        // 计算变化数据
        self.weightChange = MeasurementChange(
            current: current.weightKg,
            previous: previous?.weightKg
        )
        
        self.muscleMassChange = MeasurementChange(
            current: current.skeletalMuscleMassKg,
            previous: previous?.skeletalMuscleMassKg
        )
        
        self.bodyFatChange = MeasurementChange(
            current: current.bodyFatKg,
            previous: previous?.bodyFatKg
        )
        
        self.bmiChange = MeasurementChange(
            current: current.bmi,
            previous: previous?.bmi
        )
        
        self.bodyFatPercentageChange = MeasurementChange(
            current: current.bodyFatPercentage,
            previous: previous?.bodyFatPercentage
        )
        
        self.visceralFatChange = MeasurementChange(
            current: Double(current.visceralFatLevel),
            previous: previous != nil ? Double(previous!.visceralFatLevel) : nil
        )
        
        let currentBMR = current.calculateBMR(age: userAge, gender: userGender)
        let previousBMR = previous?.calculateBMR(age: userAge, gender: userGender)
        self.bmrChange = MeasurementChange(
            current: currentBMR,
            previous: previousBMR
        )
    }
    
    /// 示例数据
    static let sampleData = DetailedMeasurementData(
        current: BodyMeasurement(
            id: 1,
            userId: 1,
            measurementTimestamp: Date(),
            weightKg: 75.5,
            heightCm: 175.0,
            bodyFatPercentage: 15.2,
            skeletalMuscleMassKg: 35.8,
            visceralFatLevel: 5,
            createdAt: Date(),
            updatedAt: Date()
        ),
        previous: nil,
        userAge: 25,
        userGender: "male"
    )
} 