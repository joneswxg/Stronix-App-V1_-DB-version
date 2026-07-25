import SwiftUI

struct QuickStartTrainingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))
            
            Text("开发中")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.gray)
            
            Text("快速训练功能正在开发中，敬请期待")
                .font(.system(size: 16))
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .navigationTitle("快速训练")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        QuickStartTrainingView()
    }
} 