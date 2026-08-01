import SwiftUI

struct StartupGatePresentation {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let isLoading: Bool
    let blockReason: DatabaseStartupBlockReason?

    init(state: AppStartupState) {
        switch state {
        case .preparingDatabase:
            title = "正在准备本地数据"
            message = "正在验证和准备本地数据库…"
            isLoading = true
            blockReason = nil
        case .restoringSession:
            title = "正在恢复登录状态"
            message = "正在安全恢复您的本地登录状态…"
            isLoading = true
            blockReason = nil
        case .ready:
            title = ""
            message = ""
            isLoading = false
            blockReason = nil
        case .blocked(let reason):
            title = ""
            message = ""
            isLoading = false
            blockReason = reason
        }
    }
}

struct StartupGateView: View {
    let state: AppStartupState
    let retry: () -> Void
    let markVisible: () -> Void

    @State private var hasMarkedVisible = false
    @Environment(\.designTokens) private var tokens

    private var presentation: StartupGatePresentation {
        StartupGatePresentation(state: state)
    }

    var body: some View {
        Group {
            if let reason = presentation.blockReason {
                DatabaseStartupBlockedView(reason: reason, retry: retry)
            } else {
                VStack(spacing: DesignTokens.Spacing.xLarge) {
                    Image("StronixLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)

                    Text("STRONIX")
                        .font(.title.bold())
                        .foregroundStyle(tokens.primary)

                    ContentStateView(
                        kind: .loading,
                        symbol: "",
                        title: presentation.title,
                        message: presentation.message
                    )
                    .frame(maxHeight: 200)
                }
                .padding(DesignTokens.Spacing.xLarge)
            }
        }
        .background(tokens.canvas.ignoresSafeArea())
        .accessibilityIdentifier("startup-gate")
        .task {
            guard !hasMarkedVisible else { return }
            hasMarkedVisible = true
            markVisible()
        }
    }
}
