import SwiftUI

struct PlanActionSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    @StateObject private var viewModel = ActionListViewModel()
    @State private var selectedActions: Set<Int> = []
    @State private var selectedTargetMuscleId: Int = 0
    @State private var selectedEquipmentId: Int = 0
    @State private var searchText = ""
    @State private var hasInitialized = false
    
    // 使用静态变量来保持全局状态
    private static var globalSelectedTargetMuscleId: Int = 5
    private static var globalHasInitialized = false
    
    // 添加回调闭包 - 支持单个动作选择
    let onActionSelected: ((ActionInfo) -> Void)?
    let onActionsSelected: (([Action]) -> Void)?
    let allowMultipleSelection: Bool
    
    // 已存在于计划中的动作ID列表
    let existingActionIds: Set<Int>
    
    // 修改初始化方法
    init(onActionSelected: ((ActionInfo) -> Void)? = nil, onActionsSelected: (([Action]) -> Void)? = nil, existingActionIds: Set<Int> = []) {
        self.onActionSelected = onActionSelected
        self.onActionsSelected = onActionsSelected
        self.allowMultipleSelection = onActionsSelected != nil
        self.existingActionIds = existingActionIds
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { mainGeometry in
                VStack(spacing: 0) {
                    // 搜索栏
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.secondary)
                        TextField("搜索训练动作", text: $searchText)
                    }
                    .padding()
                    .background(theme.surface)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 训练设备过滤栏
                    equipmentFilterView
                        .background(theme.background)
                        .shadow(color: theme.secondary.opacity(0.1), radius: 1, y: 1)
                    
                    // 主要内容区域
                    HStack(spacing: 0) {
                        // 左侧导航栏
                        VStack {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    // 添加"所有动作"按钮
                                    Button(action: { 
                                        selectedTargetMuscleId = 0
                                        Self.globalSelectedTargetMuscleId = 0
                                        Task {
                                            await viewModel.loadActions()
                                        }
                                    }) {
                                        Text("所有动作")
                                            .font(.system(size: 13))
                                            .foregroundColor(selectedTargetMuscleId == 0 ? theme.onPrimary : theme.onBackground)
                                            .fontWeight(selectedTargetMuscleId == 0 ? .medium : .regular)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 10)
                                            .background(selectedTargetMuscleId == 0 ? theme.primary : Color.clear)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    ForEach(viewModel.targetMuscles) { muscle in
                                        Button(action: { 
                                            selectedTargetMuscleId = muscle.id
                                            Self.globalSelectedTargetMuscleId = muscle.id
                                            Task {
                                                await viewModel.loadActionsByTargetMuscle(targetMuscleId: muscle.id)
                                            }
                                        }) {
                                            Text(muscle.display_name)
                                                .font(.system(size: 13))
                                                .foregroundColor(selectedTargetMuscleId == muscle.id ? theme.onPrimary : theme.onBackground)
                                                .fontWeight(selectedTargetMuscleId == muscle.id ? .medium : .regular)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 10)
                                                .background(selectedTargetMuscleId == muscle.id ? theme.primary : Color.clear)
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                            }
                            .frame(width: mainGeometry.size.width * 0.25)
                            .background(theme.surface)
                        }
                        .frame(maxHeight: .infinity)
                        
                        // 右侧动作列表
                        ScrollView(.vertical, showsIndicators: false) {
                            if viewModel.isLoading {
                                ProgressView("加载中...")
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            } else if filteredActions.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(theme.secondary)
                                    
                                    Text("暂无动作")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("请尝试切换其他肌肉群或调整筛选条件")
                                        .font(.system(size: 14))
                                        .foregroundColor(theme.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                // 按器材分组显示动作
                                LazyVStack(alignment: .leading, spacing: 20) {
                                    ForEach(groupedActionsByEquipment.keys.sorted(by: { $0 < $1 }), id: \.self) { equipmentName in
                                        if let actions = groupedActionsByEquipment[equipmentName], !actions.isEmpty {
                                            VStack(alignment: .leading, spacing: 12) {
                                                // 器材分类标题
                                                HStack {
                                                    Text(equipmentName)
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundColor(theme.onBackground)
                                                    
                                                    Spacer()
                                                    
                                                    Text("\(actions.count)个动作")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(theme.secondary)
                                                }
                                                .padding(.horizontal, 16)
                                                
                                                // 该器材下的动作网格
                                                LazyVGrid(columns: [
                                                    GridItem(.flexible()),
                                                    GridItem(.flexible())
                                                ], spacing: 16) {
                                                    ForEach(actions) { action in
                                                        SelectableActionCard(
                                                            action: action,
                                                            isSelected: selectedActions.contains(action.id),
                                                            allowMultipleSelection: allowMultipleSelection,
                                                            isDisabled: existingActionIds.contains(action.id),
                                                            onToggle: {
                                                                // 如果动作已存在于计划中，不允许选择
                                                                if existingActionIds.contains(action.id) {
                                                                    return
                                                                }
                                                                
                                                                if allowMultipleSelection {
                                                                    // 多选模式
                                                                    if selectedActions.contains(action.id) {
                                                                        selectedActions.remove(action.id)
                                                                    } else {
                                                                        selectedActions.insert(action.id)
                                                                    }
                                                                } else {
                                                                    // 单选模式 - 直接选择并关闭
                                                                    let actionInfo = ActionInfo(id: action.id, name: action.name, imageUrl: action.gifUrl ?? "")
                                                                    onActionSelected?(actionInfo)
                                                                    dismiss()
                                                                }
                                                            }
                                                        )
                                                    }
                                                }
                                                .padding(.horizontal, 16)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical)
                            }
                        }
                        .frame(width: mainGeometry.size.width * 0.75)
                        .clipped()
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("选择训练动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(theme.secondary)
                }
                
                // 只在多选模式下显示确定按钮
                if allowMultipleSelection {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("确定(\(selectedActions.count))") {
                            // 获取选中的动作并通过回调传递
                            let selectedActionsList = filteredActions.filter { selectedActions.contains($0.id) }
                            onActionsSelected?(selectedActionsList)
                            dismiss()
                        }
                        .foregroundColor(selectedActions.isEmpty ? theme.secondary : theme.primary)
                        .disabled(selectedActions.isEmpty)
                    }
                }
            })
        }
        .onAppear {
            Task {
                viewModel.loadInitialData()
                
                // 使用静态变量保持状态
                selectedTargetMuscleId = Self.globalSelectedTargetMuscleId
                
                // 只在全局首次初始化时设置默认胸肌过滤
                if !Self.globalHasInitialized {
                    await viewModel.loadActionsByTargetMuscle(targetMuscleId: Self.globalSelectedTargetMuscleId)
                    Self.globalHasInitialized = true
                    print("🔄 PlanActionSelectView: 默认选中胸肌，已加载 \(viewModel.actions.count) 个动作")
                } else {
                    // 如果不是首次初始化，根据当前选择的肌肉群加载动作
                    if selectedTargetMuscleId == 0 {
                        await viewModel.loadActions()
                    } else {
                        await viewModel.loadActionsByTargetMuscle(targetMuscleId: selectedTargetMuscleId)
                    }
                }
            }
        }
    }
    
    // 设备过滤视图
    private var equipmentFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                // "全部"选项
                Button(action: { selectedEquipmentId = 0 }) {
                    Text("全部")
                        .font(.system(size: 14))
                        .foregroundColor(selectedEquipmentId == 0 ? theme.background : theme.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedEquipmentId == 0 ?
                                theme.primary :
                                theme.surface
                        )
                        .cornerRadius(12)
                }
                
                // 动态设备选项
                ForEach(viewModel.equipments) { equipment in
                    Button(action: { selectedEquipmentId = equipment.id }) {
                        Text(equipment.display_name)
                            .font(.system(size: 14))
                            .foregroundColor(selectedEquipmentId == equipment.id ? theme.background : theme.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedEquipmentId == equipment.id ?
                                    theme.primary :
                                    theme.surface
                            )
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .frame(height: 50)
        .background(theme.background)
    }
    
    // 过滤后的动作列表
    private var filteredActions: [Action] {
        viewModel.actions.filter { action in
            let matchesTargetMuscle = selectedTargetMuscleId == 0 || action.target_muscle_ids.contains(selectedTargetMuscleId)
            let matchesEquipment = selectedEquipmentId == 0 || (action.equipment_id ?? 0) == selectedEquipmentId
            let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
            return matchesTargetMuscle && matchesEquipment && matchesSearch
        }
    }
    
    // 按器械分组的动作
    private var groupedActionsByEquipment: [String: [Action]] {
        let actions = filteredActions
        var grouped: [String: [Action]] = [:]
        
        for action in actions {
            // 获取器材名称
            let equipmentName: String
            if let equipmentId = action.equipment_id {
                equipmentName = viewModel.equipments.first { $0.id == equipmentId }?.display_name ?? "未知器材"
            } else {
                equipmentName = "无器材"
            }
            
            // 将动作添加到对应器材分组
            if grouped[equipmentName] == nil {
                grouped[equipmentName] = []
            }
            grouped[equipmentName]?.append(action)
        }
        
        return grouped
    }
}

