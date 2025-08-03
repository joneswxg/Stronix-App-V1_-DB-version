import SwiftUI

struct ActionListView: View {
    // MARK: - 状态属性
    @State private var selectedBodyPartId: Int = 0 // 0表示"全部"
    @State private var searchText = ""
    @State private var selectedEquipmentId: Int = 0 // 0表示"全部"
    @State private var selectedTargetMuscleId: Int = 0 // 修改：0表示"所有动作"
    @StateObject private var viewModel = ActionListViewModel()
    
    // MARK: - 设备过滤视图
    private var equipmentFilterView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 左侧空白区域，对应左侧导航栏的宽度（25%）
                Spacer()
                    .frame(width: geometry.size.width * 0.25)
                
                // 下拉框容器，对应右侧动作列表区域（75%）
                HStack(spacing: 16) {
                    // 器材类型下拉框
                    Menu {
                        // "全部器材"选项
                        Button(action: { 
                            selectedEquipmentId = 0
                            Task {
                                await viewModel.loadActionsByFilters(
                                    targetMuscleId: selectedTargetMuscleId == 0 ? nil : selectedTargetMuscleId,
                                    equipmentId: 0,
                                    bodyPartId: selectedBodyPartId,
                                    searchText: searchText
                                )
                            }
                        }) {
                            HStack {
                                Text("全部器材")
                                if selectedEquipmentId == 0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // 动态设备选项
                        ForEach(viewModel.equipments) { equipment in
                            Button(action: { 
                                selectedEquipmentId = equipment.id
                                Task {
                                    await viewModel.loadActionsByFilters(
                                        targetMuscleId: selectedTargetMuscleId == 0 ? nil : selectedTargetMuscleId,
                                        equipmentId: equipment.id,
                                        bodyPartId: selectedBodyPartId,
                                        searchText: searchText
                                    )
                                }
                            }) {
                                HStack {
                                    Text(equipment.display_name)
                                    if selectedEquipmentId == equipment.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedEquipmentName)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .frame(width: 120) // 与动作图片宽度对齐
                    
                    // 身体部位下拉框
                    Menu {
                        // "全部部位"选项
                        Button(action: { 
                            selectedBodyPartId = 0
                            Task {
                                await viewModel.loadActionsByFilters(
                                    targetMuscleId: selectedTargetMuscleId == 0 ? nil : selectedTargetMuscleId,
                                    equipmentId: selectedEquipmentId,
                                    bodyPartId: 0,
                                    searchText: searchText
                                )
                            }
                        }) {
                            HStack {
                                Text("全部部位")
                                if selectedBodyPartId == 0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // 动态身体部位选项
                        ForEach(viewModel.bodyParts) { bodyPart in
                            Button(action: { 
                                selectedBodyPartId = bodyPart.id
                                Task {
                                    await viewModel.loadActionsByFilters(
                                        targetMuscleId: selectedTargetMuscleId == 0 ? nil : selectedTargetMuscleId,
                                        equipmentId: selectedEquipmentId,
                                        bodyPartId: bodyPart.id,
                                        searchText: searchText
                                    )
                                }
                            }) {
                                HStack {
                                    Text(bodyPart.display_name)
                                    if selectedBodyPartId == bodyPart.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedBodyPartName)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .frame(width: 120) // 身体部位下拉框宽度
                    
                    Spacer() // 填充剩余空间
                }
                .padding(.horizontal, 16) // 与右侧动作列表的padding保持一致
                .frame(width: geometry.size.width * 0.75, alignment: .leading)
            }
        }
        .frame(height: 50) // 固定高度
        .background(Color.white)
        .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
    }
    
    // MARK: - 计算属性：当前选中的设备名称
    private var selectedEquipmentName: String {
        if selectedEquipmentId == 0 {
            return "全部器材"
        }
        return viewModel.equipments.first { $0.id == selectedEquipmentId }?.display_name ?? "全部器材"
    }
    
    // MARK: - 计算属性：当前选中的身体部位名称
    private var selectedBodyPartName: String {
        if selectedBodyPartId == 0 {
            return "全部部位"
        }
        return viewModel.bodyParts.first { $0.id == selectedBodyPartId }?.display_name ?? "全部部位"
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
                    
                    // 添加搜索框和下拉框之间的间距
                    Spacer()
                        .frame(height: 16)
                    
                    // 训练设备过滤栏
                    equipmentFilterView
                        .frame(maxWidth: .infinity)
                    
                    // 主要内容区域
                    HStack(spacing: 0) {
                        // 左侧导航栏
                        VStack {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    // 添加"所有动作"按钮
                                    Button(action: { 
                                        selectedTargetMuscleId = 0
                                        Task {
                                            await viewModel.loadActionsByFilters(
                                                targetMuscleId: nil,
                                                equipmentId: selectedEquipmentId,
                                                bodyPartId: selectedBodyPartId,
                                                searchText: searchText
                                            )
                                        }
                                    }) {
                                        Text("所有动作")
                                            .font(.system(size: 13))
                                            .foregroundColor(selectedTargetMuscleId == 0 ? .white : .black)
                                            .fontWeight(selectedTargetMuscleId == 0 ? .medium : .regular)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 10)
                                            .background(
                                                selectedTargetMuscleId == 0 ?
                                                    Color.blue :
                                                    Color.clear
                                            )
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    ForEach(viewModel.targetMuscles) { muscle in
                                        Button(action: { 
                                            selectedTargetMuscleId = muscle.id
                                            Task {
                                                await viewModel.loadActionsByFilters(
                                                    targetMuscleId: muscle.id,
                                                    equipmentId: selectedEquipmentId,
                                                    bodyPartId: selectedBodyPartId,
                                                    searchText: searchText
                                                )
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
                                            await viewModel.loadActionsByFilters(
                                                targetMuscleId: selectedTargetMuscleId,
                                                equipmentId: selectedEquipmentId,
                                                bodyPartId: selectedBodyPartId,
                                                searchText: searchText
                                            )
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
                    await viewModel.loadFilters()
                    // 默认选中"所有动作"并加载所有动作
                    selectedTargetMuscleId = 0
                    await viewModel.loadActionsByFilters(
                        targetMuscleId: nil,
                        equipmentId: selectedEquipmentId,
                        bodyPartId: selectedBodyPartId,
                        searchText: searchText
                    )
                }
            }
            .onChange(of: viewModel.targetMuscles) { oldValue, newValue in
                // 当目标肌肉数据加载完成时，如果当前没有选中任何肌肉，保持"所有动作"状态
                if !newValue.isEmpty && selectedTargetMuscleId == 0 {
                    Task {
                        await viewModel.loadActionsByFilters(
                            targetMuscleId: nil,
                            equipmentId: selectedEquipmentId,
                            bodyPartId: selectedBodyPartId,
                            searchText: searchText
                        )
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                // 搜索文本变化时实时过滤
                Task {
                    await viewModel.loadActionsByFilters(
                        targetMuscleId: selectedTargetMuscleId == 0 ? nil : selectedTargetMuscleId,
                        equipmentId: selectedEquipmentId,
                        bodyPartId: selectedBodyPartId,
                        searchText: newValue
                    )
                }
            }
        }
    }
    
    // MARK: - 过滤后的动作列表
    private var filteredActions: [Action] {
        let filtered = viewModel.actions.filter { action in
            let matchesEquipment = selectedEquipmentId == 0 || (action.equipment_id ?? 0) == selectedEquipmentId
            let matchesBodyPart = selectedBodyPartId == 0 || action.bodypart_id == selectedBodyPartId
            let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
            return matchesEquipment && matchesBodyPart && matchesSearch
        }
        
        print("🔍 filteredActions - 原始动作数量: \(viewModel.actions.count)")
        print("🔍 filteredActions - selectedEquipmentId: \(selectedEquipmentId)")
        print("🔍 filteredActions - selectedBodyPartId: \(selectedBodyPartId)")
        print("🔍 filteredActions - searchText: '\(searchText)'")
        print("🔍 filteredActions - 过滤后动作数量: \(filtered.count)")
        
        if viewModel.actions.count > 0 && filtered.count != viewModel.actions.count {
            print("🔍 filteredActions - 动作筛选详情:")
            for action in viewModel.actions {
                let matchesEquipment = selectedEquipmentId == 0 || (action.equipment_id ?? 0) == selectedEquipmentId
                let matchesBodyPart = selectedBodyPartId == 0 || action.bodypart_id == selectedBodyPartId
                let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
                print("  - \(action.name): equipment_id=\(action.equipment_id ?? -1), bodypart_id=\(action.bodypart_id), matchesEquipment=\(matchesEquipment), matchesBodyPart=\(matchesBodyPart), matchesSearch=\(matchesSearch)")
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

// MARK: - 异步图片加载视图（支持新的目录结构）
struct AsyncImageView: View {
    let imageName: String
    @State private var uiImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 加载失败时显示占位图
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // 尝试加载图片，支持新的目录结构
        guard let url = Bundle.main.url(forResource: imageName, withExtension: "gif") else {
            print("❌ ActionListView: 找不到GIF文件: \(imageName).gif")
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                print("❌ ActionListView: 图片加载失败: \(imageName)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.uiImage = image
                self.isLoading = false
                print("✅ ActionListView: 图片加载成功: \(imageName)")
            }
        }
    }
} 
