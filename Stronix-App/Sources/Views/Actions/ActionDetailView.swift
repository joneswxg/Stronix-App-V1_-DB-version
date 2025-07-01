import SwiftUI
import UIKit

// 简化的图片显示组件 - 使用SwiftUI原生方式
struct ActionImageView: View {
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
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.gray)
                            .font(.system(size: 40))
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = Bundle.main.url(forResource: imageName, withExtension: "gif") else {
            print("❌ 找不到GIF文件: \(imageName).gif")
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                print("❌ 图片加载失败: \(imageName)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.uiImage = image
                self.isLoading = false
                print("✅ 图片加载成功: \(imageName)")
            }
        }
    }
}

struct ActionDetailView: View {
    let action: Action
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActionDetailViewModel()

    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 动作GIF区域
                VStack {
                    ActionImageView(imageName: action.localImageName)
                        .frame(height: 300)
                    
                    // 调试信息
                    VStack(spacing: 8) {
                        Text("图片资源: \(action.localImageName)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // 动作名称和详细信息
                VStack(alignment: .leading, spacing: 16) {
                    Text(action.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 动作基本信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("动作信息")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        if let actionDetail = viewModel.actionDetail {
                            VStack(alignment: .leading, spacing: 8) {
                                // 英文名称
                                if let nameEn = actionDetail.name_en, !nameEn.isEmpty {
                                    InfoRow(title: "英文名称", value: nameEn)
                                }
                                
                                // 难度等级
                                if let difficulty = actionDetail.difficulty, !difficulty.isEmpty {
                                    InfoRow(title: "难度等级", value: difficulty)
                                }
                                
                                // 目标肌肉群
                                if !actionDetail.target_muscles.isEmpty {
                                    InfoRow(title: "目标肌肉", value: actionDetail.target_muscles.map { $0.display_name }.joined(separator: ", "))
                                }
                                
                                // 使用设备
                                if let equipment = actionDetail.equipment {
                                    InfoRow(title: "使用设备", value: equipment.display_name)
                                }
                                
                                // 身体部位
                                if let bodypart = actionDetail.bodypart {
                                    InfoRow(title: "身体部位", value: bodypart.display_name)
                                }
                                
                                // 双侧训练
                                InfoRow(title: "双侧训练", value: actionDetail.is_bilateral ? "是" : "否")
                            }
                        }
                    }
                    
                    // 动作描述
                    if let description = viewModel.actionDetail?.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("动作描述")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Text(description)
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 8)
                    } else {
                        // 默认指导内容
                        VStack(alignment: .leading, spacing: 12) {
                            Text("训练指导")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.black)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                InstructionStep(
                                    number: 1,
                                    text: "准备动作：调整好设备和姿势，确保安全。"
                                )
                                
                                InstructionStep(
                                    number: 2,
                                    text: "执行动作：按照标准动作要求，控制好节奏。"
                                )
                                
                                InstructionStep(
                                    number: 3,
                                    text: "注意呼吸：动作过程中保持正常呼吸。"
                                )
                                
                                InstructionStep(
                                    number: 4,
                                    text: "完成训练：按照计划完成所有组数和次数。"
                                )
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // 默认训练参数
                    VStack(alignment: .leading, spacing: 12) {
                        Text("建议训练参数")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("建议组数")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("\(action.default_sets)组")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("建议次数")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("\(action.default_reps)次")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(action.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
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
        }
        .onAppear {
            Task {
                await viewModel.loadActionDetail(actionId: action.id)
            }
        }
    }
}

// 信息行组件
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// 指导步骤组件
struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .leading)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// ViewModel
class ActionDetailViewModel: ObservableObject {
    @Published var actionDetail: ActionDetail?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let localActionService = LocalActionService.shared
    
    func loadActionDetail(actionId: Int) async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let detail = try await localActionService.fetchActionDetail(actionId: actionId)
            await MainActor.run {
                self.actionDetail = detail
                self.isLoading = false
            }
            print("✅ ActionDetailViewModel: 成功加载动作详情 \(actionId)")
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            print("❌ ActionDetailViewModel: 加载动作详情失败: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        ActionDetailView(action: Action(
            id: 1,
            external_id: "1",
            name: "腹轮滚动",
            name_en: "Ab Wheel Rollout",
            gifUrl: "exercise_1.gif",
            description: "腹轮滚动是一个很好的核心训练动作",
            description_en: "Ab wheel rollout is a great core exercise",
            difficulty: "中等",
            bodypart_id: 1,
            equipment_id: 2,
            is_bilateral: false,
            target_muscle_ids: [1, 2, 3]
        ))
    }
} 
