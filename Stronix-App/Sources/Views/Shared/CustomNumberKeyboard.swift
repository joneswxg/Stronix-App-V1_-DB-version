import SwiftUI

/// 自定义数字键盘组件
/// 用于训练、编辑历史、创建计划、编辑计划等场景的数值输入
struct CustomNumberKeyboard: View {
    @Environment(\.theme) private var theme: AppTheme
    @Binding var value: Double
    @Binding var isShowing: Bool
    let step: Double // 步进值，重量用1.0，次数用1.0
    let maxValue: Double // 最大值限制
    let isInteger: Bool // 是否为整数（次数为true，重量为false）
    let keyboardManager: CustomKeyboardManager?
    
    // 内部输入字符串状态
    @State private var inputString: String = ""
    @State private var isInitialized: Bool = false
    
    init(value: Binding<Double>, isShowing: Binding<Bool>, step: Double = 1.0, maxValue: Double = 999.0, isInteger: Bool = false, keyboardManager: CustomKeyboardManager? = nil) {
        self._value = value
        self._isShowing = isShowing
        self.step = step
        self.maxValue = maxValue
        self.isInteger = isInteger
        self.keyboardManager = keyboardManager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 键盘背景
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 8) {
                        // 键盘按钮区域
                        VStack(spacing: 6) {
                            // 第一行: 1 2 3 键盘隐藏
                            HStack(spacing: 8) {
                                numberButton("1")
                                numberButton("2")
                                numberButton("3")
                                actionButton("keyboard.chevron.compact.down", action: hideKeyboard)
                            }
                            
                            // 第二行: 4 5 6 清零
                            HStack(spacing: 8) {
                                numberButton("4")
                                numberButton("5")
                                numberButton("6")
                                actionButton("clear", action: clearInput)
                            }
                            
                            // 第三行: 7 8 9 减少
                            HStack(spacing: 8) {
                                numberButton("7")
                                numberButton("8")
                                numberButton("9")
                                actionButton("minus", action: decreaseValue)
                            }
                            
                            // 第四行: . 0 删除 增加
                            HStack(spacing: 8) {
                                if !isInteger {
                                    numberButton(".")
                                } else {
                                    emptyButton()
                                }
                                numberButton("0")
                                actionButton("delete.left", action: deleteLastDigit)
                                actionButton("plus", action: increaseValue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    }
                )
        }
        .animation(.easeInOut(duration: 0.3), value: isShowing)
        .onAppear {
            initializeInputString()
        }
        .onChange(of: value) { _, newValue in
            if !isInitialized {
                initializeInputString()
            }
        }
    }
    
    // MARK: - 私有方法
    
    // 数字按钮
    private func numberButton(_ number: String) -> some View {
        Button(action: {
            appendNumber(number)
        }) {
            Text(number)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 55, height: 42)
                .background(Color.gray.opacity(0.4))
                .cornerRadius(6)
        }
    }
    
    // 功能按钮
    private func actionButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 55, height: 42)
                .background(theme.primary)
                .cornerRadius(6)
        }
    }
    
    // 空按钮（占位用）
    private func emptyButton() -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 55, height: 42)
    }
    
    // 格式化显示值
    private func formatValue(_ val: Double) -> String {
        if isInteger {
            return String(Int(val))
        } else {
            return String(format: "%.1f", val)
        }
    }
    
    // 初始化输入字符串
    private func initializeInputString() {
        if !isInitialized {
            if value == 0 {
                inputString = "0"
            } else if isInteger {
                inputString = String(Int(value))
            } else {
                // 对于小数，如果是整数值（如7.0），显示为"7"
                if value == Double(Int(value)) {
                    inputString = String(Int(value))
                } else {
                    inputString = String(value)
                }
            }
            isInitialized = true
        }
    }
    
    // 添加数字
    private func appendNumber(_ number: String) {
        if !isInitialized {
            initializeInputString()
        }
        
        // 如果数值被选中，直接替换
        if keyboardManager?.isValueSelected == true {
            keyboardManager?.isValueSelected = false
            if number == "." && !isInteger {
                inputString = "0."
            } else {
                inputString = number
            }
            updateValueFromString()
            return
        }
        
        if number == "." && !isInteger {
            // 添加小数点
            if !inputString.contains(".") {
                inputString += "."
                updateValueFromString()
            }
        } else {
            // 添加数字
            if inputString == "0" && number != "0" {
                inputString = number
            } else {
                inputString += number
            }
            updateValueFromString()
        }
    }
    
    // 删除最后一位
    private func deleteLastDigit() {
        if !isInitialized {
            initializeInputString()
        }
        
        // 如果数值被选中，直接清零
        if keyboardManager?.isValueSelected == true {
            keyboardManager?.isValueSelected = false
            inputString = "0"
            updateValueFromString()
            return
        }
        
        if inputString.count > 1 {
            inputString = String(inputString.dropLast())
            if inputString.isEmpty || inputString == "." {
                inputString = "0"
            }
        } else {
            inputString = "0"
        }
        updateValueFromString()
    }
    
    // 从字符串更新数值
    private func updateValueFromString() {
        if let newValue = Double(inputString) {
            let validValue = newValue.isNaN || newValue.isInfinite ? 0.0 : min(newValue, maxValue)
            value = validValue
        } else {
            value = 0
            inputString = "0"
        }
        keyboardManager?.updateValue(value)
    }
    
    // 清空输入
    private func clearInput() {
        keyboardManager?.isValueSelected = false
        inputString = "0"
        value = 0
        keyboardManager?.updateValue(value)
    }
    
    // 增加值
    private func increaseValue() {
        // 取消选中状态
        keyboardManager?.isValueSelected = false
        let newValue = value + step
        value = newValue.isNaN || newValue.isInfinite ? 0.0 : min(newValue, maxValue)
        // 重新初始化输入字符串以反映新值
        isInitialized = false
        initializeInputString()
        keyboardManager?.updateValue(value)
    }
    
    // 减少值
    private func decreaseValue() {
        // 取消选中状态
        keyboardManager?.isValueSelected = false
        let newValue = value - step
        value = newValue.isNaN || newValue.isInfinite ? 0.0 : max(newValue, 0)
        // 重新初始化输入字符串以反映新值
        isInitialized = false
        initializeInputString()
        keyboardManager?.updateValue(value)
    }
    
    // 隐藏键盘
    private func hideKeyboard() {
        isShowing = false
    }
}

