import SwiftUI

struct ManageHistoryRecordsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
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
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
                
                // 内容区域
                VStack {
                    Spacer()
                    Image(systemName: "tray.full")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    Text("管理历史记录功能开发中...")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.95))
            }
            .navigationBarHidden(true)
        }
        .overlay(
            // 关闭按钮
            VStack {
                HStack {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
            }
        )
    }
}

#Preview {
    ManageHistoryRecordsView()
} 