import SwiftUI
import UIKit

protocol PlanFormSet: Identifiable {
    var weight: Double { get set }
    var leftWeight: Double { get set }
    var rightWeight: Double { get set }
    var reps: Int { get set }
}

struct PlanFormSetNotesConfiguration<SetValue> {
    let hasNotes: (SetValue) -> Bool
    let toggleNotes: (inout SetValue) -> Void
    let note: (SetValue) -> String
    let updateNote: (inout SetValue, String) -> Void
}

protocol PlanFormAction: Identifiable where ID == Int {
    associatedtype SetValue: PlanFormSet

    var actionId: Int { get }
    var name: String { get }
    var imageUrl: String { get }
    var restTime: Int { get set }
    var formNote: String { get set }
    var recordsBilateral: Bool { get set }
    var isExpanded: Bool { get set }
    var sets: [SetValue] { get set }
}

struct PlanFormNameEditor: View {
    enum DescriptionStyle {
        case optionalMenu
        case labeled
    }

    @Environment(\.theme) private var theme: AppTheme
    @Binding var name: String
    @Binding var description: String
    @Binding var isDescriptionVisible: Bool
    let style: DescriptionStyle
    let isDisabled: Bool
    let dismissNumericKeyboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if style == .labeled {
                Text("计划名称")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                TextField("输入计划名称", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isDisabled)
                    .onTapGesture(perform: dismissNumericKeyboard)

                if style == .optionalMenu {
                    Menu {
                        Button(isDescriptionVisible ? "删除描述" : "添加描述", systemImage: isDescriptionVisible ? "trash" : "note.text") {
                            isDescriptionVisible.toggle()
                            if !isDescriptionVisible { description = "" }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(theme.secondary)
                            .frame(width: 30, height: 30)
                            .background(theme.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal, 16)

            if isDescriptionVisible {
                if style == .labeled {
                    Text("计划描述")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                }

                TextField(style == .optionalMenu ? "添加计划描述" : "输入计划描述", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                    .padding(.horizontal, 16)
                    .disabled(isDisabled)
                    .onTapGesture(perform: dismissNumericKeyboard)
            }
        }
    }
}

struct PlanFormSaveButton: View {
    let isSaving: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSaving {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Text("保存")
                }
            }
        }
        .disabled(!isEnabled || isSaving)
    }
}

struct PlanFormActionList<Action: PlanFormAction>: View {
    @Binding var actions: [Action]
    let weightUnit: String
    let allowsUnitToggle: Bool
    let notesConfiguration: PlanFormSetNotesConfiguration<Action.SetValue>?
    let usesCircularImage: Bool
    let isDisabled: Bool
    let keyboardManager: CustomKeyboardManager
    let makeSet: () -> Action.SetValue
    let onDelete: (Action) -> Void
    let onToggleUnit: () -> Void
    let actionDetail: ((Action) -> AnyView)?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(actions) { action in
                PlanFormActionCard(
                    action: binding(for: action),
                    weightUnit: weightUnit,
                    allowsUnitToggle: allowsUnitToggle,
                    notesConfiguration: notesConfiguration,
                    usesCircularImage: usesCircularImage,
                    isDisabled: isDisabled,
                    keyboardManager: keyboardManager,
                    makeSet: makeSet,
                    onDelete: { onDelete(action) },
                    onToggleUnit: onToggleUnit,
                    actionDetail: actionDetail
                )
            }
        }
    }

    private func binding(for action: Action) -> Binding<Action> {
        Binding(
            get: { actions.first(where: { $0.id == action.id }) ?? action },
            set: { updated in
                guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
                actions[index] = updated
            }
        )
    }
}

private struct PlanFormActionCard<Action: PlanFormAction>: View {
    @Environment(\.theme) private var theme: AppTheme
    @Binding var action: Action
    let weightUnit: String
    let allowsUnitToggle: Bool
    let notesConfiguration: PlanFormSetNotesConfiguration<Action.SetValue>?
    let usesCircularImage: Bool
    let isDisabled: Bool
    let keyboardManager: CustomKeyboardManager
    let makeSet: () -> Action.SetValue
    let onDelete: () -> Void
    let onToggleUnit: () -> Void
    let actionDetail: ((Action) -> AnyView)?

    @State private var showRestTimer = false
    @State private var showDeleteAlert = false
    @State private var minutes = 1
    @State private var seconds = 0
    @State private var showActionDetail = false