// 可选择的动作卡片
struct SelectableActionCard: View {
    @Environment(\.theme) private var theme: AppTheme
    let action: Action
    let isSelected: Bool
    let allowMultipleSelection: Bool
    let isDisabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 动作图片
            Group {
                if let uiImage = loadLocalActionImage(fileName: action.localImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(theme.secondary.opacity(0.3))
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(theme.secondary)
                        )
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 动作信息
            VStack(alignment: .leading, spacing: 4) {
                Text(action.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isDisabled ? theme.secondary : theme.onBackground)
                
                // 如果动作已存在，显示提示文字
                if isDisabled {
                    Text("已添加")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(isDisabled ? theme.secondary.opacity(0.1) : theme.background)
        .cornerRadius(12)
        .shadow(color: theme.onBackground.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDisabled ? theme.secondary.opacity(0.3) : 
                    (isSelected ? theme.primary : Color.clear), 
                    lineWidth: 2
                )
        )
        .opacity(isDisabled ? 0.6 : 1.0)
        .onTapGesture {
            if !isDisabled {
                onToggle()
            }
        }
    }
}

/// 从本地bundle加载动作图片
private func loadLocalActionImage(fileName: String) -> UIImage? {
    // 清理路径，移除 .gif 扩展名
    let cleanPath = fileName.replacingOccurrences(of: ".gif", with: "")
    
    // 首先尝试直接使用完整路径加载
    if let url = Bundle.main.url(forResource: cleanPath, withExtension: "gif"),
       let data = try? Data(contentsOf: url),
       let image = UIImage(data: data) {
        return image
    }
    
    // 备用方案：提取文件名并从所有可能的目录加载
    let fileName = URL(string: cleanPath)?.lastPathComponent ?? cleanPath
    
    // 所有可能的目标肌肉目录
    let muscleDirectories = [
        "abs", "pectorals", "biceps", "triceps", "delts", "lats", "upper back",
        "quads", "hamstrings", "glutes", "calves", "forearms", "traps",
        "cardiovascular system", "spine", "adductors", "abductors",
        "serratus anterior", "levator scapulae"
    ]
    
    // 尝试从各个肌肉目录加载
    for muscleDir in muscleDirectories {
        let path = "Images/\(muscleDir)/\(fileName)"
        if let url = Bundle.main.url(forResource: path, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
    }
    
    // 最后尝试旧的路径格式（兼容性）
    let legacyPaths = [
        "Media/Actions/\(fileName)",
        "Images/\(fileName)",
        fileName
    ]
    
    for path in legacyPaths {
        if let url = Bundle.main.url(forResource: path, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
    }
    
    return nil
}

#Preview {
    PlanActionSelectView { action in
        print("选择了动作: \(action.name)")
    }
}