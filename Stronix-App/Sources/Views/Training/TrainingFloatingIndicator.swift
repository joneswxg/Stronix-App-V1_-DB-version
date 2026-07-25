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
        if trainingManager.isTrainingActive {
            GeometryReader { geometry in
                Button(action: onTap) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        Image(systemName: "figure.strengthtraining.traditional").accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                            Text("training.floating.active").font(DesignTokens.Typography.label)
                            Text(trainingManager.formattedTrainingTime()).font(DesignTokens.Typography.feedback).monospacedDigit()
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "line.3.horizontal").accessibilityHidden(true)
                    }
                    .foregroundStyle(tokens.onPrimary)
                    .padding(DesignTokens.Spacing.medium)
                    .frame(minWidth: 150, minHeight: DesignTokens.Metric.minimumTapSize)
                    .background(tokens.primary)
                    .clipShape(Capsule())
                }
                .fixedSize(horizontal: false, vertical: true)
                .position(x: xPosition(in: geometry), y: yPosition(in: geometry))
                .offset(dragOffset)
                .gesture(dragGesture(geometry))
                .accessibilityLabel("training.accessibility.floatingLabel")
                .accessibilityValue(trainingManager.formattedTrainingTime())
                .accessibilityHint("training.accessibility.floatingHint")
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func dragGesture(_ geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let width: CGFloat = 150
                let height: CGFloat = 56
                let x = min(max(width / 2 + padding, xPosition(in: geometry) + value.translation.width), geometry.size.width - width / 2 - padding)
                let y = min(max(height / 2 + padding, yPosition(in: geometry) + value.translation.height), geometry.size.height - height / 2 - padding - (isKeyboardVisible ? 240 : 80))
                lastDragPosition = CGSize(width: x - (geometry.size.width - width / 2 - padding), height: y - (geometry.size.height - height / 2 - padding - (isKeyboardVisible ? 80 : 0)))
                withAnimation(.spring()) { dragOffset = .zero }
            }
    }

    private func xPosition(in geometry: GeometryProxy) -> CGFloat { geometry.size.width - 75 - padding + lastDragPosition.width }
    private func yPosition(in geometry: GeometryProxy) -> CGFloat { geometry.size.height - 28 - padding - (isKeyboardVisible ? 260 : 80) + lastDragPosition.height }
}
