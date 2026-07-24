import SwiftUI

struct ProfileMainView: View {
    @State private var showLogin = false
    @State private var showUserInfo = false
    @State private var showSettings = false
    @State private var showArticles = false
    @State private var showTools = false
    @State private var showGuide = false
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.theme) private var theme: AppTheme
    
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
            .shadow(color: theme.secondary.opacity(0.1), radius: 1, y: 1)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 用户信息区域
                    VStack(spacing: 16) {
                        // 头像和用户信息
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(theme.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userSession.currentUser?.username ?? "未登录")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(theme.onSurface)
                                
                                if !userSession.isAuthenticated {
                                    Text("点击登录")
                                        .font(.system(size: 14))
                                        .foregroundColor(theme.primary)
                                }
                            }
                            
                            Spacer()
                            
                            if !userSession.isAuthenticated {
                                Button(action: {
                                    showLogin = true
                                }) {
                                    Text("登录")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(theme.onPrimary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(theme.primary)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(20)
                        .background(theme.surface)
                        .cornerRadius(16)
                        .shadow(color: theme.onSurface.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    // 功能菜单区域
                    VStack(spacing: 16) {
                        // 第一组功能
                        VStack(spacing: 12) {
                            ProfileMenuItem(
                                icon: "person.circle",
                                title: "用户信息",
                                subtitle: "身体数据、个人资料"
                            ) {
                                showUserInfo = true
                            }
                            
                            ProfileMenuItem(
                                icon: "wrench.and.screwdriver",
                                title: "小工具",
                                subtitle: "1RM计算器、其他工具"
                            ) {
                                showTools = true
                            }
                        }
                        
                        // 第二组功能
                        VStack(spacing: 12) {
                            ProfileMenuItem(
                                icon: "gearshape",
                                title: "设置",
                                subtitle: "语言、界面风格"
                            ) {
                                showSettings = true
                            }
                            
                            ProfileMenuItem(
                                icon: "questionmark.circle",
                                title: "操作指南",
                                subtitle: "使用教程、帮助文档"
                            ) {
                                showGuide = true
                            }
                            
                            ProfileMenuItem(
                                icon: "square.and.arrow.up",
                                title: "分享应用",
                                subtitle: "推荐给朋友"
                            ) {
                                shareApp()
                            }
                        }
                        
                        // 退出登录按钮（仅在已登录时显示）
                        if userSession.isAuthenticated {
                            Button(action: {
                                logout()
                            }) {
                                Text("退出登录")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.error)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.error, lineWidth: 1)
                                )
                                    .cornerRadius(12)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .background(theme.background)
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showUserInfo) {
            UserInfoView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showArticles) {
            ArticlesView()
        }
        .sheet(isPresented: $showTools) {
            ToolsView()
        }
        .sheet(isPresented: $showGuide) {
            GuideView()
        }
    }
    
    private func logout() {
        Task {
            do {
                try await userSession.logout()
            } catch {
                // Keep the authenticated state when the protected session cannot be cleared.
            }
        }
    }
    
    private func shareApp() {
        // 分享功能实现
        print("分享应用")
    }
}

// 个人资料菜单项
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @Environment(\.theme) private var theme: AppTheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.primary)
                    .frame(width: 40, height: 40)
                    .background(theme.primary.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.onSurface)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
            }
            .padding(16)
            .background(theme.surface)
            .cornerRadius(12)
            .shadow(color: theme.onSurface.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileMainView()
        .environmentObject(
            UserSession(
                operations: AuthenticationUseCases(
                    repository: SQLiteAuthRepository(),
                    sessionStore: InMemoryLocalSessionStore()
                )
            )
        )
}
