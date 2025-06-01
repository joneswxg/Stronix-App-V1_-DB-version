import SwiftUI
import UIKit

// 简化的GIF显示组件
struct GIFView: UIViewRepresentable {
    let url: URL
    @State private var hasLoaded = false
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.clear
        imageView.clipsToBounds = true
        return imageView
    }
    
    func updateUIView(_ imageView: UIImageView, context: Context) {
        // 异步加载GIF数据
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("GIF加载失败: \(error?.localizedDescription ?? "未知错误")")
                return
            }
            
            DispatchQueue.main.async {
                // 尝试创建动画图片
                if let animatedImage = UIImage.gif(data: data) {
                    imageView.image = animatedImage
                    print("GIF动画加载成功: \(url.absoluteString)")
                } else if let staticImage = UIImage(data: data) {
                    // 如果GIF动画失败，显示静态图片
                    imageView.image = staticImage
                    print("静态图片加载成功: \(url.absoluteString)")
                } else {
                    print("图片加载完全失败: \(url.absoluteString)")
                }
            }
        }.resume()
    }
}

// UIImage扩展，支持GIF
extension UIImage {
    static func gif(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("无法创建CGImageSource")
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            print("不是动画GIF，帧数: \(count)")
            return nil
        }
        
        var images: [UIImage] = []
        var duration: Double = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)
                
                // 获取每帧的持续时间
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                   let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                    duration += frameDuration
                } else {
                    duration += 0.1 // 默认持续时间
                }
            }
        }
        
        guard !images.isEmpty else {
            print("没有成功解析任何帧")
            return nil
        }
        
        print("成功解析GIF: \(images.count)帧, 总时长: \(duration)秒")
        return UIImage.animatedImage(with: images, duration: duration)
    }
}

struct ActionDetailView: View {
    let action: ActionListView.Action
    @Environment(\.dismiss) private var dismiss
    @State private var showFallback = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 动作GIF区域
                VStack {
                    if showFallback {
                        // 备用AsyncImage显示
                        AsyncImage(url: URL(string: "http://localhost:6000/api/action/images/\(action.image_url)")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                        Text("加载中...")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                        .frame(height: 300)
                    } else {
                        // 主要的GIF显示
                        if let url = URL(string: "http://localhost:6000/api/action/images/\(action.image_url)") {
                            GIFView(url: url)
                                .frame(height: 300)
                        } else {
                            Rectangle()
                                .fill(Color.red.opacity(0.2))
                                .frame(height: 300)
                                .overlay(
                                    Text("URL错误")
                                        .foregroundColor(.red)
                                )
                        }
                    }
                    
                    // 调试信息和切换按钮
                    VStack(spacing: 8) {
                       
                        Button(action: {
                            showFallback.toggle()
                        }) {
                            Text(showFallback ? "切换动态模式" : "切换静态模式")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 8)
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // 动作名称
                VStack(alignment: .leading, spacing: 16) {
                    Text(action.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 指导部分
                    VStack(alignment: .leading, spacing: 12) {
                        Text("指导")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InstructionStep(
                                number: 1,
                                text: "双手握住腹轮把手，跪在地板上。"
                            )
                            
                            InstructionStep(
                                number: 2,
                                text: "将腹轮放在膝盖前方的地板上。这是您的起始位置。"
                            )
                            
                            InstructionStep(
                                number: 3,
                                text: "缓慢地向前滚动轮子，以受控的方式伸展躯干，尽可能远地伸展，而不让身体接触地板。"
                            )
                            
                            InstructionStep(
                                number: 4,
                                text: "完全伸展时停止并暂停片刻。"
                            )
                            
                            InstructionStep(
                                number: 5,
                                text: "通过收缩腹肌将自己拉回到起始位置。"
                            )
                        }
                    }
                    .padding(.top, 8)
                    
                    // 视频链接部分
                    VStack(alignment: .leading, spacing: 12) {
                        Text("视频教程")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Button(action: {
                            // TODO: 打开视频链接
                        }) {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("观看详细视频教程")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    Text("专业教练指导，标准动作演示")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(16)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 占位文字
                        Text("视频链接将在后续版本中更新")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.8))
                            .italic()
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

#Preview {
    NavigationView {
        ActionDetailView(action: ActionListView.Action(
            id: 1,
            name: "腹轮滚动",
            name_en: "Ab Wheel Rollout",
            image_url: "exercise_1.gif",
            body_part_id: 1,
            equipment_id: 2,
            target_muscle_ids: [1, 2, 3]
        ))
    }
} 