    private var volume: Int {
        action.sets.reduce(0) { total, set in
            let weight = action.recordsBilateral ? set.leftWeight + set.rightWeight : set.weight
            let safeWeight = weight.isFinite ? weight : 0
            return total + Int(safeWeight * Double(set.reps))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if action.isExpanded {
                PlanFormSetEditor(
                    sets: $action.sets,
                    recordsBilateral: $action.recordsBilateral,
                    actionID: action.id,
                    weightUnit: weightUnit,
                    notesConfiguration: notesConfiguration,
                    isDisabled: isDisabled,
                    keyboardManager: keyboardManager,
                    makeSet: makeSet
                )
            }
        }
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.onBackground.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showRestTimer) { restTimerSheet }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive, action: onDelete)
        } message: {
            Text("确定要删除这个训练动作吗？")
        }
        .navigationDestination(isPresented: $showActionDetail) {
            actionDetail?(action) ?? AnyView(EmptyView())
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Group {
                    if let image = loadLocalActionImage(fileName: action.imageUrl) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(theme.secondary.opacity(0.3))
                            .overlay(Image(systemName: "figure.strengthtraining.traditional").foregroundColor(theme.secondary))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: usesCircularImage ? 25 : 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(action.name).font(.system(size: 16, weight: .medium)).lineLimit(1)
                        Spacer()
                        Text("\(volume)").font(.system(size: 16, weight: .medium)).foregroundColor(theme.secondary)
                    }
                    HStack {
                        Text("\(action.sets.count)组").font(.system(size: 14)).foregroundColor(theme.secondary)
                        Spacer()
                        Toggle("记录左右", isOn: $action.recordsBilateral)
                            .font(.system(size: 12))
                            .tint(theme.primary)
                            .scaleEffect(0.8)
                            .disabled(isDisabled)
                            .onChange(of: action.recordsBilateral) { _, bilateral in
                                for index in action.sets.indices {
                                    if bilateral {
                                        action.sets[index].weight = 0
                                    } else {
                                        action.sets[index].leftWeight = 0
                                        action.sets[index].rightWeight = 0
                                    }
                                }
                            }
                    }
                }

                Menu {
                    if actionDetail != nil {
                        Button("动作详情", systemImage: "info.circle") { showActionDetail = true }
                    }
                    Button("设置休息计时器", systemImage: "timer") {
                        minutes = action.restTime / 60
                        seconds = action.restTime % 60
                        showRestTimer = true
                    }
                    if allowsUnitToggle {
                        Button("切换单位 (\(weightUnit))", systemImage: "arrow.2.squarepath", action: onToggleUnit)
                    }
                    Button("删除动作", systemImage: "trash", role: .destructive) { showDeleteAlert = true }
                } label: {
                    Image(systemName: "gearshape.fill").foregroundColor(theme.primary).font(.system(size: 20))
                }
                .disabled(isDisabled)
            }

            if action.isExpanded {
                Divider().padding(.vertical, 4)
                PlanFormSetHeader(recordsBilateral: action.recordsBilateral, weightUnit: weightUnit)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { action.isExpanded.toggle() }
        }
    }

    private var restTimerSheet: some View {
        NavigationView {
            Form {
                Section("设置休息时间") {
                    Stepper("分钟: \(minutes)", value: $minutes, in: 0...10)
                    Stepper("秒数: \(seconds)", value: $seconds, in: 0...59)
                }
            }
            .navigationTitle("休息计时器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { showRestTimer = false } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        action.restTime = minutes * 60 + seconds
                        showRestTimer = false
                    }
                }
            }
        }
    }
}

private struct PlanFormSetHeader: View {
    @Environment(\.theme) private var theme: AppTheme
    let recordsBilateral: Bool
    let weightUnit: String

    var body: some View {
        HStack(spacing: 16) {
            label("组", width: 30)
            if recordsBilateral {
                label("左\(weightUnit)", width: 60)
                label("右\(weightUnit)", width: 60)
            } else {
                label(weightUnit, width: 60)
            }
            label("次数", width: 60)
            Spacer()
        }
        .padding(.horizontal, 36)
    }

    private func label(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .frame(width: width, height: 36)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(theme.secondary)
            .background(theme.surface)
            .cornerRadius(6)
    }
}

private struct PlanFormSetEditor<SetValue: PlanFormSet>: View {
    @Environment(\.theme) private var theme: AppTheme
    @Binding var sets: [SetValue]
    @Binding var recordsBilateral: Bool
    let actionID: Int
    let weightUnit: String
    let notesConfiguration: PlanFormSetNotesConfiguration<SetValue>?
    let isDisabled: Bool
    let keyboardManager: CustomKeyboardManager
    let makeSet: () -> SetValue

    @State private var setIDToDelete: SetValue.ID?

