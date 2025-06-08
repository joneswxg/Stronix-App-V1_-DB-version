import SwiftUI

struct PlanActionSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActionListViewModel()
    @State private var selectedActions: Set<Int> = []
    @State private var selectedTargetMuscleId: Int = 1
    @State private var selectedEquipmentId: Int = 0
    @State private var searchText = ""
    
    // 添加回调闭包 - 支持单个动作选择
    let onActionSelected: ((ActionInfo) -> Void)?
    let onActionsSelected: (([ActionListView.Action]) -> Void)?
    let allowMultipleSelection: Bool
    
    // 修改初始化方法
    init(onActionSelected: ((ActionInfo) -> Void)? = nil, onActionsSelected: (([ActionListView.Action]) -> Void)? = nil) {
        self.onActionSelected = onActionSelected
        self.onActionsSelected = onActionsSelected
        self.allowMultipleSelection = onActionsSelected != nil
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
                                            onToggle: {
                                                if allowMultipleSelection {
                                                    // 多选模式
                                                    if selectedActions.contains(action.id) {
                                                        selectedActions.remove(action.id)
                                                    } else {
                                                        selectedActions.insert(action.id)
                                                    }
                                                } else {
                                                    // 单选模式 - 直接选择并关闭
                                                    let actionInfo = ActionInfo(id: action.id, name: action.name, imageUrl: action.image_url)
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
    private var filteredActions: [ActionListView.Action] {
        viewModel.actions.filter { action in
            let matchesEquipment = selectedEquipmentId == 0 || action.equipment_id == selectedEquipmentId
            let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
            return matchesEquipment && matchesSearch
        }
    }
}

// 可选择的动作卡片
struct SelectableActionCard: View {
    let action: ActionListView.Action
    let isSelected: Bool
    let allowMultipleSelection: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 动作图片
            ZStack {
                AsyncImage(url: URL(string: "http://127.0.0.1:6000/api/action/images/\(action.image_url)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // 动作信息
            VStack(alignment: .leading, spacing: 4) {
                Text(action.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onToggle()
        }
    }
}

#Preview {
    PlanActionSelectView { action in
        print("选择了动作: \(action.name)")
    }
} 