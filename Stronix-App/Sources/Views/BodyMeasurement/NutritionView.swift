import SwiftUI
import Combine

struct NutritionView: View {
    @Environment(\.theme) private var theme
    @StateObject private var calculator = NutritionCalculator()
    @State private var showingMifflinInfo = false
    @State private var showingKatchInfo = false
    @State private var showingCaloriesInfo = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    Text("营养热量计算器")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // 计算方法选择
                    Picker("计算方法", selection: $calculator.calculationMethod) {
                        Text("基础代谢计算").tag(CalculationMethod.mifflinStJeor)
                        Text("体脂率基础代谢计算").tag(CalculationMethod.katchMcArdle)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // 基础信息输入
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("基础信息")
                                .font(.headline)
                            
                            if calculator.calculationMethod == .mifflinStJeor {
                                Button(action: {
                                    showingMifflinInfo = true
                                }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(theme.primary)
                                }
                                .sheet(isPresented: $showingMifflinInfo) {
                                    NavigationView {
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 15) {
                                                Text("Mifflin-St Jeor 方程")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                
                                                Text("Mifflin-St Jeor 方程是目前普遍认为最准确的基础代谢率（BMR）计算公式之一。")
                                                    .font(.body)
                                                
                                                Text("计算公式：")
                                                    .font(.headline)
                                                    .padding(.top)
                                                
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Text("男性: (10 × 体重kg) + (6.25 × 身高cm) - (5 × 年龄) + 5")
                                                        .font(.system(.body, design: .monospaced))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(theme.secondary.opacity(0.1))
                                                        .cornerRadius(5)
                                                    
                                                    Text("女性: (10 × 体重kg) + (6.25 × 身高cm) - (5 × 年龄) - 161")
                                                        .font(.system(.body, design: .monospaced))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(theme.secondary.opacity(0.1))
                                                        .cornerRadius(5)
                                                }
                                                
                                                Text("该公式根据性别、年龄、体重和身高来估算身体在休息状态下每天消耗的卡路里。适用于大多数成年人，不考虑体脂率。")
                                                    .font(.body)
                                                    .padding(.top)
                                            }
                                            .padding()
                                        }
                                        .navigationTitle("Mifflin-St Jeor 方程")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .navigationBarItems(trailing: Button("关闭") {
                                            showingMifflinInfo = false
                                        })
                                    }
                                }
                            } else if calculator.calculationMethod == .katchMcArdle {
                                Button(action: {
                                    showingKatchInfo = true
                                }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(theme.primary)
                                }
                                .sheet(isPresented: $showingKatchInfo) {
                                    NavigationView {
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 15) {
                                                Text("Katch-McArdle 方程")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                
                                                Text("Katch-McArdle 方程是一种针对已知体脂率人群的基础代谢率（BMR）计算公式。")
                                                    .font(.body)
                                                
                                                Text("计算公式：")
                                                    .font(.headline)
                                                    .padding(.top)
                                                
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Text("BMR = 370 + (21.6 × 去脂体重kg)")
                                                        .font(.system(.body, design: .monospaced))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(theme.secondary.opacity(0.1))
                                                        .cornerRadius(5)
                                                    
                                                    Text("去脂体重 = 体重kg × (1 - 体脂率% ÷ 100)")
                                                        .font(.system(.body, design: .monospaced))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(theme.secondary.opacity(0.1))
                                                        .cornerRadius(5)
                                                }
                                                
                                                Text("这个公式被认为比Mifflin-St Jeor方程更准确，因为它考虑了瘦体重（Lean Body Mass），而瘦体重是影响基础代谢率的关键因素。适用于健身人群或对体脂率有准确了解的人。")
                                                    .font(.body)
                                                    .padding(.top)
                                            }
                                            .padding()
                                        }
                                        .navigationTitle("Katch-McArdle 方程")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .navigationBarItems(trailing: Button("关闭") {
                                            showingKatchInfo = false
                                        })
                                    }
                                }
                            }
                            
                            Spacer()
                        }
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
                                    .focused($isInputFocused)
                                Text("岁")
                            }
                            
                            HStack {
                                Text("身高:")
                                Spacer()
                                TextField("身高", value: $calculator.height, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                    .focused($isInputFocused)
                                Text("cm")
                            }
                            
                            HStack {
                                Text("体重:")
                                Spacer()
                                TextField("体重", value: $calculator.weight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                    .focused($isInputFocused)
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
                                        .focused($isInputFocused)
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
                                    isInputFocused = false // 点击选项时隐藏键盘
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
                                                .foregroundColor(theme.primary)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(calculator.activityLevel == level ? theme.primary.opacity(0.1) : theme.secondary.opacity(0.05))
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
                        .onChange(of: calculator.goal) {
                            isInputFocused = false // 切换目标时隐藏键盘
                        }
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
                                
                                Button(action: {
                                    showingCaloriesInfo = true
                                    isInputFocused = false // 打开弹窗时隐藏键盘
                                }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                }
                                .sheet(isPresented: $showingCaloriesInfo) {
                                    NavigationView {
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 15) {
                                                Text("目标热量说明")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                
                                                Text("目标热量是根据您的基础代谢率（BMR）、活动水平和健身目标计算得出的每日所需卡路里摄入量。")
                                                    .font(.body)
                                                
                                                Text("TDEE计算公式：")
                                                    .font(.headline)
                                                    .padding(.top)
                                                
                                                Text("TDEE = BMR（基础代谢率）× 活动系数")
                                                    .font(.system(.body, design: .monospaced))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color.gray.opacity(0.1))
                                                    .cornerRadius(5)
                                                
                                                Text("TDEE（Total Daily Energy Expenditure）是您每日总能量消耗，包括基础代谢、日常活动、运动等所有消耗的热量。")
                                                    .font(.body)
                                                    .padding(.top, 5)
                                                
                                                Text("热量范围依据：")
                                                    .font(.headline)
                                                    .padding(.top)
                                                
                                                VStack(alignment: .leading, spacing: 10) {
                                                    Text("• 减脂：TDEE - 300~500 卡路里")
                                                        .font(.body)
                                                    Text("  创造适度热量缺口，帮助减少脂肪，同时避免过快减重导致肌肉流失。")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .padding(.leading, 10)
                                                    
                                                    Text("• 维持：TDEE ± 100 卡路里")
                                                        .font(.body)
                                                        .padding(.top, 5)
                                                    Text("  保持现有体重和体组成，允许小幅波动。")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .padding(.leading, 10)
                                                    
                                                    Text("• 增肌：TDEE + 300~500 卡路里")
                                                        .font(.body)
                                                        .padding(.top, 5)
                                                    Text("  提供足够的热量盈余，支持肌肉生长，同时避免过量导致过多脂肪堆积。")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .padding(.leading, 10)
                                                }
                                                
                                                Text("建议值是该范围的中间值，用于后续蛋白质、碳水化合物和脂肪的比例计算。实际摄入可根据身体反应和目标进展在范围内调整。")
                                                    .font(.body)
                                                    .padding(.top)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                        }
                                        .navigationTitle("目标热量说明")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .navigationBarItems(trailing: Button("关闭") {
                                            showingCaloriesInfo = false
                                        })
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("\(Int(calculator.totalCaloriesRange.lowerBound)) - \(Int(calculator.totalCaloriesRange.upperBound)) 卡路里")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Text("建议值: \(Int(calculator.totalCalories)) 卡路里")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            
                            // 营养素分配
                            VStack(spacing: 15) {
                                // 蛋白质
                                MacroSlider(
                                    name: "蛋白质",
                                    gramsPerKgValue: $calculator.proteinGramsPerKg,
                                    gramRange: calculator.proteinGramRange,
                                    recommendedRange: calculator.proteinRecommendedRange,
                                    percentageRange: calculator.proteinPercentageRangeString,
                                    color: .blue,
                                    totalGrams: calculator.proteinGrams,
                                    calories: calculator.proteinCalories,
                                    weight: calculator.weight,
                                    currentPercentage: calculator.proteinPercentage,
                                    onValueChanged: { newValue in
                                        calculator.proteinGramsPerKg = newValue
                                        isInputFocused = false
                                    }
                                )
                                
                                // 碳水化合物
                                MacroSlider(
                                    name: "碳水化合物",
                                    gramsPerKgValue: $calculator.carbGramsPerKg,
                                    gramRange: calculator.carbGramRange,
                                    recommendedRange: calculator.carbRecommendedRange,
                                    percentageRange: calculator.carbPercentageRangeString,
                                    color: .green,
                                    totalGrams: calculator.carbGrams,
                                    calories: calculator.carbCalories,
                                    weight: calculator.weight,
                                    currentPercentage: calculator.carbPercentage,
                                    onValueChanged: { newValue in
                                        calculator.carbGramsPerKg = newValue
                                        isInputFocused = false
                                    }
                                )
                                
                                // 脂肪
                                MacroSlider(
                                    name: "脂肪",
                                    gramsPerKgValue: $calculator.fatGramsPerKg,
                                    gramRange: calculator.fatGramRange,
                                    recommendedRange: calculator.fatRecommendedRange,
                                    percentageRange: calculator.fatPercentageRangeString,
                                    color: .orange,
                                    totalGrams: calculator.fatGrams,
                                    calories: calculator.fatCalories,
                                    weight: calculator.weight,
                                    currentPercentage: calculator.fatPercentage,
                                    onValueChanged: { newValue in
                                        calculator.fatGramsPerKg = newValue
                                        isInputFocused = false
                                    }
                                )
                            }
                            .padding(.horizontal)
                            
                            // 热量分配验证
                            VStack(spacing: 5) {
                                HStack {
                                    Text("当前热量分配:")
                                    Spacer()
                                    Text("\(Int(calculator.currentTotalCalories)) 卡路里")
                                        .foregroundColor(calculator.currentTotalCalories <= calculator.maxCalories ? .green : .red)
                                }
                                .padding(.horizontal)
                                .font(.footnote)
                                
                                HStack {
                                    Text("建议范围:")
                                    Spacer()
                                    Text("\(Int(calculator.totalCaloriesRange.lowerBound)) - \(Int(calculator.totalCaloriesRange.upperBound)) 卡路里")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .font(.caption)
                                
                                HStack {
                                    Text("最大限制:")
                                    Spacer()
                                    Text("\(Int(calculator.maxCalories)) 卡路里")
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal)
                                .font(.caption)
                            }
                        }
                        .background(theme.primary.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        isInputFocused = false
                    }
                }
            }
            .onTapGesture {
                // 点击空白区域隐藏键盘
                isInputFocused = false
            }
        }
    }
}