// MARK: - 键盘管理器
/// 用于管理自定义键盘的显示和数据绑定
class CustomKeyboardManager: ObservableObject {
    @Published var isShowing = false
    @Published var currentValue: Double = 0.0
    @Published var isInteger = false
    @Published var step: Double = 1.0
    @Published var maxValue: Double = 999.0
    @Published var activeInputId: String = "" // 当前激活的输入框ID
    @Published var isValueSelected = false // 数值是否被选中（用于全选替换）
    
    private var onValueChanged: ((Double) -> Void)?
    
    /// 显示键盘
    /// - Parameters:
    ///   - inputId: 输入框的唯一标识
    ///   - initialValue: 初始值
    ///   - isInteger: 是否为整数
    ///   - step: 步进值
    ///   - maxValue: 最大值
    ///   - onValueChanged: 值改变回调
    func showKeyboard(
        inputId: String,
        initialValue: Double,
        isInteger: Bool = false,
        step: Double = 1.0,
        maxValue: Double = 999.0,
        onValueChanged: @escaping (Double) -> Void
    ) {
        self.activeInputId = inputId
        self.currentValue = initialValue
        self.isInteger = isInteger
        self.step = step
        self.maxValue = maxValue
        self.onValueChanged = onValueChanged
        self.isValueSelected = true // 新打开键盘时，默认选中数值
        self.isShowing = true
    }
    
    /// 隐藏键盘并应用值
    func hideKeyboard() {
        let validValue = currentValue.isNaN || currentValue.isInfinite ? 0.0 : currentValue
        onValueChanged?(validValue)
        activeInputId = ""
        isValueSelected = false
        isShowing = false
    }
    
    /// 取消键盘（不应用值）
    func cancelKeyboard() {
        activeInputId = ""
        isValueSelected = false
        isShowing = false
    }
    
    /// 实时更新值（在键盘输入过程中调用）
    func updateValue(_ newValue: Double) {
        let validValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
        currentValue = validValue
        onValueChanged?(validValue) // 实时更新
    }
}

#Preview {
    @Previewable @State var testValue = 12.5
    @Previewable @State var showKeyboard = true
    @Previewable @StateObject var keyboardManager = CustomKeyboardManager()
    
    return VStack {
        Spacer()
        
        VStack(spacing: 20) {
            Text("当前值: \(testValue, specifier: "%.1f")")
                .font(.title2)
            
            Button("点击输入重量") {
                keyboardManager.showKeyboard(
                    inputId: "test_weight",
                    initialValue: testValue,
                    isInteger: false,
                    step: 1.0,
                    maxValue: 999.0
                ) { newValue in
                    testValue = newValue
                    print("重量更新为: \(newValue)")
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("点击输入次数") {
                keyboardManager.showKeyboard(
                    inputId: "test_reps",
                    initialValue: Double(Int(testValue)),
                    isInteger: true,
                    step: 1.0,
                    maxValue: 999.0
                ) { newValue in
                    testValue = newValue
                    print("次数更新为: \(Int(newValue))")
                }
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        
        Spacer()
        
        // 自定义键盘
        if keyboardManager.isShowing {
            CustomNumberKeyboard(
                value: $keyboardManager.currentValue,
                isShowing: $keyboardManager.isShowing,
                step: keyboardManager.step,
                maxValue: keyboardManager.maxValue,
                isInteger: keyboardManager.isInteger,
                keyboardManager: keyboardManager
            )
        }
    }
    .background(Color.gray.opacity(0.1))
}