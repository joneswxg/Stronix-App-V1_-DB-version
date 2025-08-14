import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var selectedLanguage = "中文"
    
    let languages = ["中文", "English"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 显示设置
                    VStack(spacing: 16) {
                        Text("显示设置")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            // 语言设置
                            SettingRow(title: "语言", subtitle: "Language") {
                                Picker("语言", selection: $selectedLanguage) {
                                    ForEach(languages, id: \.self) { language in
                                        Text(language)
                                            .foregroundColor(language == "English" ? theme.secondary.opacity(0.5) : theme.onSurface)
                                            .tag(language)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .disabled(selectedLanguage == "English")
                            }
                            
                            // 颜色方案设置
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("颜色方案")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(theme.onSurface)
                                        
                                        Text("Color Scheme")
                                            .font(.system(size: 14))
                                            .foregroundColor(theme.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Picker("颜色方案", selection: $themeManager.currentThemeType) {
                                    ForEach(ThemeType.allCases, id: \.self) { themeType in
                                        Text(themeType.displayName).tag(themeType)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .onChange(of: themeManager.currentThemeType) { _, newTheme in
                                    themeManager.setTheme(newTheme)
                                }
                            }
                            .padding(16)
                            .background(theme.surface)
                            .cornerRadius(12)
                            .shadow(color: theme.shadow, radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 通知设置
                    VStack(spacing: 16) {
                        Text("通知设置")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            SettingToggleRow(
                                title: "推送通知",
                                subtitle: "接收训练提醒和更新通知",
                                isOn: $notificationManager.notificationsEnabled
                            )
                            
                            SettingToggleRow(
                                title: "声音提醒",
                                subtitle: "训练时的声音提示",
                                isOn: $notificationManager.soundEnabled
                            )
                            
                            SettingToggleRow(
                                title: "震动反馈",
                                subtitle: "操作时的触觉反馈",
                                isOn: $notificationManager.vibrationEnabled
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 数据设置
                    VStack(spacing: 16) {
                        Text("数据设置")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            SettingActionRow(
                                title: "清除缓存",
                                subtitle: "清除应用缓存数据",
                                icon: "trash"
                            ) {
                                clearCache()
                            }
                            
                            SettingActionRow(
                                title: "重置应用",
                                subtitle: "恢复到初始状态",
                                icon: "arrow.clockwise",
                                isDestructive: true
                            ) {
                                resetApp()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 关于
                    VStack(spacing: 16) {
                        Text("关于")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            SettingInfoRow(title: "版本", value: "1.0.0")
                            SettingInfoRow(title: "构建号", value: "2025.01.01")
                            
                            SettingActionRow(
                                title: "隐私政策",
                                subtitle: "查看隐私政策",
                                icon: "doc.text"
                            ) {
                                openPrivacyPolicy()
                            }
                            
                            SettingActionRow(
                                title: "用户协议",
                                subtitle: "查看用户协议",
                                icon: "doc.text"
                            ) {
                                openUserAgreement()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .background(theme.background)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(theme.primary)
                }
            }
        }
    }
    
    private func exportData() {
        print("导出数据")
    }
    
    private func clearCache() {
        print("清除缓存")
    }
    
    private func resetApp() {
        print("重置应用")
    }
    
    private func openPrivacyPolicy() {
        print("打开隐私政策")
    }
    
    private func openUserAgreement() {
        print("打开用户协议")
    }
}

// 设置行组件
struct SettingRow<Content: View>: View {
    @Environment(\.theme) private var theme: AppTheme
    let title: String
    let subtitle: String
    let content: Content
    
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.onSurface)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
            }
            
            Spacer()
            
            content
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow, radius: 4, x: 0, y: 2)
    }
}

// 开关设置行
struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

// 操作设置行
struct SettingActionRow: View {
    @Environment(\.theme) private var theme: AppTheme
    let title: String
    let subtitle: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDestructive ? theme.error : theme.onSurface)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                }
                
                Spacer()
                
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? theme.error : theme.primary)
            }
            .padding(16)
            .background(theme.surface)
            .cornerRadius(12)
            .shadow(color: theme.shadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 信息设置行
struct SettingInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        SettingRow(title: title, subtitle: value) {
            EmptyView()
        }
    }
}

#Preview {
    SettingsView()
}