import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            BodyMeasurementTabView()
                .tabItem {
                    Image(systemName: "figure.mixed.cardio")
                    Text("体测")
                }
            ActionListView()
                .tabItem {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("动作")
                }
            PlanListView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("训练")
                }
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("历史")
                }
            ProfileMainView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("其他")
                }
        }
    }
}

// 占位视图，后续可替换为实际页面
struct HistoryView: View { 
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
    MainTabView()
} 