    var body: some View {
        VStack(spacing: 16) {
            ForEach(sets.indices, id: \.self) { index in
                row(index: index)
            }
            HStack {
                Button("新增一组") { sets.append(makeSet()) }
                    .font(.system(size: 14))
                    .foregroundColor(theme.primary)
                    .disabled(isDisabled)
                Spacer()
                Button("动作历史") { }
                    .font(.system(size: 14))
                    .foregroundColor(theme.primary)
                    .disabled(isDisabled)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .alert("确认删除", isPresented: Binding(
            get: { setIDToDelete != nil },
            set: { if !$0 { setIDToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { setIDToDelete = nil }
            Button("删除", role: .destructive) {
                if let id = setIDToDelete { sets.removeAll { $0.id == id } }
                setIDToDelete = nil
            }
        } message: {
            Text("确定要删除这组吗？")
        }
    }

    private func row(index: Int) -> some View {
        let set = sets[index]
        return VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 36)
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(6)

                if recordsBilateral {
                    numberButton("left_weight", value: set.leftWeight, index: index) { sets[index].leftWeight = $0 }
                    numberButton("right_weight", value: set.rightWeight, index: index) { sets[index].rightWeight = $0 }
                } else {
                    numberButton("weight", value: set.weight, index: index) { sets[index].weight = $0 }
                }
                numberButton("reps", value: Double(set.reps), index: index, isInteger: true) { sets[index].reps = Int($0) }
                Spacer()
                Menu {
                    if let notesConfiguration {
                        Button(
                            notesConfiguration.hasNotes(set) ? "删除备注" : "输入备注",
                            systemImage: notesConfiguration.hasNotes(set) ? "trash" : "note.text"
                        ) {
                            var updatedSet = sets[index]
                            notesConfiguration.toggleNotes(&updatedSet)
                            sets[index] = updatedSet
                        }
                    }
                    Button("删除", systemImage: "trash", role: .destructive) { setIDToDelete = set.id }
                } label: {
                    Image(systemName: "ellipsis").foregroundColor(.gray).frame(width: 30, height: 30)
                }
                .disabled(isDisabled)
            }
            .padding(.horizontal, 36)

            if let notesConfiguration, notesConfiguration.hasNotes(set) {
                TextField("输入备注", text: Binding(
                    get: { notesConfiguration.note(sets[index]) },
                    set: { note in
                        var updatedSet = sets[index]
                        notesConfiguration.updateNote(&updatedSet, note)
                        sets[index] = updatedSet
                    }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
                .padding(.horizontal, 78)
                .disabled(isDisabled)
                .onTapGesture { keyboardManager.cancelKeyboard() }
            }
        }
    }

    private func numberButton(
        _ kind: String,
        value: Double,
        index: Int,
        isInteger: Bool = false,
        update: @escaping (Double) -> Void
    ) -> some View {
        let inputID = "\(kind)_\(actionID)_\(sets[index].id)"
        let active = keyboardManager.activeInputId == inputID
        let selected = active && keyboardManager.isValueSelected
        return Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            keyboardManager.showKeyboard(inputId: inputID, initialValue: value, isInteger: isInteger, step: 1, maxValue: 999) {
                update($0.isFinite ? $0 : 0)
            }
        } label: {
            Text(isInteger ? "\(Int(value))" : (value == 0 ? "0" : String(format: "%.1f", value)))
                .font(.system(size: 16))
                .foregroundColor(selected ? .white : .black)
                .frame(width: 60, height: 36)
                .background(selected ? theme.primary : Color(UIColor.systemGroupedBackground))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(active && !selected ? theme.primary : .clear, lineWidth: 2))
        }
        .disabled(isDisabled)
    }
}

private func loadLocalActionImage(fileName: String) -> UIImage? {
    let cleanPath = fileName.replacingOccurrences(of: ".gif", with: "")
    if let url = Bundle.main.url(forResource: cleanPath, withExtension: "gif"), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
        return image
    }
    let name = URL(fileURLWithPath: fileName).lastPathComponent.replacingOccurrences(of: ".gif", with: "")
    for path in ["Images/abs/\(name)", "Images/pectorals/\(name)", "Images/biceps/\(name)", "Images/triceps/\(name)", "Images/delts/\(name)", "Images/lats/\(name)", "Images/quads/\(name)", "Images/hamstrings/\(name)", "Images/glutes/\(name)", "Images/calves/\(name)", "Images/forearms/\(name)", "Images/traps/\(name)", "Images/cardiovascular system/\(name)", "Images/spine/\(name)", "Images/upper back/\(name)", "Images/serratus anterior/\(name)", "Images/levator scapulae/\(name)", "Images/adductors/\(name)", "Images/abductors/\(name)", name] {
        if let url = Bundle.main.url(forResource: path, withExtension: "gif"), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            return image
        }
    }
    return nil
}
