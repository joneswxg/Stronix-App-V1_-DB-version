import SwiftUI

struct NutritionView: View {
    @StateObject private var calculator = NutritionCalculator()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    Text("专业营养热量计算器")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // 计算方法选择
                    Picker("计算方法", selection: $calculator.calculationMethod) {
                        Text("基础代谢计算").tag(CalculationMethod.mifflinStJeor)
                        Text("体脂率精确计算").tag(CalculationMethod.katchMcArdle)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // 基础信息输入
                    VStack(alignment: .leading, spacing: 15) {
                        Text("基础信息")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            HStack {
                                Text("性别:")
                                Spacer()
                                Picker("性别", selection: $calculator.gender) {
                                    Text("男性").tag(Gender.male)
                                    Text("女性").tag(Gender.female)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 150)
                            }
                            
                            HStack {
                                Text("年龄:")
                                Spacer()
                                TextField("年龄", value: $calculator.age, format: .number)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                Text("岁")
                            }
                            
                            HStack {
                                Text("身高:")
                                Spacer()
                                TextField("身高", value: $calculator.height, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                Text("cm")
                            }
                            
                            HStack {
                                Text("体重:")
                                Spacer()
                                TextField("体重", value: $calculator.weight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                Text("kg")
                            }
                            
                            // 体脂率输入（仅在Katch-McArdle方法时显示）
                            if calculator.calculationMethod == .katchMcArdle {
                                HStack {
                                    Text("体脂率:")
                                    Spacer()
                                    TextField("体脂率", value: $calculator.bodyFatPercentage, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 80)
                                    Text("%")
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // 活动水平选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text("活动水平")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(ActivityLevel.allCases, id: \.self) { level in
                                Button(action: {
                                    calculator.activityLevel = level
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(level.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(level.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if calculator.activityLevel == level {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(calculator.activityLevel == level ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 目标选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text("健身目标")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("目标", selection: $calculator.goal) {
                            Text("减脂").tag(Goal.weightLoss)
                            Text("维持").tag(Goal.maintenance)
                            Text("增肌").tag(Goal.muscleGain)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    
                    // 计算结果
                    if calculator.totalCalories > 0 {
                        VStack(spacing: 15) {
                            Text("营养计算结果")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // 总热量显示
                            HStack {
                                Text("目标热量:")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(calculator.totalCalories)) 卡路里")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            
                            // 营养素分配
                            VStack(spacing: 15) {
                                // 蛋白质
                                MacroSlider(
                                    name: "蛋白质",
                                    value: $calculator.proteinPercentage,
                                    range: calculator.proteinRange,
                                    color: .red,
                                    grams: calculator.proteinGrams,
                                    calories: calculator.proteinCalories
                                )
                                
                                // 碳水化合物
                                MacroSlider(
                                    name: "碳水化合物",
                                    value: $calculator.carbPercentage,
                                    range: calculator.carbRange,
                                    color: .green,
                                    grams: calculator.carbGrams,
                                    calories: calculator.carbCalories
                                )
                                
                                // 脂肪
                                MacroSlider(
                                    name: "脂肪",
                                    value: $calculator.fatPercentage,
                                    range: calculator.fatRange,
                                    color: .orange,
                                    grams: calculator.fatGrams,
                                    calories: calculator.fatCalories
                                )
                            }
                            .padding(.horizontal)
                            
                            // 热量分配验证
                            HStack {
                                Text("总热量分配:")
                                Spacer()
                                Text("\(Int(calculator.currentTotalCalories)) / \(Int(calculator.totalCalories)) 卡路里")
                                    .foregroundColor(abs(calculator.currentTotalCalories - calculator.totalCalories) < 10 ? .green : .red)
                            }
                            .padding(.horizontal)
                            .font(.footnote)
                        }
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// 宏量营养素滑块组件
struct MacroSlider: View {
    let name: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    let grams: Double
    let calories: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(value))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(range.lowerBound, specifier: "%.0f")%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: range, step: 1)
                    .accentColor(color)
                
                Text("\(range.upperBound, specifier: "%.0f")%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(grams, specifier: "%.1f")g")
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
                Text("\(Int(calories)) 卡路里")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

// 数据模型
class NutritionCalculator: ObservableObject {
    @Published var calculationMethod: CalculationMethod = .mifflinStJeor
    @Published var gender: Gender = .male
    @Published var age: Double = 25
    @Published var height: Double = 175
    @Published var weight: Double = 70
    @Published var bodyFatPercentage: Double = 15
    @Published var activityLevel: ActivityLevel = .moderate
    @Published var goal: Goal = .maintenance
    
    @Published var proteinPercentage: Double = 20
    @Published var carbPercentage: Double = 50
    @Published var fatPercentage: Double = 30
    
    var bmr: Double {
        switch calculationMethod {
        case .mifflinStJeor:
            return calculateMifflinStJeorBMR()
        case .katchMcArdle:
            return calculateKatchMcArdleBMR()
        }
    }
    
    var tdee: Double {
        return bmr * activityLevel.multiplier
    }
    
    var totalCalories: Double {
        switch goal {
        case .weightLoss:
            return tdee - 400
        case .maintenance:
            return tdee
        case .muscleGain:
            return tdee + 300
        }
    }
    
    // 营养素范围根据目标调整
    var proteinRange: ClosedRange<Double> {
        switch goal {
        case .weightLoss: return 25...35
        case .maintenance: return 15...25
        case .muscleGain: return 20...30
        }
    }
    
    var carbRange: ClosedRange<Double> {
        switch goal {
        case .weightLoss: return 30...40
        case .maintenance: return 45...55
        case .muscleGain: return 40...50
        }
    }
    
    var fatRange: ClosedRange<Double> {
        switch goal {
        case .weightLoss: return 25...35
        case .maintenance: return 25...35
        case .muscleGain: return 20...30
        }
    }
    
    // 计算各营养素的克数和热量
    var proteinGrams: Double {
        return (totalCalories * proteinPercentage / 100) / 4
    }
    
    var proteinCalories: Double {
        return proteinGrams * 4
    }
    
    var carbGrams: Double {
        return (totalCalories * carbPercentage / 100) / 4
    }
    
    var carbCalories: Double {
        return carbGrams * 4
    }
    
    var fatGrams: Double {
        return (totalCalories * fatPercentage / 100) / 9
    }
    
    var fatCalories: Double {
        return fatGrams * 9
    }
    
    var currentTotalCalories: Double {
        return proteinCalories + carbCalories + fatCalories
    }
    
    private func calculateMifflinStJeorBMR() -> Double {
        let baseCalories = 10 * weight + 6.25 * height - 5 * age
        return gender == .male ? baseCalories + 5 : baseCalories - 161
    }
    
    private func calculateKatchMcArdleBMR() -> Double {
        let leanBodyMass = weight * (1 - bodyFatPercentage / 100)
        return 370 + (21.6 * leanBodyMass)
    }
    
    init() {
        // 确保营养素比例在合理范围内
        updateMacroPercentages()
    }
    
    private func updateMacroPercentages() {
        // 自动调整营养素比例以符合目标
        switch goal {
        case .weightLoss:
            proteinPercentage = 30
            carbPercentage = 35
            fatPercentage = 35
        case .maintenance:
            proteinPercentage = 20
            carbPercentage = 50
            fatPercentage = 30
        case .muscleGain:
            proteinPercentage = 25
            carbPercentage = 45
            fatPercentage = 30
        }
    }
}

// 枚举定义
enum CalculationMethod: CaseIterable {
    case mifflinStJeor, katchMcArdle
}

enum Gender: CaseIterable {
    case male, female
}

enum ActivityLevel: CaseIterable {
    case sedentary, light, moderate, active, veryActive
    
    var title: String {
        switch self {
        case .sedentary: return "久坐不动"
        case .light: return "轻度活动"
        case .moderate: return "中度活动"
        case .active: return "高强度活动"
        case .veryActive: return "极高强度"
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "几乎不运动，办公室工作"
        case .light: return "轻度运动 1-3天/周"
        case .moderate: return "中度运动 3-5天/周"
        case .active: return "高强度运动 6-7天/周"
        case .veryActive: return "极高强度运动，体力劳动"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum Goal: CaseIterable {
    case weightLoss, maintenance, muscleGain
}

// 预览
struct NutritionView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionView()
    }
}
