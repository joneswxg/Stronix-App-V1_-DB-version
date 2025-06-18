import Foundation

// MARK: - 体测数据模型

/// 体测记录数据模型
struct BodyMeasurementRecord: Codable, Identifiable, Equatable {
    let id: Int
    let user_id: Int
    let measurement_timestamp: String
    let weight_kg: Double
    let height_cm: Double
    let body_fat_percentage: Double
    let skeletal_muscle_mass_kg: Double
    let visceral_fat_level: Int
    let created_at: String
    let updated_at: String
    
    /// 转换为Date对象的测量时间
    var measurementDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: measurement_timestamp) ?? Date()
    }
    
    /// 计算BMI
    var bmi: Double {
        let heightInMeters = height_cm / 100
        return weight_kg / (heightInMeters * heightInMeters)
    }
    
    /// 计算体脂肪重量(kg)
    var bodyFatKg: Double {
        return weight_kg * body_fat_percentage / 100
    }
    
    /// 计算基础代谢率(BMR) - 需要年龄和性别信息
    func calculateBMR(age: Int, gender: String) -> Double {
        if gender.lowercased() == "male" {
            return 10 * weight_kg + 6.25 * height_cm - 5 * Double(age) + 5
        } else {
            return 10 * weight_kg + 6.25 * height_cm - 5 * Double(age) - 161
        }
    }
}

/// 创建体测记录请求模型
struct CreateBodyMeasurementRequest: Codable {
    let user_id: Int
    let measurement_timestamp: String
    let weight_kg: Double
    let height_cm: Double
    let body_fat_percentage: Double
    let skeletal_muscle_mass_kg: Double
    let visceral_fat_level: Int
}

/// 体测记录响应模型
struct BodyMeasurementResponse: Codable {
    let measurements: [BodyMeasurementRecord]
}

/// 创建体测记录响应模型
struct CreateBodyMeasurementResponse: Codable {
    let success: Bool
    let measurement_id: Int
}

/// 体测记录详情响应模型
struct BodyMeasurementDetailResponse: Codable {
    let measurement: BodyMeasurementRecord
}

// MARK: - UI显示用的数据模型

/// 指标类型枚举
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
    func getValue(from record: BodyMeasurementRecord) -> Double {
        switch self {
        case .weight: return record.weight_kg
        case .muscleMass: return record.skeletal_muscle_mass_kg
        case .bodyFat: return record.body_fat_percentage
        }
    }
}

/// 体测数据变化信息
struct MeasurementChange {
    let current: Double
    let previous: Double?
    let change: Double
    let changePercentage: Double
    
    init(current: Double, previous: Double?) {
        self.current = current
        self.previous = previous
        if let prev = previous {
            self.change = current - prev
            self.changePercentage = prev != 0 ? (change / prev) * 100 : 0
        } else {
            self.change = 0
            self.changePercentage = 0
        }
    }
    
    var isIncreasing: Bool {
        return change > 0
    }
    
    var isDecreasing: Bool {
        return change < 0
    }
    
    var changeText: String {
        if change == 0 {
            return "无变化"
        } else if change > 0 {
            return "+\(String(format: "%.1f", change))"
        } else {
            return String(format: "%.1f", change)
        }
    }
}

/// 详细体测数据模型（用于详情页面显示）
struct DetailedMeasurementData {
    let record: BodyMeasurementRecord
    let weightChange: MeasurementChange
    let muscleMassChange: MeasurementChange
    let bodyFatChange: MeasurementChange
    let bmiChange: MeasurementChange
    let bodyFatPercentageChange: MeasurementChange
    let visceralFatChange: MeasurementChange
    let bmrChange: MeasurementChange
    
    // MARK: - 兼容性计算属性
    var weight: Double { record.weight_kg }
    var muscleMass: Double { record.skeletal_muscle_mass_kg }
    var bodyFat: Double { record.bodyFatKg }
    var bmi: Double { record.bmi }
    var bodyFatPercentage: Double { record.body_fat_percentage }
    var visceralFatLevel: Int { record.visceral_fat_level }
    var basalMetabolicRate: Int { Int(bmrChange.current) }
    
    init(current: BodyMeasurementRecord, previous: BodyMeasurementRecord?, userAge: Int, userGender: String) {
        self.record = current
        
        self.weightChange = MeasurementChange(
            current: current.weight_kg,
            previous: previous?.weight_kg
        )
        
        self.muscleMassChange = MeasurementChange(
            current: current.skeletal_muscle_mass_kg,
            previous: previous?.skeletal_muscle_mass_kg
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
            current: current.body_fat_percentage,
            previous: previous?.body_fat_percentage
        )
        
        self.visceralFatChange = MeasurementChange(
            current: Double(current.visceral_fat_level),
            previous: previous.map { Double($0.visceral_fat_level) }
        )
        
        let currentBMR = current.calculateBMR(age: userAge, gender: userGender)
        let previousBMR = previous?.calculateBMR(age: userAge, gender: userGender)
        self.bmrChange = MeasurementChange(
            current: currentBMR,
            previous: previousBMR
        )
    }
    
    // MARK: - 示例数据
    static let sampleData: DetailedMeasurementData = {
        let sampleRecord = BodyMeasurementRecord(
            id: 1,
            user_id: 1,
            measurement_timestamp: "2024-01-30 14:30:00",
            weight_kg: 74.9,
            height_cm: 175.0,
            body_fat_percentage: 13.1,
            skeletal_muscle_mass_kg: 37.1,
            visceral_fat_level: 3,
            created_at: "2024-01-30 14:30:00",
            updated_at: "2024-01-30 14:30:00"
        )
        
        return DetailedMeasurementData(
            current: sampleRecord,
            previous: nil,
            userAge: 25,
            userGender: "male"
        )
    }()
} 