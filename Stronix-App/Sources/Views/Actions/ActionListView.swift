import SwiftUI

struct ActionListView: View {
    // MARK: - 数据模型
    struct BodyPart: Identifiable {
        let id: Int
        let name: String
        let nameEn: String
    }
    
    struct Action: Identifiable, Codable {
        let id: Int
        let name: String
        let name_en: String?
        let image_url: String
        let body_part_id: Int
        let equipment_id: Int
        let target_muscle_ids: [Int]
    }
    
    struct TargetMuscle: Identifiable, Codable, Equatable {
        let id: Int
        let name: String
        let display_name: String
        
        // 实现Equatable协议
        static func == (lhs: TargetMuscle, rhs: TargetMuscle) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct Equipment: Identifiable, Codable, Equatable {
        let id: Int
        let name: String
        let display_name: String
        
        // 实现Equatable协议
        static func == (lhs: Equipment, rhs: Equipment) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
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
                    await viewModel.loadInitialData()
                    // 同步选中的目标肌肉ID
                    if let firstMuscle = viewModel.targetMuscles.first {
                        selectedTargetMuscleId = firstMuscle.id
                    }
                }
            }
            .onChange(of: viewModel.targetMuscles) { oldValue, newValue in
                // 当目标肌肉数据加载完成时，同步选中状态
                if selectedTargetMuscleId == 1 && !newValue.isEmpty {
                    selectedTargetMuscleId = newValue.first?.id ?? 1
                }
            }
        }
    }
    
    // MARK: - 过滤后的动作列表
    private var filteredActions: [Action] {
        viewModel.actions.filter { action in
            let matchesEquipment = selectedEquipmentId == 0 || action.equipment_id == selectedEquipmentId
            let matchesSearch = searchText.isEmpty || action.name.localizedCaseInsensitiveContains(searchText)
            return matchesEquipment && matchesSearch
        }
    }
}

// MARK: - 动作卡片视图
struct ActionCard: View {
    let action: ActionListView.Action
    
    var body: some View {
        NavigationLink(destination: ActionDetailView(action: action)) {
            VStack(alignment: .leading, spacing: 8) {
                // 动作图片 - 使用静态图片显示以提高性能
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

class ActionListViewModel: ObservableObject {
    @Published var actions: [ActionListView.Action] = []
    @Published var targetMuscles: [ActionListView.TargetMuscle] = []
    @Published var equipments: [ActionListView.Equipment] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadInitialData() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            // 并行加载目标肌肉和设备数据
            async let targetMusclesTask: Void = loadTargetMusclesFromAPI()
            async let equipmentsTask: Void = loadEquipmentsFromAPI()
            
            let (_, _) = try await (targetMusclesTask, equipmentsTask)
            
            // 等待目标肌肉数据加载完成后，加载第一个目标肌肉的动作
            await MainActor.run {
                if let firstMuscle = self.targetMuscles.first {
                    Task {
                        await self.loadActionsByTargetMuscle(targetMuscleId: firstMuscle.id)
                    }
                } else {
                    self.isLoading = false
                }
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func loadTargetMusclesFromAPI() async throws {
        guard let url = URL(string: "http://127.0.0.1:6000/api/action/target_muscle") else { return }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TargetMuscleResponse.self, from: data)
        await MainActor.run {
            self.targetMuscles = response.result
        }
    }
    
    func loadEquipmentsFromAPI() async throws {
        guard let url = URL(string: "http://127.0.0.1:6000/api/action/equipment") else { return }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(EquipmentResponse.self, from: data)
        await MainActor.run {
            self.equipments = response.result
        }
    }
    
    func loadActionsByTargetMuscle(targetMuscleId: Int) async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil // 清除之前的错误状态
        }
        
        do {
            guard let url = URL(string: "http://127.0.0.1:6000/api/action/actions?target_muscle_id=\(targetMuscleId)") else { 
                await MainActor.run {
                    self.isLoading = false
                }
                return 
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ActionResponse.self, from: data)
            await MainActor.run {
                self.actions = response.result
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
}

// MARK: - 响应结构体
struct TargetMuscleResponse: Codable {
    let result: [ActionListView.TargetMuscle]
}

struct EquipmentResponse: Codable {
    let result: [ActionListView.Equipment]
}

struct ActionResponse: Codable {
    let result: [ActionListView.Action]
} 
