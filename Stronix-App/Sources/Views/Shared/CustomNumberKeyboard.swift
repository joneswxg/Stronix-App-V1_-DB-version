import SwiftUI

struct BilateralRecordingAccessory {
    var isEnabled: Bool
    let onChange: (Bool) -> Void
}

struct TrainingKeyboardRail {
    let isBilateralRecording: () -> Bool
    let displayUnit: () -> TrainingDisplayUnit
    let onToggleBilateral: () -> Void
    let onFill: () -> Void
    let onToggleDisplayUnit: () -> Void
    let onAddSet: () -> Void
}

struct CustomNumberKeyboard: View {
    @Environment(\.designTokens) private var tokens
    @Binding var value: Double
    @Binding var isShowing: Bool
    let step: Double
    let maxValue: Double
    let isInteger: Bool
    let keyboardManager: CustomKeyboardManager?

    @State private var inputString = ""
    @State private var isInitialized = false
    @State private var feedbackKey: String?

    init(value: Binding<Double>, isShowing: Binding<Bool>, step: Double = 1.0, maxValue: Double = 999.0, isInteger: Bool = false, keyboardManager: CustomKeyboardManager? = nil) {
        _value = value
        _isShowing = isShowing
        self.step = step
        self.maxValue = maxValue
        self.isInteger = isInteger
        self.keyboardManager = keyboardManager
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.small) {
                if let rail = keyboardManager?.trainingKeyboardRail {
                    actionRail(rail)
                }
                VStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: DesignTokens.Spacing.small) {
                            ForEach(row, id: \.self) { key in
                                keyButton(key)
                            }
                        }
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(tokens.controlSurface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("training.accessibility.numberKeyboard")
        .onAppear(perform: initializeInputString)
        .onChange(of: value) { _, _ in
            if !isInitialized {
                initializeInputString()
            }
        }
    }

    private func actionRail(_ rail: TrainingKeyboardRail) -> some View {
        let isBilateralRecording = rail.isBilateralRecording()
        return VStack(spacing: DesignTokens.Spacing.small) {
            railButton(title: "记录左右", label: "training.keyboard.bilateral", isSelected: isBilateralRecording, action: rail.onToggleBilateral)
            railButton(title: "一键设置", label: "training.keyboard.fill", action: { rail.onFill(); showFeedback("training.keyboard.fill.feedback") })
            railButton(title: "kg/lbs", label: "training.keyboard.unit", action: rail.onToggleDisplayUnit)
            railButton(title: "增加一组", label: "training.keyboard.addSet", action: { rail.onAddSet(); showFeedback("training.keyboard.addSet.feedback") })
            if let feedbackKey {
                Text(LocalizedStringKey(feedbackKey))
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(tokens.primary)
                    .frame(maxWidth: 96)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func railButton(title: String, label: LocalizedStringKey, isSelected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.supporting)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? tokens.onPrimary : tokens.primary)
                .frame(width: 84, height: DesignTokens.Metric.minimumTapSize)
                .background(isSelected ? tokens.primary : tokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                        .stroke(tokens.border, lineWidth: DesignTokens.Metric.borderWidth)
                }
        }
        .accessibilityLabel(label)
        .accessibilityValue(feedbackKey.map { Text($0) } ?? Text(""))
    }

