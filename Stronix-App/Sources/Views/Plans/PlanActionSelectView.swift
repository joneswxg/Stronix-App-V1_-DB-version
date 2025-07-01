import SwiftUI

struct PlanActionSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActionListViewModel()
    @State private var selectedActions: Set<Int> = []
    @State private var selectedTargetMuscleId: Int = 0
    @State private var selectedEquipmentId: Int = 0
    @State private var searchText = ""
    
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
                            .foregroundColor(.gray)
                        TextField("搜索训练动作", text: $searchText)
                    }
                    .padding()
                    .background(Color(white: 0.97))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 训练设备过滤栏
                    equipmentFilterView
                        .background(Color.white)
                        .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
                    
                    // 主要内容区域
                    HStack(spacing: 0) {
                        // 左侧导航栏
                        VStack {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.targetMuscles) { muscle in
                                        Button(action: { 
                                            selectedTargetMuscleId = muscle.id
                                            Task {
                                                await viewModel.loadActionsByTargetMuscle(targetMuscleId: muscle.id)
                                            }
                                        }) {
                                            Text(muscle.display_name)
                                                .font(.system(size: 13))
                                                .foregroundColor(selectedTargetMuscleId == muscle.id ? .white : .black)
                                                .fontWeight(selectedTargetMuscleId == muscle.id ? .medium : .regular)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 10)
                                                .background(
                                                    selectedTargetMuscleId == muscle.id ?
                                                        Color.blue :
                                                        Color.clear
                                                )
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                            }
                            .frame(width: mainGeometry.size.width * 0.25)
                            .background(Color(white: 0.97))
                        }
                        .frame(maxHeight: .infinity)
                        
                        // 右侧动作列表
                        ScrollView(.vertical, showsIndicators: false) {
                            if viewModel.isLoading {
                                ProgressView("加载中...")
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(filteredActions) { action in
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
                                .padding()
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
                        .disabled(selectedActions.isEmpty)
                    }
                }
            })
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
                // 初始化完成后，自动选中第一个目标肌群并加载对应的动作
                if !viewModel.targetMuscles.isEmpty {
                    let firstMuscleId = viewModel.targetMuscles[0].id
                    selectedTargetMuscleId = firstMuscleId
                    print("🔄 PlanActionSelectView: 自动选中第一个目标肌群 ID=\(firstMuscleId), 名称=\(viewModel.targetMuscles[0].display_name)")
                    await viewModel.loadActionsByTargetMuscle(targetMuscleId: firstMuscleId)
                    print("🔄 PlanActionSelectView: 已加载 \(viewModel.actions.count) 个动作")
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
                        .foregroundColor(selectedEquipmentId == 0 ? .white : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedEquipmentId == 0 ?
                                Color.blue :
                                Color.gray.opacity(0.1)
                        )
                        .cornerRadius(12)
                }
                
                // 动态设备选项
                ForEach(viewModel.equipments) { equipment in
                    Button(action: { selectedEquipmentId = equipment.id }) {
                        Text(equipment.display_name)
                            .font(.system(size: 14))
                            .foregroundColor(selectedEquipmentId == equipment.id ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedEquipmentId == equipment.id ?
                                    Color.blue :
                                    Color.gray.opacity(0.1)
                            )
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .frame(height: 50)
        .background(Color.white)
    }
    
    // 过滤后的动作列表
    private var filteredActions: [Action] {
        viewModel.actions.filter { action in
            let matchesEquipment = selectedEquipmentId == 0 || (action.equipment_id ?? 0) == selectedEquipmentId
            let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
            return matchesEquipment && matchesSearch
        }
    }
}

// 可选择的动作卡片
struct SelectableActionCard: View {
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
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(.gray)
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
                    .foregroundColor(isDisabled ? .gray : .black)
                
                // 如果动作已存在，显示提示文字
                if isDisabled {
                    Text("已添加")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(isDisabled ? Color.gray.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDisabled ? Color.gray.opacity(0.3) : 
                    (isSelected ? Color.blue : Color.clear), 
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
    // 尝试从不同的bundle路径加载图片
    let possiblePaths = [
        "Images/\(fileName)",
        "Media/Actions/\(fileName)",
        fileName
    ]
    
    for path in possiblePaths {
        if let url = Bundle.main.url(forResource: path.replacingOccurrences(of: ".gif", with: ""), withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        
        // 也尝试不去除扩展名的方式
        if let url = Bundle.main.url(forResource: path, withExtension: nil),
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