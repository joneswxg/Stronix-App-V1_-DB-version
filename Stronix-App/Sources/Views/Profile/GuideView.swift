import SwiftUI

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    @State private var selectedGuide: GuideItem?
    
    let guideItems: [GuideItem] = [
        GuideItem(
            id: 1,
            title: "快速开始",
            subtitle: "了解应用基本功能",
            icon: "play.circle.fill",
            color: .blue,
            content: """
            欢迎使用 STRONIX 健身应用！

            🏋️‍♂️ 主要功能：
            • 训练计划管理
            • 动作库浏览
            • 训练记录追踪
            • 历史数据分析
            • 个人资料管理

            📱 快速上手：
            1. 浏览动作库，了解各种训练动作
            2. 创建个人训练计划
            3. 开始训练并记录数据
            4. 查看训练历史和进度

            💡 小贴士：
            建议先完善个人信息，这样可以获得更准确的训练建议。
            """
        ),
        GuideItem(
            id: 2,
            title: "创建训练计划",
            subtitle: "制定个性化训练方案",
            icon: "list.bullet.rectangle.portrait.fill",
            color: .green,
            content: """
            如何创建有效的训练计划：

            📋 步骤指南：
            1. 点击"计划"标签页
            2. 选择"创建计划"
            3. 输入计划名称和描述
            4. 从动作库中添加训练动作
            5. 设置每个动作的组数和次数
            6. 保存计划

            🎯 计划建议：
            • 新手：每周3次，全身训练
            • 进阶：每周4-5次，分部位训练
            • 高级：每周6次，精细化训练

            ⚠️ 注意事项：
            • 合理安排休息时间
            • 循序渐进增加强度
            • 注意动作标准性
            """
        ),
        GuideItem(
            id: 3,
            title: "训练记录",
            subtitle: "记录每次训练数据",
            icon: "chart.line.uptrend.xyaxis",
            color: .orange,
            content: """
            如何正确记录训练数据：

            📊 记录要点：
            • 每组的重量和次数
            • 组间休息时间
            • 训练感受和备注
            • 完成情况标记

            🔄 训练流程：
            1. 选择训练计划
            2. 点击"开始训练"
            3. 按顺序完成每个动作
            4. 实时记录数据
            5. 结束训练并保存

            📈 数据价值：
            • 追踪训练进度
            • 调整训练强度
            • 发现训练规律
            • 制定下阶段目标
            """
        ),
        GuideItem(
            id: 4,
            title: "动作库使用",
            subtitle: "学习正确的训练动作",
            icon: "figure.strengthtraining.traditional",
            color: .purple,
            content: """
            如何有效使用动作库：

            🎯 浏览方式：
            • 按身体部位分类浏览
            • 使用搜索功能快速查找
            • 查看动作演示动图
            • 阅读详细动作说明

            📚 学习建议：
            • 先学习基础动作
            • 注意动作要领
            • 观察动作轨迹
            • 了解目标肌群

            ⚡ 添加到计划：
            • 点击动作卡片
            • 查看详细信息
            • 点击"添加到计划"
            • 选择目标训练计划
            """
        ),
        GuideItem(
            id: 5,
            title: "数据分析",
            subtitle: "查看训练历史和进度",
            icon: "chart.bar.fill",
            color: .red,
            content: """
            如何分析训练数据：

            📊 历史记录：
            • 查看训练日历
            • 分析训练频率
            • 对比不同时期数据
            • 识别训练模式

            📈 进度追踪：
            • 重量进步曲线
            • 训练容量变化
            • 身体数据变化
            • 目标完成情况

            🎯 数据应用：
            • 调整训练计划
            • 设定新的目标
            • 发现薄弱环节
            • 优化训练策略
            """
        ),
        GuideItem(
            id: 6,
            title: "常见问题",
            subtitle: "解决使用中的疑问",
            icon: "questionmark.circle.fill",
            color: .cyan,
            content: """
            常见问题解答：

            ❓ 如何修改训练计划？
            在计划详情页点击"编辑计划"即可修改。

            ❓ 训练数据丢失怎么办？
            数据会自动保存到云端，重新登录即可恢复。

            ❓ 如何分享训练记录？
            在训练完成页面点击分享按钮。

            ❓ 忘记密码怎么办？
            在登录页面点击"忘记密码"进行重置。

            ❓ 如何联系客服？
            在设置页面找到"意见反馈"功能。

            💡 更多帮助：
            如有其他问题，请通过应用内反馈功能联系我们。
            """
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(guideItems) { item in
                        GuideCard(item: item) {
                            selectedGuide = item
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(theme.background)
            .navigationTitle("操作指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedGuide) { guide in
            GuideDetailView(guide: guide)
        }
    }
}

// 指南项目数据模型
struct GuideItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let content: String
}

// 指南卡片
struct GuideCard: View {
    @Environment(\.theme) private var theme: AppTheme
    let item: GuideItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: item.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(item.color)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                    
                    Text(item.subtitle)
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
            .shadow(color: theme.shadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 指南详情视图
struct GuideDetailView: View {
    @Environment(\.theme) private var theme: AppTheme
    let guide: GuideItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题区域
                    HStack(spacing: 16) {
                        Image(systemName: guide.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(guide.color)
                            .cornerRadius(16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(guide.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(theme.onSurface)
                            
                            Text(guide.subtitle)
                                .font(.system(size: 16))
                                .foregroundColor(theme.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 内容区域
                    Text(guide.content)
                        .font(.system(size: 16))
                        .lineSpacing(6)
                        .foregroundColor(theme.onSurface)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }
            .background(theme.background)
            .navigationTitle(guide.title)
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

#Preview {
    GuideView()
}