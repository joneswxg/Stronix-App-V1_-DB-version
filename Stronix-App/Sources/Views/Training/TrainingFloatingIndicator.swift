import SwiftUI

/// 训练进行中的浮动指示器
struct TrainingFloatingIndicator: View {
    @ObservedObject var trainingManager = TrainingSessionManager.shared
    let onTap: () -> Void
    
    var body: some View {
        if trainingManager.isTrainingActive {
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: onTap) {
                        HStack(spacing: 8) {
                            // 训练图标
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("训练进行中")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text(trainingManager.formattedTrainingTime())
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            // 箭头图标
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 100) // 避免被底部导航栏遮挡
            }
            .allowsHitTesting(false) // 禁用整个VStack的点击事件，避免干扰其他UI
            .background(
                // 只有按钮区域可以接收点击
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Color.clear
                            .frame(width: 150, height: 50) // 按钮的大致尺寸
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTap()
                            }
                            .padding(.trailing, 16)
                    }
                    .padding(.bottom, 100)
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: trainingManager.isTrainingActive)
        }
    }
}

#Preview {
    // 预览代码暂时注释，等待类型定义完成
    Text("TrainingFloatingIndicator Preview")
} 