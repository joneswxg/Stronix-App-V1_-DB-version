import Foundation

enum SetRIR: Int, Codable, Equatable, Hashable, Sendable {
    case zero = 0
    case one = 1
    case two = 2
    case threeOrMore = 3

    var displayLabel: String {
        switch self {
        case .zero: "0"
        case .one: "1"
        case .two: "2"
        case .threeOrMore: "3+"
        }
    }
}

extension Optional where Wrapped == SetRIR {
    var historyDisplayLabel: String {
        map { "RIR \($0.displayLabel)" } ?? "未记录余力"
    }
}

enum TrainingDisplayUnit: String, Equatable {
    case kilograms
    case pounds

    static let poundsPerKilogram = 2.20462

    func displayValue(forKilograms value: Double) -> Double {
        switch self {
        case .kilograms: value
        case .pounds: value * Self.poundsPerKilogram
        }
    }

    func kilogramsValue(fromDisplay value: Double) -> Double {
        switch self {
        case .kilograms: value
        case .pounds: value / Self.poundsPerKilogram
        }
    }

    var keyboardLabel: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lbs"
        }
    }
}

enum TrainingEditingField: Equatable {
    case weight(actionID: Int, setID: Int)
    case leftWeight(actionID: Int, setID: Int)
    case rightWeight(actionID: Int, setID: Int)
    case reps(actionID: Int, setID: Int)

    init?(id: String) {
        let components = id.split(separator: "_")
        guard components.count == 3,
              let actionID = Int(components[1]),
              let setID = Int(components[2]) else { return nil }

        switch components[0] {
        case "weight": self = .weight(actionID: actionID, setID: setID)
        case "left": self = .leftWeight(actionID: actionID, setID: setID)
        case "right": self = .rightWeight(actionID: actionID, setID: setID)
        case "reps": self = .reps(actionID: actionID, setID: setID)
        default: return nil
        }
    }

    var actionID: Int {
        switch self {
        case let .weight(actionID, _), let .leftWeight(actionID, _), let .rightWeight(actionID, _), let .reps(actionID, _): actionID
        }
    }

    var setID: Int {
        switch self {
        case let .weight(_, setID), let .leftWeight(_, setID), let .rightWeight(_, setID), let .reps(_, setID): setID
        }
    }

    var id: String {
        switch self {
        case let .weight(actionID, setID): "weight_\(actionID)_\(setID)"
        case let .leftWeight(actionID, setID): "left_\(actionID)_\(setID)"
        case let .rightWeight(actionID, setID): "right_\(actionID)_\(setID)"
        case let .reps(actionID, setID): "reps_\(actionID)_\(setID)"
        }
    }

    func forSet(_ setID: Int) -> TrainingEditingField {
        switch self {
        case let .weight(actionID, _): .weight(actionID: actionID, setID: setID)
        case let .leftWeight(actionID, _): .leftWeight(actionID: actionID, setID: setID)
        case let .rightWeight(actionID, _): .rightWeight(actionID: actionID, setID: setID)
        case let .reps(actionID, _): .reps(actionID: actionID, setID: setID)
        }
    }
}

struct TrainingKeyboardState: Equatable {
    let field: TrainingEditingField
    let value: Double
    let displayUnit: TrainingDisplayUnit
    let isBilateralRecording: Bool

    var isInteger: Bool {
        if case .reps = field { return true }
        return false
    }
}

/// 本地可变的训练模型（用于训练过程中的编辑）
/// 迁移自 MutableTrainingModels.swift

/// 本地可变的训练动作模型（用于训练过程中的编辑）
struct LocalMutableTrainingAction: Identifiable {
    let id: Int
    let name: String
    let imageUrl: String
    var sets: [LocalMutableTrainingSet]
    var restTime: Int
    var recordBilateral: Bool
    
