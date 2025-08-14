import SwiftUI

/// 训练进行中的浮动指示器
struct TrainingFloatingIndicator: View {
    @ObservedObject var trainingManager = TrainingSessionManager.shared
    let onTap: () -> Void
    @Environment(\.theme) private var theme: AppTheme
    let keyboardManager: CustomKeyboardManager?
    
    // 拖拽位置状态
    @State private var dragOffset = CGSize.zero
    @State private var lastDragPosition = CGSize.zero
    
    // 计算键盘是否可见
    private var isKeyboardVisible: Bool {
        keyboardManager?.isShowing ?? false
    }
    
    // 屏幕边界
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    private let indicatorWidth: CGFloat = 150
    private let indicatorHeight: CGFloat = 50
    private let padding: CGFloat = 16
    
    var body: some View {
        if trainingManager.isTrainingActive {
            floatingIndicatorView
        }
    }
    
    // MARK: - 视图组件
    
    private var floatingIndicatorView: some View {
        GeometryReader { geometry in
            draggableButton(geometry: geometry)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: trainingManager.isTrainingActive)
        .animation(.easeInOut(duration: 0.3), value: isKeyboardVisible)
    }
    
    private func draggableButton(geometry: GeometryProxy) -> some View {
        Button(action: onTap) {
            buttonContent
        }
        .frame(width: indicatorWidth, height: indicatorHeight)
        .position(
            x: calculateXPosition(in: geometry),
            y: calculateYPosition(in: geometry)
        )
        .offset(dragOffset)
        .gesture(dragGesture(geometry: geometry))
    }
    
    private var buttonContent: some View {
        HStack(spacing: 8) {
            trainingIcon
            trainingInfo
            dragIcon
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(buttonBackground)
        .cornerRadius(25)
        .shadow(color: theme.onSurface.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var trainingIcon: some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(theme.onPrimary)
    }
    
    private var trainingInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("训练进行中")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.onPrimary)
            
            Text(trainingManager.formattedTrainingTime())
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(theme.onPrimary.opacity(0.9))
        }
    }
    
    private var dragIcon: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(theme.onPrimary.opacity(0.8))
    }
    
    private var buttonBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [theme.primary, theme.primary.opacity(0.8)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                handleDragEnd(value: value, geometry: geometry)
            }
    }
    
    private func handleDragEnd(value: DragGesture.Value, geometry: GeometryProxy) {
        // 计算最终位置
        let finalX = calculateXPosition(in: geometry) + value.translation.width
        let finalY = calculateYPosition(in: geometry) + value.translation.height
        
        // 限制在屏幕边界内
        let constrainedX = max(indicatorWidth/2 + padding, 
                             min(geometry.size.width - indicatorWidth/2 - padding, finalX))
        let constrainedY = max(indicatorHeight/2 + padding + 100, // 顶部安全区域
                             min(geometry.size.height - indicatorHeight/2 - padding - (isKeyboardVisible ? 250 : 100), finalY))
        
        // 更新最后位置
        lastDragPosition = CGSize(
            width: constrainedX - geometry.size.width + indicatorWidth/2 + padding,
            height: constrainedY - geometry.size.height + indicatorHeight/2 + (isKeyboardVisible ? 250 : 100) + padding
        )
        
        // 重置拖拽偏移
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = .zero
        }
    }
    
    // MARK: - 位置计算方法
    
    /// 计算X轴位置
    private func calculateXPosition(in geometry: GeometryProxy) -> CGFloat {
        // 默认位置在右侧，考虑拖拽偏移
        let defaultX = geometry.size.width - indicatorWidth/2 - padding
        return defaultX + lastDragPosition.width
    }
    
    /// 计算Y轴位置
    private func calculateYPosition(in geometry: GeometryProxy) -> CGFloat {
        // 默认位置在底部，键盘显示时上移
        let bottomOffset: CGFloat = isKeyboardVisible ? 280 : 100
        let defaultY = geometry.size.height - indicatorHeight/2 - bottomOffset - padding
        return defaultY + lastDragPosition.height
    }
}

#Preview {
    // 预览代码暂时注释，等待类型定义完成
    Text("TrainingFloatingIndicator Preview")
}