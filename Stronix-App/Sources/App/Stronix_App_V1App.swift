import SwiftUI

@main
struct Stronix_App_V1App: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var userSession: UserSession
    @StateObject private var startupCoordinator: AppStartupCoordinator

    init() {
        let repository = SQLiteAuthRepository()
        let useCases = AuthenticationUseCases(
            repository: repository,
            sessionStore: KeychainLocalSessionStore()
        )
        let userSession = UserSession(operations: useCases)
        _userSession = StateObject(wrappedValue: userSession)
        _startupCoordinator = StateObject(
            wrappedValue: AppStartupCoordinator(
                database: DatabaseManager.shared,
                arguments: ProcessInfo.processInfo.arguments,
                session: userSession
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch startupCoordinator.state {
                case .ready:
                    MainTabView()
                        .id(userSession.scopeID)
                        .accessibilityIdentifier("first-interactive-gateway")
                default:
                    StartupGateView(
                        state: startupCoordinator.state,
                        retry: {
                            Task { await startupCoordinator.retry() }
                        },
                        markVisible: startupCoordinator.markStartupUIVisible
                    )
                }
            }
            .withAppTheme()
            .environmentObject(userSession)
            .task {
                guard !Self.isRunningUnitTests else { return }
                await startupCoordinator.start()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard !Self.isRunningUnitTests else { return }
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("📱 应用进入后台")
            TrainingSessionManager.shared.handleAppDidEnterBackground()
        case .active:
            print("📱 应用变为活跃状态")
            TrainingSessionManager.shared.handleAppDidBecomeActive()
        case .inactive:
            print("📱 应用变为非活跃状态")
        @unknown default:
            break
        }
    }
}

struct DatabaseStartupBlockedView: View {
    let reason: DatabaseStartupBlockReason
    let retry: () -> Void

    var body: some View {
        ContentStateView(
            kind: contentStateKind,
            symbol: "externaldrive.badge.exclamationmark",
            title: title,
            message: message,
            actionTitle: reason.permitsRetry ? "重试" : nil,
            action: reason.permitsRetry ? retry : nil
        )
    }

    private var contentStateKind: ContentStateKind {
        reason == .incompatibleSchema ? .warning : .error
    }

    private var title: LocalizedStringKey {
        switch reason {
        case .incompatibleSchema:
            "本地数据库需要更新"
        case .recoverablePreparationFailure:
            "本地数据库准备失败"
        case .unrecoverableRecoveryFailure:
            "无法恢复本地数据库"
        }
    }

    private var message: LocalizedStringKey {
        switch reason {
        case .incompatibleSchema:
            "本地数据库由较新版本的 App 创建，请更新 App 后再继续使用。"
        case .recoverablePreparationFailure:
            "本地数据库准备失败，请重试或联系支持。"
        case .unrecoverableRecoveryFailure:
            "为了保护本地数据，App 已停止启动。请联系支持。"
        }
    }
}
