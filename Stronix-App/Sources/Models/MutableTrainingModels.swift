import Foundation

/// 可变的训练动作模型（用于训练过程中的编辑）
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
}

/// 可变的训练组模型（用于训练过程中的编辑）
struct MutableTrainingSet: Identifiable {
    let id: Int
    var weight: Double
    var reps: Int
    var leftWeight: Double
    var rightWeight: Double
    
    // 从不可变模型转换
    init(from set: TrainingSet) {
        self.id = set.id
        self.weight = set.weight
        self.reps = set.reps
        self.leftWeight = set.leftWeight
        self.rightWeight = set.rightWeight
    }
    
    // 直接创建
    init(id: Int, weight: Double, reps: Int, leftWeight: Double = 0.0, rightWeight: Double = 0.0) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
    }
} 