import SwiftUI

struct StatisticsView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("统计功能开发中...")
                .font(.title2)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.95))
        .navigationTitle("统计")
        .navigationBarHidden(true)
    }
}

#Preview {
    StatisticsView()
} 