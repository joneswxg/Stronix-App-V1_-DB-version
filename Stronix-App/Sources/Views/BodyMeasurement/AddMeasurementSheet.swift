import SwiftUI

struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BodyMeasurementViewModel
    
    @State private var selectedDate = Date()
    @State private var weight = ""
    @State private var height = ""
    @State private var bodyFatPercentage = ""
    @State private var muscleMass = ""
    @State private var visceralFatLevel = ""
    @State private var isSaving = false
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题区域
                VStack(spacing: 16) {
                    Text("手动输入体测仪测试结果")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.top, 20)
                    
                    // 测试日期
                    VStack(alignment: .leading, spacing: 8) {
                        Text("测试日期")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        
                        HStack {
                            Text(formatDate(selectedDate))
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            Spacer()
                            Button("修改") {
                                showingDatePicker = true
                                hideKeyboard() // 打开日期选择器时隐藏键盘
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                
                // 添加结果标题
                HStack {
                    Text("添加结果")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 16)
                
                // 输入字段
                VStack(spacing: 16) {
                    InputField(
                        title: "体重",
                        value: $weight,
                        unit: "kg",
                        placeholder: "请输入体重"
                    )
                    
                    InputField(
                        title: "身高",
                        value: $height,
                        unit: "cm",
                        placeholder: "请输入身高"
                    )
                    
                    InputField(
                        title: "体脂百分比",
                        value: $bodyFatPercentage,
                        unit: "%",
                        placeholder: "请输入体脂百分比"
                    )
                    
                    InputField(
                        title: "骨骼肌量",
                        value: $muscleMass,
                        unit: "kg",
                        placeholder: "请输入骨骼肌量"
                    )
                    
                    InputField(
                        title: "内脏脂肪等级",
                        value: $visceralFatLevel,
                        unit: "Lv",
                        placeholder: "请输入内脏脂肪等级"
                    )
                }
                .padding(.horizontal, 20)
                
                // 提示信息
                VStack(spacing: 4) {
                    Text("由于报告纸上只会显示小数点一位数，")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("所以手动输入时可能会产生微小的误差")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 确认按钮
                Button(action: {
                    hideKeyboard() // 保存前先隐藏键盘
                    Task {
                        await saveData()
                    }
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isSaving ? "保存中..." : "确认")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background((isFormValid && !isSaving) ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(!isFormValid || isSaving)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
                
                // 键盘工具栏
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        hideKeyboard()
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate)
            }
            .onTapGesture {
                // 点击空白区域隐藏键盘
                hideKeyboard()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var isFormValid: Bool {
        !weight.isEmpty && 
        !height.isEmpty && 
        !bodyFatPercentage.isEmpty && 
        !muscleMass.isEmpty && 
        !visceralFatLevel.isEmpty &&
        isValidWeight &&
        isValidHeight &&
        isValidBodyFat &&
        isValidMuscleMass &&
        isValidVisceralFat
    }
    
    private var isValidWeight: Bool {
        guard let value = Double(weight) else { return false }
        return value >= 20 && value <= 200
    }
    
    private var isValidHeight: Bool {
        guard let value = Double(height) else { return false }
        return value >= 100 && value <= 250
    }
    
    private var isValidBodyFat: Bool {
        guard let value = Double(bodyFatPercentage) else { return false }
        return value >= 0 && value <= 50
    }
    
    private var isValidMuscleMass: Bool {
        guard let value = Double(muscleMass) else { return false }
        return value >= 10 && value <= 100
    }
    
    private var isValidVisceralFat: Bool {
        guard let value = Int(visceralFatLevel) else { return false }
        return value >= 1 && value <= 20
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
    
    private func saveData() async {
        guard let weightValue = Double(weight),
              let heightValue = Double(height),
              let bodyFatValue = Double(bodyFatPercentage),
              let muscleMassValue = Double(muscleMass),
              let visceralFatValue = Int(visceralFatLevel) else {
            return
        }
        
        isSaving = true
        
        let request = CreateBodyMeasurementRequest(
            userId: LocalUserService.shared.currentUser?.id ?? 0,
            measurementTimestamp: selectedDate,
            weightKg: weightValue,
            heightCm: heightValue,
            bodyFatPercentage: bodyFatValue,
            skeletalMuscleMassKg: muscleMassValue,
            visceralFatLevel: visceralFatValue
        )
        
        let success = await viewModel.addMeasurement(request)
        
        isSaving = false
        
        if success {
            dismiss()
        }
        // 如果失败，错误信息会在viewModel中处理
    }
}

// 日期选择器组件
struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    @State private var tempDate: Date
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "选择日期",
                    selection: $tempDate,
                    in: ...Date(),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("选择测试日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        selectedDate = tempDate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// 输入字段组件
struct InputField: View {
    let title: String
    @Binding var value: String
    let unit: String
    let placeholder: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
                HStack(spacing: 8) {
                    TextField(placeholder, text: $value)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 16))
                        .focused($isFocused)
                    Text(unit)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Button(action: {
                        value = ""
                        isFocused = false // 清空输入时隐藏键盘
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    AddMeasurementSheet(viewModel: BodyMeasurementViewModel())
} 