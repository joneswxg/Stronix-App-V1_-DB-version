import SwiftUI

struct BodyMeasurementTabView: View {
    @Environment(\.theme) private var theme: AppTheme
    @State private var selectedTab = 0
    
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
                    .foregroundColor(theme.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surface)
            .shadow(color: theme.shadow, radius: 1, y: 1)
            
            // 顶部Tab导航
            HStack(spacing: 0) {
                TabButton(title: "概览", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "查看更多", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(title: "变化", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                TabButton(title: "饮食营养", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }
            .background(theme.surface)
            .shadow(color: theme.shadow, radius: 1, y: 1)
            
            // 内容区域
            VStack {
                if selectedTab == 0 {
                    BodyMeasurementOverview()
                } else if selectedTab == 1 {
                    BodyMeasurementDetail()
                } else if selectedTab == 2 {
                    BodyMeasurementChange()
                } else if selectedTab == 3 {
                    NutritionView()
                } else {
                    BodyMeasurementOverview()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// 自定义Tab按钮组件
struct TabButton: View {
    @Environment(\.theme) private var theme: AppTheme
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? theme.primary : theme.secondary)
                
                Rectangle()
                    .fill(isSelected ? theme.primary : Color.clear)
                    .frame(height: 2)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    BodyMeasurementTabView()
}