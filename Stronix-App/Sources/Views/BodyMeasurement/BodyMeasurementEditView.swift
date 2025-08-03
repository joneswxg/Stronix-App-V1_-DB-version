import SwiftUI

struct BodyMeasurementEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: BodyMeasurementViewModel
    let record: BodyMeasurement
    
    @State private var selectedDate: Date
    @State private var weight: String
    @State private var height: String
    @State private var bodyFatPercentage: String
    @State private var muscleMass: String
    @State private var visceralFatLevel: String
    @State private var isSaving = false
    @State private var showingDatePicker = false
    
    init(viewModel: BodyMeasurementViewModel, record: BodyMeasurement) {
        self.viewModel = viewModel
        self.record = record
        
        // 初始化状态变量
        self._selectedDate = State(initialValue: record.measurementTimestamp)
        self._weight = State(initialValue: String(format: "%.1f", record.weightKg))
        self._height = State(initialValue: String(format: "%.1f", record.heightCm))
        self._bodyFatPercentage = State(initialValue: String(format: "%.1f", record.bodyFatPercentage))
        self._muscleMass = State(initialValue: String(format: "%.1f", record.skeletalMuscleMassKg))
        self._visceralFatLevel = State(initialValue: String(record.visceralFatLevel))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 日期区域
            VStack(spacing: 16) {
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
            .padding(.top, 20)
            
            // 编辑数据标题
            HStack {
                Text("编辑数据")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 16)
            
            // 输入字段
            VStack(spacing: 16) {
                EditInputField(
                    title: "体重",
                    value: $weight,
                    unit: "kg",
                    placeholder: "请输入体重"
                )
                
                EditInputField(
                    title: "身高",
                    value: $height,
                    unit: "cm",
                    placeholder: "请输入身高"
                )
                
                EditInputField(
                    title: "体脂百分比",
                    value: $bodyFatPercentage,
                    unit: "%",
                    placeholder: "请输入体脂百分比"
                )
                
                EditInputField(
                    title: "骨骼肌量",
                    value: $muscleMass,
                    unit: "kg",
                    placeholder: "请输入骨骼肌量"
                )
                
                EditInputField(
                    title: "内脏脂肪等级",
                    value: $visceralFatLevel,
                    unit: "Lv",
                    placeholder: "请输入内脏脂肪等级"
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // 保存按钮
            Button(action: {
                hideKeyboard() // 保存前先隐藏键盘
                Task {
                    await saveChanges()
                }
            }) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    Text(isSaving ? "保存中..." : "保存修改")
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
        .navigationTitle("编辑体测记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("返回")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.blue)
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
    
    private func saveChanges() async {
        guard let weightValue = Double(weight),
              let heightValue = Double(height),
              let bodyFatValue = Double(bodyFatPercentage),
              let muscleMassValue = Double(muscleMass),
              let visceralFatValue = Int(visceralFatLevel) else {
            return
        }
        
        isSaving = true
        
        // 这里需要调用更新API
        // 暂时使用删除+添加的方式来模拟更新
        let deleteSuccess = await viewModel.deleteMeasurement(record.id)
        
        if deleteSuccess {
            let request = CreateBodyMeasurementRequest(
                userId: LocalUserService.shared.currentUser?.id ?? 0,
                measurementTimestamp: selectedDate,
                weightKg: weightValue,
                heightCm: heightValue,
                bodyFatPercentage: bodyFatValue,
                skeletalMuscleMassKg: muscleMassValue,
                visceralFatLevel: visceralFatValue
            )
            
            let addSuccess = await viewModel.addMeasurement(request)
            
            if addSuccess {
                presentationMode.wrappedValue.dismiss()
            }
        }
        
        isSaving = false
    }
}

// 编辑输入字段组件
struct EditInputField: View {
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
    NavigationView {
        BodyMeasurementEditView(
            viewModel: BodyMeasurementViewModel(),
            record: BodyMeasurement(
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
            )
        )
    }
} 