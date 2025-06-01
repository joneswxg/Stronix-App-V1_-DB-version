import SwiftUI

struct ArticlesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var articles: [Article] = [
        Article(id: 1, title: "健身新手必读：如何制定训练计划", summary: "详细介绍健身新手如何科学制定训练计划，避免常见误区", publishDate: "2025-01-15", category: "训练指导"),
        Article(id: 2, title: "蛋白质摄入指南：增肌期间的营养策略", summary: "深入解析增肌期间的蛋白质需求量和最佳摄入时机", publishDate: "2025-01-12", category: "营养指导"),
        Article(id: 3, title: "正确的深蹲技巧：避免膝盖受伤", summary: "详细讲解深蹲的正确姿势和常见错误，保护膝关节健康", publishDate: "2025-01-10", category: "动作指导"),
        Article(id: 4, title: "减脂期间如何保持肌肉量", summary: "科学的减脂策略，在减少体脂的同时最大程度保持肌肉", publishDate: "2025-01-08", category: "减脂指导"),
        Article(id: 5, title: "睡眠对健身效果的重要性", summary: "探讨充足睡眠对肌肉恢复和训练表现的关键作用", publishDate: "2025-01-05", category: "恢复指导")
    ]
    
    @State private var selectedCategory = "全部"
    let categories = ["全部", "训练指导", "营养指导", "动作指导", "减脂指导", "恢复指导"]
    
    var filteredArticles: [Article] {
        if selectedCategory == "全部" {
            return articles
        } else {
            return articles.filter { $0.category == selectedCategory }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分类筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryButton(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
                .background(Color.white)
                
                // 文章列表
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredArticles) { article in
                            ArticleCard(article: article) {
                                openArticle(article)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(Color(white: 0.95))
            }
            .navigationTitle("科普文章")
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
    
    private func openArticle(_ article: Article) {
        // 打开微信公众号文章链接
        print("打开文章: \(article.title)")
    }
}

// 文章数据模型
struct Article: Identifiable {
    let id: Int
    let title: String
    let summary: String
    let publishDate: String
    let category: String
}

// 分类按钮
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

// 文章卡片
struct ArticleCard: View {
    let article: Article
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题和分类
                HStack {
                    Text(article.category)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text(article.publishDate)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // 文章标题
                Text(article.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 文章摘要
                Text(article.summary)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                
                // 底部信息
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text("微信公众号")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ArticlesView()
} 