// 宏量营养素滑块组件
struct MacroSlider: View {
    let name: String
    @Binding var gramsPerKgValue: Double
    let gramRange: ClosedRange<Double>
    let recommendedRange: ClosedRange<Double>
    let percentageRange: String
    let color: Color
    let totalGrams: Double
    let calories: Double
    let weight: Double
    let currentPercentage: Double
    let onValueChanged: (Double) -> Void
    
    var recommendedIntake: String {
        return String(format: "%.1f-%.1f g/kg", recommendedRange.lowerBound, recommendedRange.upperBound)
    }
    
    // 判断当前值是否在建议范围内 - 根据g/kg值
    var isInRecommendedGramRange: Bool {
        return recommendedRange.contains(gramsPerKgValue)
    }
    
    // 判断百分比是否在建议范围内 - 根据占总热量百分比
    func isPercentageInRange(currentPercentage: Double, percentageRangeString: String) -> Bool {
        // 解析百分比范围字符串，例如 "20%-30%"
        let components = percentageRangeString.replacingOccurrences(of: "%", with: "").components(separatedBy: "-")
        guard components.count == 2,
              let lowerBound = Double(components[0]),
              let upperBound = Double(components[1]) else {
            return true // 如果无法解析，默认为正确
        }
        
        let range = lowerBound...upperBound
        return range.contains(currentPercentage)
    }
    
