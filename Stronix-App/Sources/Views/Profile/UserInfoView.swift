import SwiftUI

struct UserInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var height = "175"
    @State private var weight = "70"
    @State private var age = "25"
    @State private var gender = "男"
    @State private var fitnessGoal = "增肌"
    
    let genderOptions = ["男", "女"]
    let goalOptions = ["增肌", "减脂", "塑形", "力量训练", "耐力训练"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 头像区域
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Button("更换头像") {
                            // 更换头像功能
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 20)
                    
                    // 基本信息
                    VStack(spacing: 16) {
                        Text("基本信息")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            UserInfoRow(title: "身高", value: $height, unit: "cm")
                            UserInfoRow(title: "体重", value: $weight, unit: "kg")
                            UserInfoRow(title: "年龄", value: $age, unit: "岁")
                            
                            // 性别选择
                            HStack {
                                Text("性别")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 60, alignment: .leading)
                                
                                Picker("性别", selection: $gender) {
                                    ForEach(genderOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                            
                            // 健身目标
                            VStack(alignment: .leading, spacing: 8) {
                                Text("健身目标")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                
                                Picker("健身目标", selection: $fitnessGoal) {
                                    ForEach(goalOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 健身数据统计
                    VStack(spacing: 16) {
                        Text("健身数据")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            StatCard(title: "总训练次数", value: "0", subtitle: "次")
                            StatCard(title: "总训练时长", value: "0", subtitle: "小时")
                            StatCard(title: "总训练容量", value: "0", subtitle: "kg")
                            StatCard(title: "连续训练天数", value: "0", subtitle: "天")
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 保存按钮
                    Button(action: {
                        saveUserInfo()
                    }) {
                        Text("保存信息")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(white: 0.95))
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
    
    private func saveUserInfo() {
        // 保存用户信息
        dismiss()
    }
}

// 用户信息行
struct UserInfoRow: View {
    let title: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 60, alignment: .leading)
            
            TextField("请输入\(title)", text: $value)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Text(unit)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    UserInfoView()
} 