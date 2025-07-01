import SwiftUI

struct ActionListView: View {
    // MARK: - 状态属性
    @State private var selectedBodyPartId: Int = 1
    @State private var searchText = ""
    @State private var selectedEquipmentId: Int = 0 // 0表示"全部"
    @State private var selectedTargetMuscleId: Int = 1
    @StateObject private var viewModel = ActionListViewModel()
    
    // MARK: - 设备过滤视图
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
    
    // MARK: - 视图主体
    var body: some View {
        NavigationView {
            GeometryReader { mainGeometry in
                VStack(spacing: 0) {
                    // Logo区域
                    HStack {
                        Image("StronixLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 35)
                        Spacer()
                        Text("STRONIX")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
                    
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
                        .frame(maxWidth: .infinity)
                    
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
                            } else if let error = viewModel.error {
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.orange)
                                    
                                    Text("加载失败")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text(error.localizedDescription)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("重试") {
                                        Task {
                                            await viewModel.loadActionsByTargetMuscle(targetMuscleId: selectedTargetMuscleId)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else if filteredActions.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    
                                    Text("暂无动作")
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text("请尝试切换其他肌肉群或调整筛选条件")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(filteredActions) { action in
                                        ActionCard(action: action)
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
            .ignoresSafeArea(.keyboard)
            .onAppear {
                Task {
                    viewModel.loadInitialData()
                    // 同步选中的目标肌肉ID
                    if let firstMuscle = viewModel.targetMuscles.first {
                        selectedTargetMuscleId = firstMuscle.id
                        // 加载选中目标肌肉的动作
                        await viewModel.loadActionsByTargetMuscle(targetMuscleId: firstMuscle.id)
                    }
                }
            }
            .onChange(of: viewModel.targetMuscles) { oldValue, newValue in
                // 当目标肌肉数据加载完成时，同步选中状态并加载对应动作
                if !newValue.isEmpty {
                    let targetId = newValue.first?.id ?? 1
                    selectedTargetMuscleId = targetId
                    Task {
                        await viewModel.loadActionsByTargetMuscle(targetMuscleId: targetId)
                    }
                }
            }
        }
    }
    
    // MARK: - 过滤后的动作列表
    private var filteredActions: [Action] {
        let filtered = viewModel.actions.filter { action in
            let matchesEquipment = selectedEquipmentId == 0 || (action.equipment_id ?? 0) == selectedEquipmentId
            let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
            return matchesEquipment && matchesSearch
        }
        
        print("🔍 filteredActions - 原始动作数量: \(viewModel.actions.count)")
        print("🔍 filteredActions - selectedEquipmentId: \(selectedEquipmentId)")
        print("🔍 filteredActions - searchText: '\(searchText)'")
        print("🔍 filteredActions - 过滤后动作数量: \(filtered.count)")
        
        if viewModel.actions.count > 0 && filtered.count != viewModel.actions.count {
            print("🔍 filteredActions - 动作筛选详情:")
            for action in viewModel.actions {
                let matchesEquipment = selectedEquipmentId == 0 || (action.equipment_id ?? 0) == selectedEquipmentId
                let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
                print("  - \(action.name): equipment_id=\(action.equipment_id ?? -1), matchesEquipment=\(matchesEquipment), matchesSearch=\(matchesSearch)")
            }
        }
        
        return filtered
    }
}

// MARK: - 动作卡片视图
struct ActionCard: View {
    let action: Action
    
    var body: some View {
        NavigationLink(destination: ActionDetailView(action: action)) {
            VStack(alignment: .leading, spacing: 8) {
                // 动作图片 - 使用本地图片资源
                AsyncImageView(imageName: action.localImageName)
                
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览
#Preview {
    ActionListView()
}

// MARK: - 异步图片加载视图（与ActionDetailView的GIFView完全一致）
struct AsyncImageView: View {
    let imageName: String
    
    var body: some View {
        // 使用与ActionDetailView中GIFView完全相同的代码
        AsyncImage(url: Bundle.main.url(forResource: imageName, withExtension: "gif")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Image(systemName: "photo")
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
} 