    // 从不可变模型转换
    init(from action: TrainingAction) {
        self.id = action.id
        self.name = action.name
        self.imageUrl = action.imageUrl
        self.sets = action.sets.map { LocalMutableTrainingSet(from: $0) }
        self.restTime = action.restTime
        self.recordBilateral = action.recordBilateral
    }
    

    
    // 直接创建
    init(id: Int, name: String, imageUrl: String, sets: [LocalMutableTrainingSet], restTime: Int, recordBilateral: Bool) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
        self.sets = sets
        self.restTime = restTime
        self.recordBilateral = recordBilateral
    }
    
    /// 转换为前端兼容的MutableTrainingAction模型
    func toMutableTrainingAction() -> MutableTrainingAction {
        let mutableSets = sets.map { $0.toMutableTrainingSet() }
        return MutableTrainingAction(
            id: id,
            name: name,
            imageUrl: imageUrl,
            sets: mutableSets,
            restTime: restTime,
            recordBilateral: recordBilateral
        )
    }
}

/// 本地可变的训练组模型（用于训练过程中的编辑）
struct LocalMutableTrainingSet: Identifiable {
    let id: Int
    var weight: Double
    var reps: Int
    var leftWeight: Double
    var rightWeight: Double
    var rir: SetRIR?
    
    // 从不可变模型转换
    init(from set: TrainingSet) {
        self.id = set.id
        self.weight = set.weight
        self.reps = set.reps
        self.leftWeight = set.leftWeight
        self.rightWeight = set.rightWeight
        self.rir = nil
    }
    

    
    // 直接创建
    init(id: Int, weight: Double, reps: Int, leftWeight: Double = 0.0, rightWeight: Double = 0.0, rir: SetRIR? = nil) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
        self.rir = rir
    }

    /// 转换为前端兼容的MutableTrainingSet模型
    func toMutableTrainingSet() -> MutableTrainingSet {
        return MutableTrainingSet(
            id: id,
            weight: weight,
            reps: reps,
            leftWeight: leftWeight,
            rightWeight: rightWeight,
            rir: rir
        )
    }
}

// MARK: - 前端兼容层模型（来自MutableTrainingModels.swift）

/// 可变的训练动作模型（前端兼容层）
struct MutableTrainingAction: Identifiable {
    let id: Int
    let name: String
    let imageUrl: String
    var sets: [MutableTrainingSet]
    var restTime: Int
    var recordBilateral: Bool
    
    // 从不可变模型转换
    init(from action: TrainingAction) {
        self.id = action.id
        self.name = action.name
        self.imageUrl = action.imageUrl
        self.sets = action.sets.map { MutableTrainingSet(from: $0) }
        self.restTime = action.restTime
        self.recordBilateral = action.recordBilateral
    }
    
    // 直接创建
    init(id: Int, name: String, imageUrl: String, sets: [MutableTrainingSet], restTime: Int, recordBilateral: Bool) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
        self.sets = sets
        self.restTime = restTime
        self.recordBilateral = recordBilateral
    }

    mutating func setRecordBilateral(_ enabled: Bool) {
        guard recordBilateral != enabled else { return }
        recordBilateral = enabled
        for index in sets.indices {
            if enabled {
                sets[index].leftWeight = sets[index].weight
                sets[index].rightWeight = sets[index].weight
            } else {
                sets[index].weight = sets[index].leftWeight
            }
        }
    }
}

/// 可变的训练组模型（前端兼容层）
struct MutableTrainingSet: Identifiable {
    let id: Int
    var weight: Double
    var reps: Int
    var leftWeight: Double
    var rightWeight: Double
    var rir: SetRIR?
    
    // 从不可变模型转换
    init(from set: TrainingSet) {
        self.id = set.id
        self.weight = set.weight
        self.reps = set.reps
        self.leftWeight = set.leftWeight
        self.rightWeight = set.rightWeight
        self.rir = nil
    }
    
    // 直接创建
    init(id: Int, weight: Double, reps: Int, leftWeight: Double = 0.0, rightWeight: Double = 0.0, rir: SetRIR? = nil) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
        self.rir = rir
    }
} 