    // 百分比显示颜色 - 根据百分比范围而不是g/kg范围
    var percentageColor: Color {
        return isPercentageInRange(currentPercentage: currentPercentage, percentageRangeString: percentageRange) ? color : .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 静态信息行
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("建议: \(recommendedIntake)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("占总热量范围: \(percentageRange)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // 滑块
            HStack {
                Text(String(format: "%.1fg", gramRange.lowerBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Slider(value: Binding(
                    get: { gramsPerKgValue },
                    set: { newValue in
                        onValueChanged(newValue)
                    }
                ), in: gramRange, step: 0.1)
                    .accentColor(color)
                
                Text(String(format: "%.1fg", gramRange.upperBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // 动态数值行
            HStack {
                Text(String(format: "%.0fg(%.1fg/kg)", totalGrams, gramsPerKgValue))
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
                Text(String(format: "%.0f%%", currentPercentage))
                    .font(.caption)
                    .foregroundColor(percentageColor)
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
    
    // 改为g/kg单位
    @Published var proteinGramsPerKg: Double = 1.8
    @Published var carbGramsPerKg: Double = 4.2
    @Published var fatGramsPerKg: Double = 1.0
    
    // 监听目标变化
    private var goalObserver: AnyCancellable?
    
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
    
    var totalCaloriesRange: ClosedRange<Double> {
        switch goal {
        case .weightLoss:
            return (tdee - 500)...(tdee - 300)
        case .maintenance:
            return (tdee - 100)...(tdee + 100)
        case .muscleGain:
            return (tdee + 300)...(tdee + 500)
        }
    }
    
    var maxCalories: Double {
        switch goal {
        case .weightLoss:
            return tdee - 300
        case .maintenance:
            return tdee
        case .muscleGain:
            return tdee + 500
        }
    }
    
    var totalCalories: Double {
        let range = totalCaloriesRange
        return (range.lowerBound + range.upperBound) / 2
    }
    
    // g/kg范围 - 扩大范围以适应更多需求
    var proteinGramRange: ClosedRange<Double> {
        return 0.8...3.5  // 适合所有健身人群的蛋白质需求
    }
    
    var carbGramRange: ClosedRange<Double> {
        return 1.0...8.0  // 适合健身房力量训练人群的碳水需求
    }
    
    var fatGramRange: ClosedRange<Double> {
        return 0.3...2.5  // 适合各种饮食方案的脂肪需求
    }
    
    // 建议范围（用于颜色判断）
    var proteinRecommendedRange: ClosedRange<Double> {
        switch goal {
        case .weightLoss: return 2.0...2.5
        case .maintenance: return 1.6...2.0
        case .muscleGain: return 1.6...2.2
        }
    }
    
    var carbRecommendedRange: ClosedRange<Double> {
        switch goal {
        case .weightLoss: return 3.0...4.5
        case .maintenance: return 3.5...5.0
        case .muscleGain: return 4.5...6.5
        }
    }
    
    var fatRecommendedRange: ClosedRange<Double> {
        switch goal {
        case .weightLoss: return 0.8...1.2
        case .maintenance: return 1.0...1.2
        case .muscleGain: return 0.8...1.2
        }
    }
    
    // 百分比范围字符串
    var proteinPercentageRangeString: String {
        switch goal {
        case .weightLoss: return "25%-35%"
        case .maintenance: return "20%-30%"
        case .muscleGain: return "20%-30%"
        }
    }
    
    var carbPercentageRangeString: String {
        switch goal {
        case .weightLoss: return "35%-45%"
        case .maintenance: return "40%-45%"
        case .muscleGain: return "55%-65%"
        }
    }
    
    var fatPercentageRangeString: String {
        switch goal {
        case .weightLoss: return "20%-30%"
        case .maintenance: return "25%-35%"
        case .muscleGain: return "15%-20%"
        }
    }
    
    // 计算各营养素的克数和热量
    var proteinGrams: Double {
        return proteinGramsPerKg * weight
    }
    
    var proteinCalories: Double {
        return proteinGrams * 4
    }
    
    var carbGrams: Double {
        return carbGramsPerKg * weight
    }
    
    var carbCalories: Double {
        return carbGrams * 4
    }
    
    var fatGrams: Double {
        return fatGramsPerKg * weight
    }
    
    var fatCalories: Double {
        return fatGrams * 9
    }
    
    var currentTotalCalories: Double {
        return proteinCalories + carbCalories + fatCalories
    }
    
    // 计算当前百分比
    var proteinPercentage: Double {
        guard currentTotalCalories > 0 else { return 0 }
        return (proteinCalories / currentTotalCalories) * 100
    }
    
    var carbPercentage: Double {
        guard currentTotalCalories > 0 else { return 0 }
        return (carbCalories / currentTotalCalories) * 100
    }
    
    var fatPercentage: Double {
        guard currentTotalCalories > 0 else { return 0 }
        return (fatCalories / currentTotalCalories) * 100
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
        
        // 监听目标变化，自动调整营养素比例
        goalObserver = $goal.sink { [weak self] _ in
            self?.updateMacroPercentages()
        }
    }
    
    private func updateMacroPercentages() {
        // 根据目标自动调整g/kg值
        switch goal {
        case .weightLoss:
            proteinGramsPerKg = 2.2
            carbGramsPerKg = 3.8
            fatGramsPerKg = 1.0
        case .maintenance:
            proteinGramsPerKg = 1.8
            carbGramsPerKg = 4.2
            fatGramsPerKg = 1.0
        case .muscleGain:
            proteinGramsPerKg = 1.9
            carbGramsPerKg = 5.5
            fatGramsPerKg = 0.9
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
        case .light: return "轻度运动 1-3天/周低强度训练,偶尔健身、散步的上班族"
        case .moderate: return "中度运动 3-5天/周,每周 3 次健身房的健身爱好者"
        case .active: return "高强度运动 6-7天/周,运动员、健身教练"
        case .veryActive: return "极高强度运动，体力劳动,建筑工人、每日 2 次训练的运动员"
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
