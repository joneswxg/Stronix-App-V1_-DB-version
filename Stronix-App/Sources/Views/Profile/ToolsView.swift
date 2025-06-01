import SwiftUI

struct ToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showOneRMCalculator = false
    @State private var showBMICalculator = false
    @State private var showCalorieCalculator = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 计算器工具
                    VStack(spacing: 16) {
                        Text("计算器工具")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            ToolCard(
                                icon: "dumbbell.fill",
                                title: "1RM计算器",
                                subtitle: "预测最大单次重复重量",
                                color: .blue
                            ) {
                                showOneRMCalculator = true
                            }
                            
                            ToolCard(
                                icon: "figure.stand",
                                title: "BMI计算器",
                                subtitle: "计算身体质量指数",
                                color: .green
                            ) {
                                showBMICalculator = true
                            }
                            
                            ToolCard(
                                icon: "flame.fill",
                                title: "卡路里计算器",
                                subtitle: "计算每日所需卡路里",
                                color: .orange
                            ) {
                                showCalorieCalculator = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 其他工具
                    VStack(spacing: 16) {
                        Text("其他工具")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            ToolCard(
                                icon: "timer",
                                title: "训练计时器",
                                subtitle: "组间休息时间提醒",
                                color: .purple
                            ) {
                                // 训练计时器功能
                                print("打开训练计时器")
                            }
                            
                            ToolCard(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "进度追踪",
                                subtitle: "可视化训练进度",
                                color: .red
                            ) {
                                // 进度追踪功能
                                print("打开进度追踪")
                            }
                            
                            ToolCard(
                                icon: "water.waves",
                                title: "饮水提醒",
                                subtitle: "保持充足水分摄入",
                                color: .cyan
                            ) {
                                // 饮水提醒功能
                                print("打开饮水提醒")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(white: 0.95))
            .navigationTitle("小工具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showOneRMCalculator) {
            OneRMCalculatorView()
        }
        .sheet(isPresented: $showBMICalculator) {
            BMICalculatorView()
        }
        .sheet(isPresented: $showCalorieCalculator) {
            CalorieCalculatorView()
        }
    }
}

// 工具卡片
struct ToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 1RM计算器视图
struct OneRMCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var reps = ""
    @State private var oneRM: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 说明
                VStack(spacing: 12) {
                    Text("1RM计算器")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("输入您能完成的重量和次数，计算预测的最大单次重复重量")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 输入区域
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("重量 (kg)")
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("请输入重量", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("次数")
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("请输入次数", text: $reps)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                // 计算按钮
                Button(action: calculateOneRM) {
                    Text("计算1RM")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 20)
                
                // 结果显示
                if oneRM > 0 {
                    VStack(spacing: 12) {
                        Text("预测1RM")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text("\(oneRM, specifier: "%.1f") kg")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text("* 此结果仅供参考，实际训练请量力而行")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle("1RM计算器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func calculateOneRM() {
        guard let weightValue = Double(weight),
              let repsValue = Double(reps),
              weightValue > 0,
              repsValue > 0 else {
            return
        }
        
        // 使用Brzycki公式计算1RM
        oneRM = weightValue * (36 / (37 - repsValue))
    }
}

// BMI计算器视图
struct BMICalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var height = ""
    @State private var weight = ""
    @State private var bmi: Double = 0
    
    var bmiCategory: String {
        if bmi < 18.5 {
            return "偏瘦"
        } else if bmi < 24 {
            return "正常"
        } else if bmi < 28 {
            return "超重"
        } else {
            return "肥胖"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("BMI计算器")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 20)
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("身高 (cm)")
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("请输入身高", text: $height)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("体重 (kg)")
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("请输入体重", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                Button(action: calculateBMI) {
                    Text("计算BMI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 20)
                
                if bmi > 0 {
                    VStack(spacing: 12) {
                        Text("BMI指数")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text("\(bmi, specifier: "%.1f")")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text(bmiCategory)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .padding(20)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle("BMI计算器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func calculateBMI() {
        guard let heightValue = Double(height),
              let weightValue = Double(weight),
              heightValue > 0,
              weightValue > 0 else {
            return
        }
        
        let heightInMeters = heightValue / 100
        bmi = weightValue / (heightInMeters * heightInMeters)
    }
}

// 卡路里计算器视图
struct CalorieCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("卡路里计算器")
                    .font(.title)
                Text("卡路里计算器开发中...")
                    .foregroundColor(.gray)
            }
            .navigationTitle("卡路里计算器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ToolsView()
} 