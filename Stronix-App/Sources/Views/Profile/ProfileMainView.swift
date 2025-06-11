import SwiftUI

struct ProfileMainView: View {
    @State private var showLogin = false
    @State private var showUserInfo = false
    @State private var showSettings = false
    @State private var showArticles = false
    @State private var showTools = false
    @State private var showGuide = false
    @ObservedObject private var authService = AuthService.shared
    
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
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 用户信息区域
                    VStack(spacing: 16) {
                        // 头像和用户信息
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authService.currentUser?.username ?? "未登录")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                if !authService.isLoggedIn {
                                    Text("点击登录")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            if !authService.isLoggedIn {
                                Button(action: {
                                    showLogin = true
                                }) {
                                    Text("登录")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
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
                                icon: "doc.text",
                                title: "科普文章",
                                subtitle: "健身知识、营养指导"
                            ) {
                                showArticles = true
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
                        if authService.isLoggedIn {
                            Button(action: {
                                logout()
                            }) {
                                Text("退出登录")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red, lineWidth: 1)
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
            .background(Color(white: 0.95))
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
        authService.logout()
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
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileMainView()
} 
