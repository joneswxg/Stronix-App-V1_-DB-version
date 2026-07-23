import SwiftUI

struct AuthForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "lock.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("暂不支持密码重置")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("此设备上的本地账户暂不支持密码重置。请使用原密码登录或联系支持人员。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("返回登录") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .navigationTitle("重置密码")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AuthForgotPasswordView()
}
