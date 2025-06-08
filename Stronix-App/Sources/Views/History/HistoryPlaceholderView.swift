import SwiftUI

// 原有的占位视图，保留作为参考
struct HistoryPlaceholderView: View {
    var body: some View {
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
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
            
            // 内容区域
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("历史记录")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                Text("功能开发中...")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.95))
        }
    }
}

#Preview {
    HistoryPlaceholderView()
} 