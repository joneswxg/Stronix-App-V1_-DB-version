import SwiftUI

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""
    @State private var planNote = ""
    @State private var showActionSelect = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 计划名称输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("计划名称")
                        .font(.system(size: 14, weight: .medium))
                    TextField("输入计划名称", text: $planName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 16)
                
                // 备注输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("计划描述")
                        .font(.system(size: 14, weight: .medium))
                    TextField("添加计划描述", text: $planNote, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                .padding(.horizontal, 16)
                
                // 添加动作按钮
                Button(action: {
                    showActionSelect = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加动作")
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.97))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("创建计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        // TODO: 保存计划
                        dismiss()
                    }
                    .disabled(planName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showActionSelect) {
            PlanActionSelectView()
        }
    }
}

#Preview {
    CreatePlanView()
} 