    private func showFeedback(_ key: String) {
        feedbackKey = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            feedbackKey = nil
        }
    }

    private var rows: [[String]] {
        [
            ["1", "2", "3", "hide"],
            ["4", "5", "6", "clear"],
            ["7", "8", "9", "decrease"],
            [isInteger ? "empty" : ".", "0", "delete", "increase"]
        ]
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key == "empty" {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Metric.minimumTapSize)
        } else {
            Button(action: { perform(key) }) {
                Group {
                    if let symbol = symbol(for: key) {
                        Image(systemName: symbol)
                    } else {
                        Text(key)
                    }
                }
                .font(DesignTokens.Typography.action)
                .foregroundStyle(keyIsAction(key) ? tokens.onPrimary : tokens.contentPrimary)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metric.minimumTapSize)
                .background(keyIsAction(key) ? tokens.primary : tokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                        .stroke(keyIsAction(key) ? .clear : tokens.border, lineWidth: DesignTokens.Metric.borderWidth)
                }
            }
            .accessibilityLabel(accessibilityLabel(for: key))
        }
    }

    private func keyIsAction(_ key: String) -> Bool {
        ["hide", "clear", "decrease", "delete", "increase"].contains(key)
    }

    private func symbol(for key: String) -> String? {
        switch key {
        case "hide": "keyboard.chevron.compact.down"
        case "clear": "clear"
        case "decrease": "minus"
        case "delete": "delete.left"
        case "increase": "plus"
        default: nil
        }
    }

    private func accessibilityLabel(for key: String) -> LocalizedStringKey {
        switch key {
        case "hide": "training.keyboard.hide"
        case "clear": "training.keyboard.clear"
        case "decrease": "training.keyboard.decrease"
        case "delete": "training.keyboard.delete"
        case "increase": "training.keyboard.increase"
        case ".": "training.keyboard.decimal"
        default: LocalizedStringKey(key)
        }
    }

    private func perform(_ key: String) {
        switch key {
        case "hide": hideKeyboard()
        case "clear": clearInput()
        case "decrease": decreaseValue()
        case "delete": deleteLastDigit()
        case "increase": increaseValue()
        default: appendNumber(key)
        }
    }

    private func initializeInputString() {
        guard !isInitialized else { return }
        if value == 0 { inputString = "0" }
        else if isInteger || value == Double(Int(value)) { inputString = String(Int(value)) }
        else { inputString = String(value) }
        isInitialized = true
    }

    private func appendNumber(_ number: String) {
        if !isInitialized { initializeInputString() }
        if keyboardManager?.isValueSelected == true {
            keyboardManager?.isValueSelected = false
            inputString = number == "." && !isInteger ? "0." : number
        } else if number == "." && !isInteger {
            guard !inputString.contains(".") else { return }
            inputString += "."
        } else {
            inputString = inputString == "0" && number != "0" ? number : inputString + number
        }
        updateValueFromString()
    }

    private func deleteLastDigit() {
        if !isInitialized { initializeInputString() }
        keyboardManager?.isValueSelected = false
        inputString = inputString.count > 1 ? String(inputString.dropLast()) : "0"
        if inputString.isEmpty || inputString == "." { inputString = "0" }
        updateValueFromString()
    }

    private func updateValueFromString() {
        guard let newValue = Double(inputString), !newValue.isNaN, !newValue.isInfinite else {
            value = 0
            inputString = "0"
            keyboardManager?.updateValue(value)
            return
        }
        value = min(newValue, maxValue)
        keyboardManager?.updateValue(value)
    }

    private func clearInput() {
        keyboardManager?.isValueSelected = false
        inputString = "0"
        value = 0
        keyboardManager?.updateValue(value)
    }

    private func increaseValue() {
        keyboardManager?.isValueSelected = false
        value = min(value + step, maxValue)
        isInitialized = false
        initializeInputString()
        keyboardManager?.updateValue(value)
    }

    private func decreaseValue() {
        keyboardManager?.isValueSelected = false
        value = max(value - step, 0)
        isInitialized = false
        initializeInputString()
        keyboardManager?.updateValue(value)
    }

    private func hideKeyboard() {
        if let keyboardManager {
            keyboardManager.hideKeyboard()
        } else {
            isShowing = false
        }
    }
}

class CustomKeyboardManager: ObservableObject {
    @Published var isShowing = false
    @Published var currentValue: Double = 0.0
    @Published var isInteger = false
    @Published var step: Double = 1.0
    @Published var maxValue: Double = 999.0
    @Published var activeInputId = ""
    @Published var isValueSelected = false
    @Published var bilateralRecordingAccessory: BilateralRecordingAccessory?
    @Published var trainingKeyboardRail: TrainingKeyboardRail?

    private var onValueChanged: ((Double) -> Void)?

    func showKeyboard(inputId: String, initialValue: Double, isInteger: Bool = false, step: Double = 1.0, maxValue: Double = 999.0, bilateralRecordingAccessory: BilateralRecordingAccessory? = nil, trainingKeyboardRail: TrainingKeyboardRail? = nil, onValueChanged: @escaping (Double) -> Void) {
        activeInputId = inputId
        currentValue = initialValue
        self.isInteger = isInteger
        self.step = step
        self.maxValue = maxValue
        self.bilateralRecordingAccessory = bilateralRecordingAccessory
        self.trainingKeyboardRail = trainingKeyboardRail
        self.onValueChanged = onValueChanged
        isValueSelected = true
        isShowing = true
    }

    func hideKeyboard() {
        let validValue = currentValue.isNaN || currentValue.isInfinite ? 0.0 : currentValue
        onValueChanged?(validValue)
        activeInputId = ""
        isValueSelected = false
        bilateralRecordingAccessory = nil
        trainingKeyboardRail = nil
        isShowing = false
    }

    func cancelKeyboard() {
        activeInputId = ""
        isValueSelected = false
        bilateralRecordingAccessory = nil
        trainingKeyboardRail = nil
        isShowing = false
    }

    func updateValue(_ newValue: Double) {
        let validValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
        currentValue = validValue
        onValueChanged?(validValue)
    }
}
