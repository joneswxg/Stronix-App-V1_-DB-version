import SwiftUI
import UIKit
import ImageIO

// MARK: - GIF播放器组件
struct GIFImageView: UIViewRepresentable {
    let imageName: String
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        loadGIFAnimation(into: uiView)
    }
    
    private func loadGIFAnimation(into imageView: UIImageView) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let gifURL = findGIFFile(named: imageName),
                  let gifData = try? Data(contentsOf: gifURL),
                  let animatedImage = createAnimatedImage(from: gifData) else {
                print("❌ 无法加载GIF动画: \(imageName)")
                DispatchQueue.main.async {
                    // 设置占位图
                    imageView.image = UIImage(systemName: "figure.strengthtraining.traditional")
                    imageView.tintColor = UIColor(.gray)
                }
                return
            }
            
            DispatchQueue.main.async {
                imageView.image = animatedImage
                print("✅ GIF动画加载成功: \(imageName)")
            }
        }
    }
    
    private func findGIFFile(named imageName: String) -> URL? {
        // 清理路径，移除可能的 .gif 扩展名
        let cleanPath = imageName.replacingOccurrences(of: ".gif", with: "")
        
        // 首先尝试直接使用完整路径加载
        if let url = Bundle.main.url(forResource: cleanPath, withExtension: "gif") {
            return url
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
            if let url = Bundle.main.url(forResource: path, withExtension: "gif") {
                return url
            }
        }
        
        // 最后尝试旧的路径格式（兼容性）
        let legacyPaths = [
            "Media/Actions/\(fileName)",
            "Images/\(fileName)",
            fileName
        ]
        
        for path in legacyPaths {
            if let url = Bundle.main.url(forResource: path, withExtension: "gif") {
                return url
            }
        }
        
        return nil
    }
    
    private func createAnimatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let frameCount = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }
            
            let image = UIImage(cgImage: cgImage)
            images.append(image)
            
            // 获取每帧的持续时间
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifDict = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let frameDuration = gifDict[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1
                totalDuration += frameDuration
            } else {
                totalDuration += 0.1 // 默认持续时间
            }
        }
        
        guard !images.isEmpty else { return nil }
        
        // 如果只有一帧，返回静态图片
        if images.count == 1 {
            return images.first
        }
        
        // 创建动画图片
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}

// MARK: - 兼容旧代码的AnimatedImageView（现在使用真正的GIF播放）
struct AnimatedImageView: View {
    let imageName: String
    
    var body: some View {
        GIFImageView(imageName: imageName)
    }
}

struct ActionDetailView: View {
    let action: Action
    @Binding var selectedTargetMuscleId: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ActionDetailViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 动作GIF区域
                VStack {
                    AnimatedImageView(imageName: action.localImageName)
                        .frame(height: 300)
                        .clipped()
                }
                .background(themeManager.currentTheme.background)
                .cornerRadius(16)
                .shadow(color: themeManager.currentTheme.onBackground.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // 动作名称和详细信息
                VStack(alignment: .leading, spacing: 16) {
                    Text(action.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.onBackground)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 动作基本信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("动作信息")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.onBackground)
                        
                        if let actionDetail = viewModel.actionDetail {
                            VStack(alignment: .leading, spacing: 8) {
                                // 目标肌肉群
                                if !actionDetail.target_muscles.isEmpty {
                                    InfoRow(title: "目标肌肉", value: actionDetail.target_muscles.map { $0.display_name }.joined(separator: ", "))
                                } else {
                                    InfoRow(title: "目标肌肉", value: "暂无数据")
                                }
                                
                                // 使用设备
                                if let equipment = actionDetail.equipment {
                                    InfoRow(title: "使用设备", value: equipment.display_name)
                                } else {
                                    InfoRow(title: "使用设备", value: "暂无数据")
                                }
                                
                                // 身体部位
                                if let bodypart = actionDetail.bodypart {
                                    InfoRow(title: "身体部位", value: bodypart.display_name)
                                } else {
                                    InfoRow(title: "身体部位", value: "暂无数据")
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(title: "目标肌肉", value: "加载中...")
                                InfoRow(title: "使用设备", value: "加载中...")
                                InfoRow(title: "身体部位", value: "加载中...")
                            }
                        }
                    }
                    
                    // 动作描述
                    VStack(alignment: .leading, spacing: 12) {
                        Text("动作描述")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.onBackground)
                        
                        if let description = action.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 16))
                                .foregroundColor(themeManager.currentTheme.onBackground)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(themeManager.currentTheme.secondary.opacity(0.05))
                                .cornerRadius(12)
                        } else {
                            // 空白内容区域
                            Text("")
                                .frame(height: 50)
                                .frame(maxWidth: .infinity)
                                .background(themeManager.currentTheme.secondary.opacity(0.05))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.top, 8)
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
                    // 根据当前动作的目标肌肉设置selectedTargetMuscleId
                    if let actionDetail = viewModel.actionDetail,
                       let firstTargetMuscle = actionDetail.target_muscles.first {
                        selectedTargetMuscleId = firstTargetMuscle.id
                    }
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("返回")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(themeManager.currentTheme.primary)
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
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.currentTheme.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(themeManager.currentTheme.onBackground)
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
            print("🔍 目标肌肉数量: \(detail.target_muscles.count)")
            print("🔍 目标肌肉: \(detail.target_muscles.map { $0.display_name })")
            print("🔍 设备: \(detail.equipment?.display_name ?? "无")")
            print("🔍 身体部位: \(detail.bodypart?.display_name ?? "无")")
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
    @Previewable @State var selectedTargetMuscleId = 1
    
    return NavigationView {
        ActionDetailView(
            action: Action(
                id: 1,
                external_id: "1",
                name: "腹轮滚动",
                name_en: "Ab Wheel Rollout",
                gifUrl: "exercise_1.gif",
                description: "腹轮滚动是一个很好的核心训练动作，可以有效锻炼腹部肌肉群，提高核心稳定性。动作要求保持身体稳定，缓慢向前滚动，然后回到起始位置。",
                description_en: "Ab wheel rollout is a great core exercise",
                difficulty: "中等",
                bodypart_id: 1,
                equipment_id: 2,
                is_bilateral: false,
                target_muscle_ids: [1, 2, 3]
            ),
            selectedTargetMuscleId: $selectedTargetMuscleId
        )
    }
}
