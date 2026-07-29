import SwiftUI
import UIKit
import ImageIO

struct GIFImageView: UIViewRepresentable {
    let imagePath: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        guard context.coordinator.imagePath != imagePath else { return }

        context.coordinator.imagePath = imagePath
        context.coordinator.requestID += 1
        let requestID = context.coordinator.requestID
        imageView.image = UIImage(systemName: "figure.strengthtraining.traditional")
        imageView.tintColor = .gray

        guard let url = ActionImageResourceLocator().bundledGIFURL(for: imagePath) else { return }
        let coordinator = context.coordinator
        DispatchQueue.global(qos: .userInitiated).async { [weak imageView] in
            guard let data = try? Data(contentsOf: url),
                  let image = Self.createAnimatedImage(from: data) else { return }
            DispatchQueue.main.async {
                guard coordinator.requestID == requestID, coordinator.imagePath == imagePath else { return }
                imageView?.image = image
            }
        }
    }

    static func dismantleUIView(_ imageView: UIImageView, coordinator: Coordinator) {
        coordinator.requestID += 1
        imageView.stopAnimating()
        imageView.image = nil
    }

    static func createAnimatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
            let gifProperties = properties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            totalDuration += gifProperties?[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1
        }

        guard !images.isEmpty else { return nil }
        return images.count == 1 ? images[0] : UIImage.animatedImage(with: images, duration: totalDuration)
    }

    final class Coordinator {
        var imagePath: String?
        var requestID = 0
    }
}

struct GIFThumbnailImageView: UIViewRepresentable {
    let imagePath: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        let displayScale = imageView.traitCollection.displayScale
        guard context.coordinator.imagePath != imagePath || context.coordinator.displayScale != displayScale else { return }

        context.coordinator.imagePath = imagePath
        context.coordinator.displayScale = displayScale
        context.coordinator.requestID += 1
        let requestID = context.coordinator.requestID
        imageView.image = UIImage(systemName: "figure.strengthtraining.traditional")
        imageView.tintColor = .gray

        guard let url = ActionImageResourceLocator().bundledGIFURL(for: imagePath) else { return }
        let coordinator = context.coordinator
        let maximumPixelSize = ceil(50 * displayScale)
        DispatchQueue.global(qos: .userInitiated).async { [weak imageView] in
            guard let image = Self.createThumbnail(from: url, maximumPixelSize: maximumPixelSize, scale: displayScale) else { return }
            DispatchQueue.main.async {
                guard coordinator.requestID == requestID, coordinator.imagePath == imagePath else { return }
                imageView?.image = image
            }
        }
    }

    static func dismantleUIView(_ imageView: UIImageView, coordinator: Coordinator) {
        coordinator.requestID += 1
        imageView.stopAnimating()
        imageView.image = nil
    }

    static func createThumbnail(from url: URL, maximumPixelSize: CGFloat, scale: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }

    final class Coordinator {
        var imagePath: String?
        var displayScale: CGFloat?
        var requestID = 0
    }
}

struct AnimatedImageView: View {
    let imagePath: String

    var body: some View {
        GIFImageView(imagePath: imagePath)
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
                    AnimatedImageView(imagePath: action.localImageName)
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
                    // 直接返回，不修改selectedTargetMuscleId
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
