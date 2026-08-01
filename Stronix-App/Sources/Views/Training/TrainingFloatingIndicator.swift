import SwiftUI

struct TrainingFloatingIndicator: View {
    @ObservedObject var trainingManager = TrainingSessionManager.shared
    let onTap: () -> Void
    @Environment(\.designTokens) private var tokens
    let keyboardManager: CustomKeyboardManager?
    @State private var dragOffset = CGSize.zero
    @State private var lastDragPosition = CGSize.zero

    private var isKeyboardVisible: Bool { keyboardManager?.isShowing ?? false }
    private let padding: CGFloat = DesignTokens.Spacing.large

    var body: some View {
        if trainingManager.isTrainingActive && trainingManager.showRestTimer {
            GeometryReader { geometry in
                Button(action: onTap) {
                    ZStack {
                        Circle()
                            .stroke(tokens.primary.opacity(0.2), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(tokens.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(restTimerText(trainingManager.currentRestTime))
                            .font(DesignTokens.Typography.feedback)
                            .monospacedDigit()
                    }
                    .foregroundStyle(tokens.contentPrimary)
                    .frame(width: 76, height: 76)
                    .background(tokens.surface)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(tokens.border, lineWidth: DesignTokens.Metric.borderWidth) }
                }
                .position(x: xPosition(in: geometry), y: yPosition(in: geometry))
                .offset(dragOffset)
                .gesture(dragGesture(geometry))
                .accessibilityLabel("training.accessibility.restTimer")
                .accessibilityValue(restTimerText(trainingManager.currentRestTime))
                .accessibilityHint("training.accessibility.floatingHint")
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var progress: CGFloat {
        guard trainingManager.currentRestDuration > 0 else { return 0 }
        return min(1, CGFloat(trainingManager.currentRestTime) / CGFloat(trainingManager.currentRestDuration))
    }

    private func dragGesture(_ geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let width: CGFloat = 76
                let height: CGFloat = 76
                let x = min(max(width / 2 + padding, xPosition(in: geometry) + value.translation.width), geometry.size.width - width / 2 - padding)
                let y = min(max(height / 2 + padding, yPosition(in: geometry) + value.translation.height), geometry.size.height - height / 2 - padding - (isKeyboardVisible ? 240 : 80))
                lastDragPosition = CGSize(width: x - (geometry.size.width - width / 2 - padding), height: y - (geometry.size.height - height / 2 - padding - (isKeyboardVisible ? 80 : 0)))
                withAnimation(.spring()) { dragOffset = .zero }
            }
    }

    private func xPosition(in geometry: GeometryProxy) -> CGFloat { geometry.size.width - 38 - padding + lastDragPosition.width }
    private func yPosition(in geometry: GeometryProxy) -> CGFloat { geometry.size.height - 38 - padding - (isKeyboardVisible ? 260 : 80) + lastDragPosition.height }
}
