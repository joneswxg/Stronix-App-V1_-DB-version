import SwiftUI

struct UserInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    @EnvironmentObject private var userSession: UserSession
    private var rows: [UserInfoRowPresentation] {
        UserInfoPresentation(user: userSession.currentUser).rows
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(theme.primary)
                        .padding(.top, 20)

                    VStack(spacing: 16) {
                        Text("基本信息")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            ForEach(rows) { row in
                                ProfileInfoRow(title: row.title, value: row.value)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Text("当前版本暂不支持修改个人资料")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                        .padding(.bottom, 30)
                }
            }
            .background(theme.background)
            .navigationTitle("用户信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct UserInfoRowPresentation: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let value: String
}

struct UserInfoPresentation: Equatable {
    let rows: [UserInfoRowPresentation]

    init(user: User?) {
        rows = [
            UserInfoRowPresentation(title: "用户名", value: user?.username ?? "未填写"),
            UserInfoRowPresentation(title: "注册邮箱", value: user?.email ?? "未填写"),
            UserInfoRowPresentation(title: "性别", value: user?.gender ?? "未填写")
        ]
    }
}

struct ProfileInfoRow: View {
    @Environment(\.theme) private var theme: AppTheme
    let title: String
    let value: String
    var unit: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.onSurface)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 16))
                .foregroundColor(theme.onSurface)

            if let unit {
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.surface)
        .cornerRadius(12)
    }
}

// 统计卡片
struct StatCard: View {
    @Environment(\.theme) private var theme: AppTheme
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow, radius: 4, x: 0, y: 2)
    }
}

#Preview {
    UserInfoView()
        .environmentObject(
            UserSession(
                operations: AuthenticationUseCases(
                    repository: SQLiteAuthRepository(),
                    sessionStore: InMemoryLocalSessionStore()
                )
            )
        )
}
